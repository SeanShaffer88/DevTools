function Assert-PlatformPath([string]$Path,[switch]$New) {
 $full=[IO.Path]::GetFullPath($Path);if($full.StartsWith('\\')){throw 'Local paths required.'}
 if($New -and (Test-Path -LiteralPath $full)){throw 'Destination already exists.'}
 $cursor=$full;while($cursor){if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force;if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse points are refused.'}};$next=[IO.Path]::GetDirectoryName($cursor);if($next -eq $cursor){break};$cursor=$next};$full
}
function Read-PlatformJson([string]$Path) { $file=Get-Item -LiteralPath (Assert-PlatformPath $Path);if($file.PSIsContainer -or $file.Length -gt 4194304){throw 'JSON file exceeds 4 MiB or is not a file.'};Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 40 }
function Resolve-PlatformExe([string]$Path) { $exe=(Get-Command -Name $Path -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source;if([IO.Path]::GetExtension($exe) -ine '.exe'){throw 'A native executable is required.'};$exe }
function Invoke-PlatformCommand([string]$Exe,[string[]]$Arguments,[int]$Timeout=20,[int]$Limit=2097152) { if(-not ('LocalDevTools.PlatformProcess' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'PlatformResources.cs')};[LocalDevTools.PlatformProcess]::Run($Exe,$Arguments,$PSScriptRoot,$Timeout,$Limit) }
function New-PlatformResult([string]$Tool,[string]$Scope) { [ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');tool=$Tool;scope=$Scope;valid=$false;findings=@();limitations=@();error=$null} }
function Write-PlatformResult($Result,[switch]$Json) { if($Json){$Result|ConvertTo-Json -Depth 30}else{[pscustomobject]$Result} }
function Get-PlatformFiles([string]$Root,[int]$Limit=10000) {
 $base=Assert-PlatformPath $Root;$queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($base);$files=[Collections.Generic.List[object]]::new();$count=0
 while($queue.Count){$dir=$queue.Dequeue();foreach($item in Get-ChildItem -LiteralPath $dir -Force){if(++$count -gt $Limit){throw 'Tree entry limit exceeded.'};if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse tree entry refused.'};if($item.PSIsContainer){$queue.Enqueue($item.FullName)}else{$files.Add($item)}}};$files.ToArray()
}
