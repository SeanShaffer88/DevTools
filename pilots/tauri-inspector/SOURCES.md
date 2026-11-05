# Sources and provenance

Original pilot source, mockup and generated simple navy/blue ICO: MIT, see LICENSE. Existing toolkit helper is invoked in place, never copied into product source. The build runner is copied byte-for-byte only into ignored local evidence.

Direct dependencies locked by Cargo.lock: Tauri 2.12.5 and tauri-build 2.7.4 (MIT/Apache-2.0), rfd 0.17.2 (MIT), serde/serde_json (MIT/Apache-2.0), sha2 0.10.9 (MIT/Apache-2.0), windows-sys 0.61.2 (MIT/Apache-2.0). These declarations do not establish rights for redistribution of a complete binary; no release was prepared. Transitive notices review and vulnerability audit remain release gates.

Verified API references during implementation:

- https://v2.tauri.app/develop/calling-rust/ — async typed commands, managed state and frontend invoke.
- https://docs.rs/rfd/0.17.2/rfd/struct.FileDialog.html — native folder selector.
- Installed `tauri-utils-2.10.2/src/config.rs` — window dataDirectory is relative; native `WebviewWindowBuilder::data_directory` accepts the absolute profile path.
- Installed Rust CommandExt creation_flags and windows-sys 0.61.2 pipe declarations: CREATE_NO_WINDOW launch and PeekNamedPipe bounded polling; no private console allocation remains.
- https://learn.microsoft.com/en-us/windows/win32/api/jobapi2/nf-jobapi2-setinformationjobobject — Job ownership limits.
- Installed windows-sys 0.61.2 declarations — Job and pipe ABI.

Skill rules applied: API design (`.agents/skills/api-and-interface-design/SKILL.md`: contract first and boundary validation); security (`security-and-hardening/SKILL.md`: encode untrusted output, restrict capabilities); TDD (`test-driven-development/SKILL.md`: failing tests before implementation); incremental implementation and git workflow (small verified slices; commits deferred to coordinator by assignment); frontend UI engineering and `.codex/skills/ui-ux-pro-max/SKILL.md` (design query and mockup before code, keyboard focus, theme parity and reduced motion); source-driven development (version-specific official APIs). Design search's landing-page and remote-font suggestions were unsuitable; only its low-cost minimal style/accessibility guidance informed the specified desktop design.

Coordinator reported XERJ listener verification failure and authorized targeted source fallback; no successful indexing claimed. Pinned GitHub catalog references were not executed or adopted. No remote frontend, telemetry, shell plugin or generic execution API.
