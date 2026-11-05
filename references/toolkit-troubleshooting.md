# Toolkit Operation And Troubleshooting

Original local operational note. Read the toolkit README.md and toolkit.json before
running helpers. Use PowerShell 7. Give future chats the DevTools folder path; this
library is not automatically injected into global instructions or memory.

Get-DevEnvironment.ps1 inventories known tools; a discovered path does not establish
that a project builds. Get-ProjectInfo.ps1 reads bounded project metadata and Git
branch information. It omits Git status because configured clean filters can
execute code. Do not infer build permission from a discovered wrapper.

Invoke-DevBuild.ps1 runs an explicit executable and argument array once. Its unique
run folder records stdout, stderr, native/runner exit codes and requested artifact
hashes. Arguments are omitted from metadata, but child output and paths can still
contain sensitive information. Keep logs local and review before sharing.

For a failure, read raw stderr/stdout and result.json, then correct the precise
offending command, symbol or file. Missing requested artifacts fail verification
even when the command exits zero. Read validation*.json for exact tested checks
and limitations; never substitute a build plan for actual execution results.

Get-DevReference.ps1 searches these local notes and never fetches source URLs.
The reference collection is small operational guidance, not a complete SDK mirror.
