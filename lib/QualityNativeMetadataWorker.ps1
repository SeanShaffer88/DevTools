param([Parameter(Mandatory)][string]$Path)
$ErrorActionPreference='Stop'
try {
 Add-Type -Path "$PSScriptRoot/QualityNativeMetadata.cs"
 $dump=[DevToolsQualityNative.MetadataDecoder]::Read($Path)
 @{schemaVersion=1;identity=$dump.Identity;surface=@($dump.Surface)}|ConvertTo-Json -Compress -Depth 10
 exit 0
}catch{ @{schemaVersion=1;status='UnsupportedOrMalformed';errorType=$_.Exception.GetType().Name}|ConvertTo-Json -Compress;exit 3 }
