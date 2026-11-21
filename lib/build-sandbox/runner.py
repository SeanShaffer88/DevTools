#!/usr/bin/env python3
"""Guest job runner for the disposable WSL2 build sandbox (New-BuildSandbox.ps1).

Runs as root inside a throwaway distro imported from the golden image; never on a host
or a distro you use. Every job step runs as the unprivileged 'builder' user inside fresh
PID/mount/IPC/UTS/network namespaces with a read-only root filesystem. Writable space is
limited to size-capped tmpfs mounts (/workspace, /tmp, /sandbox/results). The host DevTools
folder is mounted read-only at /workspace/devtools. stdout/stderr of every step are logged.
"""
import argparse
import datetime
import json
import os
import pwd
import shutil
import signal
import stat
import subprocess
import sys
import time
import traceback

BUILDER = "builder"
WORKSPACE = "/workspace"
RESULTS = "/sandbox/results"
IMAGE_MARKER = "/etc/build-sandbox-image.json"
SAFE_PATH = "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
STEP_TMP_MB = 512
PROBE_TIMEOUT = 120
TOOL_PROBES = {
    "gcc": ["gcc", "--version"],
    "clang++": ["clang++", "--version"],
    "mingw-w64-g++": ["x86_64-w64-mingw32-g++", "--version"],
    "cmake": ["cmake", "--version"],
    "ninja": ["ninja", "--version"],
    "python3": ["python3", "--version"],
    "pytest": ["python3", "-m", "pytest", "--version"],
    "dotnet": ["dotnet", "--version"],
}
# Each step: private mounts, fresh /tmp, WSLg display/audio sockets (/mnt/wslg) and the
# cross-distro shared /mnt/wsl hidden, read-only root, then drop to builder for good.
STEP_PRELUDE = (
    "set -e; mount --make-rprivate /; "
    "mount -t tmpfs -o size={tmp}m,mode=1777,nosuid,nodev tmpfs /tmp; "
    "for d in /mnt/wslg /mnt/wsl; do if [ -d $d ]; then mount -t tmpfs -o size=1m,mode=0555 tmpfs $d; fi; done; "
    # .NET keeps named-mutex shared memory under the passwd home, not $HOME: make it the writable home.
    "mount --bind {home} {passwd_home}; "
    "mount -o remount,bind,ro /; "
    'exec setpriv --reuid={uid} --regid={gid} --init-groups --no-new-privs -- "$@"'
)


def utcnow():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def check(argv):
    return subprocess.run(argv, check=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)


def contained(base, relative):
    full = os.path.realpath(os.path.join(base, relative))
    if full != base and not full.startswith(base + os.sep):
        raise ValueError(f"path escapes {base}: {relative}")
    return full


class Context:
    def __init__(self, args, uid, gid, passwd_home):
        self.uid, self.gid, self.passwd_home = uid, gid, passwd_home
        self.allow_network = args.allow_network
        self.src = os.path.join(WORKSPACE, "src")
        self.devtools = os.path.join(WORKSPACE, "devtools") if args.devtools else ""
        self.artifacts = os.path.join(RESULTS, "artifacts")
        self.steps_dir = os.path.join(RESULTS, "steps")
        self.env = {
            "PATH": SAFE_PATH,
            "HOME": os.path.join(WORKSPACE, "home"),
            "USER": BUILDER,
            "LOGNAME": BUILDER,
            "LANG": "C.UTF-8",
            "TMPDIR": "/tmp",
            "DOTNET_CLI_TELEMETRY_OPTOUT": "1",
            "DOTNET_NOLOGO": "1",
            "DOTNET_SKIP_FIRST_TIME_EXPERIENCE": "1",
            "PIP_DISABLE_PIP_VERSION_CHECK": "1",
            "PYTHONDONTWRITEBYTECODE": "1",
            "PYTHONUNBUFFERED": "1",
            "SANDBOX_WORKSPACE": WORKSPACE,
            "SANDBOX_SRC": self.src,
            "SANDBOX_DEVTOOLS": self.devtools,
            "SANDBOX_ARTIFACTS": self.artifacts,
        }

    def expand(self, value):
        for token, path in (("%WORKSPACE%", WORKSPACE), ("%SRC%", self.src),
                            ("%DEVTOOLS%", self.devtools), ("%ARTIFACTS%", self.artifacts)):
            value = value.replace(token, path)
        return value

    def sandbox_argv(self, command):
        namespaces = ["unshare", "--mount", "--pid", "--fork", "--kill-child", "--mount-proc", "--ipc", "--uts"]
        if not self.allow_network:
            namespaces.append("--net")
        prelude = STEP_PRELUDE.format(tmp=STEP_TMP_MB, uid=self.uid, gid=self.gid,
                                      home=self.env["HOME"], passwd_home=self.passwd_home)
        return namespaces + ["--", "/bin/sh", "-c", prelude, "sandbox-step"] + command


def run_sandboxed(ctx, command, cwd, stdout, stderr, timeout):
    """Returns (exit_code, timed_out). Kills the whole PID namespace on timeout."""
    proc = subprocess.Popen(ctx.sandbox_argv(command), cwd=cwd, env=ctx.env, stdin=subprocess.DEVNULL,
                            stdout=stdout, stderr=stderr, start_new_session=True)
    try:
        return proc.wait(timeout=timeout), False
    except subprocess.TimeoutExpired:
        os.killpg(proc.pid, signal.SIGKILL)
        return proc.wait(), True


def probe_toolchains(ctx):
    found = {}
    for name, command in TOOL_PROBES.items():
        try:
            out = subprocess.run(ctx.sandbox_argv(command), cwd=ctx.src, env=ctx.env, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                                 timeout=PROBE_TIMEOUT, start_new_session=True)
            lines = [line.strip() for line in out.stdout.splitlines() if line.strip()]
            found[name] = {"available": out.returncode == 0, "detail": lines[0] if lines else ""}
        except (OSError, subprocess.TimeoutExpired) as exc:
            found[name] = {"available": False, "detail": f"{type(exc).__name__}: {exc}"}
    return found


def run_step(index, step, ctx, deadline):
    base = f"{index:02d}-{step['name']}"
    out_path = os.path.join(ctx.steps_dir, base + ".stdout.log")
    err_path = os.path.join(ctx.steps_dir, base + ".stderr.log")
    record = {"name": step["name"], "startedUtc": utcnow(), "exitCode": None, "timedOut": False,
              "passed": False, "durationSeconds": 0.0, "stdout": os.path.relpath(out_path, RESULTS),
              "stderr": os.path.relpath(err_path, RESULTS), "error": None}
    started = time.monotonic()
    try:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise TimeoutError("job deadline reached before step start")
        timeout = min(step["timeoutSeconds"], remaining)
        cwd = contained(ctx.src, step.get("workingDirectory") or ".")
        executable = ctx.expand(step["executable"])
        if "/" in executable and not executable.startswith("/"):
            executable = contained(ctx.src, executable)
        arguments = [ctx.expand(a) for a in step.get("arguments") or []]
        with open(out_path, "wb") as so, open(err_path, "wb") as se:
            code, timed_out = run_sandboxed(ctx, [executable] + arguments, cwd, so, se, timeout)
        record["exitCode"], record["timedOut"] = code, timed_out
        record["passed"] = not timed_out and code in step.get("expectedExitCodes", [0])
    except Exception as exc:  # recorded per step; the job continues or stops per policy
        record["error"] = f"{type(exc).__name__}: {exc}"
    record["durationSeconds"] = round(time.monotonic() - started, 3)
    return record


def write_offline_nuget_config(ctx):
    """No network: drop nuget.org; use the image's offline feed plus vendored src/nuget-packages."""
    sources = [("image-offline", "/opt/nuget-offline"), ("vendored", os.path.join(ctx.src, "nuget-packages"))]
    source = "".join(f'    <add key="{key}" value="{path}" />\n' for key, path in sources if os.path.isdir(path))
    config_dir = os.path.join(ctx.env["HOME"], ".nuget", "NuGet")
    os.makedirs(config_dir, exist_ok=True)
    with open(os.path.join(config_dir, "NuGet.Config"), "w", encoding="utf-8") as fh:
        fh.write('<?xml version="1.0" encoding="utf-8"?>\n<configuration>\n  <packageSources>\n'
                 f'    <clear />\n{source}  </packageSources>\n</configuration>\n')


def mount_devtools(windows_path, target):
    os.makedirs(target, exist_ok=True)
    check(["mount", "-t", "drvfs", windows_path, target, "-o", "ro,nosuid,nodev"])
    probe = os.path.join(target, ".build-sandbox-write-probe")
    try:
        open(probe, "w").close()
    except OSError:
        return True
    os.unlink(probe)
    subprocess.run(["umount", "-l", target])
    raise RuntimeError("DevTools mount accepted a write; refusing to run untrusted steps.")


def sanitize_tree(root):
    """Drop symlinks and special files so nothing in results can point outside it."""
    removed = []
    for dirpath, dirnames, filenames in os.walk(root, topdown=True, followlinks=False):
        for name in list(dirnames):
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                os.unlink(path)
                dirnames.remove(name)
                removed.append(os.path.relpath(path, root))
        for name in filenames:
            path = os.path.join(dirpath, name)
            if not stat.S_ISREG(os.lstat(path).st_mode):
                os.unlink(path)
                removed.append(os.path.relpath(path, root))
    return removed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--inbox", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--devtools")
    parser.add_argument("--workspace-mb", type=int, default=4096)
    parser.add_argument("--results-mb", type=int, default=1024)
    parser.add_argument("--allow-network", action="store_true")
    parser.add_argument("--sandbox-acknowledged", action="store_true")
    args = parser.parse_args()
    if not args.sandbox_acknowledged or os.geteuid() != 0 or not os.path.isfile(IMAGE_MARKER):
        print("runner must run as root inside a build-sandbox distro", file=sys.stderr)
        return 125

    summary = {"schemaVersion": 1, "startedUtc": utcnow(), "finishedUtc": None, "passed": False,
               "network": "enabled" if args.allow_network else "disabled", "devtoolsMounted": False,
               "image": None, "toolchains": {}, "steps": [], "removedFromResults": [], "error": None}
    exit_code = 125
    os.makedirs(RESULTS, exist_ok=True)
    log_file = None
    devtools_target = os.path.join(WORKSPACE, "devtools")
    try:
        check(["mount", "-t", "tmpfs", "-o", f"size={args.results_mb}m,mode=0755,nosuid,nodev", "tmpfs", RESULTS])
        log_file = open(os.path.join(RESULTS, "runner.log"), "a", encoding="utf-8")

        def note(message):
            line = f"[{utcnow()}] {message}"
            print(line, flush=True)
            log_file.write(line + "\n")
            log_file.flush()

        with open(IMAGE_MARKER, encoding="utf-8") as fh:
            summary["image"] = json.load(fh)
        builder = pwd.getpwnam(BUILDER)
        ctx = Context(args, builder.pw_uid, builder.pw_gid, builder.pw_dir)

        note("Locking job inbox (root-owned, read-only to builder)")
        check(["chown", "-R", "root:root", args.inbox])
        check(["chmod", "-R", "go-w", args.inbox])
        with open(os.path.join(args.inbox, "job.json"), encoding="utf-8") as fh:
            job = json.load(fh)
        deadline = time.monotonic() + job["timeoutSeconds"]

        note(f"Mounting {args.workspace_mb} MB tmpfs workspace")
        os.makedirs(WORKSPACE, exist_ok=True)
        check(["mount", "-t", "tmpfs", "-o", f"size={args.workspace_mb}m,mode=0755,nosuid,nodev", "tmpfs", WORKSPACE])
        shutil.copytree(os.path.join(args.inbox, "src"), ctx.src, symlinks=True)
        for path in (ctx.env["HOME"], ctx.artifacts, ctx.steps_dir):
            os.makedirs(path, exist_ok=True)
        if not args.allow_network:
            write_offline_nuget_config(ctx)
        check(["chown", "-R", f"{BUILDER}:{BUILDER}", ctx.src, ctx.env["HOME"], ctx.artifacts])

        if args.devtools:
            note("Mounting host DevTools read-only at /workspace/devtools")
            summary["devtoolsMounted"] = mount_devtools(args.devtools, devtools_target)

        note("Probing toolchains")
        summary["toolchains"] = probe_toolchains(ctx)

        all_passed = True
        for index, step in enumerate(job["steps"], start=1):
            note(f"Step {index}: {step['name']}")
            record = run_step(index, step, ctx, deadline)
            summary["steps"].append(record)
            note(f"Step {index} exit={record['exitCode']} timedOut={record['timedOut']} passed={record['passed']}"
                 + (f" error={record['error']}" if record["error"] else ""))
            if not record["passed"]:
                all_passed = False
                if not job.get("continueOnFailure", False):
                    break
        summary["passed"] = all_passed and len(summary["steps"]) == len(job["steps"])
        exit_code = 0 if summary["passed"] else 2
    except Exception as exc:
        summary["error"] = f"{type(exc).__name__}: {exc}"
        traceback.print_exc()
        if log_file:
            log_file.write(traceback.format_exc())
    finally:
        summary["finishedUtc"] = utcnow()
        if log_file:
            log_file.close()
        if os.path.ismount(devtools_target):
            subprocess.run(["umount", "-l", devtools_target])
        try:
            summary["removedFromResults"] = sanitize_tree(RESULTS)
        except OSError as exc:
            summary["error"] = summary["error"] or f"sanitize failed: {exc}"
        with open(os.path.join(RESULTS, "summary.json"), "w", encoding="utf-8") as fh:
            json.dump(summary, fh, indent=2)
        if os.path.exists(args.out):
            shutil.rmtree(args.out)
        shutil.copytree(RESULTS, args.out, symlinks=True)
        subprocess.run(["chmod", "-R", "u=rwX,go=rX", args.out])
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
