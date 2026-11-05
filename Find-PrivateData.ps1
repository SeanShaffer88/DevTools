#requires -Version 7.1
<#
.SYNOPSIS
Bounded local heuristic scan; output uses file ordinals, never source paths or text.
.DESCRIPTION
Fingerprints group candidates within this run only. Random HMAC key is never returned.
False positives/negatives are possible; this does not certify secret-free content.
Generated folders bin,obj,node_modules,.git,.cache are skipped. UTF-8 only.
#>
[CmdletBinding()]param([Parameter(Mandatory)][string[]]$Path,[ValidateRange(0,12)][int]$MaxDepth=3,[ValidateRange(1,10000)][int]$MaxFiles=1000,[ValidateRange(1,16777216)][long]$MaxFileBytes=1048576,[ValidateRange(1,134217728)][long]$MaxTotalBytes=16777216,[ValidateRange(1,10000)][int]$MaxFindings=10000,[switch]$Json)
. "$PSScriptRoot/lib/QualityNative.ps1"
$r=New-NResult 'Find-PrivateData';$code=0;$ordinal=0;$total=0L;$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$key=[Security.Cryptography.RandomNumberGenerator]::GetBytes(32);$hmac=[Security.Cryptography.HMACSHA256]::new($key)
try {
 $rules=@(
 @{id='credential';severity='High';pattern='(?i)(?:(?<key>"(?:\\.|[^"\\])*")|''?(?:password|passwd|secret|api[_-]?key|token)''?)\s*[:=]\s*(?<value>"(?:\\.|[^"\\])*"|''[^'']*''|[^\s,;}]+)'},
 @{id='private-key';severity='High';pattern='(?<value>-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)'},
 @{id='private-path';severity='Medium';pattern='(?i)(?<value>[A-Z]:[\\/]+Users[\\/]+[^\s"''<>]+)'},
 @{id='debug-payload';severity='Medium';pattern='(?i)(?<value>(?:debug|trace|console\.log)\s*\([^\r\n]{1,256})'} )
 $queue=[Collections.Generic.Queue[object]]::new();foreach($p in $Path){$queue.Enqueue(@((Assert-QPath $p),0))}
 $entries=0
 :scan while($queue.Count){$entry=$queue.Dequeue();$f=Get-Item -LiteralPath $entry[0] -Force
  if(++$entries -gt 20000){$code=3;$r.findings+=@{ruleId='entry-limit';fileOrdinal=$null};break}
  if($f.Attributes -band [IO.FileAttributes]::ReparsePoint){$code=3;continue}
  if($r.findings.Count -ge $MaxFindings){$code=3;break}
  if($f.PSIsContainer){if($entry[1] -ge $MaxDepth){$code=3;continue};foreach($child in [IO.Directory]::EnumerateFileSystemEntries($f.FullName)){if([IO.Path]::GetFileName($child) -cin @('bin','obj','node_modules','.git','.cache')){continue};if($queue.Count+$entries -ge 20000){$code=3;break scan};$queue.Enqueue(@($child,($entry[1]+1)))};continue}
  if(-not $seen.Add($f.FullName)){continue};$ordinal++;if($ordinal -gt $MaxFiles){$code=3;break}
  if($f.Length -gt $MaxFileBytes -or $total+$f.Length -gt $MaxTotalBytes){$code=3;$r.findings+=@{ruleId='size-limit';fileOrdinal=$ordinal};continue};$total+=$f.Length
  try {$bytes=[IO.File]::ReadAllBytes($f.FullName);if($bytes -contains 0){throw 'Binary'};$text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)}catch{$code=3;$r.findings+=@{ruleId='encoding-or-binary';fileOrdinal=$ordinal};continue}
  foreach($rule in $rules){$regex=[regex]::new($rule.pattern,[Text.RegularExpressions.RegexOptions]::CultureInvariant,[TimeSpan]::FromMilliseconds(100));foreach($m in $regex.Matches($text)){if($r.findings.Count -ge $MaxFindings){$code=3;break scan};if($rule.id -eq 'credential' -and $m.Groups['key'].Success){$keyName=ConvertFrom-Json -InputObject $m.Groups['key'].Value;if($keyName -notmatch '^(?i:password|passwd|secret|api[_-]?key|token)$'){continue}};$g=$m.Groups['value'];$value=$g.Value;if($rule.id -eq 'credential' -and $value.StartsWith('"')){try{$value=ConvertFrom-Json -InputObject $value -ErrorAction Stop}catch{}}
   if($rule.id -eq 'credential' -and $value.StartsWith("'") -and $value.EndsWith("'")){$value=$value.Substring(1,$value.Length-2)}
   $before=$text.Substring(0,$g.Index);$line=1+([regex]::Matches($before,"`n")).Count;$last=$before.LastIndexOf("`n");$r.findings+=@{ruleId=$rule.id;severity=$rule.severity;fileOrdinal=$ordinal;line=$line;column=$g.Index-$last;fingerprint=[Convert]::ToHexString($hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($value)))}
  }}
 }
 $r.executionEvidence+=@{operation='LocalHeuristicScan';filesConsidered=[Math]::Min($ordinal,$MaxFiles);bytesRead=$total;pathMapping='Ordinal in this invocation traversal only; no persisted lookup'}
 if($code -eq 0 -and $r.findings.Count){$code=2}
 $r.limitations=@('Heuristic UTF-8 scan; false positives and negatives possible.','File ordinals intentionally omit paths; HMAC fingerprints only comparable within one run.','Skipped, binary, invalid encoding and bounded-out inputs are Unknown.')
}catch [Text.RegularExpressions.RegexMatchTimeoutException]{$r.error="Regex deadline exceeded.";$code=3}catch{$r.error='Scan setup or bounded scan failed; paths and source data suppressed.';$code=125}finally{$hmac.Dispose();[Array]::Clear($key)}
Finish-N $r $code -Json:$Json
