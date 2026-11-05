#requires -Version 7.1
<#
.SYNOPSIS
Deterministic bounded mutations of explicit seeds against an explicitly trusted executable.
.DESCRIPTION
ArgumentList must contain {InputPath}. AllowedExitCodes must declare ordinary rejects.
Unexpected exits are retained and minimized by actual deletion retests preserving exit code.
A known unexpected exit remains a failure even when later coverage is incomplete.
Replay descriptor omits all argument values: retain the original invocation privately.
Child isolation is not a security sandbox. Only newly created owned trees may be killed.
#>
[CmdletBinding()]param([Parameter(Mandatory)][string]$TargetPath,[Parameter(Mandatory)][string[]]$ArgumentList,[Parameter(Mandatory)][string[]]$SeedPath,[Parameter(Mandatory)][int[]]$AllowedExitCodes,[Parameter(Mandatory)][string]$Destination,[switch]$ExecuteTrusted,[int]$RandomSeed=1,[ValidateRange(1,1000)][int]$Cases=20,[ValidateRange(1,30)][int]$PerProcessSeconds=2,[ValidateRange(1,300)][int]$GlobalSeconds=30,[ValidateRange(1,1048576)][int]$MaxInputBytes=65536,[ValidateRange(128,1048576)][int]$MaxOutputBytes=65536,[ValidateRange(0,100)][int]$MinimizeCalls=20,[switch]$Json)
. "$PSScriptRoot/lib/QualityNative.ps1"
$r=New-NResult 'Invoke-ParserFuzz';$clock=[Diagnostics.Stopwatch]::StartNew();$calls=0;$done=0
$knownFailure=$false;$coverageIncomplete=$false;$invocationFailed=$false;$runReady=$false
function Invoke-NCase([string]$inputFile) {
 $remaining=$GlobalSeconds-$clock.Elapsed.TotalSeconds;if($remaining -lt 1){return $null}
 $argv=[string[]]@($ArgumentList|ForEach-Object {$_.Replace('{InputPath}',$inputFile)})
 $p=Invoke-NProcess $target $argv ([Math]::Min($PerProcessSeconds,[int][Math]::Floor($remaining))) $MaxOutputBytes $dest
 $script:calls++;Add-NEvidence $r 'TrustedParserChild' $p;return $p
}
try {
 if(-not $ExecuteTrusted){throw 'ExecuteTrusted acknowledgement required'};if(-not $AllowedExitCodes.Count -or $AllowedExitCodes.Count -gt 64){throw 'Declare allowed exits'}
 if($ArgumentList.Count -gt 64 -or @($ArgumentList|Where-Object {$_.Contains('{InputPath}')}).Count -lt 1){throw 'Bounded argv protocol requires {InputPath}'}
 $target=Test-NFile $TargetPath 134217728;if([IO.Path]::GetExtension($target) -ine '.exe'){throw 'Select an executable, e.g. pwsh.exe with explicit script args'}
 if($SeedPath.Count -lt 1 -or $SeedPath.Count -gt 32){throw '1..32 seed files required'};$seeds=@();foreach($s in $SeedPath){$seeds+=,([IO.File]::ReadAllBytes((Test-NFile $s $MaxInputBytes)))}
 $dest=Assert-QPath $Destination -New;[void][IO.Directory]::CreateDirectory($dest);$random=[Random]::new($RandomSeed)
 $descriptor=@{schemaVersion=1;randomSeed=$RandomSeed;cases=$Cases;allowedExitCodes=$AllowedExitCodes;argumentCount=$ArgumentList.Count;inputPlaceholderIndices=@(for($i=0;$i -lt $ArgumentList.Count;$i++){if($ArgumentList[$i].Contains('{InputPath}')){$i}});targetAndArguments='Not persisted; replay requires original trusted invocation';perProcessSeconds=$PerProcessSeconds;maxInputBytes=$MaxInputBytes;maxOutputBytes=$MaxOutputBytes}
 $descriptor|ConvertTo-Json -Depth 10|Set-Content -LiteralPath (Join-Path $dest 'replay-descriptor.json') -Encoding utf8
 $runReady=$true
 for($case=0;$case -lt $Cases;$case++){
  $bytes=[byte[]]$seeds[$case%$seeds.Count].Clone();$op=if($case -lt $seeds.Count){'seed'}else{@('bit','truncate','insert')[$random.Next(3)]}
  switch($op){'bit'{if($bytes.Length){$at=$random.Next($bytes.Length);$bytes[$at]=$bytes[$at] -bxor (1 -shl $random.Next(8))}}'truncate'{if($bytes.Length){$length=$random.Next($bytes.Length);$short=[byte[]]::new($length);[Array]::Copy($bytes,$short,$length);$bytes=$short}}'insert'{if($bytes.Length -lt $MaxInputBytes){$at=$random.Next($bytes.Length+1);$list=[Collections.Generic.List[byte]]::new($bytes);$list.Insert($at,[byte]$random.Next(256));$bytes=$list.ToArray()}}}
  $file=Join-Path $dest ('case-{0:d4}.bin' -f $case);[IO.File]::WriteAllBytes($file,$bytes);$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes));$p=Invoke-NCase $file
  if($null -eq $p){$coverageIncomplete=$true;break};$done++;$finding=@{case=$case;mutation=$op;sha256=$hash;path=$file;exitCode=$p.ExitCode;status='ExpectedExit'}
  if($p.TimedOut -or $p.Truncated){$finding.status='Unknown';$coverageIncomplete=$true}
  elseif($p.ExitCode -notin $AllowedExitCodes){$finding.status='UnexpectedExit';$knownFailure=$true}
  # Retain the original finding before minimization can exhaust a budget or fail.
  $r.findings+=$finding
  if($finding.status -eq 'UnexpectedExit'){
   $best=$bytes;$used=0;$minimizationInterrupted=$false
   $candidateFile=Join-Path $dest ('minimize-{0:d4}.bin' -f $case);$chunk=[Math]::Max(1,[int][Math]::Floor($best.Length/2))
   while($chunk -ge 1 -and $used -lt $MinimizeCalls -and $best.Length){$improved=$false
    for($offset=0;$offset -lt $best.Length -and $used -lt $MinimizeCalls;$offset+=$chunk){$remove=[Math]::Min($chunk,$best.Length-$offset);$candidate=[byte[]]::new($best.Length-$remove);[Array]::Copy($best,0,$candidate,0,$offset);[Array]::Copy($best,$offset+$remove,$candidate,$offset,$best.Length-$offset-$remove);[IO.File]::WriteAllBytes($candidateFile,$candidate);$q=Invoke-NCase $candidateFile
     if($null -ne $q){$used++}
     if($null -eq $q -or $q.TimedOut -or $q.Truncated){$minimizationInterrupted=$true;break}
     if($q.ExitCode -eq $p.ExitCode){$best=$candidate;$improved=$true;break}
    }
    if($minimizationInterrupted){break}
    if(-not $improved){$chunk=[int][Math]::Floor($chunk/2)}
   }
   $minFile=Join-Path $dest ('failure-{0:d4}.bin' -f $case);[IO.File]::WriteAllBytes($minFile,$best);$verify=Invoke-NCase $minFile;$preserved=$null -ne $verify -and -not $verify.TimedOut -and -not $verify.Truncated -and $verify.ExitCode -eq $p.ExitCode
   if($minimizationInterrupted -or -not $preserved){$coverageIncomplete=$true}
   $finding.minimization=@{path=$minFile;bytes=$best.Length;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($best));retests=$used;reproduced=$preserved;claim='Budget-bounded deletion reduction, not global minimum'}
  }
 }
}catch{$r.error='Fuzz setup or child invocation failed; argument values suppressed.';$invocationFailed=$true}
if($runReady){
 $coverageIncomplete=$coverageIncomplete -or $done -lt $Cases -or $invocationFailed
 $r.executionEvidence+=@{operation='FuzzSummary';casesCompleted=$done;requestedCases=$Cases;childCalls=$calls;randomSeed=$RandomSeed;coverageIncomplete=$coverageIncomplete}
 $r.artifacts+=@{path=$dest};$r.limitations=@('Process isolation is not a security sandbox.','Unexpected exit predicate requires declared expected reject codes.','No stdout/stderr or argument values persisted; replay requires original trusted invocation.','Minimization preserves exact unexpected exit and retests deletions within budgets.')
}
$code=if($knownFailure){2}elseif($invocationFailed){125}elseif($coverageIncomplete){3}else{0}
Finish-N $r $code -Json:$Json
