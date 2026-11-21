# Build sandbox job format (for the job author, e.g. ChatGPT)

Drop one folder per job into the inbox:

```
<inbox>\<job-name>\          job-name: letters, digits, _ . - (max 64)
    job.json                 what to run (schema below)
    src\                     your source tree (no symlinks/junctions, <= 2 GB, <= 100000 files)
    READY                    create this LAST, after everything else is written
```

Results appear in `<outbox>\<job-name>-<runId>\`; wait for the `DONE` file there, then read:
`summary.json` (pass/fail, exit codes, toolchain versions), `steps\NN-<step>.stdout.log` /
`.stderr.log`, `runner.log`, `artifacts\`, and `host\` (orchestrator logs).

## Environment each step gets

- Ubuntu (WSL2) Linux, **not Windows**. Toolchains: `gcc`/`g++`, `clang++`, `cmake`, `ninja`,
  `x86_64-w64-mingw32-g++` (Windows .exe cross-compiles; cannot be run), `python3` + `pytest`,
  `dotnet` (C#; SDK version in `summary.json`).
- **No network.** Vendor dependencies into `src\`: NuGet `.nupkg` files in `src\nuget-packages\`
  (used automatically as the only NuGet source), Python wheels installed with
  `pip install --no-index --find-links <dir>` into a venv, C/C++ headers alongside your code.
- Runs as unprivileged user `builder`; root filesystem is read-only.
- Writable: `$SANDBOX_SRC` (copy of `src\`, cwd by default), `$HOME`, `/tmp`, `$SANDBOX_ARTIFACTS`.
- `$SANDBOX_DEVTOOLS` = host DevTools folder, **read-only**.
- Files in `src\` arrive without the executable bit: run scripts as `sh build.sh` / `python3 x.py`,
  or `chmod +x` them in an earlier step.
- Nothing persists between jobs; every job starts from the same clean image.

## job.json

```json
{
  "schemaVersion": 1,
  "timeoutSeconds": 900,
  "continueOnFailure": false,
  "steps": [
    {
      "name": "build",
      "executable": "g++",
      "arguments": ["-O2", "-o", "%ARTIFACTS%/app", "main.cpp"],
      "workingDirectory": ".",
      "timeoutSeconds": 120,
      "expectedExitCodes": [0]
    }
  ]
}
```

- `executable`: a name on PATH, a path relative to `src` containing `/`, or an absolute path.
- `arguments`: an exact argument array; no shell is involved. Use `sh -c "..."` only if you need one.
- Tokens expanded in `executable`/`arguments`: `%SRC%`, `%WORKSPACE%`, `%ARTIFACTS%`, `%DEVTOOLS%`.
- `workingDirectory`: relative to `src`, no `..`.
- Limits: job 30–14400 s, 1–64 steps, each step 1..job timeout, 256 arguments of at most 8192 characters.
- Unknown fields are rejected.

See `job.json` and `src\` beside this file for a complete C++/Python/C# example.
