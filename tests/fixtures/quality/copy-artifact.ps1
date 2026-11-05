param([string]$Source,[string]$Destination,[Parameter(ValueFromRemainingArguments=$true)]$Flags)
$ErrorActionPreference='Stop'
Copy-Item -LiteralPath $Source -Destination $Destination
