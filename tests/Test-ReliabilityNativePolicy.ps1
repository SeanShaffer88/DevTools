#requires -Version 7.0
[CmdletBinding()]
param([string]$Destination = (Join-Path $PSScriptRoot '../work/devtools-reliability-wave/native/policy'))
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
$Destination=[IO.Path]::GetFullPath($Destination)
$run=Join-Path $Destination ('test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $run | Out-Null
$results=[Collections.Generic.List[object]]::new()
$exe=(Get-Process -Id $PID).Path
$targetHash=(Get-FileHash -LiteralPath "$root/README.md").Hash
$policyBefore=Get-ExecutionPolicy -List | ConvertTo-Json -Compress
function Check($name,$evidence,$expected,$category,$extra=@()) {
 $path=Join-Path $run ($name+'.json')
 $evidence | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $path
 $raw=& $exe -NoProfile -File "$root/Get-PolicyDiagnostics.ps1" -EvidencePath $path -Json @extra 2>&1 | Out-String
 $code=$LASTEXITCODE
 $raw | Set-Content -LiteralPath (Join-Path $run ($name+'.result.json'))
 try {$r=$raw|ConvertFrom-Json; $ok=$code -eq $expected -and (!$category -or $category -in $r.findings.category) -and $raw -notmatch 'SECRET_SENTINEL'; if($expected -eq 125){$ok=$ok -and $r.status -eq 'SetupError'};if($name -eq 'generic access'){$ok=$ok -and ($r.artifacts|Where-Object id -eq 'selected-target').exists -and ($r.executionEvidence|Where-Object operation -eq 'own-process-context').languageMode -ne $null}}catch{$ok=$false}
 $results.Add(@{name=$name;passed=$ok;exitCode=$code;expected=$expected})
 if(!$ok){Write-Host "FAILED $name : $raw"}
}
$base=@{schemaVersion=1;operation='launch';exitCode=1;stderr='Access is denied SECRET_SENTINEL';stdout='';context=@{host='local';sandbox='unknown';windowsSandboxConfigured=$true}}
Check 'generic access' $base 3 'AccessDenied' @('-TargetPath',"$root/README.md",'-ExecutablePath',$exe)
$base.stderr='File cannot be loaded because running scripts is disabled on this system. UnauthorizedAccess'
Check 'script restriction' $base 0 'ScriptPolicyRestriction'
$base.stderr='Sandbox backend was omitted; windows sandbox is configured.'
Check 'backend omission' $base 3 'PolicyUnknown'
$base.stderr='Operation denied by sandbox configuration'
Check 'sandbox restriction' $base 0 'SandboxConfigurationDenial'
$base.stderr='The process cannot access the file because it is being used by another process.'
Check 'sharing' $base 0 'SharingViolation'
$base.stderr='tool not found'
Check 'missing executable' $base 2 'MissingTool' @('-ExecutablePath',(Join-Path $run 'missing tool.exe'))
$marker=Join-Path $run 'must-not-exist'
$base.stderr="SECRET_SENTINEL; Set-Content '$marker' compromised"
Check 'malicious inert' $base 3 'PolicyUnknown'
$base.stderr='x'*65537
Check 'oversize field' $base 125 $null
$base.stderr='blocked by policy'
Check 'traversal' $base 125 $null @('-TargetPath',"$root/../DevTools/README.md")
Check 'ads' $base 125 $null @('-TargetPath',"${root}/README.md:secret")
Check 'unc' $base 125 $null @('-TargetPath','\\localhost\share\file')
Check 'second colon' $base 125 $null @('-TargetPath',"${root}/README.md:/secret")
$base.stderr='blocked by policy'
Check 'generic policy' $base 3 'PolicyUnknown'
$base.exitCode=0;$base.stderr='running scripts is disabled on this system'
Check 'successful operation not attributed' $base 3 'PolicyUnknown'
$base.exitCode=1;$base.context.windowsSandboxConfigured='true'
Check 'invalid flag' $base 125 $null
$base.context.windowsSandboxConfigured=$true
$base.schemaVersion=2
Check 'invalid schema' $base 125 $null
$base.schemaVersion=1;$base.exitCode='1'
Check 'invalid exit type' $base 125 $null
$base.exitCode=1
$base.stdout='x'*262145
Check 'oversize file' $base 125 $null
$base.stdout=''
$junction=Join-Path $run 'junction'
New-Item -ItemType Junction -Path $junction -Target $root | Out-Null
Check 'reparse ancestor' $base 125 $null @('-TargetPath',(Join-Path $junction 'README.md'))
foreach($fixture in Get-ChildItem "$root/resources/reliability/v1/regressions-native/policy-*.json") {
 $v=Get-Content $fixture.FullName -Raw|ConvertFrom-Json -AsHashtable
 $expected=if($fixture.BaseName -eq 'policy-script-restriction'){0}else{3}
 Check $fixture.BaseName $v $expected $null
}
$bad=Join-Path $run 'malformed.json'; '{broken'|Set-Content $bad
$raw=& $exe -NoProfile -File "$root/Get-PolicyDiagnostics.ps1" -EvidencePath $bad -Json | Out-String
$results.Add(@{name='malformed';passed=($LASTEXITCODE -eq 125 -and ($raw|ConvertFrom-Json).status -eq 'SetupError');exitCode=$LASTEXITCODE;expected=125})
$results.Add(@{name='no injected write';passed=!(Test-Path -LiteralPath $marker)})
$results.Add(@{name='target unchanged';passed=((Get-FileHash -LiteralPath "$root/README.md").Hash -eq $targetHash)})
$results.Add(@{name='policy unchanged';passed=((Get-ExecutionPolicy -List | ConvertTo-Json -Compress) -eq $policyBefore)})
$summary=@{schemaVersion=1;total=$results.Count;passed=@($results|Where-Object passed).Count;failed=@($results|Where-Object { !$_.passed }).Count;results=$results}
$summary|ConvertTo-Json -Depth 10|Set-Content (Join-Path $run 'results.json')
$summary|ConvertTo-Json -Depth 10
if($summary.failed){exit 2};exit 0
