#requires -Version 7.1
<#
.SYNOPSIS
Compare explicit PNG/BMP images and/or schema1 UIA snapshots with compatible contexts.
.DESCRIPTION
Context files require context:{dpi,theme,locale,coordinateSpace}. Snapshot context can be
embedded. Pixel channels are straight decoded RGBA (including RGB of transparent pixels),
no color management, scaling or antialias normalization. Diff image is opaque RGB deltas.
Budget schema1: channelTolerance 0..255, maxChangedPixels, maxChannelDifference 0..255,
meanChannelDifference 0..255. All four are required. Names and patterns are ordinal.
#>
[CmdletBinding()]param([string]$BaselineImage,[string]$CurrentImage,[string]$BaselineSnapshot,[string]$CurrentSnapshot,[string]$BaselineContext,[string]$CurrentContext,[string]$BudgetPath,[string]$DiffImage,[ValidateRange(1,16777216)][long]$MaxImageBytes=8388608,[ValidateRange(1,4194304)][long]$MaxPixels=1048576,[ValidateRange(1,10000)][int]$MaxNodes=2000,[switch]$Json)
. "$PSScriptRoot/lib/QualityNative.ps1"
function Get-NImageHeader($path) {
 $p=Test-NFile $path $MaxImageBytes;$s=[IO.File]::OpenRead($p)
 try{$h=[byte[]]::new(54);$n=$s.Read($h,0,54)
  if($n -ge 33 -and [Convert]::ToHexString($h[0..7]) -ceq '89504E470D0A1A0A' -and [Text.Encoding]::ASCII.GetString($h,12,4) -ceq 'IHDR'){$wb=[byte[]]$h[16..19];$hb=[byte[]]$h[20..23];if([BitConverter]::IsLittleEndian){[Array]::Reverse($wb);[Array]::Reverse($hb)};$w=[BitConverter]::ToUInt32($wb,0);$height=[BitConverter]::ToUInt32($hb,0)}
  elseif($n -ge 54 -and $h[0] -eq 66 -and $h[1] -eq 77 -and [BitConverter]::ToUInt32($h,14) -ge 40){$w=[BitConverter]::ToInt32($h,18);$height=[Math]::Abs([long][BitConverter]::ToInt32($h,22))}else{throw 'Only bounded PNG IHDR or Windows BMP supported'}
  if($w -lt 1 -or $height -lt 1 -or $w -gt 16384 -or $height -gt 16384 -or [long]$w*$height -gt $MaxPixels){throw 'Image dimension/pixel budget exceeded before decoding'}
  @{path=$p;width=[int]$w;height=[int]$height}
 }finally{$s.Dispose()}
}
function Get-NContext($file,$snapshot) {if($file){(Read-NJson $file).context}elseif($null -ne $snapshot){$snapshot.context}else{$null}}
$r=New-NResult 'Compare-UiSnapshot';$code=0;$a=$null;$b=$null;$diff=$null
try {
 if(-not $BaselineImage -and -not $BaselineSnapshot){throw 'Image and/or snapshot pair required'}
 if([bool]$BaselineImage -ne [bool]$CurrentImage -or [bool]$BaselineSnapshot -ne [bool]$CurrentSnapshot){throw 'Both members of each comparison pair required'}
 $old=$null;$new=$null;if($BaselineSnapshot){$old=Read-NJson $BaselineSnapshot;$new=Read-NJson $CurrentSnapshot}
 $ca=Get-NContext $BaselineContext $old;$cb=Get-NContext $CurrentContext $new;$contextOK=$true
 foreach($key in @('dpi','theme','locale','coordinateSpace')){if($ca -isnot [Collections.IDictionary] -or $cb -isnot [Collections.IDictionary] -or -not $ca.Contains($key) -or -not $cb.Contains($key)){$contextOK=$false;continue};if($key -eq 'dpi'){[void](Get-NNumber $ca[$key] 1 1000);[void](Get-NNumber $cb[$key] 1 1000)}elseif($ca[$key] -isnot [string] -or $cb[$key] -isnot [string] -or -not $ca[$key].Length -or -not $cb[$key].Length){throw 'Invalid context string'};if((ConvertTo-QCanonical $ca[$key]) -cne (ConvertTo-QCanonical $cb[$key])){$contextOK=$false}}
 if(-not $contextOK){$r.findings+=@{kind='Context';status='Unknown';reason='Missing or incompatible declared context'};Finish-N $r 3 -Json:$Json}
 if($BaselineImage){$budget=Read-NJson $BudgetPath;$t=Get-NNumber $budget.channelTolerance 0 255;$allowed=Assert-QInteger $budget.maxChangedPixels 0 $MaxPixels 'maxChangedPixels';$maxAllowed=Get-NNumber $budget.maxChannelDifference 0 255;$meanAllowed=Get-NNumber $budget.meanChannelDifference 0 255
  $ha=Get-NImageHeader $BaselineImage;$hb=Get-NImageHeader $CurrentImage
  if($ha.width -ne $hb.width -or $ha.height -ne $hb.height){$code=2;$r.findings+=@{kind='Dimensions';status='Fail'}}else{
   if($DiffImage){$out=Assert-QPath $DiffImage -New;if([IO.Path]::GetExtension($out) -ine '.png'){throw 'Diff output must be a new PNG path'}}
   Add-Type -AssemblyName System.Drawing;$a=[Drawing.Bitmap]::new($ha.path);$b=[Drawing.Bitmap]::new($hb.path)
   if($a.Width -ne $ha.width -or $b.Width -ne $hb.width -or $a.Height -ne $ha.height -or $b.Height -ne $hb.height){throw 'Decoded/header dimensions disagree'}
   if($DiffImage){$diff=[Drawing.Bitmap]::new($a.Width,$a.Height)};$changed=0L;$maximum=0;$sum=0L
   for($y=0;$y -lt $a.Height;$y++){for($x=0;$x -lt $a.Width;$x++){$pa=$a.GetPixel($x,$y);$pb=$b.GetPixel($x,$y);$dr=[Math]::Abs([int]$pa.R-$pb.R);$dg=[Math]::Abs([int]$pa.G-$pb.G);$db=[Math]::Abs([int]$pa.B-$pb.B);$da=[Math]::Abs([int]$pa.A-$pb.A);$m=[Math]::Max([Math]::Max($dr,$dg),[Math]::Max($db,$da));$maximum=[Math]::Max($maximum,$m);$sum+=$dr+$dg+$db+$da;if($m -gt $t){$changed++};if($diff){$diff.SetPixel($x,$y,[Drawing.Color]::FromArgb(255,$dr,$dg,$db))}}}
   $mean=$sum/([double]$a.Width*$a.Height*4);if($changed -gt $allowed -or $maximum -gt $maxAllowed -or $mean -gt $meanAllowed){$code=2};$r.findings+=@{kind='Pixels';changedPixels=$changed;maxChannelDifference=$maximum;meanChannelDifference=$mean}
   if($diff){$stream=[IO.File]::Open($out,[IO.FileMode]::CreateNew);try{$diff.Save($stream,[Drawing.Imaging.ImageFormat]::Png)}finally{$stream.Dispose()};$r.artifacts+=@{path=$out}}
  };$r.executionEvidence+=@{operation='ActualDecodedRgbaComparison';codec='Installed System.Drawing';pixelBudget=$MaxPixels}
 }
 if($BaselineSnapshot){$maps=@();foreach($s in @($old,$new)){if($s.nodes -isnot [array] -or $s.nodes.Count -gt $MaxNodes){throw 'Bounded nodes array required'};if($s.Contains('truncated') -and $s.truncated){$code=3};$map=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal)
   foreach($node in $s.nodes){if($node -isnot [Collections.IDictionary] -or $node.automationId -isnot [string] -or [string]::IsNullOrEmpty($node.automationId)){$code=3;$r.findings+=@{kind='Identity';status='Unknown'};continue};foreach($key in @('name','controlType')){if($node[$key] -isnot [string]){throw 'Invalid node string'}};foreach($key in @('enabled','keyboardFocusable')){if($node[$key] -isnot [bool]){throw 'Invalid node state'}};if($node.patterns -isnot [array] -or @($node.patterns|Where-Object {$_ -isnot [string]}).Count){throw 'Invalid patterns'}
    if(-not $map.TryAdd($node.automationId,$node)){$code=3;$r.findings+=@{kind='AmbiguousIdentity';status='Unknown'}}
   };$maps+=,$map
  }
  foreach($id in $maps[0].Keys){if(-not $maps[1].ContainsKey($id)){$r.findings+=@{kind='RemovedNode';automationId=$id};if($code -ne 3){$code=2};continue};foreach($key in @('name','controlType','enabled','keyboardFocusable','patterns')){$v1=$maps[0][$id][$key];$v2=$maps[1][$id][$key];if($key -eq 'patterns'){$v1=@($v1|Sort-Object -CaseSensitive);$v2=@($v2|Sort-Object -CaseSensitive)};if((ConvertTo-QCanonical $v1) -cne (ConvertTo-QCanonical $v2)){$r.findings+=@{kind='NodeChanged';automationId=$id;property=$key};if($code -ne 3){$code=2}}}}
  foreach($id in $maps[1].Keys){if(-not $maps[0].ContainsKey($id)){$r.findings+=@{kind='AddedNode';automationId=$id};if($code -ne 3){$code=2}}};$r.executionEvidence+=@{operation='SuppliedUiaNodeComparison'}
 }
 $r.limitations=@('Supplied images/trees do not establish live UI or accessibility certification.','Straight RGBA differences; no DPI scaling, color management or antialias normalization.','Stable identity requires unique nonempty AutomationId; timestamps ignored.')
}catch{$r.error=$_.Exception.Message;$code=125}finally{if($a){$a.Dispose()};if($b){$b.Dispose()};if($diff){$diff.Dispose()}}
Finish-N $r $code -Json:$Json
