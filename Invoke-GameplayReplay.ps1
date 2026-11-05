#requires -Version 7.0
<#
.SYNOPSIS
Runs an explicitly trusted JSON stdin/stdout gameplay adapter once or twice.
.PARAMETER ScenarioPath
Strict schema1: {schemaVersion,seed,events:[{tick,type,data?}],rules:[assertion IDs],initialState?,checkpoints?:[ticks]}. Events must be ordered. Request is {schemaVersion:1,seed,events,initialState?,checkpoints?}; rules are expected assertion IDs and are not executed as source.
.PARAMETER AdapterPath
Explicit native executable; argument array is passed without a shell. ExecuteTrusted is required. The adapter may execute arbitrary code with caller permissions.
.NOTES
Response: {schemaVersion:1,states:[{tick,stateHash,state?}],assertions:[{id,passed,detail?}],saveLoad?:{beforeHash,afterHash}}. Each requested checkpoint needs a state. saveLoad required with checkpoints. State hash: SHA256 UTF8 canonical JSON: ordinal keys, JSON-escaped strings, preserved numeric lexemes, array order, no whitespace/BOM. Duplicate properties/nonfinite numbers refused. Hashes are checked when state is supplied. Runs compare canonical states/assertions/saveLoad only, never timing/PID. No engine integration is implied. Output/input <=1 MiB, 1-60 seconds/run, 1-2 runs.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AdapterPath,[string[]]$ArgumentList=@(),[Parameter(Mandatory)][string]$ScenarioPath,[Parameter(Mandatory)][string]$Destination,[switch]$ExecuteTrusted,[ValidateRange(1,2)][int]$Runs=2,[ValidateRange(1,60)][int]$TimeoutSeconds=15,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib/QualityGames.ps1');$r=QG-Result 'Invoke-GameplayReplay' @{scenario=$ScenarioPath;runs=$Runs};$code=125;$dest=$null
try{
 if(-not $ExecuteTrusted){throw 'ExecuteTrusted acknowledgement required.'};$exe=QG-Exe $AdapterPath;if($ArgumentList.Count -gt 64 -or @($ArgumentList|Where-Object{$null -eq $_ -or $_.Length -gt 4096}).Count){throw 'Adapter arguments exceed bounds.'};$new=QG-Path $Destination -New;$s=QG-Read $ScenarioPath;QG-Fields $s @('schemaVersion','seed','events','rules') @('initialState','checkpoints');QG-Schema $s;QG-Int $s.seed 0 9007199254740991
 if($s.events -isnot [array] -or $s.events.Count -gt 4096 -or $s.rules -isnot [array] -or $s.rules.Count -lt 1 -or $s.rules.Count -gt 256){throw 'Bounded events and nonempty required rules arrays required.'}
 $previous=-1L;foreach($e in $s.events){QG-Fields $e @('tick','type') @('data');QG-Int $e.tick 0 2147483647;if($e.tick -lt $previous -or $e.type -isnot [string] -or $e.type -cnotmatch '^[A-Za-z][A-Za-z0-9_.-]{0,63}$'){throw 'Events must have ordered ticks and safe type labels.'};$previous=$e.tick}
 $rules=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($rule in $s.rules){if($rule -isnot [string] -or $rule -cnotmatch '^[A-Za-z][A-Za-z0-9_.-]{0,63}$' -or -not $rules.Add($rule)){throw 'Invalid/duplicate rule ID.'}}
 if($s.Contains('checkpoints')){if($s.checkpoints -isnot [array] -or $s.checkpoints.Count -lt 1 -or $s.checkpoints.Count -gt 256){throw 'Checkpoints must be nonempty bounded ticks array.'};$ticks=[Collections.Generic.HashSet[long]]::new();foreach($t in $s.checkpoints){QG-Int $t;if(-not $ticks.Add($t)){throw 'Duplicate checkpoint.'}}}
 $request=[ordered]@{schemaVersion=1;seed=$s.seed;events=$s.events};foreach($key in @('initialState','checkpoints')){if($s.Contains($key)){$request[$key]=$s[$key]}};$inputText=$request|ConvertTo-Json -Depth 32 -Compress;$null=QG-JsonText $inputText
 $null=[IO.Directory]::CreateDirectory($new);$dest=$new;$code=0;$canonical=$null
 for($run=1;$run -le $Runs;$run++){
  $cmd=QG-Run $exe $ArgumentList $inputText $TimeoutSeconds $dest;$r.executionEvidence+=@{run=$run;pid=$cmd.Pid;exitCode=$cmd.ExitCode;timedOut=$cmd.TimedOut;truncated=$cmd.Truncated};foreach($stream in @('Output','Error')){$path=Join-Path $dest "run-$run-$stream.txt";[IO.File]::WriteAllText($path,$cmd.$stream);$r.artifacts+=QG-Artifact $path}
  if($cmd.TimedOut -or $cmd.Truncated){$code=3;QG-Finding $r "run-$run" 'Unknown' 'Adapter exceeded time/output limit';break};if($cmd.ExitCode -ne 0){$code=2;QG-Finding $r "run-$run" 'Fail' 'Adapter returned nonzero exit';break}
  try{$o=QG-JsonText $cmd.Output;QG-Fields $o @('schemaVersion','states','assertions') @('saveLoad');QG-Schema $o;if($o.states -isnot [array] -or $o.states.Count -lt 1 -or $o.states.Count -gt 8192 -or $o.assertions -isnot [array] -or $o.assertions.Count -gt 256){throw 'Response states/assertions missing or oversized.'}
   $seenTicks=[Collections.Generic.HashSet[long]]::new();$prev=-1L;foreach($state in $o.states){QG-Fields $state @('tick','stateHash') @('state');QG-Int $state.tick;if($state.tick -lt $prev -or -not $seenTicks.Add($state.tick) -or $state.stateHash -isnot [string] -or $state.stateHash -cnotmatch '^[0-9a-f]{64}$'){throw 'Invalid state tick/hash.'};$prev=$state.tick;if($state.Contains('state')){
     # Extract state JSON directly to preserve the adapter's number lexemes.
     $doc=[Text.Json.JsonDocument]::Parse($cmd.Output);try{$element=$doc.RootElement.GetProperty('states')[[int]($seenTicks.Count-1)].GetProperty('state');$hash=[DevTools.QualityGames.Data]::Hash($element.GetRawText())}finally{$doc.Dispose()};if($hash -cne $state.stateHash){QG-Finding $r "run-$run/state" 'Fail' 'Canonical state hash mismatch';$code=2}
    }}
   $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($assertion in $o.assertions){QG-Fields $assertion @('id','passed') @('detail');if($assertion.id -isnot [string] -or $assertion.id.Length -gt 64 -or -not $ids.Add($assertion.id) -or $assertion.passed -isnot [bool]){throw 'Invalid assertion.'};if(-not $assertion.passed){QG-Finding $r $assertion.id 'Fail' 'Adapter assertion false';$code=2}}
   foreach($rule in $rules){if(-not $ids.Contains($rule)){QG-Finding $r $rule 'Fail' 'Required assertion absent';$code=2}}
   if($s.Contains('checkpoints')){foreach($tick in $s.checkpoints){if(-not $seenTicks.Contains($tick)){QG-Finding $r "checkpoint-$tick" 'Fail' 'Checkpoint state absent';$code=2}};if(-not $o.Contains('saveLoad')){QG-Finding $r 'saveLoad' 'Fail' 'Checkpoint save/load evidence absent';$code=2}}
   if($o.Contains('saveLoad')){QG-Fields $o.saveLoad @('beforeHash','afterHash');foreach($k in @('beforeHash','afterHash')){if($o.saveLoad[$k] -isnot [string] -or $o.saveLoad[$k] -cnotmatch '^[0-9a-f]{64}$'){throw 'Invalid save/load hash.'}};if($o.saveLoad.beforeHash -cne $o.saveLoad.afterHash){QG-Finding $r 'saveLoad' 'Fail' 'Save/load hash mismatch';$code=2}}
   $current=[DevTools.QualityGames.Data]::Canonical($cmd.Output);if($run -eq 1){$canonical=$current}elseif($canonical -cne $current){QG-Finding $r 'determinism' 'Fail' 'Canonical declared response differs between runs';$code=2};QG-Finding $r "run-$run/protocol" 'Pass' 'Nonempty response validated'
  }catch{QG-Finding $r "run-$run/protocol" 'Unknown' $_.Exception.Message;if($code -eq 0){$code=3};break}
 }
 $r.limitations=@('Only explicitly selected adapter mechanics are tested; no arbitrary game engine integration.','Adapter assertions/state hashes are supplied evidence. Optional state is independently hashed.','Canonical numbers preserve JSON lexical precision: 1 and 1.0 are distinct. No timestamps are accepted in the response envelope.','A subprocess is not a sandbox; adapter writes are not constrained by this helper.')
}catch{$r.error=$_.Exception.Message;$code=125};QG-Finish $r $code -Json:$Json -Destination $dest
