# Private support for the five native quality helpers. No target argument values in evidence.
. (Join-Path $PSScriptRoot 'QualityCommon.ps1')
$ErrorActionPreference='Stop'
function New-NResult([string]$Tool) { New-QResult $Tool 'Explicit local inputs only' }
function Finish-N($r,[int]$code,[switch]$Json) { $r.status=switch($code){0{'Pass'}2{'Fail'}3{'Unknown'}default{'Setup'}}; $r.valid=$code -eq 0; Complete-QResult $r -Json:$Json; exit $code }
function Read-NJson([string]$Path) { $v=Read-QJson $Path; Assert-QSchema $v; return $v }
function Get-NNumber($v,[double]$min,[double]$max) { if(($v -isnot [long] -and $v -isnot [int] -and $v -isnot [double] -and $v -isnot [decimal] -and $v -isnot [Numerics.BigInteger]) -or -not [double]::IsFinite([double]$v) -or $v -lt $min -or $v -gt $max){throw 'Invalid finite numeric budget.'}; [double]$v }
function Invoke-NProcess([string]$Exe,[string[]]$Arguments,[int]$Timeout=20,[int]$Limit=1048576,[string]$WorkingDirectory=$PWD.Path,$Environment=$null) { if(-not ('DevToolsQualityNative.ProcessRunner' -as [type])){Add-Type -Path "$PSScriptRoot/QualityNativeProcess.cs"};$actual=(Get-Command -Name $Exe -CommandType Application -ErrorAction Stop|Select-Object -First 1).Source;if([IO.Path]::GetExtension($actual) -ine '.exe'){throw 'Explicit native executable required'};$envMap=[Collections.Generic.Dictionary[string,string]]::new();if($null -ne $Environment){foreach($key in $Environment.Keys){$envMap.Add($key,$Environment[$key])}};[DevToolsQualityNative.ProcessRunner]::Run($actual,$Arguments,$WorkingDirectory,$Timeout,$Limit,$envMap) }
function Add-NEvidence($r,[string]$operation,$p) { $r.executionEvidence+=@{operation=$operation;exitCode=$p.ExitCode;timedOut=$p.TimedOut;outputTruncated=$p.Truncated} }
function Test-NFile([string]$Path,[long]$Max=16777216) { $p=Assert-QPath $Path; $f=Get-Item -LiteralPath $p; if($f.PSIsContainer -or $f.Length -gt $Max){throw 'Input is not a bounded file.'}; $p }
