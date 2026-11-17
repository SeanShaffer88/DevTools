# DevToolsCommon: shared hardened helpers

`lib/DevToolsCommon.psm1` (+ `lib/DevToolsProcess.cs`) consolidates boilerplate that the toolkit re-implements in `lib/QualityCommon.ps1`, `lib/PlatformResources.ps1`, `lib/RuntimeCommon.ps1`, `lib/WindowsDiagnosticsCommon.ps1`, `lib/ReliabilityNativeCommon.ps1`, `lib/AndroidProcess.cs` and inline in `Test-Package.ps1`, `Test-WowAddon.ps1`, `Get-DevReference.ps1`, `Compare-DevBuild.ps1` and `Resolve-NativeDependencies.ps1`.

New helpers should import this module. Migrate old helpers one at a time, each with its own test suite.

**Migrated:** `Compare-DevBuild.ps1` (2026-11-17). Its parameters, result fields, exit codes 0/2/125 and manifest format are unchanged, and manifests interoperate with the previous version in both directions. Changes:

- Results add a `status` field (`Pass`/`Changed`/`SetupError`).
- Error text is redacted.
- Capture paths containing `..` segments are now refused even when they resolve inside the root.
- Manifests with a string `schemaVersion`, non-integer sizes or malformed hashes are now rejected.

**Migrated:** `Test-Package.ps1` (2026-11-17). Its JSON output is byte-identical to the previous version (apart from `observedUtc`), including finding codes, severities, hash-budget fields and exit codes. Changes:

- Reserved device names in manifest paths are now refused before hashing.
- Manifests must be UTF-8 (a BOM is fine). UTF-16 manifests are no longer accepted.
- Finding messages are redacted.
- `PackagePath` and `ManifestPath` must be local drive paths, so UNC shares are refused.

**Migrated:** `Test-WowAddon.ps1` (2026-11-17). Its JSON output is byte-identical to the previous version (apart from `observedUtc`) on every repo addon fixture and on a freshly generated `WowAddon` template. Parent-relative XML includes (`..\Shared\x.xml`) that stay inside the addon still work, and TOC decoding is unchanged (lenient UTF-8, BOM-detected, so legacy Windows-1252 titles still pass). Changes:

- References whose segment ends in a dot or space (`main.lua.`) are refused as `UnsafeReference`. Previously they were silently treated as `main.lua` and passed.
- Device names (`CON.lua`) are reported as `UnsafeReference` instead of `MissingFile`.
- TOC and XML files are read with the size cap enforced on the open handle.
- TOC discovery matches the `.toc` extension exactly.
- Finding messages are redacted.
- `AddonPath` must be a local drive path.

**Migrated:** `Get-DevReference.ps1` (2026-11-17). Its JSON output is identical to the previous version for default, `-Resources`, `-Query` and `-Category` searches. All 18 existing notes and both indexes were verified as valid UTF-8 before switching to strict decoding. Changes:

- Index entries such as `note.md.` (silently read as `note.md`) and device names are refused.
- Notes and indexes that aren't valid UTF-8 are refused instead of returned with replacement characters.
- A string `schemaVersion` is refused.
- Files are read with size caps enforced on the open handle.
- Error text is redacted.
- A copy of the script needs `lib\DevToolsCommon.psm1` beside it.

All other helpers are unchanged.

```powershell
Import-Module (Join-Path $PSScriptRoot 'lib/DevToolsCommon.psm1') -Force
```

- Requires PowerShell 7.0+ on Windows; no third-party dependencies.
- Importing performs no I/O. `Invoke-DtProcess` compiles `DevToolsProcess.cs` on first use.
- Every function throws on invalid input and none calls `exit`, so the caller owns exit codes.
- Tests: `pwsh -NoProfile -File tests/Test-DevToolsCommon.ps1 [-WorkRoot <dir>]` runs 96 behaviour and adversarial checks.

---

## 1. Paths

### `Resolve-DtLocalPath -Path <string> [-Kind Any|File|Directory] [-New]`
Normalises a caller-supplied path to an absolute local path. It returns `[string]`.

- **Inputs:** absolute or CWD-relative path text. `-Kind` requires existence as that type. `-New` requires that the path does not exist and that its parent directory does.
- **Security:**
  - Refuses UNC, `\\?\` and `\\.\` device paths, including the `//` forms. This stops NTLM credential leaks to remote hosts and device-namespace tricks.
  - Refuses alternate data streams (any `:` after the drive), wildcards, control characters and `"<>|`.
  - Refuses reserved DOS device names (`CON`, `NUL`, `COM1`–`9`, `LPT1`–`9`, superscript variants, `CONIN$`) in any segment.
  - Refuses segments ending in `.` or space. Windows silently strips these, so the opened path would differ from the validated one.
  - Refuses any existing reparse point (symlink, junction, mount point) on the path or its ancestors.
  - 8.3 short names are expanded by `GetFullPath`, so containment comparisons use long names.
- **Residual risk:** time-of-check/time-of-use (TOCTOU). Someone with write access to an ancestor directory can swap in a junction after the check. Treat directories writable by other users as untrusted.

### `Resolve-DtContainedPath -Root <dir> -RelativePath <string> [-Kind …]`
Resolves an untrusted relative path (from a manifest, TOC, archive entry or config) strictly inside a trusted root.

- **Inputs:** an existing `Root`; a relative path using `/` or `\`.
- **Security:**
  - Applies every `Resolve-DtLocalPath` rule.
  - Refuses rooted paths, drive-relative paths (`C:x`) and any `..` segment.
  - Checks the prefix against `Root + separator`, so `C:\rootEvil` cannot match `C:\root`.
  - Refuses junctions or symlinks inside the root that would redirect outside it, and refuses the root itself (`.`).

### `Get-DtFileTree -Root <dir> [-MaxEntries 10000] [-MaxDepth 16] [-MaxTotalBytes 1GB] [-ExcludeDirectoryName …] [-SkipReparsePoints | -IncludeReparsePoints]`
A breadth-first, bounded file inventory. It emits `{FullName, RelativePath, Length, IsReparsePoint}`, with `/` separators in `RelativePath`.

- **Security:** entry, depth and byte caps stop DoS from huge or deep trees. Reparse entries are refused by default. `-SkipReparsePoints` skips them silently; `-IncludeReparsePoints` emits them with `IsReparsePoint=$true` so the caller can report them. In every mode, traversal never follows a link out of the tree. Inaccessible entries throw instead of being silently omitted, so coverage is never overstated.

### `New-DtRunDirectory -Parent <dir>`
Creates `<Parent>\yyyyMMddTHHmmssfffZ-<12 hex>` and returns its path.

- **Security:** the suffix comes from a CSPRNG, which defeats name prediction and collisions. The parent is validated, and the call supports `-WhatIf`.

## 2. Bounded I/O

### `Read-DtBytes -Path <file> [-MaxBytes 16MB]`
Returns `[byte[]]` without enumerating it into the pipeline.

- **Security:** the size cap is enforced on the **open handle**. The function also throws if the file grows or shrinks during the read. This closes the check-then-read memory DoS present in `Read-QJson`, `Read-PlatformJson` and `Read-DevJson`.

### `Read-DtText -Path <file> [-MaxBytes 16MB]`
Reads strict UTF-8: invalid byte sequences throw instead of becoming U+FFFD. A UTF-8 BOM is stripped.

- **Security:** stops mis-decoded input from slipping past later validation, such as an overlong encoding that hides a `/`.

### `Write-DtFileAtomic -Path <file> -Content <string|byte[]> [-Overwrite] [-MaxBytes 256MB]`
Writes a same-directory temp file (`CreateNew`, exclusive), flushes it to disk, then renames it over the target.

- **Security:**
  - The target path is validated.
  - Without `-Overwrite`, the final rename is itself no-clobber, so racing writers never overwrite each other.
  - Readers never see a partial file.
  - The temp file is removed on any failure.
  - Strings are written as UTF-8 without a BOM, and the call supports `-WhatIf`.

## 3. JSON

### `Read-DtJson -Path <file> [-MaxBytes 4MB] [-Depth 64] [-AllowNonObjectRoot] [-SchemaVersion <int>]`
Reads JSON into ordered hashtables and returns the root without enumerating it.

- **Security:** limits size, strict UTF-8 and nesting depth. The root must be an object by default. `schemaVersion` is checked as a true integer, so `"1"` and `1.0` are rejected.
- **Residual risk:** duplicate keys follow PowerShell's parser (last value wins). Do not use this function where duplicate-key smuggling matters, such as signatures.

### `ConvertTo-DtCanonicalJson -InputObject <any> [-MaxDepth 64]`
Produces deterministic compact JSON with ordinal-sorted keys. It supports dictionaries, any `IEnumerable` (arrays, `List<T>`, `ArrayList`), `PSCustomObject`, invariant-culture numbers and UTC ISO-8601 dates.

- **Security:** use it for hashing and comparing evidence. It throws on NaN or Infinity, non-string keys, unsupported types and excessive depth. This fixes `Compare-DevBuild.ps1`'s `Canon`, which sorts only `[array]` and so emits unsorted keys for lists and `PSCustomObject`.

### `Get-DtJsonPointer -InputObject <any> -Pointer <string>`
Implements RFC 6901 (`~0` and `~1` escapes) and returns `@{Exists; Value}`.

- **Security:** array indexes must be canonical decimals with no leading zeros or signs. Missing paths return `Exists=$false` instead of throwing or returning `$null` ambiguously.

## 4. Validation

| Function | Accepts | Rejects |
| --- | --- | --- |
| `Assert-DtInteger -Value -Minimum -Maximum -Name` | `int`, `long`, `short`, `byte` and `BigInteger` in range; returns `[long]` | strings, floats, bools, `$null` |
| `Assert-DtSafeName -Name [-MaxLength 64]` | `^[A-Za-z][A-Za-z0-9._-]*$` | `..`, a trailing `.`, separators, reserved device names, empty |
| `Assert-DtSha256 -Value` | exactly 64 hex characters; returns uppercase | anything else |

Security: type confusion is a common bypass, for example `"5"` passing `-ge 1`. These functions check the .NET type, not just whether the value compares as a number.

## 5. Hashing

### `Get-DtFileSha256 -Path <file> [-MaxBytes 4GB]`
Streams the file in 80 KiB chunks and returns uppercase hex.

- **Security:** a byte budget is enforced during streaming, so a file that grows mid-hash throws. Memory use stays constant, and the hash and stream objects are always disposed.

### `Get-DtTreeHash -Root <dir> [-MaxEntries] [-MaxTotalBytes] [-ExcludeDirectoryName]`
Returns `{Sha256, FileCount, TotalBytes}`, computed as SHA-256 over the canonical JSON of `{relativePath: fileSha256}`.

- **Security:** combines the tree caps with a shared byte budget. Reparse entries are refused. Hashes establish file identity, not correctness or provenance.

## 6. Processes

### `Resolve-DtExecutable -Name <absolute path | bare name>`
Resolves to a native `.exe` or `.com` file.

- **Security:**
  - A bare name is looked up on PATH only, never in the current directory, which blocks binary planting. Relative paths with separators are refused.
  - `.bat`, `.cmd` and `.ps1` are refused. `cmd.exe` re-parses batch-file arguments, so argument arrays can still be injected (the "BatBadBut" class, e.g. CVE-2024-24576). Select the interpreter and pass the script as an argument instead.
  - One exception: a Store app-execution alias (a reparse point) is accepted only directly inside `%LOCALAPPDATA%\Microsoft\WindowsApps`, and only when its ancestors are ordinary directories.

### `Invoke-DtProcess -Executable -WorkingDirectory [-ArgumentList] [-TimeoutSeconds 60] [-MaxOutputBytes 2MB] [-Environment @{}] [-CleanEnvironment] [-MaxProcessMemoryBytes 0]`
Returns `{Executable, ExitCode, TimedOut, Stdout, Stderr, StdoutTruncated, StderrTruncated, JobAssigned, DescendantsTerminated, ElapsedMilliseconds}`. A timeout returns exit code `124`. Argument values are deliberately **not** echoed back, following the toolkit rule against storing them.

- **Injection:** no shell is involved. Each `ArgumentList` element becomes exactly one argv entry through `ProcessStartInfo.ArgumentList`. The tests pass `&calc`, `| whoami`, `$(whoami)`, `%PATH%`, embedded quotes, trailing backslashes and empty strings through unchanged. NUL characters, more than 4096 arguments and command lines over 32,000 characters are refused.
- **Hangs and deadlocks:**
  - Stdin is closed at once.
  - Stdout and stderr are drained concurrently. A full pipe would otherwise block the child forever.
  - Waits are hard-bounded.
- **Memory:** each stream keeps at most `MaxOutputBytes`. Excess output is read and discarded rather than buffered, and truncation is reported exactly. `-MaxProcessMemoryBytes` sets a per-process commit cap through the Job Object.
- **Process leaks:**
  - The child is assigned to a kill-on-close Job Object.
  - On timeout, the whole job is terminated.
  - If the root exits while a descendant still holds the pipes, the job is terminated after 5 s and `DescendantsTerminated` is set.
  - If anything throws, the job is terminated and its handle closed.
  - The existing `AndroidProcess.cs` and `PlatformResources.cs` instead throw and leave such descendants running.
- **Secrets in the environment:** `-CleanEnvironment` starts the child with only `SystemRoot`, `windir`, `SystemDrive`, `TEMP`, `TMP`, `PATH`, `PATHEXT`, `NUMBER_OF_PROCESSORS`, `PROCESSOR_ARCHITECTURE` and `OS`, plus anything in `-Environment`. Tokens in the parent environment are not inherited. Environment variable names are validated and values must not contain NUL.
- **Residual risk:**
  - This is **not a sandbox**: the child runs with your full user rights.
  - A descendant spawned in the microseconds before job assignment can escape.
  - Children of **Store/MSIX-packaged apps** (including Store-installed `pwsh.exe`) break away from jobs by OS policy. If such a child keeps the pipes open, the call throws with an explicit message and the child may keep running.
  - Output is decoded as lossy UTF-8.

## 7. Results and redaction

### `New-DtResult -Tool [-Scope]` / `Add-DtFinding -Result -Code -Message [-Severity Info|Warning|Error] [-Path]` / `Complete-DtResult -Result -ExitCode [-ErrorRecord] [-Json]`
These create and fill the toolkit's `schemaVersion: 1` envelope. Exit codes map to statuses as follows: `0` Pass, `2` Fail, `3` Unknown, `124` TimedOut, anything else SetupError.

- **Security:**
  - Finding codes must match `^[A-Za-z][A-Za-z0-9.]{0,63}$`.
  - Messages, paths and error text pass through `Protect-DtText` before storage.
  - The number of findings is capped at 10,000.
  - `Complete-DtResult` never calls `exit`. By contrast, `Finish-RN` in `ReliabilityNativeCommon.ps1` exits the host when dot-sourced interactively.

### `Protect-DtText -Text <string> [-MaxChars 16M]`
Redacts the following:

- PEM private keys
- GitHub tokens (`ghp_`, `gho_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`)
- `sk-…` and `sk-ant-…` API keys
- AWS `AKIA` and `ASIA` access keys
- Slack `xox?-` tokens
- JWTs
- `Bearer` and `Basic` credentials
- `scheme://user:pass@` URL credentials
- `password`, `secret`, `token`, `api_key`, `client_secret` and `access_key` in `key=value` or `key: value` form
- The user-profile path, replaced with `%USERPROFILE%`

- **Security:** all regexes are bounded and run with a 2 s timeout, so crafted input cannot cause catastrophic backtracking (ReDoS). Input length is capped.
- **Residual risk:** pattern matching is best effort and cannot prove text is secret-free. Binary dumps and screenshots cannot be sanitised this way. Review evidence before sharing it.

---

## Audit of the existing duplicated helpers (not modified)

These defects were confirmed by probes or by reading the code. They are listed for a later, deliberate migration.

| Location | Issue | Severity | Fixed in module by |
| --- | --- | --- | --- |
| `lib/QualityCommon.ps1` `Assert-QPath`, `lib/PlatformResources.ps1` `Assert-PlatformPath` | Accept `C:\x\a.txt:stream` (ADS), `CON.txt`, and `x.`, which is silently rewritten to `x` (probe-confirmed) | Medium | `Resolve-DtLocalPath` |
| `lib/WindowsDiagnosticsCommon.ps1` `Assert-DevNewDestination` | Accepts reserved device names such as `CON.txt` (probe-confirmed) | Low | `Resolve-DtLocalPath -New` |
| `Read-QJson`, `Read-PlatformJson`, `lib/RuntimeCommon.ps1` `Read-DevJson` | Size checked by `Get-Item`, then read separately (TOCTOU memory DoS if the file grows); `Read-DevJson` has no reparse check and no pinned encoding | Medium | `Read-DtBytes` / `Read-DtJson` |
| `lib/AndroidProcess.cs`, `lib/PlatformResources.cs` | Stdin is inherited, so children prompting for input hang until timeout; a descendant holding the pipes causes a throw and is **left running** | Medium | `Invoke-DtProcess` (Job Object) |
| `lib/AndroidProcess.cs` | `Truncated` is reported when output is exactly the limit (false positive) | Low | exact truncation tracking |
| `Compare-DevBuild.ps1` (**migrated**) | Previously: `Canon` treated only `[array]` as a list; `-OutputPath …\CON.json` returned exit 0 and wrote to the console device, leaving a stray temp file; trailing-dot input `x.` silently recorded `x`; `schemaVersion: "1"` was accepted (all reproduced before the migration, refused after) | Medium | migrated onto the module |
| `lib/ReliabilityNativeCommon.ps1` `Finish-RN` | Calls `exit` inside a library function | Low | `Complete-DtResult` |
| `Test-Package.ps1` (**migrated**) | Previously: manifest path `data/CON.txt` was accepted and the package hashed; invalid UTF-8 manifests were loosely decoded and accepted; error messages exposed the full profile path (all reproduced before the migration, refused or redacted after) | Low | migrated onto the module |
| `Test-WowAddon.ps1` (**migrated**) | Previously: TOC/XML references like `main.lua.` were silently treated as `main.lua` and the addon passed; `CON.lua` was misreported as missing; TOC/XML size was checked before a separate read; error messages exposed the profile path (all reproduced before the migration, refused or redacted after) | Low | migrated onto the module |
| `Get-DevReference.ps1` (**migrated**) | Previously: index entry `note.md.` silently read `note.md`; invalid UTF-8 notes were returned with replacement characters; string `schemaVersion` was accepted; errors exposed the profile path (all reproduced before the migration, refused or redacted after) | Low | migrated onto the module |
| `No-Reparse`, `Finding` and `Inside` copied into 3 scripts | Behaviour drifted between copies | Maintainability | **resolved**: all three scripts now use the module |
