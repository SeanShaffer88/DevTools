#requires -Version 7.0
$ErrorActionPreference='Stop'
$app=Start-Process -FilePath "$PSScriptRoot/target/debug/devtools-inspector.exe" -WindowStyle Hidden -RedirectStandardOutput "$PSScriptRoot/evidence/native-stdout.log" -RedirectStandardError "$PSScriptRoot/evidence/native-stderr.log" -PassThru
try {
 $deadline=[DateTime]::UtcNow.AddSeconds(10)
 do {Start-Sleep -Milliseconds 200;$app.Refresh()}until($app.MainWindowHandle -ne 0 -or $app.HasExited -or [DateTime]::UtcNow -gt $deadline)
 if($app.HasExited){throw "App exited with $($app.ExitCode)"}
 Start-Sleep -Seconds 3
 @{processId=$app.Id;windowHandle=$app.MainWindowHandle.ToInt64();title=$app.MainWindowTitle;responding=$app.Responding;observedUtc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/native-process.json"
 $dest=Join-Path "$PSScriptRoot/evidence" ('native-ui-'+[DateTime]::UtcNow.ToString('yyyyMMddTHHmmssfffZ'))
 & "$PSScriptRoot/../../Test-WindowsUi.ps1" -ProcessId $app.Id -AssertionsPath "$PSScriptRoot/tests/native-assertions.json" -Destination $dest -TimeoutSeconds 15 -Json
 $uiExit=$LASTEXITCODE
 python "$PSScriptRoot/tests/capture-owned-window.py" $app.MainWindowHandle.ToInt64() "$PSScriptRoot/evidence/native-window.bmp"
 $captureExit=$LASTEXITCODE
 @{uiExit=$uiExit;captureExit=$captureExit} | ConvertTo-Json | Set-Content "$PSScriptRoot/evidence/native-exits.json"
 exit $uiExit
}finally{if(-not $app.HasExited){$null=$app.CloseMainWindow();if(-not $app.WaitForExit(3000)){$app.Kill()}}}
