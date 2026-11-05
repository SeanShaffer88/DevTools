# Private Games wave implementation. No inspected code is loaded by static helpers.
if(-not ('DevTools.QualityGames.Data' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'QualityGames.cs')}
function QG-Path([string]$Path,[switch]$New){
 if([string]::IsNullOrWhiteSpace($Path)){throw 'Explicit path required.'};$full=[IO.Path]::GetFullPath($Path);if($full.StartsWith('\\') -or $full.Substring(2).Contains(':')){throw 'Local canonical paths only.'}
 if($New -and (Test-Path -LiteralPath $full)){throw 'Destination must be new.'};$p=$full
 while($p){if(Test-Path -LiteralPath $p){if((Get-Item -LiteralPath $p -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Reparse paths refused.'}};$p=[IO.Path]::GetDirectoryName($p)};$full
}
function QG-Relative([string]$Root,[string]$Relative){if(-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '[:*?\x00-\x1f]' -or @($Relative.Replace('\','/').Split('/')|Where-Object{$_ -cin @('','..','.')}).Count){throw 'Unsafe relative path.'};$p=QG-Path (Join-Path $Root $Relative);if(-not $p.StartsWith($Root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Path escapes root.'};$p}
function QG-JsonText([string]$Text){if([Text.Encoding]::UTF8.GetByteCount($Text) -gt 1048576){throw 'JSON exceeds 1 MiB.'};$null=[DevTools.QualityGames.Data]::Canonical($Text);$v=ConvertFrom-Json -InputObject $Text -AsHashtable -Depth 32 -NoEnumerate;if($v -isnot [Collections.IDictionary]){throw 'JSON object required.'};return ,$v}
function QG-Read([string]$Path){$p=QG-Path $Path;$f=Get-Item -LiteralPath $p;if($f.PSIsContainer -or $f.Length -gt 1048576){throw 'JSON must be a file <=1 MiB.'};QG-JsonText ([IO.File]::ReadAllText($p))}
function QG-Fields($Object,[string[]]$Required,[string[]]$Optional=@()){
 if($Object -isnot [Collections.IDictionary]){throw 'Object required.'};foreach($key in $Required){if($key -cnotin @($Object.Keys)){throw "Missing property: $key"}};foreach($key in $Object.Keys){if($key -cnotin $Required -and $key -cnotin $Optional){throw "Unexpected property: $key"}}
}
function QG-Int($Value,[long]$Min=0,[long]$Max=2147483647){if(($Value -isnot [long] -and $Value -isnot [int]) -or $Value -lt $Min -or $Value -gt $Max){throw 'Typed integer out of range.'}}
function QG-Number($Value,[double]$Min=0,[double]$Max=1e15){if(($Value -isnot [long] -and $Value -isnot [int] -and $Value -isnot [double] -and $Value -isnot [decimal]) -or -not [double]::IsFinite([double]$Value) -or $Value -lt $Min -or $Value -gt $Max){throw 'Finite typed number out of range.'}}
function QG-Schema($Object){QG-Int $Object['schemaVersion'] 1 1}
function QG-Result([string]$Tool,$Scope){[ordered]@{schemaVersion=1;tool=$Tool;observedUtc=[DateTime]::UtcNow.ToString('o');scope=$Scope;status='SetupError';findings=@();artifacts=@();executionEvidence=@();limitations=@();error=$null}}
function QG-Finding($R,[string]$Id,[string]$Status,$Evidence){$R.findings+=@{id=$Id;status=$Status;evidence=$Evidence}}
function QG-Finish($R,[int]$Code,[switch]$Json,[string]$Destination){$R.status=switch($Code){0{'Pass'}2{'Fail'}3{'Unknown'}default{'SetupError'}};if($Destination){$R|ConvertTo-Json -Depth 32|Set-Content -LiteralPath (Join-Path $Destination 'result.json') -Encoding utf8};$global:LASTEXITCODE=$Code;if($Json){$R|ConvertTo-Json -Depth 32}else{[pscustomobject]$R}}
function QG-Files([string]$Root,[int]$MaxEntries=4096){$queue=[Collections.Generic.Queue[string]]::new();$queue.Enqueue($Root);$count=0;while($queue.Count){foreach($f in Get-ChildItem -LiteralPath $queue.Dequeue() -Force){if(++$count -gt $MaxEntries){throw 'Tree entry count exceeds limit.'};$null=QG-Path $f.FullName;if($f.PSIsContainer){$queue.Enqueue($f.FullName)}else{$f}}}}
function QG-Exe([string]$Path){$p=QG-Path $Path;if(-not (Test-Path -LiteralPath $p -PathType Leaf) -or [IO.Path]::GetExtension($p) -ine '.exe'){throw 'Explicit existing native executable required.'};$p}
function QG-Run([string]$Exe,[string[]]$Arguments,[string]$InputText='', [int]$Timeout=15,[string]$Directory=$PSScriptRoot){[DevTools.QualityGames.Command]::Run($Exe,$Arguments,$InputText,$Timeout,1048576,$Directory)}
function QG-Artifact([string]$Path){@{path=$Path;bytes=(Get-Item -LiteralPath $Path).Length;sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}}
