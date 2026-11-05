#requires -Version 7.0
function Assert-DevNewDestination([string]$Destination){
    $full=[IO.Path]::GetFullPath($Destination);if($full.Substring([IO.Path]::GetPathRoot($full).Length) -match '[:*?]'){throw 'Destination must not contain alternate streams or wildcards.'};if(Test-Path -LiteralPath $full){throw 'Destination must not already exist.'}
    $cursor=Split-Path $full -Parent
    while($cursor){if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force;if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Destination ancestors must be ordinary directories.'}};$next=Split-Path $cursor -Parent;if($next -eq $cursor){break};$cursor=$next};return $full
}
function Resolve-DevContainedFile([string]$Root,[string]$Relative){
    if(-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '[:*?]' -or '..' -in $Relative.Replace('/','\').Split('\')){throw 'Expected a contained relative file path.'}
    $rootPath=[IO.Path]::GetFullPath($Root).TrimEnd('\');$full=[IO.Path]::GetFullPath((Join-Path $rootPath $Relative));if(-not $full.StartsWith($rootPath+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes input root.'}
    $cursor=$full;while($cursor){if(Test-Path -LiteralPath $cursor){$item=Get-Item -LiteralPath $cursor -Force;if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse input paths are not supported.'}};$next=Split-Path $cursor -Parent;if($next -eq $cursor){break};$cursor=$next};return $full
}
function Invoke-DevBoundedProcess([string]$Executable,[string[]]$Arguments,[string]$WorkingDirectory,[int]$TimeoutSeconds=60){
    if(-not ('LocalDevTools.AndroidProcess' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'AndroidProcess.cs')}
    [LocalDevTools.AndroidProcess]::Run($Executable,$Arguments,$WorkingDirectory,$TimeoutSeconds)
}
