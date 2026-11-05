#requires -Version 7.0
<#
.SYNOPSIS
Validates declared primitive DLL contracts and optionally executes explicitly trusted DLLs in a child.
.PARAMETER ExecuteTrusted
Acknowledges the DLL is trusted/owned and authorizes child-process native execution (including DllMain).
Without this switch runtime is NotPerformed and LASTEXITCODE3 even if static checks pass.
.PARAMETER PowerShellPath
Optional explicit PS7 executable for a matching architecture; the child verifies its architecture before loading.
.NOTES
Contracts support validated Cdecl/StdCall functions, numeric primitive parameters/returns and finite cases only.
No pointers/strings/structs or guessed signatures. Process isolation is not a sandbox.
Writes a new runs/contract-* evidence folder for explicit execution. Exit0 pass,2 contract failure,
3 runtime unperformed/architecture blocked,125 malformed/setup. Child timeouts/crashes are failures.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$LibraryPath,[Parameter(Mandatory)][string]$ContractPath,[switch]$ExecuteTrusted,[ValidateRange(1,120)][int]$TimeoutSeconds=15,[string]$PowerShellPath,[switch]$Json)
$ErrorActionPreference='Stop';. (Join-Path $PSScriptRoot 'lib/RuntimeCommon.ps1');. (Join-Path $PSScriptRoot 'lib/WindowsDiagnosticsCommon.ps1')
$result=[ordered]@{schemaVersion=1;observedUtc=[datetime]::UtcNow.ToString('o');tool='Test-DllContract';scope='Declared primitive signatures only';valid=$false;library=$null;runtime='NotPerformed';staticChecks=@();execution=$null;findings=@();error=$null;limitations=@('Signatures are supplied assertions, not inferred ABI guarantees.','Explicit execution loads trusted DLL code in a child; process isolation does not make untrusted native code safe.','Pointer/string/structure arguments and decorated export names are unsupported.')}
$types=@{Int32='int';UInt32='uint';Int64='long';UInt64='ulong';Float='float';Double='double'}
function Check-Number($Value,[string]$Type){
    if($Value -is [bool] -or $Value -is [string] -or $null -eq $Value){throw 'Contract values must be JSON numbers.'}
    $number=[double]$Value;if([double]::IsNaN($number) -or [double]::IsInfinity($number)){throw 'Contract values must be finite.'}
    if($Type -in @('Int32','UInt32','Int64','UInt64')){$decimal=[decimal]$Value;if([decimal]::Truncate($decimal) -ne $decimal){throw 'Integer signature requires integral arguments/returns.'};$bounds=switch($Type){Int32{@([decimal][int]::MinValue,[decimal][int]::MaxValue)}UInt32{@([decimal]0,[decimal][uint32]::MaxValue)}Int64{@([decimal][long]::MinValue,[decimal][long]::MaxValue)}UInt64{@([decimal]0,[decimal][uint64]::MaxValue)}};if($decimal -lt $bounds[0] -or $decimal -gt $bounds[1]){throw 'Contract number exceeds declared primitive range.'}}
    if($Type -eq 'Float' -and [single]::IsInfinity([single]$Value)){throw 'Float value exceeds finite Single range.'}
}
try{
    $contract=Read-DevJson $ContractPath
    if($contract.schemaVersion -ne 1 -or $contract.architecture -notin @('x86','x64','Arm64') -or $contract.functions -isnot [array] -or $contract.functions.Count -lt 1 -or $contract.functions.Count -gt 64){throw 'Invalid DLL contract schema.'}
    $source=[Text.StringBuilder]::new();$null=$source.AppendLine('using System; using System.Runtime.InteropServices; namespace LocalDevTools { public static class ContractDelegates { [DllImport("kernel32.dll")] public static extern uint SetErrorMode(uint mode);')
    $total=0;$index=0
    foreach($function in $contract.functions){
        if($function.export -isnot [string] -or $function.export -notmatch '^[A-Za-z_][A-Za-z0-9_]{0,127}$' -or $function.callingConvention -notin @('Cdecl','StdCall') -or -not $types.ContainsKey($function.returnType) -or $function.parameterTypes -isnot [array] -or $function.parameterTypes.Count -gt 16 -or $function.cases -isnot [array] -or $function.cases.Count -lt 1){throw 'Invalid or unsupported function declaration.'}
        foreach($type in $function.parameterTypes){if(-not $types.ContainsKey($type)){throw 'Unsupported parameter type.'}}
        $function.callingConvention=if($function.callingConvention -ieq 'Cdecl'){'Cdecl'}else{'StdCall'}
        foreach($case in $function.cases){if(++$total -gt 2048){throw 'Contract case limit exceeded.'};if($case.arguments -isnot [array] -or $case.arguments.Count -ne $function.parameterTypes.Count){throw 'Contract argument count mismatch.'};for($i=0;$i -lt $case.arguments.Count;$i++){Check-Number $case.arguments[$i] $function.parameterTypes[$i]};Check-Number $case.expectedReturn $function.returnType;if($case.Contains('tolerance')){Check-Number $case.tolerance Double;if($case.tolerance -lt 0){throw 'Tolerance must be nonnegative.'}}}
        $parameters=@(for($i=0;$i -lt $function.parameterTypes.Count;$i++){"$($types[$function.parameterTypes[$i]]) a$i"}) -join ','
        $null=$source.AppendLine("[UnmanagedFunctionPointer(CallingConvention.$($function.callingConvention))] public delegate $($types[$function.returnType]) D$index($parameters);");$index++
    }
    $null=$source.AppendLine('}}')
    $library=Get-Item -LiteralPath $LibraryPath;if($library.PSIsContainer){throw 'LibraryPath must be a file.'};$result.library=$library.FullName
    $info=& (Join-Path $PSScriptRoot 'Get-DllInfo.ps1') -Path $library.FullName
    if(-not $info.valid){throw $info.error};$static=[Collections.Generic.List[object]]::new()
    $static.Add(@{id='Architecture';status=$(if($info.image.Architecture -eq $contract.architecture){'pass'}else{'fail'});expected=$contract.architecture;observed=$info.image.Architecture})
    foreach($function in $contract.functions){$exists=@($info.image.Exports | Where-Object {$_.Name -ceq $function.export}).Count -gt 0;$static.Add(@{id='Export';name=$function.export;status=$(if($exists){'pass'}else{'fail'})})}
    $result.staticChecks=@($static.ToArray())
    if(@($static | Where-Object status -ne pass).Count){$global:LASTEXITCODE=2}
    elseif(-not $ExecuteTrusted){$result.findings=@(@{id='RuntimeNotPerformed';status='unknown';detail='Use ExecuteTrusted only for an explicitly trusted/owned DLL.'});$global:LASTEXITCODE=3}
    else{
        if(-not $PowerShellPath){$PowerShellPath=Join-Path $PSHOME 'pwsh.exe'};$pwsh=Get-Item -LiteralPath $PowerShellPath;if($pwsh.PSIsContainer -or $pwsh.Extension -ine '.exe'){throw 'PowerShellPath must be an explicit executable.'}
        $run=Join-Path $PSScriptRoot ('runs\contract-'+[guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($run)
        $configuration=Join-Path $run 'contract-data.json';@{library=$library.FullName;architecture=$contract.architecture;functions=$contract.functions;delegateSource=$source.ToString()} | ConvertTo-Json -Depth 16 | Set-Content -LiteralPath $configuration
        $execution=Invoke-DevBoundedProcess $pwsh.FullName @('-NoProfile','-File',(Join-Path $PSScriptRoot 'lib/WindowsDiagnosticsContractChild.ps1'),'-ConfigurationPath',$configuration) $run $TimeoutSeconds
        [IO.File]::WriteAllText((Join-Path $run 'stdout.log'),$execution.Stdout);[IO.File]::WriteAllText((Join-Path $run 'stderr.log'),$execution.Stderr)
        $child=$null;try{$child=$execution.Stdout | ConvertFrom-Json -Depth 16}catch{}
        $result.runtime=if($execution.TimedOut){'TimedOut'}elseif($child){$child.runtime}else{'CrashedOrInvalidOutput'}
        $result.execution=@{exitCode=$execution.ExitCode;timedOut=$execution.TimedOut;truncated=$execution.Truncated;runPath=$run;result=$child}
        $result.valid=$execution.ExitCode -eq 0 -and -not $execution.Truncated -and $child.valid;$global:LASTEXITCODE=if($result.valid){0}elseif($execution.ExitCode -eq 3 -and $child.runtime -eq 'BlockedArchitecture'){3}else{2}
        $result | ConvertTo-Json -Depth 18 | Set-Content -LiteralPath (Join-Path $run 'result.json')
    }
}catch{$result.error=$_.Exception.Message;$global:LASTEXITCODE=125}
if($Json){$result | ConvertTo-Json -Depth 18}else{[pscustomobject]$result}
