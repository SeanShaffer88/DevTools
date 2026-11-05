#requires -Version 7.0
# Internal read-only helpers for runtime/SDK/dependency inspectors.
function Read-DevJson([string]$LiteralPath) {
    $item=Get-Item -LiteralPath $LiteralPath -ErrorAction Stop
    if($item.PSIsContainer -or $item.Length -gt 2097152){throw 'JSON input must be a file of at most 2 MiB.'}
    Get-Content -LiteralPath $item.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 32
}
function ConvertTo-DevVersion([string]$Text,[string]$Kind='') {
    if($Kind -eq 'Java' -and $Text -match '^1\.(\d+)\.0_(\d+)(?:-b(\d+))?$'){$Text="$($Matches[1]).0.$($Matches[2])"}
    $maxExtra=if($Kind -eq 'Java'){7}else{3}
    $pattern='^[vV]?(?<core>\d+(?:\.\d+){0,'+$maxExtra+'})(?:-(?<pre>[0-9A-Za-z][0-9A-Za-z.-]*))?(?:\+(?<build>[0-9A-Za-z][0-9A-Za-z.-]*))?$'
    $match=[regex]::Match($Text,$pattern)
    if(-not $match.Success){throw "Unsupported numeric version: $Text"}
    $parts=@($match.Groups['core'].Value.Split('.'));while($parts.Count -lt 8){$parts+='0'}
    $key=[Numerics.BigInteger]::Zero
    foreach($part in $parts){$number=0U;if(-not [uint32]::TryParse($part,[ref]$number)){throw 'Version component exceeds UInt32.'};$key=$key*([Numerics.BigInteger]::new(4294967296L))+$number}
    [pscustomobject]@{value=$key;prerelease=$match.Groups['pre'].Success;text=$Text}
}
function Get-DevArchitecture([string]$Text) {
    switch -Regex ($Text) {'^(x64|amd64|x86_64)$' {'x64';break} '^(x86|i[3-6]86)$' {'x86';break} '^(arm64|aarch64)$' {'Arm64';break} default {'Unknown'}}
}
function Get-DevFileArchitecture([string]$LiteralPath) {
    $stream=[IO.File]::Open($LiteralPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
    try {$reader=[IO.BinaryReader]::new($stream); if($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d){return 'Unknown'}; $stream.Position=0x3c;$offset=$reader.ReadUInt32();if($offset -gt $stream.Length-6){return 'Unknown'};$stream.Position=$offset;if($reader.ReadUInt32() -ne 0x4550){return 'Unknown'};switch($reader.ReadUInt16()){0x14c{'x86'}0x8664{'x64'}0xaa64{'Arm64'}default{'Unknown'}}}finally{$stream.Dispose()}
}
function Get-DevChildDirectories([string]$LiteralPath,[int]$Limit=256) {
    if(-not [IO.Directory]::Exists($LiteralPath)){return}
    $items=@(Get-ChildItem -LiteralPath $LiteralPath -Directory -Force -ErrorAction Stop | Select-Object -First ($Limit+1))
    if($items.Count -gt $Limit){throw 'Directory inventory exceeds safety limit.'}
    $items | Where-Object {($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -eq 0}
}
