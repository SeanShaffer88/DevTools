#requires -Version 7.0
param([Parameter(Mandatory)][string]$ProjectPath)
$ErrorActionPreference='Stop'
# Fixed trusted adapter: encoding belongs to this child, never the GUI console.
[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)
$OutputEncoding=[Console]::OutputEncoding
$helper=(Get-Item -LiteralPath (Join-Path $PSScriptRoot '../../Get-ProjectInfo.ps1')).FullName
$root=(Get-Item -LiteralPath $helper).Directory.FullName
$selected=[IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($ProjectPath))
if($selected -ine $root){
 & $helper -ProjectPath $ProjectPath -MaxDepth 2 -Json
 return
}
$gitDir=Get-Item -LiteralPath (Join-Path $root '.git') -Force -ErrorAction SilentlyContinue
if($null -eq $gitDir -or -not $gitDir.PSIsContainer -or ($gitDir.Attributes -band [IO.FileAttributes]::ReparsePoint)){
 & $helper -ProjectPath $ProjectPath -MaxDepth 2 -Json
 return
}

# Trust only this checkout in the Git processes started by the fixed helper.
$countValue=[Environment]::GetEnvironmentVariable('GIT_CONFIG_COUNT','Process')
$count=0
if($null -ne $countValue -and ($countValue -cnotmatch '^[0-9]+$' -or
 -not [int]::TryParse($countValue,[ref]$count) -or $count -eq [int]::MaxValue)){
 throw 'Malformed inherited GIT_CONFIG_COUNT.'
}
$key="GIT_CONFIG_KEY_$count"
$value="GIT_CONFIG_VALUE_$count"
$oldKey=[Environment]::GetEnvironmentVariable($key,'Process')
$oldValue=[Environment]::GetEnvironmentVariable($value,'Process')
try{
 [Environment]::SetEnvironmentVariable($key,'safe.directory','Process')
 [Environment]::SetEnvironmentVariable($value,$root.Replace('\','/'),'Process')
 [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT',($count+1).ToString([Globalization.CultureInfo]::InvariantCulture),'Process')
 & $helper -ProjectPath $ProjectPath -MaxDepth 2 -Json
}finally{
 [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT',$countValue,'Process')
 [Environment]::SetEnvironmentVariable($key,$oldKey,'Process')
 [Environment]::SetEnvironmentVariable($value,$oldValue,'Process')
}
