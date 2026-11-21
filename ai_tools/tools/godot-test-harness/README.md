# GodotTestHarness (GTHarness)

Run one Godot headless script and capture bounded stdout/stderr and likely assertion failures.

```powershell
py -3 -m ai_tools godot-test-harness C:\Game --godot C:\Godot\Godot.exe --test-script tests\run.gd --allow-project-code
```

Arguments: project directory, `--godot` executable, `--test-script` inside the project, optional `--timeout` (1–3600 seconds; default 300), and required `--allow-project-code`. JSON v1 contains exit status, command, output tails, assertion lines, and limitations. Exit `0` success, `2` test failure/timeout, `125` refused or invalid run. Project code runs with the caller's permissions; this is not a sandbox.
