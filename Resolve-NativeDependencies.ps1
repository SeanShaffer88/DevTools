#requires -Version 7.0
<#
.SYNOPSIS
Builds a bounded static native DLL import/export dependency graph without loading targets.
.PARAMETER SearchDirectory
Explicit candidate directories after the root application's directory. PATH is never searched.
.NOTES
KnownDLL names prefer architecture-correct Windows system files. API-set mappings,
activation contexts and dynamic LoadLibrary calls are not emulated. Nonzero delay
import directories are explicitly unknown; zero/absent directories are known absent.
Symbols and ordinals are checked, including bounded forwarded-export chains.
LASTEXITCODE: 0 static checks pass, 2 definite missing/invalid/architecture/symbol issue,
3 unsupported or bounded/incomplete evidence, 125 setup failure. A pass is not loader equivalence.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$Path,[string[]]$SearchDirectory=@(),[ValidateRange(1,32)][int]$MaxDepth=12,[ValidateRange(1,1024)][int]$MaxNodes=256,[switch]$Json)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/RuntimeCommon.ps1')
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;root=$null;searchDirectories=@();nodes=@();edges=@();findings=@();cycles=@();error=$null;scope='Static native imports in the declared search context';limitations=@('Not Windows loader emulation: API-set host mappings, SxS/activation contexts and loaded-module state are not resolved.','Dynamic LoadLibrary calls, managed dependencies and signature trust are not checked.','Nonzero delay-import directories are explicitly unsupported, not silently ignored.','Directory order is explicit root app directory, supplied directories, system directory; KnownDLL names prefer system directory.')}
$nodes=[Collections.Generic.List[object]]::new();$edges=[Collections.Generic.List[object]]::new();$findings=[Collections.Generic.List[object]]::new();$cycles=[Collections.Generic.List[object]]::new();$cache=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::OrdinalIgnoreCase);$active=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$known=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$script:symbolChecks=0;$script:symbolBudgetExceeded=$false;$result.limits=@{maxDepth=$MaxDepth;maxNodes=$MaxNodes;maxEdges=8192;maxSymbolChecks=65536}
function Finding([string]$Id,[string]$Status,[string]$Detail,[string]$File=''){$findings.Add(@{id=$Id;status=$Status;detail=$Detail;path=$File})}
function Get-DelayDirectory([string]$File){
    $stream=[IO.File]::Open($File,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try{$reader=[IO.BinaryReader]::new($stream);if($stream.Length -lt 64){throw 'Truncated PE header.'};$stream.Position=0x3c;$pe=$reader.ReadUInt32();if($pe -gt $stream.Length-26){throw 'Invalid PE offset.'};$stream.Position=$pe+20;$optSize=$reader.ReadUInt16();$opt=[long]$pe+24;if($optSize -gt $stream.Length-$opt){throw 'Truncated PE optional header.'};$stream.Position=$opt;$magic=$reader.ReadUInt16();$directoryBase=if($magic -eq 0x20b){112}elseif($magic -eq 0x10b){96}else{throw 'Unsupported PE format.'};if($optSize -lt $directoryBase){throw 'Truncated data directory header.'};$stream.Position=$opt+$directoryBase-4;$count=$reader.ReadUInt32();if($count -le 13){return $false};if($optSize -lt $directoryBase+14*8){throw 'Truncated delay directory slot.'};$stream.Position=$opt+$directoryBase+13*8;$rva=$reader.ReadUInt32();$size=$reader.ReadUInt32();return ($rva -ne 0 -or $size -ne 0)}finally{$stream.Dispose()}
}
function Read-Node([string]$File,[int]$Depth){
    $File=[IO.Path]::GetFullPath($File)
    if($cache.ContainsKey($File)){if($active.Contains($File)){$cycles.Add(@{kind='ImportCycle';path=$File})};return $cache[$File]}
    if($Depth -gt $MaxDepth -or $nodes.Count -ge $MaxNodes){Finding GraphLimit unknown 'Dependency depth/node bound reached.' $File;return $null}
    $info=& (Join-Path $PSScriptRoot 'Get-DllInfo.ps1') -Path $File
    if(-not $info.valid){Finding InvalidImage fail $info.error $File;return $null}
    $nameIndex=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal);$ordinalIndex=[Collections.Generic.Dictionary[uint32,object]]::new()
    foreach($export in $info.image.Exports){if($export.Name -and -not $nameIndex.ContainsKey($export.Name)){$nameIndex.Add($export.Name,$export)};if(-not $ordinalIndex.ContainsKey($export.Ordinal)){$ordinalIndex.Add($export.Ordinal,$export)}}
    $node=[pscustomobject]@{id=$nodes.Count;path=$File;architecture=$info.image.Architecture;managedIndicator=$info.image.HasClrHeader;delayImports='None';image=$info.image;nameIndex=$nameIndex;ordinalIndex=$ordinalIndex}
    $cache.Add($File,$node);$nodes.Add($node);$null=$active.Add($File)
    if($node.architecture -ne $script:targetArchitecture){Finding ArchitectureMismatch fail "Expected $script:targetArchitecture, observed $($node.architecture)" $File}
    if(Get-DelayDirectory $File){$node.delayImports='Unsupported';Finding DelayImportsUnsupported unknown 'Image declares delay imports; those edges have not been resolved.' $File}
    if($node.managedIndicator){Finding ManagedDependenciesNotInspected unknown 'CLR metadata is present; this graph checks native imports only.' $File}
    foreach($import in $info.image.Imports){
        if($edges.Count -ge 8192 -or $script:symbolBudgetExceeded){Finding GraphLimit unknown 'Aggregate edge/symbol-check budget reached.' $File;break}
        $dependency=Find-Module $import.Library ($Depth+1)
        $edge=@{from=$File;library=$import.Library;to=$(if($dependency){$dependency.path}else{$null});symbols=@();resolution=$(if($dependency){'CandidateSelected'}elseif($import.Library -match '^(api-ms-win-|ext-ms-win-)'){'SystemContractUnknown'}else{'Unresolved'})}
        $checks=[Collections.Generic.List[object]]::new()
        if($dependency){foreach($symbol in $import.Symbols){if($script:symbolBudgetExceeded){break};$identity=if($symbol.Name){$symbol.Name}else{"#$($symbol.Ordinal)"};$checks.Add((Check-Symbol $dependency $identity 0 ([Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal))))}}
        $edge.symbols=@($checks.ToArray());$edges.Add($edge)
    }
    $null=$active.Remove($File);return $node
}
function Find-Module([string]$Library,[int]$Depth){
    if($Library -notmatch '^[A-Za-z0-9_.-]{1,260}$' -or $Library -in @('.','..')){Finding UnsafeImportName fail "Unsupported library leaf name: $Library";return $null}
    if($Library -match '^(api-ms-win-|ext-ms-win-)'){Finding ApiSetMappingUnknown unknown "System API contract $Library requires an actual OS mapping; no file-missing inference made.";return $null}
    $locations=if($known.Contains($Library)){@($script:systemDirectory)+@($script:directories)}else{@($script:directories)}
    $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$found=$false
    foreach($directory in $locations){$candidate=Join-Path $directory $Library;if(-not $seen.Add($candidate)){continue};if([IO.File]::Exists($candidate)){$found=$true;return Read-Node $candidate $Depth}}
    if(-not $found){Finding MissingLibrary fail "No $Library in declared search context."};return $null
}
function Check-Symbol($Node,[string]$Identity,[int]$Depth,$Visited){
    if($script:symbolChecks -ge 65536){$script:symbolBudgetExceeded=$true;Finding GraphLimit unknown 'Aggregate symbol-check budget reached.' $Node.path;return @{symbol=$Identity;status='unknown'}};$script:symbolChecks++
    $key="$($Node.path.ToUpperInvariant())|$Identity"
    if($Depth -gt $MaxDepth){Finding ForwarderDepth unknown "Forwarder depth bound: $Identity" $Node.path;return @{symbol=$Identity;status='unknown'}}
    if(-not $Visited.Add($key)){$cycles.Add(@{kind='ForwarderCycle';path=$Node.path;symbol=$Identity});Finding ForwarderCycle unknown "Forwarded symbol cycle: $Identity" $Node.path;return @{symbol=$Identity;status='unknown'}}
    $exports=if($Identity.StartsWith('#')){$ordinal=0U;if(-not [uint32]::TryParse($Identity.Substring(1),[ref]$ordinal)){Finding InvalidOrdinal fail $Identity $Node.path;return @{symbol=$Identity;status='fail'}};if($Node.ordinalIndex.ContainsKey($ordinal)){@($Node.ordinalIndex[$ordinal])}else{@()}}else{if($Node.nameIndex.ContainsKey($Identity)){@($Node.nameIndex[$Identity])}else{@()}}
    if(-not $exports.Count){Finding MissingExport fail "Missing export $Identity" $Node.path;return @{symbol=$Identity;status='fail'}}
    $export=$exports[0]
    if($export.Forwarder){$split=$export.Forwarder.LastIndexOf('.');if($split -lt 1 -or $split -eq $export.Forwarder.Length-1){Finding MalformedForwarder fail $export.Forwarder $Node.path;return @{symbol=$Identity;status='fail'}};$library=$export.Forwarder.Substring(0,$split);if(-not $library.EndsWith('.dll',[StringComparison]::OrdinalIgnoreCase)){$library+='.dll'};$next=Find-Module $library ($Depth+1);if(-not $next){return @{symbol=$Identity;status=$(if($library -match '^(api-ms-win-|ext-ms-win-)'){'unknown'}else{'fail'});forwarder=$export.Forwarder}};$forwardResult=Check-Symbol $next $export.Forwarder.Substring($split+1) ($Depth+1) $Visited;return @{symbol=$Identity;status=$forwardResult.status;forwarder=$export.Forwarder;target=$next.path}}
    return @{symbol=$Identity;status='pass';ordinal=$export.Ordinal}
}
try{
    $item=Get-Item -LiteralPath $Path -ErrorAction Stop;if($item.PSIsContainer){throw 'Path must be a PE file.'};$result.root=$item.FullName
    $rootInfo=& (Join-Path $PSScriptRoot 'Get-DllInfo.ps1') -Path $item.FullName;if(-not $rootInfo.valid){throw $rootInfo.error};$script:targetArchitecture=$rootInfo.image.Architecture
    if($script:targetArchitecture -notin @('x86','x64','Arm64')){throw 'Unsupported root image architecture.'}
    $osArch=Get-DevArchitecture ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString())
    $script:systemDirectory=if($script:targetArchitecture -eq 'x86' -and $osArch -ne 'x86'){Join-Path $env:WINDIR 'SysWOW64'}else{Join-Path $env:WINDIR 'System32'}
    if($script:targetArchitecture -eq 'Arm64' -and $osArch -ne 'Arm64'){Finding SystemArchitectureUnknown unknown 'Host system directory cannot supply target Arm64 runtime DLLs.';$script:systemDirectory=''}
    if($SearchDirectory.Count -gt 64){throw 'At most 64 explicit search directories are supported.'}
    $directorySet=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);$directoryList=[Collections.Generic.List[string]]::new()
    foreach($directory in (@($item.DirectoryName)+$SearchDirectory+@($script:systemDirectory))){if(-not $directory){continue};$resolved=[IO.Path]::GetFullPath($directory);if(-not [IO.Directory]::Exists($resolved)){throw "Search directory does not exist: $resolved"};if($directorySet.Add($resolved)){$directoryList.Add($resolved)}}
    $script:directories=@($directoryList.ToArray());$result.searchDirectories=$script:directories
    $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryView]::Registry64)
    try{$key=$base.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs');if($key){try{foreach($name in $key.GetValueNames()){if($name -notin @('DllDirectory','DllDirectory32')){$value=[string]$key.GetValue($name);if($value -match '^[A-Za-z0-9_.-]+\.dll$'){$null=$known.Add($value)}}}}finally{$key.Dispose()}}}finally{$base.Dispose()}
    $null=Read-Node $item.FullName 0
    if([IO.File]::Exists($item.FullName+'.manifest')){Finding ActivationContextUnknown unknown 'An application sidecar manifest exists; SxS redirection is not applied.' $item.FullName}
    $result.nodes=@($nodes | ForEach-Object {@{id=$_.id;path=$_.path;architecture=$_.architecture;managedIndicator=$_.managedIndicator;delayImports=$_.delayImports}});$result.edges=@($edges.ToArray());$result.findings=@($findings.ToArray());$result.cycles=@($cycles.ToArray());$result.valid= -not @($findings | Where-Object status -in @('fail','unknown')).Count
    $global:LASTEXITCODE=if(@($findings | Where-Object status -eq fail).Count){2}elseif(-not $result.valid){3}else{0}
}catch{$result.error=$_.Exception.Message;$global:LASTEXITCODE=125}
if($Json){$result | ConvertTo-Json -Depth 16}else{[pscustomobject]$result}
