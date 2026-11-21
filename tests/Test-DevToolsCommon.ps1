#requires -Version 7.0
<#
.SYNOPSIS  Behaviour and adversarial tests for lib/DevToolsCommon.psm1.
.PARAMETER WorkRoot  Parent for a unique fixture directory (default: the user temp directory).
.NOTES     Creates a junction (no elevation needed) and starts pwsh/ping children. Exit 0 = all passed.
#>
[CmdletBinding()]
param([string]$WorkRoot = [IO.Path]::GetTempPath())
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'lib/DevToolsCommon.psm1') -Force

$fixture = [IO.Path]::GetFullPath((Join-Path $WorkRoot ('dtcommon-' + [Guid]::NewGuid().ToString('N'))))
$null = New-Item -ItemType Directory -Path $fixture
$script:passed = 0
$script:failed = [Collections.Generic.List[string]]::new()

function Check([string]$Name, [scriptblock]$Body) {
    try { if (& $Body) { $script:passed++ } else { $script:failed.Add($Name) } }
    catch { $script:failed.Add("$Name :: $($_.Exception.Message)") }
}
function Throws([string]$Name, [scriptblock]$Body) {
    try { $null = & $Body; $script:failed.Add("$Name :: did not throw") }
    catch { $script:passed++ }
}

try {
    $root = Join-Path $fixture 'root'
    $outside = Join-Path $fixture 'outside'
    $null = New-Item -ItemType Directory -Path (Join-Path $root 'sub'), $outside
    Set-Content -LiteralPath (Join-Path $root 'sub/a.txt') -Value 'alpha' -NoNewline
    Set-Content -LiteralPath (Join-Path $outside 'secret.txt') -Value 'secret' -NoNewline
    $junction = Join-Path $root 'link'
    $null = New-Item -ItemType Junction -Path $junction -Target $outside

    # --- Paths ---------------------------------------------------------------
    Check 'local path resolves' { (Resolve-DtLocalPath -Path $root -Kind Directory) -eq $root }
    Throws 'UNC refused' { Resolve-DtLocalPath -Path '\\server\share\x' }
    Throws 'device path refused' { Resolve-DtLocalPath -Path '\\?\C:\Windows' }
    Throws 'forward-slash UNC refused' { Resolve-DtLocalPath -Path '//server/share' }
    Throws 'ADS refused' { Resolve-DtLocalPath -Path "$root\sub\a.txt:hidden" }
    Throws 'reserved device refused' { Resolve-DtLocalPath -Path "$root\CON.txt" }
    Throws 'superscript device refused' { Resolve-DtLocalPath -Path "$root\COM$([char]0xB9)" }
    Throws 'trailing dot refused' { Resolve-DtLocalPath -Path "$root\sub." }
    Throws 'wildcard refused' { Resolve-DtLocalPath -Path "$root\*.txt" }
    Throws 'control char refused' { Resolve-DtLocalPath -Path "$root\a`tb" }
    Throws 'junction ancestor refused' { Resolve-DtLocalPath -Path "$junction\secret.txt" }
    Throws 'New refuses existing' { Resolve-DtLocalPath -Path $root -New }
    Throws 'New requires parent' { Resolve-DtLocalPath -Path "$root\missing\x" -New }
    Check 'contained path resolves' { (Resolve-DtContainedPath -Root $root -RelativePath 'sub/a.txt' -Kind File) -eq (Join-Path $root 'sub\a.txt') }
    Throws 'contained .. refused' { Resolve-DtContainedPath -Root $root -RelativePath '..\outside\secret.txt' }
    Throws 'contained absolute refused' { Resolve-DtContainedPath -Root $root -RelativePath "$outside\secret.txt" }
    Throws 'contained drive-relative refused' { Resolve-DtContainedPath -Root $root -RelativePath 'C:secret.txt' }
    Throws 'contained via junction refused' { Resolve-DtContainedPath -Root $root -RelativePath 'link\secret.txt' }
    Throws 'contained root itself refused' { Resolve-DtContainedPath -Root $root -RelativePath '.' }

    # --- Tree enumeration ----------------------------------------------------
    Throws 'tree refuses reparse' { Get-DtFileTree -Root $root }
    Check 'tree skips reparse' { $t = @(Get-DtFileTree -Root $root -SkipReparsePoints); $t.Count -eq 1 -and $t[0].RelativePath -eq 'sub/a.txt' }
    Throws 'tree entry limit' { Get-DtFileTree -Root $root -SkipReparsePoints -MaxEntries 1 }
    Throws 'tree depth limit' { Get-DtFileTree -Root $root -SkipReparsePoints -MaxDepth 0 }
    Throws 'tree byte limit' { Get-DtFileTree -Root $root -SkipReparsePoints -MaxTotalBytes 2 }
    Check 'tree reports reparse' { $t = @(Get-DtFileTree -Root $root -IncludeReparsePoints); $l = @($t | Where-Object IsReparsePoint); $t.Count -eq 2 -and $l.Count -eq 1 -and $l[0].RelativePath -eq 'link' -and -not ($t.RelativePath -match '^link/') }
    Throws 'tree reparse modes exclusive' { Get-DtFileTree -Root $root -IncludeReparsePoints -SkipReparsePoints }
    Check 'tree exclude' { @(Get-DtFileTree -Root $root -SkipReparsePoints -ExcludeDirectoryName 'SUB').Count -eq 0 }
    Check 'run directory unique' { $a = New-DtRunDirectory -Parent $fixture; $b = New-DtRunDirectory -Parent $fixture; $a -ne $b -and (Test-Path $a) -and (Split-Path $a -Leaf) -match '^\d{8}T\d{9}Z-[0-9a-f]{12}$' }

    # --- Bounded I/O ---------------------------------------------------------
    $big = Join-Path $fixture 'big.bin'
    [IO.File]::WriteAllBytes($big, [byte[]]::new(2048))
    Check 'bytes returned as array' { $b = Read-DtBytes -Path $big; $b -is [byte[]] -and $b.Length -eq 2048 }
    Throws 'bytes cap' { Read-DtBytes -Path $big -MaxBytes 1024 }
    $bad = Join-Path $fixture 'bad.txt'
    [IO.File]::WriteAllBytes($bad, [byte[]](0x61, 0xC3, 0x28))
    Throws 'invalid utf8 refused' { Read-DtText -Path $bad }
    $bom = Join-Path $fixture 'bom.txt'
    [IO.File]::WriteAllBytes($bom, [byte[]](0xEF, 0xBB, 0xBF, 0x68, 0x69))
    Check 'BOM stripped' { (Read-DtText -Path $bom) -ceq 'hi' }

    $target = Join-Path $fixture 'atomic.txt'
    Write-DtFileAtomic -Path $target -Content 'one'
    Throws 'atomic no-clobber' { Write-DtFileAtomic -Path $target -Content 'two' }
    Write-DtFileAtomic -Path $target -Content 'three' -Overwrite
    Check 'atomic overwrite' { (Read-DtText -Path $target) -ceq 'three' }
    Check 'atomic no temp left' { @(Get-ChildItem -LiteralPath $fixture -Filter '*.tmp' -Force).Count -eq 0 }
    Throws 'atomic size cap' { Write-DtFileAtomic -Path (Join-Path $fixture 'cap.txt') -Content 'abcdef' -MaxBytes 3 }
    Throws 'atomic rejects object' { Write-DtFileAtomic -Path (Join-Path $fixture 'obj.txt') -Content @{a = 1} }

    # --- JSON ----------------------------------------------------------------
    $j = Join-Path $fixture 'doc.json'
    Set-Content -LiteralPath $j -Value '{"schemaVersion":1,"b":[1,2,{"x/y":true}],"a":"z"}' -NoNewline
    Check 'json reads object' { $d = Read-DtJson -Path $j -SchemaVersion 1; $d -is [Collections.IDictionary] -and $d.a -eq 'z' }
    Throws 'json schema mismatch' { Read-DtJson -Path $j -SchemaVersion 2 }
    $arr = Join-Path $fixture 'arr.json'
    Set-Content -LiteralPath $arr -Value '[1,2]' -NoNewline
    Throws 'json array root refused' { Read-DtJson -Path $arr }
    Check 'json array root allowed' { (Read-DtJson -Path $arr -AllowNonObjectRoot).Count -eq 2 }
    $deep = Join-Path $fixture 'deep.json'
    Set-Content -LiteralPath $deep -Value (('[' * 40) + (']' * 40)) -NoNewline
    Throws 'json depth limit' { Read-DtJson -Path $deep -AllowNonObjectRoot -Depth 10 }
    Throws 'json size limit' { Read-DtJson -Path $j -MaxBytes 8 }
    Check 'canonical order-independent' { (ConvertTo-DtCanonicalJson @{ b = 1; a = @(1, 'x', $null) }) -ceq (ConvertTo-DtCanonicalJson ([ordered]@{ a = @(1, 'x', $null); b = 1 })) }
    Check 'canonical exact' { (ConvertTo-DtCanonicalJson ([ordered]@{ z = $true; a = 1.5; m = [Collections.Generic.List[int]]@(2, 1) })) -ceq '{"a":1.5,"m":[2,1],"z":true}' }
    Check 'canonical pscustomobject' { (ConvertTo-DtCanonicalJson ([pscustomobject]@{ b = 'q"'; a = 0 })) -ceq '{"a":0,"b":"q\""}' }
    Throws 'canonical NaN' { ConvertTo-DtCanonicalJson @{ a = [double]::NaN } }
    Throws 'canonical non-string key' { ConvertTo-DtCanonicalJson @{ 1 = 'a' } }
    Check 'pointer escapes' { $d = Read-DtJson -Path $j; (Get-DtJsonPointer -InputObject $d -Pointer '/b/2/x~1y').Value -eq $true }
    Check 'pointer missing' { $d = Read-DtJson -Path $j; -not (Get-DtJsonPointer -InputObject $d -Pointer '/b/9').Exists }

    # --- Validation ----------------------------------------------------------
    Check 'integer ok' { (Assert-DtInteger -Value 5 -Minimum 1 -Maximum 9) -eq 5 }
    Throws 'integer string' { Assert-DtInteger -Value '5' }
    Throws 'integer double' { Assert-DtInteger -Value 5.0 }
    Throws 'integer bool' { Assert-DtInteger -Value $true }
    Throws 'integer range' { Assert-DtInteger -Value 10 -Maximum 9 }
    Check 'name ok' { (Assert-DtSafeName -Name 'My.App-2') -eq 'My.App-2' }
    foreach ($n in 'CON', 'nul.txt', '..', 'a/b', 'a\b', '1abc', 'a..b', 'a.', '') { Throws "name '$n'" { Assert-DtSafeName -Name $n } }
    Check 'sha normalised' { (Assert-DtSha256 -Value ('ab' * 32)) -ceq ('AB' * 32) }
    Throws 'sha length' { Assert-DtSha256 -Value 'abc' }

    # --- Hashing -------------------------------------------------------------
    Check 'sha256 matches Get-FileHash' { (Get-DtFileSha256 -Path $big) -eq (Get-FileHash -LiteralPath $big -Algorithm SHA256).Hash }
    Throws 'sha256 budget' { Get-DtFileSha256 -Path $big -MaxBytes 100 }
    $tree = Join-Path $fixture 'tree'
    $null = New-Item -ItemType Directory -Path (Join-Path $tree 'n')
    Set-Content -LiteralPath (Join-Path $tree 'n/f.txt') -Value 'f' -NoNewline
    Check 'tree hash stable' { $h1 = Get-DtTreeHash -Root $tree; $h2 = Get-DtTreeHash -Root $tree; $h1.Sha256 -eq $h2.Sha256 -and $h1.FileCount -eq 1 }
    Check 'tree hash detects change' { $h1 = (Get-DtTreeHash -Root $tree).Sha256; Set-Content -LiteralPath (Join-Path $tree 'n/f.txt') -Value 'g' -NoNewline; $h1 -ne (Get-DtTreeHash -Root $tree).Sha256 }

    # --- Processes -----------------------------------------------------------
    $pwsh = (Get-Command pwsh.exe -CommandType Application | Select-Object -First 1).Source
    $cmdFile = Join-Path $fixture 'x.cmd'
    Set-Content -LiteralPath $cmdFile -Value '@echo hi'
    Throws 'batch refused' { Resolve-DtExecutable -Name $cmdFile }
    Throws 'relative path refused' { Resolve-DtExecutable -Name '.\pwsh.exe' }
    Check 'PATH lookup' { (Resolve-DtExecutable -Name 'pwsh') -ieq $pwsh }

    $echo = Join-Path $fixture 'echo.ps1'
    Set-Content -LiteralPath $echo -Value '$args | ConvertTo-Json -Compress -AsArray'
    $hostile = @('a b', 'quote"inside', '&calc', '| whoami', '$(whoami)', '%PATH%', '\\"x', '')
    Check 'arguments are literal' {
        $r = Invoke-DtProcess -Executable $pwsh -ArgumentList (@('-NoProfile', '-File', $echo) + $hostile) -WorkingDirectory $fixture
        $got = @($r.Stdout | ConvertFrom-Json)
        $r.ExitCode -eq 0 -and $got.Count -eq $hostile.Count -and (-join ($got -join '|')) -ceq ($hostile -join '|')
    }
    Throws 'NUL argument refused' { Invoke-DtProcess -Executable $pwsh -ArgumentList @("a$([char]0)b") -WorkingDirectory $fixture }
    Check 'output cap' {
        $r = Invoke-DtProcess -Executable $pwsh -ArgumentList @('-NoProfile', '-Command', "'x' * 100000") -WorkingDirectory $fixture -MaxOutputBytes 1000
        $r.StdoutTruncated -and $r.Stdout.Length -eq 1000 -and $r.ExitCode -eq 0
    }
    Check 'timeout kills' {
        $r = Invoke-DtProcess -Executable $pwsh -ArgumentList @('-NoProfile', '-Command', 'Start-Sleep 60') -WorkingDirectory $fixture -TimeoutSeconds 2
        $r.TimedOut -and $r.ExitCode -eq 124 -and $r.ElapsedMilliseconds -lt 15000
    }
    Check 'stdin closed' {
        $r = Invoke-DtProcess -Executable $pwsh -ArgumentList @('-NoProfile', '-Command', '[Console]::In.ReadToEnd().Length') -WorkingDirectory $fixture -TimeoutSeconds 20
        -not $r.TimedOut -and $r.Stdout.Trim() -eq '0'
    }
    # cmd.exe (not a Store/MSIX-packaged parent, whose children may break away from jobs by OS policy).
    Check 'orphaned descendant terminated' {
        $before = @((Get-Process ping -ErrorAction SilentlyContinue).Id)
        $r = Invoke-DtProcess -Executable cmd.exe -ArgumentList @('/d', '/c', 'start /b ping -n 60 127.0.0.1') -WorkingDirectory $fixture -TimeoutSeconds 30
        Start-Sleep -Milliseconds 500
        $left = @(Get-Process ping -ErrorAction SilentlyContinue | Where-Object Id -notin $before)
        $r.DescendantsTerminated -and $r.JobAssigned -and $left.Count -eq 0 -and $r.ElapsedMilliseconds -lt 20000
    }
    Check 'clean environment drops secrets' {
        $env:DT_TEST_SECRET = 'leak'
        try {
            $r = Invoke-DtProcess -Executable $pwsh -ArgumentList @('-NoProfile', '-Command', '"[$env:DT_TEST_SECRET][$env:DT_ADDED]"') -WorkingDirectory $fixture -CleanEnvironment -Environment @{ DT_ADDED = 'ok' }
            $r.Stdout.Trim() -ceq '[][ok]'
        }
        finally { Remove-Item Env:DT_TEST_SECRET }
    }
    Throws 'bad env name' { Invoke-DtProcess -Executable $pwsh -WorkingDirectory $fixture -Environment @{ 'A=B' = 'x' } }
    Throws 'working dir must exist' { Invoke-DtProcess -Executable $pwsh -WorkingDirectory (Join-Path $fixture 'nope') }

    # --- Results and redaction -----------------------------------------------
    $samples = @{
        ('ghp_' + ('a' * 36))                                 = '[REDACTED-TOKEN]'
        ('AKIA' + ('B' * 16))                                 = '[REDACTED-TOKEN]'
        'Authorization: Bearer abcdefghijklmnopqrstu'         = 'Authorization: Bearer [REDACTED]'
        'https://user:hunter2@example.test/x'                 = 'https://[REDACTED]@example.test/x'
        'password = "p@ss word"'                              = 'password = [REDACTED]'
        'api_key=XYZ123;'                                     = 'api_key=[REDACTED];'
        "-----BEGIN RSA PRIVATE KEY-----`nAAA`n-----END RSA PRIVATE KEY-----" = '[REDACTED-PRIVATE-KEY]'
        'eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dozjgNryP4J3jVmNHl0w5N_XgL0n3I9PlFUP0THsR8U' = '[REDACTED-JWT]'
    }
    foreach ($k in $samples.Keys) { $expected = $samples[$k]; Check "redact $($expected)" { (Protect-DtText $k) -ceq $expected } }
    Check 'redact profile path' { (Protect-DtText ([Environment]::GetFolderPath('UserProfile') + '\x')) -ceq '%USERPROFILE%\x' }
    Check 'redact passthrough' { (Protect-DtText 'plain text') -ceq 'plain text' }

    $res = New-DtResult -Tool 'Test' -Scope 'unit'
    Add-DtFinding -Result $res -Code 'Sample.One' -Message 'token=abc' -Severity Warning
    Throws 'finding code validated' { Add-DtFinding -Result $res -Code 'bad code!' -Message 'x' }
    Check 'finding redacted' { $res.findings[0].message -ceq 'token=[REDACTED]' }
    Check 'complete pass' { $o = Complete-DtResult -Result $res -ExitCode 0; $o.status -eq 'Pass' -and $o.valid }
    Check 'complete timeout' { (Complete-DtResult -Result $res -ExitCode 124).status -eq 'TimedOut' }
    Check 'complete json' { $o = Complete-DtResult -Result $res -ExitCode 2 -Json | ConvertFrom-Json; $o.status -eq 'Fail' -and -not $o.valid -and $o.findings.Count -eq 1 }
}
finally {
    if (Test-Path -LiteralPath $junction) { [IO.Directory]::Delete($junction) }   # remove link only, never its target
    Remove-Item -LiteralPath $fixture -Recurse -Force
}

"Passed: $script:passed  Failed: $($script:failed.Count)"
$script:failed | ForEach-Object { "  FAIL $_" }
exit ([int]($script:failed.Count -gt 0))
