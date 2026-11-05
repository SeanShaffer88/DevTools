# Client Profiles And Lua

Original operational note, version 1. WoW client Interface numbers, exposed APIs and Lua behavior are client-specific. Manage-WowClientProfile.ps1 imports explicit API sources and SavedVariables fixtures as data, preserving hashes and provenance. A sample mock is not an authentic client API snapshot. Never evaluate SavedVariables merely to inspect them.

Test-WowAddon.ps1 checks TOC/XML paths and structure. Test-WowLua.ps1 uses a real matching interpreter to compile syntax with loadfile; it does not execute addon chunks during syntax checking. Explicit trusted harness execution uses mock API/event behavior and does not certify real game execution, protected frames, combat restrictions or taint. No interpreter means Blocked/NotPerformed, not a successful language check.

The included Lua event harness is original, deliberately small and intended for test-owned sources. Add actual API snapshots only from the explicitly chosen client/source. Addon author convention is Malikor. Official language pointer for appropriate legacy clients: https://www.lua.org/manual/5.1/ . No interpreter is downloaded automatically.
