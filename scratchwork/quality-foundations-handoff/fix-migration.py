from pathlib import Path
p=Path('Test-DataMigration.ps1');s=p.read_text()
s=s.replace('[string]$InputRoot,$FromVersion,$ToVersion,[switch]$CheckInput)', '$FrozenInput,$FromVersion,$ToVersion)')
s=s.replace(';$inputPath=Resolve-QChild $InputRoot $check.path','')
s=s.replace("$original=if($check.Contains('preservePointers') -and $check.preservePointers.Count -and (Test-Path -LiteralPath $inputPath)){Read-QJson $inputPath}else{$null}","$original=$FrozenInput[$check.path]")
s=s.replace("0 2147483647 'fromVersion'","0 ([long]::MaxValue) 'fromVersion'").replace("0 2147483647 'toVersion'","0 ([long]::MaxValue) 'toVersion'")
a=s.index("  foreach($a in @($case.assertions)");b=s.index('\n }\n if(-not $ExecuteTrusted)',a)
s=s[:a]+'''  foreach($phase in @($case)+$(if($case.Contains('rollback')){@($case.rollback)}else{@()})){
   $a=$phase.assertions;if($a -isnot [Collections.IDictionary]){throw 'Assertions object required.'}
   if(-not $a.Contains('jsonFiles') -or $a.jsonFiles -isnot [array] -or $a.jsonFiles.Count -eq 0){throw 'Plan requires at least one input JSON version check.'}
   $expectedVersion=if([object]::ReferenceEquals($phase,$case)){$case.toVersion}else{$case.fromVersion}
   foreach($group in @('jsonFiles','files')){if($a.Contains($group)){
    if($a[$group] -isnot [array]){throw 'Assertion groups must be arrays.'}
    foreach($entry in $a[$group]){
     if($entry -isnot [Collections.IDictionary] -or $entry.path -isnot [string]){throw 'Assertion requires a path string.'};$null=Resolve-QChild (Join-Path $dest $case.id) $entry.path
     if($group -ceq 'jsonFiles'){
      $sourceFile=Resolve-QChild $source $entry.path;if(-not(Test-Path -LiteralPath $sourceFile -PathType Leaf)){throw 'Selected input JSON evidence is missing.'}
      if($entry.Contains('expectedVersion')){$null=Assert-QInteger $entry.expectedVersion 0 ([long]::MaxValue) 'expectedVersion';if((ConvertTo-QCanonical $entry.expectedVersion) -cne (ConvertTo-QCanonical $expectedVersion)){throw 'expectedVersion contradicts the declared migration or rollback version.'}}
      if($entry.Contains('preservePointers') -and $entry.preservePointers -isnot [array]){throw 'preservePointers must be an array.'}
      if($entry.Contains('equals') -and $entry.equals -isnot [Collections.IDictionary]){throw 'equals must be an object.'}
      $pointers=@($(if($entry.Contains('versionPointer')){$entry.versionPointer}else{'/schemaVersion'}))+@($entry.preservePointers)+@($(if($entry.Contains('equals')){$entry.equals.Keys}))
      foreach($pointer in $pointers){if($null -eq $pointer){continue};if($pointer -isnot [string] -or ($pointer -cne '' -and -not $pointer.StartsWith('/')) -or $pointer -match '~(?![01])'){throw 'Invalid JSON pointer configuration.'}}
      if($entry.Contains('versionPointer') -and $entry.versionPointer -isnot [string]){throw 'versionPointer must be a string.'}
     }elseif($entry.Contains('sha256') -and ($entry.sha256 -isnot [string] -or $entry.sha256 -notmatch '^[A-Fa-f0-9]{64}$')){throw 'Invalid expected hash.'}
    }
   }}
  }'''+s[b:]
s=s.replace('$inputFindings=@();$inputInvalid=$false',"$inputFindings=@();$inputInvalid=$false;$frozenInput=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)")
a=s.index("  if(-not $case.assertions.Contains('jsonFiles')");b=s.index('\n  $expectedInvalid=',a)
s=s[:a]+'''  foreach($check in $case.assertions.jsonFiles){$beforePath=Resolve-QChild $input $check.path;$vp=if($check.Contains('versionPointer')){$check.versionPointer}else{'/schemaVersion'};try{$beforeJson=Read-QJson $beforePath;$frozenInput[$check.path]=$beforeJson;$beforeVersion=Get-QPointer $beforeJson $vp;$match=$beforeVersion.exists -and (ConvertTo-QCanonical $beforeVersion.value) -ceq (ConvertTo-QCanonical $case.fromVersion);if(-not $match){$inputInvalid=$true};$inputFindings+=@{id='input.version';path=$check.path;status=if($match){'Pass'}else{'Fail'}}}catch{$inputInvalid=$true;$inputFindings+=@{id='input.parse';path=$check.path;status='Fail'}}}
  if($case.Contains('rollback')){foreach($check in $case.rollback.assertions.jsonFiles){if(-not $frozenInput.ContainsKey($check.path)){try{$frozenInput[$check.path]=Read-QJson (Resolve-QChild $input $check.path)}catch{}}}}'''+s[b:]
s=s.replace(' $output $input $case.fromVersion',' $output $frozenInput $case.fromVersion')
p.write_text(s)
