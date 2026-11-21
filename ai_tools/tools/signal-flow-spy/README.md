# SignalFlowSpy

Index static GDScript/C# signal declarations, emissions, and `.tscn`/script connections.

```powershell
py -3 -m ai_tools signal-flow-spy C:\Game
```

Argument: project directory (required); `--text` selects readable output. JSON v1 contains `signals`, `emissions`, `connections`, `autoloads`, and common findings. Findings flag undeclared static references and signals with no detected use. Exit `0` when no errors, `2` for errors, `125` for setup. This is regex-based. Godot 4 Signal-object references are counted in two forms: `sig.emit(...)`/`sig.connect(...)` (optionally `self.`) inside the script that declares `sig`, and `<Autoload>.sig.emit/connect(...)` where `<Autoload>` is a name in the `project.godot` `[autoload]` section. Rows found this way carry `via` (`self` or `autoload:<Name>`); an autoload reference to a name not declared anywhere (for example a built-in `Node` signal) is not reported as undeclared.

Limitations: references through instance variables or other receivers (`health.died.connect(...)`, `get_node(...).sig.emit()`) are not resolved, so those signals can still show as `UnreferencedSignal`. Signals are keyed by name across the project, so same-named signals in different scripts share references. Inherited signals, dynamic callables, and signatures are not resolved.
