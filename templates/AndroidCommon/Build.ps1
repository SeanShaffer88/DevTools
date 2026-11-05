#requires -Version 7.0
<# .SYNOPSIS Builds an unsigned APK using an explicitly selected installed SDK; no downloads, signing, or installation. #>
[CmdletBinding()]
param([Parameter(Mandatory)][string]$SdkPath,[string]$Platform='android-36',[string]$BuildToolsVersion='36.0.0',[string]$JavaPath='java.exe',[string]$JavacPath='javac.exe')
$ErrorActionPreference='Stop';$buildExit=1;$evidence=$null;$commands=[Collections.Generic.List[object]]::new()
function Assert-NoReparse([string]$Path){
 $part=[IO.Path]::GetFullPath($Path)
 while($part){if(Test-Path -LiteralPath $part){$entry=Get-Item -LiteralPath $part -Force;if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Project/build reparse points are refused.'}};$parent=[IO.Path]::GetDirectoryName($part);if($parent -eq $part){break};$part=$parent}
}
function Invoke-LocalTool([string]$Executable,[string[]]$Arguments){
 $exe=(Get-Command -Name $Executable -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source
 if([IO.Path]::GetExtension($exe) -ine '.exe'){throw 'Tools must be native .exe files.'}
 $r=[LocalDevTools.AndroidProcess]::Run($exe,$Arguments,$PSScriptRoot,120)
 $n=$commands.Count;$out=Join-Path $evidence ("$n.stdout.log");$err=Join-Path $evidence ("$n.stderr.log")
 [IO.File]::WriteAllText($out,$r.Stdout);[IO.File]::WriteAllText($err,$r.Stderr)
 $commands.Add([pscustomobject]@{executable=$exe;exitCode=$r.ExitCode;stdout=$out;stderr=$err;truncated=$r.Truncated})
 if($r.ExitCode -ne 0){$script:buildExit=$r.ExitCode;throw "Tool failed ($($r.ExitCode)); see $err"}
}
try{
 Assert-NoReparse $PSScriptRoot
 Assert-NoReparse (Join-Path $PSScriptRoot 'build')
 if($Platform -notmatch '^android-[0-9]+$' -or $BuildToolsVersion -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$'){throw 'Select installed numeric platform/build-tools versions.'}
 $sdk=(Get-Item -LiteralPath $SdkPath -ErrorAction Stop).FullName
 $androidJar=Join-Path $sdk ("platforms\$Platform\android.jar");$tools=Join-Path $sdk ("build-tools\$BuildToolsVersion")
 foreach($file in @($androidJar,(Join-Path $tools 'lib\d8.jar'),(Join-Path $tools 'aapt2.exe'),(Join-Path $tools 'zipalign.exe'))){if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw "Required installed tool missing: $file"}}
 if(-not('LocalDevTools.AndroidProcess' -as [type])){Add-Type -Path (Join-Path $PSScriptRoot 'tools\AndroidProcess.cs')}
 $evidence=Join-Path $PSScriptRoot ('build\'+[Guid]::NewGuid().ToString('N'));$null=[IO.Directory]::CreateDirectory($evidence)
 $classes=Join-Path $evidence 'classes';$dex=Join-Path $evidence 'dex';$null=[IO.Directory]::CreateDirectory($classes);$null=[IO.Directory]::CreateDirectory($dex)
 $javaFiles=@(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'src') -File -Filter '*.java' -Recurse | Select-Object -ExpandProperty FullName)
 if($javaFiles.Count -eq 0 -or $javaFiles.Count -gt 100){throw 'Expected 1-100 local Java source files.'}
 Invoke-LocalTool $JavacPath (@('-source','8','-target','8','-encoding','UTF-8','-classpath',$androidJar,'-d',$classes)+$javaFiles)
 $classFiles=@(Get-ChildItem -LiteralPath $classes -File -Filter '*.class' -Recurse | Select-Object -ExpandProperty FullName)
 Invoke-LocalTool $JavaPath (@('-cp',(Join-Path $tools 'lib\d8.jar'),'com.android.tools.r8.D8','--min-api','23','--lib',$androidJar,'--output',$dex)+$classFiles)
 $base=Join-Path $evidence 'base.apk';$output=Join-Path $evidence '__NAME__-unsigned.apk'
 Invoke-LocalTool (Join-Path $tools 'aapt2.exe') @('link','-I',$androidJar,'--manifest',(Join-Path $PSScriptRoot 'AndroidManifest.xml'),'-o',$base)
 $archive=[IO.Compression.ZipFile]::Open($base,[IO.Compression.ZipArchiveMode]::Update)
 try{foreach($dexFile in Get-ChildItem -LiteralPath $dex -File -Filter '*.dex'){$null=[IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive,$dexFile.FullName,$dexFile.Name,[IO.Compression.CompressionLevel]::Optimal)}}finally{$archive.Dispose()}
 Invoke-LocalTool (Join-Path $tools 'zipalign.exe') @('-p','4',$base,$output)
 Invoke-LocalTool (Join-Path $tools 'zipalign.exe') @('-c','-p','4',$output)
 $buildExit=0
 [pscustomobject]@{path=$output;sha256=(Get-FileHash -LiteralPath $output).Hash;signed=$false;installed=$false;runtimeValidation='NotPerformed'}
}catch{Write-Error -Message $_.Exception.Message -ErrorAction Continue}
finally{if($evidence){[ordered]@{schemaVersion=1;observedUtc=[DateTime]::UtcNow.ToString('o');exitCode=$buildExit;commands=$commands.ToArray();signed=$false;installed=$false;runtimeValidation='NotPerformed'} | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $evidence 'result.json')}}
exit $buildExit
