#requires -Version 7.0
param([ValidateSet("All","Startup","Inspection","Cancellation")][string]$Scenario="All")
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$evidence=Join-Path $PSScriptRoot ('evidence/native-smoke-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $evidence
if($Scenario -eq 'All'){
 $pwsh=(Get-Process -Id $PID).Path
 $phases=@(foreach($phase in 'Inspection','Cancellation'){
  $output=@(& $pwsh -NoProfile -NonInteractive -File $PSCommandPath -Scenario $phase 2>&1)
  $code=$LASTEXITCODE
  $output | Set-Content (Join-Path $evidence "$phase.log")
  $marker=@($output | Where-Object {$_ -is [string] -and $_.StartsWith('Native smoke evidence: ')})
  $path=if($marker.Count -eq 1){$marker[0].Substring('Native smoke evidence: '.Length)}
  [ordered]@{scenario=$phase;exitCode=$code;evidence=$path}
 })
 $failed=@($phases | Where-Object {$_.exitCode -ne 0})
 $exitCode=if($failed.Count){$failed[0].exitCode}else{0}
 [ordered]@{scenario='All';runnerExit=$exitCode;phases=$phases} |
  ConvertTo-Json -Depth 6 | Set-Content (Join-Path $evidence 'native-exits.json')
 Write-Output "Native smoke evidence: $evidence"
 exit $exitCode
}
$exits=[ordered]@{scenario=$Scenario;uiExit=$null;captureExit=$null;runnerExit=125;error=$null}
$app=$null
try {
 $image=(Get-Item -LiteralPath (Join-Path $PSScriptRoot 'target/debug/devtools-inspector.exe')).FullName
 $fixtureProject=$null
 $fixtureLog=$null
 $environment=@{}
 if($Scenario -eq 'Inspection'){
  $git=(Get-Command git.exe -CommandType Application | Select-Object -First 1).Source
  $fixtureProject=(New-Item -Path (Join-Path $evidence 'Repository Fixture') -ItemType Directory).FullName
  $gitOutput=& $git -C $fixtureProject init --quiet --initial-branch=smoke 2>&1
  $exits.gitFixtureExit=$LASTEXITCODE
  if($exits.gitFixtureExit -ne 0){throw "Local Git fixture initialization failed: $gitOutput"}
  Set-Content -LiteralPath (Join-Path $fixtureProject 'README.md') -Value 'Inert local Project Inspector fixture.'
 }elseif($Scenario -eq 'Cancellation'){
  if($PSVersionTable.PSVersion -lt [version]'7.4'){throw 'Cancellation smoke requires PowerShell 7.4 or later.'}
  . (Join-Path $PSScriptRoot 'tests/native-cancel-fixture.ps1')
  $fixture=New-NativeCancelFixture -EvidencePath $evidence -PilotPath $PSScriptRoot
  $fixtureProject=$fixture.ProjectPath
  $fixtureLog=$fixture.LogPath
  $environment.Environment=@{
   PATH=$fixture.BinPath+';'+$env:PATH
   DEVTOOLS_INSPECTOR_FIXTURE_LOG=$fixtureLog
  }
 }
 $app=Start-Process -FilePath $image -WindowStyle Normal -RedirectStandardOutput "$evidence/native-stdout.log" -RedirectStandardError "$evidence/native-stderr.log" -PassThru @environment
 $clock=[Diagnostics.Stopwatch]::StartNew()
 do {Start-Sleep -Milliseconds 200;$app.Refresh()}until($app.MainWindowHandle -ne 0 -or $app.HasExited -or $clock.Elapsed.TotalSeconds -ge 10)
 if($app.HasExited){throw "App exited with $($app.ExitCode) before the native smoke checks."}
 if($app.MainWindowHandle -eq 0){throw 'Owned window handle was unavailable after 10 seconds.'}

 $app.Refresh()
 if($app.HasExited -or $app.MainWindowHandle -eq 0){throw 'Owned window handle disappeared before the native smoke checks.'}
 $windowHandle=$app.MainWindowHandle.ToInt64()
 @{processId=$app.Id;windowHandle=$windowHandle;title=$app.MainWindowTitle;responding=$app.Responding;observedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$evidence/native-process.json"

 $worker=Join-Path $PSScriptRoot 'tests/native-keyboard-worker.ps1'
 $legacy=Join-Path $env:WINDIR 'System32/WindowsPowerShell/v1.0/powershell.exe'
 $runner=Join-Path $evidence 'Invoke-DevBuild.ps1'
 Copy-Item -LiteralPath "$PSScriptRoot/../../Invoke-DevBuild.ps1" -Destination $runner
 $started=$app.StartTime.ToUniversalTime().ToString('o')
 $workerArgs=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-STA','-File',$worker,'-ProcessId',"$($app.Id)",'-WindowHandle',"$windowHandle",'-StartUtc',$started,'-ImagePath',$image)
 $workerTimeout=20
 if($Scenario -ne 'Startup'){
  $workerArgs+=@('-Scenario',$Scenario,'-FixtureProject',$fixtureProject)
  if($fixtureLog){$workerArgs+=@('-FixtureLog',$fixtureLog)}
  $workerTimeout=40
 }
 $run=@(& $runner -ProjectPath $PSScriptRoot -Executable $legacy -ArgumentList $workerArgs -TimeoutSeconds $workerTimeout)
 $exits.uiWorkerExit=$LASTEXITCODE
 $exits.uiExit=switch($exits.uiWorkerExit){
  0 {0}
  2 {2}
  3 {3}
  124 {3}
  default {125}
 }
 $workerResult=$run[-1]
 $exits.uiWorkerResult=Join-Path $workerResult.runDirectory 'result.json'
 $ui=Join-Path $evidence 'ui'
 $null=New-Item -ItemType Directory -Path $ui
 Copy-Item -LiteralPath (Join-Path $workerResult.runDirectory 'stdout.log') -Destination (Join-Path $ui 'result.json')
 $app.Refresh()
 if($app.HasExited -or $app.MainWindowHandle.ToInt64() -ne $windowHandle){throw 'Owned window handle changed before capture.'}
 $python=(Get-Command python.exe -CommandType Application | Select-Object -First 1).Source
 $captureArgs=@((Join-Path $PSScriptRoot 'tests/capture-owned-window.py'),"$windowHandle",(Join-Path $evidence 'native-window.bmp'))
 $capture=@(& $runner -ProjectPath $PSScriptRoot -Executable $python -ArgumentList $captureArgs -TimeoutSeconds 10)
 $exits.captureExit=$LASTEXITCODE
 $exits.captureRunnerResult=Join-Path $capture[-1].runDirectory 'result.json'
 $exits.runnerExit=if($exits.uiExit -ne 0){$exits.uiExit}else{$exits.captureExit}
}catch{
 $exits.error=$_.Exception.Message
 if($null -ne $exits.uiExit -and $exits.uiExit -ne 0){$exits.runnerExit=$exits.uiExit}
}finally{
 try{
  if($null -ne $app -and -not $app.HasExited){
   $null=$app.CloseMainWindow()
   if(-not $app.WaitForExit(3000)){$app.Kill();$null=$app.WaitForExit(2000)}
  }
 }finally{
  if($null -ne $app){$app.Dispose()}
  $exits | ConvertTo-Json | Set-Content "$evidence/native-exits.json"
  Write-Output "Native smoke evidence: $evidence"
 }
}
exit $exits.runnerExit
