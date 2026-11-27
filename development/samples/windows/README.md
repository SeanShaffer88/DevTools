# Native Windows Fixture

A small original Win32 counter uses the native message loop and a keyboard-focusable standard button. It has no persistence, registry, network or service API. The saved Zig compiler supplies its Windows C headers/import libraries; no Microsoft SDK is copied into the repository. The original icon and asInvoker manifest are generated during the isolated build. A successful executable build does not prove UI, accessibility, footprint or older-Windows runtime behavior.
