<#
.SYNOPSIS
Named owned WPR capture, supplied metric budgets, or explicit ETL inventory.
.DESCRIPTION
Capture writes a new local destination. ETL files can contain sensitive data.
ETL inventory is not analysis and returns Unknown. Metrics are supplied, never derived.
#>
[CmdletBinding()]param([ValidateSet('Probe','Capture','Inventory','Metrics')][string]$Mode='Probe',[string]$Destination,[string]$Profile='CPU',[ValidateRange(1,60)][int]$DurationSeconds=1,[string]$EtlPath,[string]$MetricsPath,[string]$BudgetPath,[string]$WprPath='C:/Windows/System32/wpr.exe',[switch]$Json)
. "$PSScriptRoot/lib/QualityNative.ps1"
$r=New-NResult 'Invoke-WindowsPerformance';$code=3;$owned=$false;$instance=[guid]::NewGuid().ToString();$exe=$null;$r.instanceId=$instance;$stopped=$false
try {
 if($Mode -eq 'Metrics'){$m=Read-NJson $MetricsPath;$b=Read-NJson $BudgetPath;if($m.metrics -isnot [Collections.IDictionary] -or $b.metrics -isnot [Collections.IDictionary] -or -not $b.metrics.Count){throw 'metrics objects required'};$code=0;foreach($k in $b.metrics.Keys){$limit=Get-NNumber $b.metrics[$k] 0 ([double]::MaxValue);if(-not $m.metrics.Contains($k)){$code=3;$r.findings+=@{metric=$k;status='Missing'};continue};$v=Get-NNumber $m.metrics[$k] 0 ([double]::MaxValue);if($v -gt $limit){if($code -ne 3){$code=2};$r.findings+=@{metric=$k;value=$v;maximum=$limit}};$r.executionEvidence+=@{operation='SuppliedMetricComparison';source='Supplied; not derived from ETL'}}
 }
 elseif($Mode -eq 'Inventory'){$p=Test-NFile $EtlPath 134217728;$r.artifacts+=@{path=$p;bytes=(Get-Item -LiteralPath $p).Length};$r.findings+=@{status='UnsupportedAnalysis';reason='Inventory alone is not performance analysis'}}
 else {$exe=Test-NFile $WprPath 33554432;$help=Invoke-NProcess $exe @('-help','start');Add-NEvidence $r 'WprHelp' $help;if($help.ExitCode -ne 0 -or $help.TimedOut -or $help.Truncated -or [Text.Encoding]::UTF8.GetString($help.Output) -notmatch '-instancename'){throw 'Named instance support unavailable'}
  $status=Invoke-NProcess $exe @('-status','-instancename',$instance);Add-NEvidence $r 'OwnedNameStatus' $status
  if($Mode -eq 'Capture') {if($Profile -notmatch '^[A-Za-z][A-Za-z0-9.]{0,63}$'){throw 'Built-in profile name required'};$dest=Assert-QPath $Destination -New;[void][IO.Directory]::CreateDirectory($dest);$trace=Join-Path $dest 'capture.etl'
   $owned=$true;$start=Invoke-NProcess $exe @('-start',$Profile,'-filemode','-instancename',$instance);Add-NEvidence $r 'OwnedStart' $start
   if($start.ExitCode -eq 0 -and -not $start.TimedOut){$owned=$true;if(-not $start.Truncated){Start-Sleep -Seconds $DurationSeconds;$stop=Invoke-NProcess $exe @('-stop',$trace,'-instancename',$instance) 30;Add-NEvidence $r 'OwnedStop' $stop;if($stop.ExitCode -eq 0 -and -not $stop.TimedOut -and -not $stop.Truncated -and (Test-Path -LiteralPath $trace)){$stopped=$true;$code=0;$r.artifacts+=@{path=$trace;bytes=(Get-Item -LiteralPath $trace).Length}}}}
   else{$r.findings+=@{status='Blocked';reason='Owned start failed; scoped reconciliation required';nativeExitCode=$start.ExitCode}}
  }else{$r.findings+=@{status='NotPerformed';reason='Probe only; no capture or performance analysis'}}
 }
 $r.limitations=@('Trace captures may contain sensitive local data.','Named capture success establishes trace creation only; no ETL analysis implemented.','No privilege escalation or global recording changes.')
}catch{$r.error='Performance setup or native operation failed.';$code=125}finally{if($owned -and $exe){$confirmed=$stopped;try{$state=Invoke-NProcess $exe @('-status','-instancename',$instance) 5;Add-NEvidence $r 'OwnedFinalStatus' $state;$cancel=Invoke-NProcess $exe @('-cancel','-instancename',$instance) 5;Add-NEvidence $r 'OwnedCancel' $cancel;if($cancel.ExitCode -eq 0 -and -not $cancel.TimedOut -and -not $cancel.Truncated){$confirmed=$true}}catch{$r.findings+=@{status='Unknown';reason='Owned cleanup operation failed'}};$r.cleanupConfirmed=$confirmed;if(-not $confirmed){if($code -ne 2){$code=3};$r.findings+=@{status='Unknown';reason='Owned instance absence not confirmed';instanceId=$instance}}}}
Finish-N $r $code -Json:$Json