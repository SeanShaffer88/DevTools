# ModuleDepGraph

Build a best-effort Rust module/import graph and report likely missing module files, cycles, and large modules.

```powershell
py -3 -m ai_tools module-dep-graph C:\Projects\App
```

Argument: project directory (required); `--text` selects readable output. JSON v1 contains `modules[]` (`name`, `path`, `imports`), `cycles`, and findings. Exit `0` no cycle, `2` a cycle, `125` setup. Rust name resolution, macro-generated modules, and cross-crate edges are not fully resolved.
