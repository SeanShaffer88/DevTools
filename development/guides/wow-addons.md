# World of Warcraft Addon Offline Fixture

Read wow-addons/AGENTS.md and the actual selected client profile before using API examples. The original OfflineSample package deliberately has no client API calls and no SavedVariables. Its TOC uses the existing repository Forever fixture Interface 16001 explicitly; this is a version-bound fixture, not a claim about an installed or current client. Author Malikor follows the user's addon convention.

Use the approved local Lua 5.1.5 tool from tools/lua-5.1.5 for matching syntax checks. Copy the tool into the owned offline task directory, retain its source/license provenance, and run the declared luac -p command under the same zero-network-capability build context. The sample packager then creates a ZIP containing only the TOC and original Lua file, retaining the folder structure the client expects.

Syntax and packaging checks do not prove addon load order, supported APIs, combat taint, protected actions, SavedVariables migration or performance. No game client is launched and nothing is installed into an addon directory by the sample builder. For real addons run Test-WowAddon.ps1 with the actual TOC/client Interface; run Test-WowLua.ps1 with the selected client language version and only explicitly trusted mock tests.
