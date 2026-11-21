#requires -Version 7.0
<#
.SYNOPSIS
Captures explicit build inputs/artifacts, or compares two captured manifests without rebuilding.
.PARAMETER ConfigurationPath
JSON data with schemaVersion 1 and optional toolchain/configuration objects. Never executed.
.NOTES
Uses lib/DevToolsCommon.psm1 for path containment, bounded strict-UTF-8 JSON, streamed hashing,
canonical comparison, atomic no-clobber output, the result envelope and error redaction.
Exit codes: 0 captured/identical, 2 differences observed (still valid), 125 invalid input or setup failure.
#>
[CmdletBinding(DefaultParameterSetName='Capture')]
param([Parameter(Mandatory,ParameterSetName='Capture')][string]$Root,[Parameter(ParameterSetName='Capture')][string[]]$InputPath=@(),[Parameter(ParameterSetName='Capture')][string[]]$ArtifactPath=@(),[Parameter(ParameterSetName='Capture')][string]$ConfigurationPath,[Parameter(ParameterSetName='Capture')][string]$OutputPath,[Parameter(Mandatory,ParameterSetName='Compare')][string]$BaselinePath,[Parameter(Mandatory,ParameterSetName='Compare')][string]$CurrentPath,[switch]$Json)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'lib\DevToolsCommon.psm1') -Force
$MAX_FILE_BYTES=1GB
$MAX_ENTRIES=10000
$r=New-DtResult -Tool 'Compare-DevBuild' -Scope $PSCmdlet.ParameterSetName
$code=125

function Check-Snapshot($s){
    if($null -eq $s -or $s['inputs'] -isnot [array] -or $s['artifacts'] -isnot [array]){throw 'Invalid build manifest.'}
    $null=Assert-DtInteger -Value $s['schemaVersion'] -Minimum 1 -Maximum 1 -Name 'schemaVersion'
    foreach($kind in @('inputs','artifacts')){
        if($s[$kind].Count -gt $MAX_ENTRIES){throw 'Snapshot entry limit.'}
        $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
        foreach($f in $s[$kind]){
            if($f -isnot [Collections.IDictionary] -or $f['path'] -isnot [string]){throw 'Invalid snapshot file record.'}
            $path=$f['path'].Replace('\','/')
            if(-not $path -or [IO.Path]::IsPathRooted($path) -or $path -match '[:*?"<>|\x00-\x1f]' -or @($path.Split('/')|Where-Object{$_ -in @('','..','.') -or $_ -match '[. ]$'}).Count -or -not $seen.Add($path)){throw 'Invalid snapshot file record.'}
            $null=Assert-DtSha256 -Value ([string]$f['sha256'])
            $null=Assert-DtInteger -Value $f['size'] -Minimum 0 -Maximum $MAX_FILE_BYTES -Name 'size'
        }
    }
}

function Resolve-CapturePath([string]$Base,[string]$Path){
    if([IO.Path]::IsPathRooted($Path)){
        $full=Resolve-DtLocalPath -Path $Path -Kind File
        if(-not $full.StartsWith($Base.TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Capture path outside root or duplicated.'}
        return $full
    }
    try{return Resolve-DtContainedPath -Root $Base -RelativePath $Path -Kind File}
    catch{throw "Capture path outside root or invalid: $($_.Exception.Message)"}
}

try{
    if($PSCmdlet.ParameterSetName -eq 'Capture'){
        $base=Resolve-DtLocalPath -Path $Root -Kind Directory
        $config=@{schemaVersion=1;toolchain=@{};configuration=@{}}
        if($ConfigurationPath){$config=Read-DtJson -Path $ConfigurationPath -SchemaVersion 1}
        $s=[ordered]@{schemaVersion=1;capturedUtc=[DateTime]::UtcNow.ToString('o');toolchain=$config['toolchain'];configuration=$config['configuration'];inputs=@();artifacts=@()}
        foreach($group in @(@{kind='inputs';paths=$InputPath},@{kind='artifacts';paths=$ArtifactPath})){
            if($group.paths.Count -gt $MAX_ENTRIES){throw 'Capture limit exceeded.'}
            $seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
            $records=[Collections.Generic.List[object]]::new()
            foreach($p in $group.paths){
                $full=Resolve-CapturePath $base $p
                $rel=[IO.Path]::GetRelativePath($base,$full).Replace('\','/')
                if(-not $seen.Add($rel)){throw 'Capture path outside root or duplicated.'}
                $length=[IO.FileInfo]::new($full).Length
                if($length -gt $MAX_FILE_BYTES){throw 'Capture needs files at most 1 GiB.'}
                $records.Add([ordered]@{path=$rel;size=$length;sha256=(Get-DtFileSha256 -Path $full -MaxBytes $MAX_FILE_BYTES)})
            }
            $s[$group.kind]=$records.ToArray()
        }
        Check-Snapshot $s
        if($OutputPath){
            $out=Resolve-DtLocalPath -Path $OutputPath -New
            Write-DtFileAtomic -Path $out -Content (($s|ConvertTo-Json -Depth 30)+[Environment]::NewLine)
            $r.outputPath=$out
        }
        $r.manifest=$s
        $code=0
    }else{
        $b=Read-DtJson -Path $BaselinePath;$c=Read-DtJson -Path $CurrentPath;Check-Snapshot $b;Check-Snapshot $c
        $changes=[Collections.Generic.List[object]]::new()
        foreach($kind in @('toolchain','configuration')){
            if((ConvertTo-DtCanonicalJson -InputObject $b[$kind]) -cne (ConvertTo-DtCanonicalJson -InputObject $c[$kind])){$changes.Add(@{kind=$kind;change='Changed';before=$b[$kind];after=$c[$kind]})}
        }
        foreach($kind in @('inputs','artifacts')){
            $old=@{};$new=@{}
            foreach($f in $b[$kind]){$old[$f.path.Replace('\','/')]=$f}
            foreach($f in $c[$kind]){$new[$f.path.Replace('\','/')]=$f}
            foreach($name in @(@($old.Keys)+@($new.Keys)|Sort-Object -Unique)){
                if(-not $old.ContainsKey($name)){$changes.Add(@{kind=$kind;path=$name;change='Added'})}
                elseif(-not $new.ContainsKey($name)){$changes.Add(@{kind=$kind;path=$name;change='Removed'})}
                elseif($old[$name].sha256 -ine $new[$name].sha256 -or $old[$name].size -ne $new[$name].size){$changes.Add(@{kind=$kind;path=$name;change='Changed';before=$old[$name];after=$new[$name]})}
            }
        }
        $r.changes=$changes.ToArray();$r.identical=$changes.Count -eq 0
        $code=if($r.identical){0}else{2}
    }
    $r.limitations.Add('Captures explicit file identity and supplied configuration only; no rebuild or proof of independent reproducibility.')
    $r.limitations.Add('Do not include credentials in supplied configuration; configuration is retained as provided.')
}catch{$r.error=Protect-DtText $_.Exception.Message;$code=125}
$r.status=switch($code){0{'Pass'}2{'Changed'}default{'SetupError'}}
$r.valid=$code -ne 125
$global:LASTEXITCODE=$code
if($Json){ConvertTo-Json -InputObject $r -Depth 32}else{[pscustomobject]$r}
