# Relocatable NSIS compiler bootstrap

The stock NSIS 3.13 and PortableApps GUI tools failed before startup with Windows error 623 in this machine's zero-capability AppContainer. This compatible **host compiler** is built from unchanged official NSIS 3.13 source with static zlib 1.4 and real PE relocations. It reports v3.13. It is an original DevTools build, not an official publisher binary or a signed release. No host security policy or upstream executable bytes were patched.

The x86 compiler keeps the stock x86 output target and plugins. An x64 host prototype built successfully but defaulted to amd64 stubs unavailable in the stock package, so it is not distributed. Only Bin/makensis.exe is replaced in the saved official NSIS package. All original runtime files and license notices remain. The forwarding GUI at the package root is not the compiler entry point: invoke **Bin/makensis.exe** directly with NSISDIR set to its package root. Existing installer stubs retain their upstream properties.

## Reproduce preparation

Use a new owned directory. Verify the pins in provenance.json before extraction. Extract the existing `nsis-source/nsis-3.13-src.tar.bz2` resource and the bootstrap payload's `zlib-1.4.tar.gz` there. Extract `scons-4.11.1-py3-none-any.whl` as a ZIP to a sibling `scons` directory. Copy build.cmd beside those three directories. No pip installation is necessary. The saved SCons source archive is provided for provenance and rebuilding.

The verified toolchain was Python 3.15.2, VS 2022 Build Tools MSVC 14.44.35207 and Windows SDK installed on the host. From PowerShell invoke the explicit batch recipe, supplying your verified executable paths:

```powershell
& $env:ComSpec /d /c '"C:\Build\Nsis\build.cmd" "C:\Python315\python.exe" "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars32.bat"'
```

Expected output: `nsis-3.13-src/build/urelease/makensis/makensis.exe`. Exit zero is required. The recipe uses the upstream zlib win32/Makefile.msc static-library target and the upstream NSIS SCons `makensis` target (documented in INSTALL). It skips stub/plugin/GUI rebuilds. /MT avoids a separately installed VC runtime; /DYNAMICBASE and /FIXED:NO preserve actual loader relocation data. Setting flags is not binary patching. Static zlib.lib is also copied as zdll.lib because NSIS's source-configured library search uses that name; no dynamic zlib is shipped.

Extract the pinned official stock `nsis-3.13.zip` and replace only its Bin/makensis.exe with this compiler; retain all remaining files unchanged and add the clearly identified DEVTOOLS-BUILD.txt notice. Set NSISDIR to that extracted root, then run `Bin/makensis.exe /VERSION`; expect v3.13 and exit zero. A static PE inspection must find x86, DYNAMICBASE set, RELOCS_STRIPPED clear and a nonempty relocation directory. Rebuilds can vary in timestamps/path diagnostics; no bit-reproducibility promise is made.

Preparation ran on the host using already installed MSVC/SDK; it is **not** an offline-isolation proof. The sample harness separately runs the saved compiler and actual PortableApps source compilation inside a zero-capability AppContainer, with its network canaries and child-token evidence. Installer build success does not establish installation, launch, upgrade or runtime portability. No generated installer is executed by this bootstrap.

Pinned dependencies and sources are recorded in provenance.json. NSIS licenses: zlib/libpng, bzip2 and CPL 1.0 for its original components (COPYING retained). zlib 1.4: zlib license. SCons 4.11.1: MIT plus its separately retained bundled notices. Full source accompanies the compiler through saved nsis-source, zlib and SCons payloads. zlib 1.4 replaces a temporary 1.3.1 bootstrap because the current publisher release fixes memory-safety defects; the earlier binary is not shipped.
