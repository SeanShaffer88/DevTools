#requires -Version 7.0
<#
.SYNOPSIS
Compares declared runtime requirements with read-only host or supplied evidence.
.PARAMETER ManifestPath
JSON schemaVersion 1; requirements contain id, kind, architecture and optional
name, minInclusive, maxExclusive, allowPrerelease. Kinds: DotNet,VCRedist,WebView2,Java,Windows.
.PARAMETER InventoryPath
Optional offline schemaVersion 1 inventory, observations and coverage. Supplied
evidence is never represented as a scan of this host. coverage maps each kind to
Complete, Partial or Unknown. Only Complete evidence can prove absence.
.NOTES
No installation or inspected-app execution. Versions are numeric 1-4 components
(Java accepts 1-8 vendor components). Java 1.8.0_XXX normalizes to 8.0.XXX. Numeric
bounds ignore +build metadata; -prerelease is distinct. Bounds are not vendor
roll-forward policy. LASTEXITCODE: 0 all pass, 2 definite mismatch, 3 unknown, 125 invalid input.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$ManifestPath,[string]$InventoryPath,[switch]$Json)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/RuntimeCommon.ps1')
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');valid=$false;source= $(if($InventoryPath){'Supplied'}else{'Host'});coverage=@{};observations=@();findings=@();error=$null;limitations=@('Installed evidence does not certify application compatibility or runtime roll-forward.','Host discovery covers known registered/default locations only; portable and app-local runtimes may be elsewhere.','Unknown evidence is never treated as a pass.')}
$kinds=@('DotNet','VCRedist','WebView2','Java','Windows')
function Add-Observation($List,$Kind,$Name,$Architecture,$Version,$Path,$Evidence) {$List.Add(@{kind=$Kind;name=$Name;architecture=$Architecture;version=$Version;path=$Path;evidence=$Evidence;status='Observed'})}
try {
    $manifest=Read-DevJson $ManifestPath
    if($manifest.schemaVersion -ne 1 -or $manifest.requirements -isnot [array] -or $manifest.requirements.Count -gt 500){throw 'Expected schemaVersion 1 and requirements array (maximum 500).'}
    $ids=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach($req in $manifest.requirements){
        if($req -isnot [Collections.IDictionary] -or -not $req.id -or $req.id.Length -gt 128 -or -not $ids.Add($req.id) -or $req.kind -notin $kinds -or $req.architecture -notin @('x86','x64','Arm64','Any')){throw 'Invalid or duplicate runtime requirement.'}
        if($req.kind -eq 'DotNet' -and (-not $req.name -or $req.name -notmatch '^[A-Za-z0-9_.-]{1,128}$')){throw 'DotNet requirements need an exact framework name.'}
        if($req.Contains('allowPrerelease') -and $req.allowPrerelease -isnot [bool]){throw 'allowPrerelease must be Boolean.'}
        $minimum=if($req.minInclusive){ConvertTo-DevVersion $req.minInclusive $req.kind};$maximum=if($req.maxExclusive){ConvertTo-DevVersion $req.maxExclusive $req.kind}
        if(($minimum -and $minimum.prerelease) -or ($maximum -and $maximum.prerelease)){throw 'Version bounds must be numeric stable versions.'}
        if($minimum -and $maximum -and $minimum.value -ge $maximum.value){throw 'minInclusive must be less than maxExclusive.'}
    }
    if($InventoryPath){
        $inventory=Read-DevJson $InventoryPath
        if($inventory.schemaVersion -ne 1 -or $inventory.observations -isnot [array] -or $inventory.observations.Count -gt 10000 -or $inventory.coverage -isnot [Collections.IDictionary]){throw 'Invalid supplied inventory schema.'}
        foreach($key in $inventory.coverage.Keys){if($key -notin $kinds -or $inventory.coverage[$key] -notin @('Complete','Partial','Unknown')){throw 'Invalid coverage kind/status.'}}
        foreach($obs in $inventory.observations){if($obs -isnot [Collections.IDictionary] -or $obs.kind -notin $kinds -or $obs.architecture -notin @('x86','x64','Arm64','Any','Unknown') -or $obs.status -notin @('Observed','Unavailable','Unknown')){throw 'Invalid supplied runtime observation.'}}
    } else {
        $observations=[Collections.Generic.List[object]]::new();$coverage=@{DotNet='Partial';VCRedist='Partial';WebView2='Partial';Java='Partial';Windows='Complete'}
        $osArch=Get-DevArchitecture ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString())
        Add-Observation $observations Windows Windows $osArch ([Environment]::OSVersion.Version.ToString()) $null 'OSVersion/RuntimeInformation; OS architecture, not shell architecture'
        $roots=@(@{path=(Join-Path $env:ProgramFiles 'dotnet');arch=$osArch},@{path=(Join-Path ${env:ProgramFiles(x86)} 'dotnet');arch='x86'},@{path=(Join-Path $env:ProgramFiles 'dotnet\x64');arch='x64'})
        foreach($root in $roots){foreach($framework in @(Get-DevChildDirectories (Join-Path $root.path 'shared'))){foreach($version in @(Get-DevChildDirectories $framework.FullName)){try{$null=ConvertTo-DevVersion $version.Name;Add-Observation $observations DotNet $framework.Name $root.arch $version.Name $version.FullName 'Default dotnet shared framework directory'}catch{}}}}
        foreach($view in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)){
            $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey([Microsoft.Win32.RegistryHive]::LocalMachine,$view)
            try{foreach($arch in @('x86','x64','Arm64')){$key=$base.OpenSubKey("SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\$arch");if($key){try{if($key.GetValue('Installed') -eq 1){$version=[string]$key.GetValue('Version');if($version){Add-Observation $observations VCRedist 'Microsoft.VC.14' $arch $version $null "HKLM $view VC Runtimes/$arch"}}}finally{$key.Dispose()}}}}finally{$base.Dispose()}
        }
        foreach($hive in @([Microsoft.Win32.RegistryHive]::LocalMachine,[Microsoft.Win32.RegistryHive]::CurrentUser)){foreach($view in @([Microsoft.Win32.RegistryView]::Registry64,[Microsoft.Win32.RegistryView]::Registry32)){
            $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,$view)
            try{$clients=$base.OpenSubKey('SOFTWARE\Microsoft\EdgeUpdate\Clients');if($clients){try{$names=$clients.GetSubKeyNames();if($names.Count -gt 256){throw 'Too many EdgeUpdate clients.'};foreach($name in $names){$key=$clients.OpenSubKey($name);if($key){try{if([string]$key.GetValue('name') -match 'WebView2' -and $key.GetValue('pv')){Add-Observation $observations WebView2 'WebView2' Unknown ([string]$key.GetValue('pv')) $null "$hive $view EdgeUpdate/$name; registry view does not prove runtime architecture"}}finally{$key.Dispose()}}}}finally{$clients.Dispose()}}}finally{$base.Dispose()}
        }}
        $javaRoots=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        if($env:JAVA_HOME){$null=$javaRoots.Add($env:JAVA_HOME)}
        $java=Get-Command java.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if($java){$null=$javaRoots.Add((Split-Path (Split-Path $java.Source -Parent) -Parent))}
        foreach($parent in @((Join-Path $env:ProgramFiles 'Java'),(Join-Path $env:ProgramFiles 'Microsoft'))){foreach($dir in @(Get-DevChildDirectories $parent)){if($dir.Name -match '^(jdk|jre|microsoft-jdk)'){$null=$javaRoots.Add($dir.FullName)}}}
        foreach($root in $javaRoots){$release=Join-Path $root 'release';if([IO.File]::Exists($release)){$item=Get-Item -LiteralPath $release;if($item.Length -le 65536){$text=Get-Content -LiteralPath $release -Raw;if($text -match '(?m)^JAVA_VERSION="([^"]+)"'){$version=$Matches[1];$arch='Unknown';if($text -match '(?m)^OS_ARCH="([^"]+)"'){$arch=Get-DevArchitecture $Matches[1]};Add-Observation $observations Java Java $arch $version $root 'JDK/JRE release metadata (not executable probe)'}}}}
        $inventory=@{schemaVersion=1;coverage=$coverage;observations=@($observations.ToArray())}
    }
    $result.coverage=$inventory.coverage;$result.observations=@($inventory.observations)
    $findings=[Collections.Generic.List[object]]::new()
    foreach($req in $manifest.requirements){
        $minimum=if($req.minInclusive){ConvertTo-DevVersion $req.minInclusive $req.kind};$maximum=if($req.maxExclusive){ConvertTo-DevVersion $req.maxExclusive $req.kind}
        $matching=@($inventory.observations | Where-Object {$_.kind -eq $req.kind -and (-not $req.name -or $_.name -ceq $req.name)})
        $passing=[Collections.Generic.List[object]]::new();$uncertain=$false
        foreach($obs in $matching){if($obs.status -ne 'Observed'){$uncertain=$true;continue};if($obs.architecture -eq 'Unknown' -and $req.architecture -ne 'Any'){$uncertain=$true;continue};if($req.architecture -ne 'Any' -and $obs.architecture -ne $req.architecture){continue};try{$version=ConvertTo-DevVersion $obs.version $req.kind;if($version.prerelease -and -not $req.allowPrerelease){continue};if($minimum -and $version.value -lt $minimum.value){continue};if($maximum -and $version.value -ge $maximum.value){continue};$passing.Add($obs)}catch{$uncertain=$true}}
        $status=if($passing.Count){'pass'}elseif($uncertain -or $inventory.coverage[$req.kind] -ne 'Complete'){'unknown'}else{'fail'}
        $findings.Add(@{id=$req.id;status=$status;expected=$req;observed=@($matching);matching=@($passing.ToArray());reason=$(if($status -eq 'pass'){'Matching observed runtime'}elseif($status -eq 'unknown'){'Incomplete or unusable evidence cannot establish absence/compatibility'}else{'Complete evidence has no matching runtime'})})
    }
    $result.findings=@($findings.ToArray());$result.valid= -not (@($findings | Where-Object {$_.status -ne 'pass'}).Count)
    $global:LASTEXITCODE=if(@($findings | Where-Object status -eq fail).Count){2}elseif(-not $result.valid){3}else{0}
}catch{$result.error=$_.Exception.Message;$global:LASTEXITCODE=125}
if($Json){$result | ConvertTo-Json -Depth 14}else{[pscustomobject]$result}
