# Crashes And Disposable Installer Tests

Original operational note, version 1. Export-CrashDiagnostics.ps1 targets one explicitly selected process owned by the current user. Bundles retain selected module/build information and optional explicit logs. Binary dumps may contain private application memory; text redaction cannot sanitize a dump. No global WER configuration is required.

New-InstallerTestLab.ps1 generates a Windows Sandbox configuration and lifecycle assertions. Generation is not a completed installation/upgrade test. Review the lab, prerequisites and result mapping before explicitly opening it. Keep installer input read-only and networking disabled. Validate process closure, version upgrades, preserved settings, shortcuts/startup preferences, uninstall and remnant assertions in the guest. Never run the guest installer commands on the host.

Official pointers: https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/nf-minidumpapiset-minidumpwritedump ; https://learn.microsoft.com/en-us/windows/security/application-security/application-isolation/windows-sandbox/windows-sandbox-configure-using-wsb-file . VM execution remains unperformed unless separately recorded.
