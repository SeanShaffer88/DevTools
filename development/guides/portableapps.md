# PortableApps.com Offline Development

Start with the canonical portableapps/AGENTS.md and portableapps/README.md. This guide is an original workflow index; it does not replace the official format or grant trademark rights. Keep original application binaries in App/, user state in Data/, and reviewed package/launcher source and licenses in Other/Source/. The supplied native sample has no persistence or registry access, so its launcher must not invent cleanup mappings.

Copy the canonical MinimalAppPortable template and reconcile every INI key against docs/01 through docs/04. Format Version is 3.9; PackageVersion has exactly four numeric components; the AppID, folder name, launcher INI and launcher EXE must agree. Preserve the actual base-app icon in the package metadata and generated installer.

The saved acquisition pack contains the official PAL, Installer and NSIS distributions and matching compiler source. Check development/acquisitions/recipes/portableapps.md for exact versions and remaining gates. Never substitute a generic NSIS script for a PortableApps.com Installer and label it PAF. Use the official Generator/Installer source-backed interface; keep generated installer logs and data out of source control.

Prepare reviewed tools and source into a new task-owned directory while connected if acquisition is still required. The sample runner then starts actual compilers under a zero-network-capability AppContainer. Tool extraction and SDK preparation are distinct from the isolated artifact-producing commands. Retain the package metadata, exact input hashes, compiler versions, command exit codes and final EXE hash with the offline isolation receipt.

The sample target produces a real launcher and .paf.exe. This establishes Built only. Installing the generated PAF, upgrades with Data preservation, launch/exit footprint, relocation, coexistence with a local installation, and crash recovery need separate explicit tests. No Windows setup or app launch is needed merely to verify compilation. Check both canonical checklists before considering any release.
