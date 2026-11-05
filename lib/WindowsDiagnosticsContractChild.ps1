#requires -Version 7.0
param([Parameter(Mandatory)][string]$ConfigurationPath)
$ErrorActionPreference='Stop';$loaded=[IntPtr]::Zero
$result=@{schemaVersion=1;runtime='Performed';valid=$false;cases=@();error=$null}
try{
    $config=Get-Content -LiteralPath $ConfigurationPath -Raw | ConvertFrom-Json
    $arch=[Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString()
    if($arch -ine $config.architecture){$result.runtime='BlockedArchitecture';$result.error="Child architecture $arch does not match $($config.architecture).";$result | ConvertTo-Json -Depth 12;exit 3}
    Add-Type -TypeDefinition $config.delegateSource
    [LocalDevTools.ContractDelegates]::SetErrorMode(3) | Out-Null
    $loaded=[Runtime.InteropServices.NativeLibrary]::Load($config.library)
    $types=@{Int32=[int];UInt32=[uint32];Int64=[long];UInt64=[uint64];Float=[single];Double=[double]}
    $cases=[Collections.Generic.List[object]]::new();$index=0
    foreach($function in $config.functions){
        $pointer=[Runtime.InteropServices.NativeLibrary]::GetExport($loaded,$function.export)
        $delegateType=('LocalDevTools.ContractDelegates+D'+$index) -as [type];$delegate=[Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($pointer,$delegateType)
        foreach($case in $function.cases){try{$arguments=[object[]]::new(@($function.parameterTypes).Count);for($i=0;$i -lt $arguments.Length;$i++){$text=([IFormattable]$case.arguments[$i]).ToString($null,[Globalization.CultureInfo]::InvariantCulture);$parseType=$types[$function.parameterTypes[$i]];$arguments[$i]=$parseType::Parse($text,[Globalization.CultureInfo]::InvariantCulture)};$actual=$delegate.DynamicInvoke($arguments);$tolerance=if($null -ne $case.tolerance){[double]$case.tolerance}else{0};$difference=if($function.returnType -in @('Float','Double')){[math]::Abs([double]$actual-[double]$case.expectedReturn)}else{[math]::Abs([decimal]$actual-[decimal]$case.expectedReturn)};$passed=$difference -le $tolerance;$cases.Add(@{export=$function.export;arguments=@($case.arguments);expectedReturn=$case.expectedReturn;observed=$actual;status=$(if($passed){'pass'}else{'fail'})})}catch{$cases.Add(@{export=$function.export;status='fail';error=$_.Exception.Message})}}
        $index++
    }
    $result.cases=@($cases.ToArray());$result.valid= -not @($cases | Where-Object status -ne pass).Count
}catch{$result.error=$_.Exception.Message}finally{if($loaded -ne [IntPtr]::Zero){[Runtime.InteropServices.NativeLibrary]::Free($loaded)}}
$result | ConvertTo-Json -Depth 12
exit $(if($result.valid){0}else{2})
