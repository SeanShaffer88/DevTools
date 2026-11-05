#requires -Version 7.0
[CmdletBinding()]
param([string]$WorkRoot='C:\Users\Sean Shaffer\Documents\Codex\2026-11-03\a\work', [string]$EvidenceDirectory)
$ErrorActionPreference='Stop'
$evidencePath=& (Join-Path $PSScriptRoot 'Resolve-SuiteEvidencePath.ps1') 'validation.json' $EvidenceDirectory ($PSBoundParameters.ContainsKey('EvidenceDirectory'))
$toolRoot=Split-Path $PSScriptRoot -Parent
$fixture=Join-Path $WorkRoot ('devtools-tests-' + [Guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $fixture
$checks=[Collections.Generic.List[object]]::new()
function Assert([bool]$Condition,[string]$Name) {
    if (-not $Condition) { throw "FAILED: $Name" }
    $checks.Add([pscustomobject]@{name=$Name;passed=$true})
}
function Invoke-Runner([string[]]$Arguments,[string[]]$Artifacts=@(),[string]$Exe=$pwsh) {
    $caller=Join-Path $fixture ('caller-' + [Guid]::NewGuid().ToString('N') + '.ps1')
    $data=Join-Path $fixture ('args-' + [Guid]::NewGuid().ToString('N') + '.json')
    @{tool=Join-Path $toolRoot 'Invoke-DevBuild.ps1';project=$project;exe=$Exe;arguments=$Arguments;artifacts=$Artifacts} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $data
    $quoted=$data.Replace("'","''")
    "`$c=Get-Content -LiteralPath '$quoted' -Raw | ConvertFrom-Json; & `$c.tool -ProjectPath `$c.project -Executable `$c.exe -ArgumentList @(`$c.arguments) -ArtifactPath @(`$c.artifacts); exit `$LASTEXITCODE" | Set-Content -LiteralPath $caller
    $p=[Diagnostics.Process]::new()
    $p.StartInfo=[Diagnostics.ProcessStartInfo]::new($pwsh)
    $p.StartInfo.UseShellExecute=$false
    $p.StartInfo.RedirectStandardOutput=$true
    $p.StartInfo.RedirectStandardError=$true
    foreach ($a in @('-NoProfile','-File',$caller)) {$p.StartInfo.ArgumentList.Add($a)}
    $null=$p.Start(); $out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();$p.WaitForExit()
    $code=$p.ExitCode; $output=$out.GetAwaiter().GetResult();$errors=$err.GetAwaiter().GetResult();$p.Dispose()
    # Other helpers keep their own evidence under runs; select this fixture's actual build result.
    $runnerResult=$null
    foreach($candidate in @(Get-ChildItem -LiteralPath (Join-Path $toolRoot 'runs') -Directory | Where-Object Name -match '^\d{8}T\d{9}Z-' | Sort-Object Name -Descending)){
        $resultPath=Join-Path $candidate.FullName 'result.json'
        if(-not(Test-Path -LiteralPath $resultPath -PathType Leaf)){continue}
        $possible=Get-Content -LiteralPath $resultPath -Raw | ConvertFrom-Json
        if($possible.projectPath -eq $project -and $null -ne $possible.runnerExitCode){$runnerResult=$possible;break}
    }
    if($null -eq $runnerResult){throw 'No build runner result for this unique fixture.'}
    [pscustomobject]@{exit=$code;result=$runnerResult;stdout=$output;stderr=$errors}
}
$pwsh=(Get-Command pwsh.exe -CommandType Application | Select-Object -First 1).Source
$testExit=1
try {
    foreach ($script in Get-ChildItem -LiteralPath $toolRoot -Filter '*.ps1' -Recurse) {
        $tokens=$null;$errors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile($script.FullName,[ref]$tokens,[ref]$errors)
        Assert ($errors.Count -eq 0) "AST parse: $($script.Name)"
    }
    $doctor=& (Join-Path $toolRoot 'Get-DevEnvironment.ps1') -Json | ConvertFrom-Json
    Assert ($doctor.schemaVersion -eq 1 -and $doctor.tools.Count -gt 0) 'Doctor JSON'
    $project=Join-Path $fixture 'Project With Spaces'
    $null=New-Item -ItemType Directory -Path $project
    foreach ($name in @('CMakeLists.txt','Example.csproj','Cargo.toml','package.json','build.gradle.kts','Example.toc','AGENTS.md','gradlew.bat')) { [IO.File]::WriteAllText((Join-Path $project $name),'fixture') }
    $before=@(Get-ChildItem -LiteralPath $project -File | ForEach-Object {"$($_.Name):$((Get-FileHash -LiteralPath $_.FullName).Hash)"}) -join '|'
    $info=& (Join-Path $toolRoot 'Get-ProjectInfo.ps1') -ProjectPath $project -Json | ConvertFrom-Json
    Assert ($null -eq $info.git -and $info.markers.Count -eq 6 -and $info.wrappers.Count -eq 1) 'Inspector nonrepository markers and spaces'
    $after=@(Get-ChildItem -LiteralPath $project -File | ForEach-Object {"$($_.Name):$((Get-FileHash -LiteralPath $_.FullName).Hash)"}) -join '|'
    Assert ($before -eq $after) 'Inspector unchanged file hashes'
    $failed=$false;try { & (Join-Path $toolRoot 'Get-ProjectInfo.ps1') -ProjectPath (Join-Path $fixture 'absent') | Out-Null } catch {$failed=$true}
    Assert $failed 'Inspector nonexistent directory'
    & git.exe -C $project init --quiet
    Assert ($LASTEXITCODE -eq 0) 'Git fixture init exit 0'
    $info=& (Join-Path $toolRoot 'Get-ProjectInfo.ps1') -ProjectPath $project -Json | ConvertFrom-Json
    Assert ($null -ne $info.git -and $info.git.status -eq 'NotQueried') 'Inspector Git fixture with status deliberately skipped'
    [IO.File]::WriteAllText((Join-Path $project '.gitattributes'),'tracked.txt filter=devtools')
    [IO.File]::WriteAllText((Join-Path $project 'tracked.txt'),'original')
    & git.exe -C $project add -- .gitattributes tracked.txt
    Assert ($LASTEXITCODE -eq 0) 'Filter fixture index setup exit 0'
    & git.exe -C $project config filter.devtools.clean 'cmd.exe /d /c echo invoked>filter-invoked.txt'
    Assert ($LASTEXITCODE -eq 0) 'Filter fixture local config exit 0'
    [IO.File]::WriteAllText((Join-Path $project 'tracked.txt'),'modified')
    $null=& (Join-Path $toolRoot 'Get-ProjectInfo.ps1') -ProjectPath $project
    Assert (-not (Test-Path -LiteralPath (Join-Path $project 'filter-invoked.txt'))) 'Inspector never invokes configured Git clean filter'
    $child=Join-Path $fixture 'child.ps1'
    @'
param([string]$Output,[int]$ExitCode,[Parameter(ValueFromRemainingArguments)][string[]]$Values)
[IO.File]::WriteAllText($Output,($Values | ConvertTo-Json -Compress))
[Console]::Out.WriteLine('fixture stdout')
[Console]::Error.WriteLine('fixture stderr')
exit $ExitCode
'@ | Set-Content -LiteralPath $child
    $artifact=Join-Path $project 'artifact.json'
    $values=@('space value','quote"value','&;$(literal)','', 'trailing\')
    $run=Invoke-Runner -Arguments (@('-NoProfile','-File',$child,'-Output',$artifact,'-ExitCode','0')+$values) -Artifacts @('artifact.json')
    Assert ($run.exit -eq 0 -and $run.result.status -eq 'Succeeded') 'Runner success exit 0'
    $actual=@(Get-Content -LiteralPath $artifact -Raw | ConvertFrom-Json)
    Assert (($actual | ConvertTo-Json -Compress) -eq ($values | ConvertTo-Json -Compress)) 'Argument boundaries spaces quotes metacharacters empty trailing slash'
    Assert ((Get-Content -LiteralPath (Join-Path $run.result.runDirectory 'stdout.log') -Raw).Contains('fixture stdout') -and (Get-Content -LiteralPath (Join-Path $run.result.runDirectory 'stderr.log') -Raw).Contains('fixture stderr')) 'Separate stdout and stderr logs'
    Assert ($run.result.artifacts[0].sha256 -eq (Get-FileHash -LiteralPath $artifact).Hash) 'Artifact SHA256'
    $firstRun=$run.result.runDirectory
    $run=Invoke-Runner -Arguments @('-NoProfile','-File',$child,'-Output',$artifact,'-ExitCode','7')
    Assert ($run.exit -eq 7 -and $run.result.processExitCode -eq 7) 'Runner native failure exit 7'
    Assert ($firstRun -ne $run.result.runDirectory) 'Unique run directories'
    $run=Invoke-Runner -Arguments @('-NoProfile','-File',$child,'-Output',$artifact,'-ExitCode','0') -Artifacts @('missing.bin')
    Assert ($run.exit -eq 2 -and $run.result.status -eq 'ArtifactVerificationFailed') 'Missing artifact exit 2'
    $run=Invoke-Runner -Arguments @() -Exe 'devtools-deliberately-missing-7a6e.exe'
    Assert ($run.exit -eq 125 -and $run.result.status -eq 'SetupFailed') 'Missing executable exit 125'
    $largeChild=Join-Path $fixture 'large-child.ps1'
    @'
$chunk=[Text.Encoding]::UTF8.GetBytes(('x' * 65536))
$out=[Console]::OpenStandardOutput();$err=[Console]::OpenStandardError()
for ($i=0;$i -lt 256;$i++) {$out.Write($chunk,0,$chunk.Length);$err.Write($chunk,0,$chunk.Length)}
exit 0
'@ | Set-Content -LiteralPath $largeChild
    $run=Invoke-Runner -Arguments @('-NoProfile','-File',$largeChild)
    Assert ($run.exit -eq 0 -and (Get-Item -LiteralPath (Join-Path $run.result.runDirectory 'stdout.log')).Length -eq 16777216 -and (Get-Item -LiteralPath (Join-Path $run.result.runDirectory 'stderr.log')).Length -eq 16777216) 'Large concurrent stdout and stderr streams: 16 MiB each'
    $testExit=0
} catch { Write-Error -Message $_ -ErrorAction Continue }
finally {
    $evidence=[pscustomobject]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');command="pwsh -NoProfile -File $PSCommandPath";exitCode=$testExit;powerShellVersion=$PSVersionTable.PSVersion.ToString();fixturePath=$fixture;checks=@($checks.ToArray())}
    $evidence | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $evidencePath -Encoding utf8
    $evidence | ConvertTo-Json -Depth 6
}
exit $testExit
