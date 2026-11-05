# WoW Addon Validation

Original local operational note. Use Test-WowAddon.ps1 -AddonPath and explicitly
select -TocPath when more than one TOC is present. Supply -InterfaceVersion for the
specific client being targeted; no client version is inferred from folder names.

The checker requires Interface and Title, reports declared dependencies, and walks
TOC Lua/XML entries plus XML Include/Script file references. XML child paths resolve
relative to the containing XML file. References must remain inside the addon and
must not traverse reparse points. DTDs/external entities and include cycles fail.
Repeated file loads are warnings because some intentional addons repeat files.

Dependencies are declarations only. The tool has no installed-addon inventory.
Lua syntax, client API existence, protected actions and runtime behavior are
NotPerformed: test those with a matching Lua/client environment and in-game checks.
WoW addon author convention for generated templates is Malikor.

No upstream WoW API documentation was downloaded. These notes describe this local
checker rather than asserting a complete TOC format or client compatibility guide.
