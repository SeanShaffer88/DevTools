#requires -Version 7.0
<#
.SYNOPSIS
Generates a dependency-free local source project without executing tools or downloading files.
.PARAMETER Template
WindowsConsole, NativeDll, WowAddon, AndroidApp, or AndroidGame.
.PARAMETER Destination
A new directory whose existing ancestors are not reparse points. Existing destinations are refused.
.PARAMETER InterfaceVersion
Required for WowAddon; select the interface version of the intended client.
.NOTES
Generation does not build, sign, install, or run the project. LASTEXITCODE is 0 or 2.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('WindowsConsole','NativeDll','WowAddon','AndroidApp','AndroidGame')][string]$Template,
 [Parameter(Mandatory)][string]$Destination,[Parameter(Mandatory)][string]$Name,
 [ValidateRange(1,9999999)][int]$InterfaceVersion,[ValidatePattern('^net[0-9]+\.0$')][string]$TargetFramework='net10.0',[switch]$Json)
$ErrorActionPreference='Stop';$global:LASTEXITCODE=2
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');created=$false;template=$Template;destination=$null;files=@();error=$null;buildStatus='NotPerformed';runtimeStatus='NotPerformed'}
try {
 if($Name -notmatch '^[A-Za-z][A-Za-z0-9_]{0,47}$' -or $Name -match '^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$'){throw 'Name must be a non-reserved identifier, 1-48 ASCII letters/digits/underscores, starting with a letter.'}
 if($Template -eq 'WowAddon' -and -not $PSBoundParameters.ContainsKey('InterfaceVersion')){throw 'WowAddon requires explicit InterfaceVersion.'}
 $dest=[IO.Path]::GetFullPath($Destination)
 if($dest -match '[:*?"<>|]' -and $dest.Substring(2) -match '[:*?"<>|]'){throw 'Destination contains invalid path characters.'}
 if(Test-Path -LiteralPath $dest){throw 'Destination already exists; generation never overwrites.'}
 $ancestor=[IO.DirectoryInfo]::new($dest).Parent
 while($null -ne $ancestor){if($ancestor.Exists -and ($ancestor.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Destination ancestors must not be reparse points.'};$ancestor=$ancestor.Parent}
 $source=Join-Path $PSScriptRoot ('templates\'+$Template)
 if(-not (Test-Path -LiteralPath $source -PathType Container)){throw 'Template source is missing.'}
 $sources=@($source)
 if($Template -in @('AndroidApp','AndroidGame')){$sources+=Join-Path $PSScriptRoot 'templates\AndroidCommon'}
 $templateFiles=[Collections.Generic.List[object]]::new()
 foreach($templateRoot in $sources){
  $sourceAncestor=[IO.DirectoryInfo]::new($templateRoot)
  while($null -ne $sourceAncestor){if($sourceAncestor.Exists -and ($sourceAncestor.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Template source ancestors must not be reparse points.'};$sourceAncestor=$sourceAncestor.Parent}
  $queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($templateRoot);$entryCount=0
  while($queue.Count){
   $directory=$queue.Dequeue()
   foreach($entry in Get-ChildItem -LiteralPath $directory -Force){
    $entryCount++;if($entryCount -gt 200){throw 'Template entries exceed limit.'}
    if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Template source links are refused.'}
    if($entry.PSIsContainer){$queue.Enqueue($entry.FullName)}else{$templateFiles.Add([pscustomobject]@{file=$entry;root=$templateRoot})}
   }
  }
 }
 if($templateFiles.Count -gt 100){throw 'Template file count exceeds limit.'}
 $pending=[Collections.Generic.List[object]]::new()
 foreach($templateFile in $templateFiles){
  $file=$templateFile.file
  if($file.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Template source links are refused.'}
  $relative=[IO.Path]::GetRelativePath($templateFile.root,$file.FullName).Replace('__NAME__',$Name)
  $target=[IO.Path]::GetFullPath((Join-Path $dest $relative))
  if(-not $target.StartsWith($dest.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Template path escapes destination.'}
  if($file.Length -gt 1048576){throw 'Template file exceeds 1 MiB limit.'}
  $content=[IO.File]::ReadAllText($file.FullName).Replace('__NAME__',$Name).Replace('__PACKAGE__',('local.devtools.app'+$Name.ToLowerInvariant())).Replace('__INTERFACE__',"$InterfaceVersion").Replace('__FRAMEWORK__',$TargetFramework)
  $pending.Add([pscustomobject]@{target=$target;relative=$relative;content=$content})
 }
 if($pending.Count -eq 0){throw 'Template has no files.'}
 $null=[IO.Directory]::CreateDirectory($dest)
 foreach($file in $pending){$null=[IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($file.target));$stream=[IO.File]::Open($file.target,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes($file.content);$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}}
 $result.destination=$dest;$result.files=@($pending.relative);$result.created=$true;$global:LASTEXITCODE=0
} catch {$result.error=$_.Exception.Message}
if($Json){$result | ConvertTo-Json -Depth 8}else{[pscustomobject]$result}
