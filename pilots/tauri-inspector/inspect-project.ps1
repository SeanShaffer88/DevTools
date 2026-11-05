#requires -Version 7.0
param([Parameter(Mandatory)][string]$ProjectPath)
$ErrorActionPreference='Stop'
# Fixed trusted adapter: encoding belongs to this child, never the GUI console.
[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)
$OutputEncoding=[Console]::OutputEncoding
& 'C:/Users/Sean Shaffer/Documents/DevTools/Get-ProjectInfo.ps1' -ProjectPath $ProjectPath -MaxDepth 2 -Json
