param([string]$Source,[string]$Destination)
$ErrorActionPreference='Stop'
Add-Type -Path $Source -ReferencedAssemblies System.Windows.Forms,System.Drawing -OutputAssembly $Destination -OutputType WindowsApplication
