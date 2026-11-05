#requires -Version 7.0
<#
.SYNOPSIS
Checks coherent SDK component files, not just tools on PATH.
.PARAMETER Profile
NativeWindows, DotNet, Android or Java.
.PARAMETER Root
SDK/JDK or Visual Studio installation/MSVC toolset root. Omitted roots use known local locations.
.PARAMETER Version
Explicit MSVC/.NET SDK version; Android platform API number (for example 36).
.PARAMETER WindowsSdkVersion
Explicit Windows Kits include/lib version for NativeWindows.
.NOTES
Read-only structural inventory. No compiler is executed, no SDK installed, and no
environment modified. Current INCLUDE/LIB values are not a substitute for files.
LASTEXITCODE: 0 structural pass, 2 missing/incompatible components, 3 unknown, 125 invalid input.
#>
[CmdletBinding()]
param([Parameter(Mandatory)][ValidateSet('NativeWindows','DotNet','Android','Java')][string]$Profile,[string]$Root,[ValidateSet('x86','x64','Arm64')][string]$Architecture='x64',[string]$Version,[string]$WindowsSdkRoot,[string]$WindowsSdkVersion,[string]$JdkRoot,[string]$BuildToolsVersion,[switch]$Json)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'lib/RuntimeCommon.ps1')
$result=[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');profile=$Profile;architecture=$Architecture;root=$null;version=$null;valid=$false;findings=@();error=$null;limitations=@('Structural component presence is not a compile/link or runtime compatibility test.','Does not modify INCLUDE/LIB/PATH; discovered files may not be selected by a project build configuration.')}
$checks=[Collections.Generic.List[object]]::new()
function Check-Component([string]$Id,[string]$Path,[bool]$Directory=$false){$present=if($Directory){[IO.Directory]::Exists($Path)}else{[IO.File]::Exists($Path)};$checks.Add(@{id=$Id;status=$(if($present){'pass'}else{'fail'});path=[IO.Path]::GetFullPath($Path);expected=$(if($Directory){'Directory'}else{'File'});observed=$present})}
function Select-VersionDirectory([string]$Parent,[string]$Requested){if($Requested){return Join-Path $Parent $Requested};$candidate=Get-DevChildDirectories $Parent | Where-Object Name -Match '^\d+(\.\d+){0,3}$' | Sort-Object {([version]((($_.Name.Split('.')+@('0','0','0')) | Select-Object -First 4) -join '.'))} -Descending | Select-Object -First 1;if($candidate){return $candidate.FullName};return Join-Path $Parent '(missing-version)'}
try{
    foreach($number in @($Version,$WindowsSdkVersion,$BuildToolsVersion)){if($number -and $number -notmatch '^\d+(\.\d+){0,3}$'){throw 'Version selectors must be numeric and contain no path components.'}}
    if(-not $Root){switch($Profile){
        NativeWindows{$roots=@('C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools','C:\Program Files\Microsoft Visual Studio\2022\Community','C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools');$Root=$roots | Where-Object {[IO.Directory]::Exists((Join-Path $_ 'VC\Tools\MSVC'))} | Select-Object -First 1;if(-not $Root){$Root=$roots[0]}}
        DotNet{$Root=Join-Path $env:ProgramFiles 'dotnet'}
        Android{$Root=if($env:ANDROID_SDK_ROOT){$env:ANDROID_SDK_ROOT}elseif($env:ANDROID_HOME){$env:ANDROID_HOME}else{Join-Path $env:LOCALAPPDATA 'Android\Sdk'}}
        Java{$Root=$env:JAVA_HOME;if(-not $Root){$javac=Get-Command javac.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1;if($javac){$Root=Split-Path (Split-Path $javac.Source -Parent) -Parent}else{$Root=Join-Path $env:ProgramFiles 'Java\(missing-jdk)'}}}
    }}
    $Root=[IO.Path]::GetFullPath($Root);$result.root=$Root
    switch($Profile){
        NativeWindows{
            $directToolset=[IO.Directory]::Exists((Join-Path $Root 'include')) -and [IO.Directory]::Exists((Join-Path $Root 'bin'))
            if($directToolset -and $Version -and (Split-Path $Root -Leaf) -ne $Version){throw 'Explicit MSVC version conflicts with the supplied toolset root.'}
            $toolset=if($directToolset){$Root}else{Select-VersionDirectory (Join-Path $Root 'VC\Tools\MSVC') $Version}
            $result.version=Split-Path $toolset -Leaf
            if(-not $WindowsSdkRoot){$WindowsSdkRoot=Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10'}
            $WindowsSdkRoot=[IO.Path]::GetFullPath($WindowsSdkRoot)
            $sdkInclude=Select-VersionDirectory (Join-Path $WindowsSdkRoot 'Include') $WindowsSdkVersion;$sdkVersion=Split-Path $sdkInclude -Leaf
            foreach($file in @('cl.exe','link.exe','lib.exe')){Check-Component "msvc.$file" (Join-Path $toolset "bin\Hostx64\$Architecture\$file")}
            foreach($header in @('vcruntime.h','vadefs.h')){Check-Component "msvc.$header" (Join-Path $toolset "include\$header")}
            foreach($library in @('vcruntime.lib','libcmt.lib')){Check-Component "msvc.$library" (Join-Path $toolset "lib\$Architecture\$library")}
            foreach($entry in @(@('windows.h','um\Windows.h'),@('sdkddkver.h','shared\sdkddkver.h'),@('stdlib.h','ucrt\stdlib.h'),@('stddef.h','ucrt\stddef.h'))){Check-Component "windows.header.$($entry[0])" (Join-Path $sdkInclude $entry[1])}
            foreach($entry in @(@('kernel32.lib','um\kernel32.lib'),@('ucrt.lib','ucrt\ucrt.lib'),@('libucrt.lib','ucrt\libucrt.lib'))){$sub=$entry[1].Split('\');Check-Component "windows.library.$($entry[0])" (Join-Path $WindowsSdkRoot "Lib\$sdkVersion\$($sub[0])\$Architecture\$($sub[1])")}
            Check-Component 'windows.rc.exe' (Join-Path $WindowsSdkRoot "bin\$sdkVersion\x64\rc.exe")
            $result.windowsSdkRoot=$WindowsSdkRoot;$result.windowsSdkVersion=$sdkVersion
        }
        DotNet{
            Check-Component 'dotnet.host' (Join-Path $Root 'dotnet.exe')
            $sdk=Select-VersionDirectory (Join-Path $Root 'sdk') $Version;$result.version=Split-Path $sdk -Leaf
            Check-Component 'dotnet.sdk' $sdk $true;Check-Component 'dotnet.compiler' (Join-Path $sdk 'Roslyn\bincore\csc.dll');Check-Component 'dotnet.msbuild' (Join-Path $sdk 'MSBuild.dll')
            $targetPrefix=if($result.version -match '^(\d+)\.(\d+)') {"$($Matches[1]).$($Matches[2])."}else{'(missing)'}
            $pack=Get-DevChildDirectories (Join-Path $Root 'packs\Microsoft.NETCore.App.Ref') | Where-Object {$_.Name.StartsWith($targetPrefix,[StringComparison]::Ordinal)} | Sort-Object {[version]$_.Name} -Descending | Select-Object -First 1
            $packPath=if($pack){$pack.FullName}else{Join-Path $Root 'packs\Microsoft.NETCore.App.Ref\(missing-matching-version)'}
            $tfm=if($targetPrefix -match '^(\d+)\.(\d+)\.') {"net$($Matches[1]).$($Matches[2])"}else{'(missing)'}
            Check-Component 'dotnet.reference-pack' (Join-Path $packPath "ref\$tfm\System.Runtime.dll")
            $dotnetHost=Join-Path $Root 'dotnet.exe';if([IO.File]::Exists($dotnetHost)){$actual=Get-DevFileArchitecture $dotnetHost;$checks.Add(@{id='dotnet.host-architecture';status=$(if($actual -eq $Architecture){'pass'}elseif($actual -eq 'Unknown'){'unknown'}else{'fail'});expected=$Architecture;observed=$actual})}
        }
        Android{
            $platform=if($Version){Join-Path $Root "platforms\android-$Version"}else{Get-DevChildDirectories (Join-Path $Root 'platforms') | Where-Object Name -Match '^android-\d+$' | Sort-Object {[int]($_.Name -replace '^android-','')} -Descending | Select-Object -First 1 -ExpandProperty FullName}
            if(-not $platform){$platform=Join-Path $Root 'platforms\(missing-platform)'}
            $result.version=Split-Path $platform -Leaf;Check-Component 'android.platform' (Join-Path $platform 'android.jar')
            $tools=Select-VersionDirectory (Join-Path $Root 'build-tools') $BuildToolsVersion
            foreach($file in @('aapt2.exe','zipalign.exe','lib\d8.jar','lib\apksigner.jar')){Check-Component "android.$file" (Join-Path $tools $file)}
            Check-Component 'android.adb' (Join-Path $Root 'platform-tools\adb.exe')
            if(-not $JdkRoot){$javac=Get-Command javac.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1;$JdkRoot=if($env:JAVA_HOME){$env:JAVA_HOME}elseif($javac){Split-Path (Split-Path $javac.Source -Parent) -Parent}else{Join-Path $env:ProgramFiles 'Java\(missing-jdk)'}}
            foreach($file in @('bin\java.exe','bin\javac.exe','release','include\jni.h')){Check-Component "android.jdk.$file" (Join-Path $JdkRoot $file)}
            $result.buildToolsVersion=Split-Path $tools -Leaf;$result.jdkRoot=[IO.Path]::GetFullPath($JdkRoot)
        }
        Java{
            foreach($file in @('bin\java.exe','bin\javac.exe','release','include\jni.h','include\win32\jni_md.h')){Check-Component "java.$file" (Join-Path $Root $file)}
            $release=Join-Path $Root 'release';if([IO.File]::Exists($release)){$item=Get-Item -LiteralPath $release;if($item.Length -gt 65536){throw 'JDK release metadata exceeds safety limit.'};$text=Get-Content -LiteralPath $release -Raw;$actual='Unknown';if($text -match '(?m)^OS_ARCH="([^"]+)"'){$actual=Get-DevArchitecture $Matches[1]};if($text -match '(?m)^JAVA_VERSION="([^"]+)"'){$result.version=$Matches[1]};$checks.Add(@{id='java.architecture';status=$(if($actual -eq $Architecture){'pass'}elseif($actual -eq 'Unknown'){'unknown'}else{'fail'});expected=$Architecture;observed=$actual})}
        }
    }
    $result.findings=@($checks.ToArray());$result.valid= -not @($checks | Where-Object status -ne pass).Count
    $global:LASTEXITCODE=if(@($checks | Where-Object status -eq fail).Count){2}elseif(-not $result.valid){3}else{0}
}catch{$result.error=$_.Exception.Message;$global:LASTEXITCODE=125}
if($Json){$result | ConvertTo-Json -Depth 10}else{[pscustomobject]$result}
