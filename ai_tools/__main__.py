"""Unified dispatcher: python -m ai_tools <tool> [tool arguments]."""
from __future__ import annotations
import importlib
import sys

COMMANDS = {
    "scene-diff": "scene_diff",
    "asset-health-guard": "asset_health_guard",
    "signal-flow-spy": "signal_flow_spy",
    "godot-test-harness": "godot_test_harness",
    "input-map-auditor": "input_map_auditor",
    "state-time-machine-validator": "state_time_machine_validator",
    "toc-manifest-linter": "toc_manifest_linter",
    "addon-memory-taint-auditor": "addon_memory_taint_auditor",
    "saved-variables-inspector": "saved_variables_inspector",
    "addon-api-compat-checker": "addon_api_compat_checker",
    "cargo-semantic-lint": "cargo_semantic_lint",
    "module-dep-graph": "module_dep_graph",
    "export-matrix": "export_matrix",
    "portable-env-auditor": "portable_env_auditor",
    "release-manifest-gen": "release_manifest_gen",
}

def main(argv=None):
    args = list(sys.argv[1:] if argv is None else argv)
    if not args or args[0] in {"-h", "--help"}:
        print("AI Developer Utilities (offline; Python standard library only)\n\nCommands:")
        for command in COMMANDS:
            print(f"  {command}")
        return 0 if args else 2
    command = args.pop(0)
    if command not in COMMANDS:
        print(f"Unknown command: {command}", file=sys.stderr)
        return 2
    return importlib.import_module(f".{COMMANDS[command]}", "ai_tools").main(args)

if __name__ == "__main__":
    raise SystemExit(main())
