# Windows offline build isolation

This original PowerShell 7 / Win32 runner starts a process in a fresh AppContainer
with zero capabilities. Windows enforces network isolation. Ordinary descendants
inherit the container; a kill-on-close job bounds their lifetime. No firewall,
network adapter, administrator setting, or installed tool is changed.

The parent PowerShell/.NET host is an explicit bootstrap prerequisite, not a
compiler supplied by the offline payload library. `Add-Type` compiles the native
interop source in memory. The canary tests additionally use the installed Windows
.NET Framework C# compiler; its actual path and hash are retained in test evidence.

## Interface

Create a **new** disposable root with `Initialize-OfflineRoot.ps1 -Path <new-path>`,
then copy reviewed tools and sources into it. Do not use a home, repository or
installed SDK directory as the root. Run:

```powershell
pwsh -NoProfile -File development/samples/isolation/Invoke-OfflineProcess.ps1 -Request C:/Task/request.json -Result C:/Task/new-result.json
```

The trusted JSON request contains:

```json
{
  "ownedRoot": "C:/Task/build-environment",
  "executable": "C:/Task/build-environment/tools/node/node.exe",
  "arguments": ["C:/Task/build-environment/sources/build.mjs"],
  "workingDirectory": "C:/Task/build-environment/sources",
  "readOnlyRoots": ["C:/Task/build-environment/tools"],
  "writableRoots": ["C:/Task/build-environment/outputs", "C:/Task/build-environment/home"],
  "timeoutSeconds": 1200,
  "useDriveAlias": false,
  "environment": {
    "USERPROFILE": "C:/Task/build-environment/home",
    "APPDATA": "C:/Task/build-environment/home",
    "LOCALAPPDATA": "C:/Task/build-environment/home",
    "TEMP": "C:/Task/build-environment/home",
    "TMP": "C:/Task/build-environment/home",
    "PATH": "C:/Windows/System32"
  },
  "artifacts": ["C:/Task/build-environment/outputs/sample.exe"]
}
```

All executable, working, read-only, writable and artifact paths must be inside the
marked root. Linked paths, UNC/device paths and alternate streams are refused.
The whole owned root receives temporary read/execute access; selected writable
subdirectories receive modify access. Only those task-owned ACLs change. Original
ACLs are restored in reverse order and the unique profile is deleted on normal
success, failure and timeout. A per-root inherited environment is not imported:
only Windows system location variables and the explicit request environment pass.
Supply owned `USERPROFILE`, `APPDATA` and `LOCALAPPDATA` values for profile-aware
Windows runtimes; an incomplete environment can fail before process startup.

An exclusive per-root file handle prevents simultaneous operations from racing
their ACL snapshots. Contending requests fail before profile creation or ACL
changes. The zero-byte `.devtools-offline.lock` remains inside the disposable
root; it is not active after the handle closes. The lock is held through job
quiescence, ACL restoration, recursive absence checks for that run's SID,
profile deletion and result writing. A cleanup scan failure makes the run fail.

Optional `useDriveAlias: true` creates an unused **user-session** DOS drive letter
that points only to this owned root. This lets tools query their drive root
without granting access to the physical volume root. The helper refuses SYSTEM
context, existing letters and foreign mappings. No system broadcast or persistent
volume mapping is used. Declared executable/cwd/path arguments and path-valued
environment entries are translated; arbitrary argument text and config-file
contents are not rewritten. A child orchestrator can use `DEVTOOLS_DRIVE_ALIAS`
and `DEVTOOLS_PHYSICAL_ROOT` to translate its reviewed configuration paths.
Original physical paths remain the authority for validation, ACLs and hashing.

The per-root lock and a cooperative user-session mutex protect mapping lifetime.
Cleanup removes only the exact raw target created by this run, after the job,
ACL/profile cleanup, and verifies the letter has no remaining definition. Raw
target and cleanup status are recorded. A host failure can leave this alias;
remove only its recorded exact mapping, never another user's existing mapping.

The runner does not invoke a shell. It records actual token AppContainer status,
capability count, exit code, timeout, stdout/stderr, expected-artifact hashes,
observed job quiescence and cleanup results. Result and logs refuse overwrite.
Exit 0 means process success plus cleanup; exit 2 means an operation/cleanup failure.
Preflight validation failures exit nonzero before creating a profile.

## Verification

```powershell
pwsh -NoProfile -File development/samples/isolation/Test-OfflineIsolation.ps1 -WorkDirectory C:/Task/new-canary
pwsh -NoProfile -File development/samples/isolation/Test-OfflineFailures.ps1 -WorkDirectory C:/Task/new-negative-tests
pwsh -NoProfile -File development/samples/isolation/Test-OfflineConcurrency.ps1 -WorkDirectory C:/Task/new-concurrency-test
pwsh -NoProfile -File development/samples/isolation/Test-OfflineAlias.ps1 -WorkDirectory C:/Task/new-alias-test
```

The live canary connects to an owned loopback listener outside the container,
then the same probe inside the container and its ordinary child attempt the same
endpoint. A second outside control proves the listener remains reachable.
Nonce receipts identify the successful control connections; no inside connection
may reach the listener. Both inside tokens must be AppContainers with no
capabilities. A three-second application timeout is recorded separately from a
native socket error: no invented Winsock error is reported. Negative tests cover
outside-root/junction rejection, native argument quoting and timeout tree cleanup.

The concurrency regression overlaps two real runner invocations on one root,
requires the second to reject before security state changes, and verifies the
first terminates its job, restores original ACLs and leaves no ACE for its unique
SID anywhere under that root. Recursive ACL scanning is bounded to 200,000
entries and refuses linked entries instead of following them.

Limits: timeout 1–1800 seconds, request 1 MiB, 512 arguments, Windows command line
32766 characters. Output files are sampled every 100 ms and the job is terminated
when either exceeds 64 MiB; this is an observed limit with possible overshoot,
not an OS disk quota. Job termination is followed by an active-process-count
check before cleanup. This is a trusted build runner, not a general hostile-code
VM. Regular AppContainer system-resource access remains available.

Abrupt parent termination can leave the profile and temporary ACL entries; no
`finally` block can promise cleanup after host/process failure. The non-inherited
job handle still closes when its owner exits and Windows terminates its members.
Keep the task root disposable and retain the unique profile/SID from evidence.

Primary API basis:
- https://learn.microsoft.com/en-us/windows/win32/secauthz/implementing-an-appcontainer
- https://learn.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-initializeprocthreadattributelist
- https://learn.microsoft.com/en-us/windows/win32/procthread/job-objects
