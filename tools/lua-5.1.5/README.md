# Approved Lua 5.1.5 Local Toolchain

The user explicitly approved obtaining official Lua 5.1 source and compiling locally for client-matched WoW syntax/mock tests. Source URL: https://www.lua.org/ftp/lua-5.1.5.tar.gz . Archive SHA256: 2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333 . Exact upstream COPYRIGHT/MIT text is retained in bin/COPYRIGHT and source trees.

bin/lua.exe and bin/luac.exe are the canonical local tools; PATH and global installations were not changed. provenance.json records actual source/compiler/SDK/flags/output hashes. verified-build contains the successful untouched source build and logs. bin also retains the initial failed build logs, which showed missing UCRT include/lib environment configuration; files were present and explicit verified SDK flags corrected the build.

Reproduce into a NEW destination with PowerShell 7: `& .\Build-Lua.ps1 -Destination 'C:\LocalScratch\Lua515Fresh'`. The script verifies the pinned existing archive and rejects unsafe tar paths/links. It uses installed VS2022 and Windows SDK 10.0.26100.0, has no downloader/updater, and preserves existing destinations. Sources are unmodified. Official offline manual: verified-build/source/lua-5.1.5/doc/manual.html.

This language runtime is for the explicitly selected legacy Lua 5.1 profile, not a claim of current WoW API support or full game compatibility. The standalone interpreter can execute arbitrary Lua and native modules, so only trusted harnesses should execute. Syntax-only driver compiles without running addon chunks. No additional dependency is authorized by this specific Lua approval.
