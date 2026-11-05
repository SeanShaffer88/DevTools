#requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory)][string]$PlanPath,[Parameter(Mandatory)][string]$InputRoot,[Parameter(Mandatory)][string]$ResultsRoot,[string]$WorkRoot='C:\DevToolsWork',[switch]$SandboxAcknowledged,[switch]$FixtureMode)
$ErrorActionPreference='Stop'
$result=[ordered]@{schemaVersion=1;observedUtc=[datetime]::UtcNow.ToString('o');executionScope=$(if($FixtureMode){'HarmlessFixtureOnly'}else{'SandboxGuest'});valid=$false;phases=@();error=$null}
$snapshots=@{};$phases=[Collections.Generic.List[object]]::new();$exitCode=2
function Expand-GuestPath([string]$Text){[Environment]::ExpandEnvironmentVariables($Text.Replace('%INPUT%',$InputRoot).Replace('%WORK%',$WorkRoot))}
function Contained([string]$Relative){if(-not $Relative -or [IO.Path]::IsPathRooted($Relative) -or $Relative -match '[:*?]' -or '..' -in $Relative.Replace('/','\').Split('\')){throw 'Unsafe staged executable path.'};$full=[IO.Path]::GetFullPath((Join-Path $InputRoot $Relative));if(-not $full.StartsWith([IO.Path]::GetFullPath($InputRoot).TrimEnd('\')+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Executable escapes input root.'};return $full}
function Guest-Hash([string]$Path){$stream=[IO.File]::OpenRead($Path);$algorithm=[Security.Cryptography.SHA256]::Create();try{[BitConverter]::ToString($algorithm.ComputeHash($stream)).Replace('-','')}finally{$algorithm.Dispose();$stream.Dispose()}}
function Test-GuestStartupExpectedValue {param($Assertion,$Observed);$property=$Assertion.PSObject.Properties['expectedValue'];if($null -ne $property){return ($Observed -is [string] -and $property.Value -is [string] -and [string]::Equals($Observed,$property.Value,[StringComparison]::Ordinal))};return $true}
try{
    if(-not $SandboxAcknowledged -and -not $FixtureMode){throw 'Guest runner requires explicit SandboxAcknowledged; do not run installers on the host.'}
    $InputRoot=[IO.Path]::GetFullPath($InputRoot);$ResultsRoot=[IO.Path]::GetFullPath($ResultsRoot);$WorkRoot=[IO.Path]::GetFullPath($WorkRoot)
    if(Test-Path -LiteralPath (Join-Path $ResultsRoot 'result.json')){throw 'Guest result already exists; use a new result directory.'}
    $plan=Get-Content -LiteralPath $PlanPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if($plan.schemaVersion -ne 1 -or -not $plan.phases -or @($plan.phases).Count -gt 3){throw 'Invalid lifecycle plan.'}
    if($FixtureMode -and -not $plan.fixtureOnly){throw 'FixtureMode requires a generated fixtureOnly plan.'}
    Add-Type -Path (Join-Path $PSScriptRoot 'WindowsDiagnosticsGuestProcess.cs')
    $null=[IO.Directory]::CreateDirectory($WorkRoot);$null=[IO.Directory]::CreateDirectory($ResultsRoot)
    foreach($phase in $plan.phases){
        $exe=if($phase.executable -eq '@system/msiexec.exe'){if($FixtureMode){throw 'System installer is forbidden in FixtureMode.'};Join-Path $env:WINDIR 'System32\msiexec.exe'}else{Contained $phase.executable}
        $arguments=[string[]]@($phase.arguments | ForEach-Object {Expand-GuestPath ([string]$_)})
        $command=[DevToolsGuest.ProcessRunner]::Run($exe,$arguments,$WorkRoot,[int]$phase.timeoutSeconds)
        [IO.File]::WriteAllText((Join-Path $ResultsRoot ($phase.name+'-stdout.log')),$command.Stdout);[IO.File]::WriteAllText((Join-Path $ResultsRoot ($phase.name+'-stderr.log')),$command.Stderr)
        $assertions=[Collections.Generic.List[object]]::new();$assertions.Add(@{id='ExitCode';status=$(if($command.ExitCode -in @($phase.expectedExitCodes) -and -not $command.TimedOut -and -not $command.Truncated){'pass'}else{'fail'});observed=$command.ExitCode;timedOut=$command.TimedOut;truncated=$command.Truncated})
        $snapshot=@{}
        foreach($assertion in @($phase.fileAssertions | Where-Object {$null -ne $_})){
            $path=Expand-GuestPath $assertion.path;if(-not [IO.Path]::IsPathRooted($path)){$path=Join-Path $WorkRoot $path};$exists=[IO.File]::Exists($path);$hash=if($exists){Guest-Hash $path}else{$null};$snapshot[$path]=$hash
            $passed=$exists -eq $assertion.exists
            if($assertion.sha256 -and $hash -ine $assertion.sha256){$passed=$false}
            if($assertion.preserveFromPhase){$prior=$snapshots[$assertion.preserveFromPhase];if(-not $prior -or -not $prior.ContainsKey($path) -or -not $prior[$path] -or $prior[$path] -ine $hash){$passed=$false}}
            $assertions.Add(@{id='File';path=$path;status=$(if($passed){'pass'}else{'fail'});exists=$exists;sha256=$hash})
        }
        foreach($assertion in @($phase.processAssertions | Where-Object {$null -ne $_})){$running=@(Get-Process -Name $assertion.name -ErrorAction SilentlyContinue).Count -gt 0;$assertions.Add(@{id='Process';name=$assertion.name;status=$(if($running -eq $assertion.running){'pass'}else{'fail'});running=$running})}
        foreach($assertion in @($phase.startupAssertions | Where-Object {$null -ne $_})){
            $base=$null;$runKey=$null
            try{
                if([string]::IsNullOrWhiteSpace($assertion.name) -or $assertion.name -match '[\x00-\x1f]'){throw 'Invalid startup value name.'}
                $hive=if($assertion.hive -eq 'CurrentUser'){[Microsoft.Win32.RegistryHive]::CurrentUser}elseif($assertion.hive -eq 'LocalMachine'){[Microsoft.Win32.RegistryHive]::LocalMachine}else{throw 'Invalid startup hive.'}
                $base=[Microsoft.Win32.RegistryKey]::OpenBaseKey($hive,[Microsoft.Win32.RegistryView]::Default);$runKey=$base.OpenSubKey('Software\Microsoft\Windows\CurrentVersion\Run');$exists=$false;$value=$null
                if($runKey){$names=$runKey.GetValueNames();if($names.Count -gt 1024){throw 'Startup value inventory exceeds bound.'};$exists=$assertion.name -in $names;if($exists){$value=$runKey.GetValue($assertion.name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}
                $passed=$exists -eq $assertion.exists;if(-not (Test-GuestStartupExpectedValue $assertion $value)){$passed=$false};$assertions.Add(@{id='Startup';name=$assertion.name;status=$(if($passed){'pass'}else{'fail'});exists=$exists})
            }catch{$assertions.Add(@{id='Startup';name=$assertion.name;status='unknown';error=$_.Exception.Message})}finally{if($runKey){$runKey.Dispose()};if($base){$base.Dispose()}}
        }
        $snapshots[$phase.name]=$snapshot;$valid= @($assertions | Where-Object status -ne 'pass').Count -eq 0;$phases.Add(@{name=$phase.name;valid=$valid;assertions=@($assertions.ToArray())})
    }
    $result.phases=@($phases.ToArray());$result.valid=@($phases | Where-Object {-not $_.valid}).Count -eq 0;$hasDefiniteFailure=@($phases | ForEach-Object {$_.assertions} | Where-Object status -eq 'fail').Count -gt 0;$exitCode=if($result.valid){0}elseif($hasDefiniteFailure){2}else{3}
}catch{$result.error=$_.Exception.Message}
$result | ConvertTo-Json -Depth 14 | Set-Content -LiteralPath (Join-Path $ResultsRoot 'result.json') -Encoding UTF8
exit $exitCode
