# Local Project Templates

Original local operational note. New-DevProject.ps1 generates WindowsConsole,
NativeDll, WowAddon, AndroidApp or AndroidGame sources in a new destination. It
refuses an existing destination and validates names/paths. Generation itself does
not compile, restore packages, download tools, sign binaries or install apps.

WindowsConsole needs a compatible installed .NET SDK. NativeDll needs CMake plus
a native compiler; on this computer the verified MSVC compiler is under Visual
Studio 2022 BuildTools, while the newer VS18 installation lacked MSVC at inspection.
Select a real toolchain rather than blindly choosing the newest installation.

WowAddon requires an explicit InterfaceVersion and uses author Malikor. Validate
the generated addon with Test-WowAddon.ps1 and then a matching client.

AndroidApp and AndroidGame need installed JDK/SDK build tools and an android.jar
platform. Their build scripts produce unsigned APKs without Gradle downloads or
new packages. UI mockups describe the minimal template screens. Device execution,
signing and publishing require subsequent explicit work.

Generated READMEs supply template-specific commands and prerequisites. Shared
toolkit tests record local build evidence; that evidence is not a guarantee for
all future SDK/compiler releases.
