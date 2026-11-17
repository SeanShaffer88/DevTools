# StateTimeMachineValidator

Check a JSON save/state graph for schema version, duplicate/malformed states, dangling transition endpoints, and isolated states.

```powershell
py -3 -m ai_tools state-time-machine-validator save.json --expected-version 3
```

Arguments: JSON file (required), optional `--expected-version`, `--text`. Input shape: `{"schemaVersion":3,"states":[{"id":"idle","initial":true}],"transitions":[{"from":"idle","to":"run"}]}`. JSON v1 result uses common findings plus `version`, `stateCount`, `transitionCount`, `initialStates`. Exit `0` pass, `2` error, `125` invalid input. Godot Resource files are not parsed.
