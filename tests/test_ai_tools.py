"""Offline smoke tests for AI developer utilities; Python standard library only."""
import json
import contextlib
import io
import sys
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import subprocess

from ai_tools.scene_diff import parse
from ai_tools.scene_diff import main as scene_diff_main
from ai_tools.asset_health_guard import main as asset_health_main
from ai_tools.signal_flow_spy import main as signal_flow_main
from ai_tools.saved_variables_inspector import Parser
from ai_tools.__main__ import COMMANDS
from ai_tools.toc_manifest_linter import main as toc_main
from ai_tools.saved_variables_inspector import main as saved_main
from ai_tools.godot_test_harness import main as harness_main
from ai_tools.state_time_machine_validator import main as state_main
from ai_tools.release_manifest_gen import main as release_main
from ai_tools.signal_flow_spy import main as signal_main
from ai_tools.input_map_auditor import main as input_main
from ai_tools.asset_health_guard import main as asset_main
from ai_tools.input_map_auditor import main as input_map_main
from ai_tools.addon_memory_taint_auditor import main as taint_main
from ai_tools.addon_api_compat_checker import main as api_compat_main
from ai_tools.cargo_semantic_lint import run as cargo_run
from ai_tools.module_dep_graph import main as module_graph_main
from ai_tools.export_matrix import main as export_matrix_main
from ai_tools.portable_env_auditor import main as portable_env_main


def run_json(main, argv):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        code = main(argv)
    return code, json.loads(output.getvalue())


def write_tree(root, files):
    for rel, text in files.items():
        path = Path(root) / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")

FIXTURES = Path(__file__).parent / "fixtures" / "ai_tools"

def run_json(main_fn, args):
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        code = main_fn([str(x) for x in args])
    return code, json.loads(output.getvalue())

class AiToolsTests(unittest.TestCase):
    def test_dispatcher_has_fifteen_tools(self):
        self.assertEqual(len(COMMANDS), 15)

    def test_scene_diff_parser_records_nodes_properties(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "sample.tscn"
            f.write_text('[gd_scene format=3]\n[node name="Root" type="Node2D"]\nposition = Vector2(1, 2)\n', encoding="utf-8")
            result = parse(f)
            self.assertIn("Root", result["nodes"])
            self.assertEqual(result["nodes"]["Root"]["properties"]["position"], "Vector2(1, 2)")

    def test_saved_variables_literal_parser(self):
        data = Parser('{["name"]="A", count=3, enabled=true, child={1,2}}').value()
        self.assertEqual(data["name"], "A")
        self.assertEqual(data["count"], 3)
        self.assertEqual(data["enabled"], True)
        self.assertEqual(data["child"][2], 2)

    def test_saved_variables_keeps_comment_marker_inside_string(self):
        data = Parser('{["text"]="left--right", -- real comment\n count=1}').value()
        self.assertEqual(data["text"], "left--right")

    def test_saved_variables_rejects_expressions(self):
        with self.assertRaises(ValueError):
            Parser('{ value = os.execute("bad") }').value()

    def test_saved_variables_rejects_unrecognized_characters(self):
        with self.assertRaises(ValueError):
            Parser('{ value = 1; @ }').value()

    def test_toc_linter_accepts_contained_minimal_addon(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "Addon.toc").write_text("## Interface: 110200\n## Title: Fixture\nmain.lua\n", encoding="utf-8")
            (root / "main.lua").write_text("-- fixture\n", encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = toc_main([d, "--interface", "110200"])
            self.assertEqual(code, 0)
            self.assertTrue(json.loads(output.getvalue())["valid"])

    def test_toc_linter_finds_missing_xml_include(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "Addon.toc").write_text("## Interface: 110200\n## Title: Fixture\nmain.xml\n", encoding="utf-8")
            (root / "main.xml").write_text('<Ui><Include file="missing.xml"/></Ui>', encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = toc_main([d])
            self.assertEqual(code, 2)
            self.assertIn("MissingXmlDependency", [x["code"] for x in json.loads(output.getvalue())["findings"]])

    def test_saved_variables_writes_new_normalized_json(self):
        with tempfile.TemporaryDirectory() as d:
            source, dest = Path(d) / "Saved.lua", Path(d) / "Saved.json"
            source.write_text('Saved = { count = 3 }', encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = saved_main([str(source), "--sanitize-json", str(dest)])
            self.assertEqual(code, 0)
            self.assertEqual(json.loads(dest.read_text(encoding="utf-8"))["Saved"]["count"], 3)

    def test_state_validator_reports_dangling_transition(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "state.json"
            path.write_text(json.dumps({"schemaVersion": 1, "states": [{"id": "idle"}],
                                        "transitions": [{"from": "idle", "to": "missing"}]}), encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = state_main([str(path)])
            self.assertEqual(code, 2)
            self.assertIn("DanglingTransition", [x["code"] for x in json.loads(output.getvalue())["findings"]])

    def test_state_validator_handles_unhashable_ids_as_findings(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / "state.json"
            path.write_text(json.dumps({"states": [{"id": ["bad"]}], "transitions": []}), encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = state_main([str(path)])
            self.assertEqual(code, 2)
            self.assertIn("InvalidState", [x["code"] for x in json.loads(output.getvalue())["findings"]])

    def test_harness_refuses_execution_without_acknowledgement(self):
        output = io.StringIO()
        with contextlib.redirect_stderr(output):
            code = harness_main([".", "--godot", "Godot.exe", "--test-script", "tests/run.gd"])
        self.assertEqual(code, 125)
        self.assertIn("allow-project-code", output.getvalue())

    def test_release_manifest_includes_nested_checksum_named_payload(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / "nested").mkdir()
            (root / "nested" / "SHA256SUMS.txt").write_text("payload", encoding="utf-8")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                code = release_main([d])
            payload = json.loads(output.getvalue())
            self.assertEqual(code, 0)
            self.assertIn("nested/SHA256SUMS.txt", payload["manifest"])

    def test_signal_flow_spy_resolves_autoload_and_own_script_signal_objects(self):
        with tempfile.TemporaryDirectory() as d:
            write_tree(d, {
                "project.godot": '[application]\nconfig/name="Fixture"\n\n[autoload]\n\nEvents="*res://autoload/events.gd"\n\n[display]\nEvents2="*res://nope.gd"\n',
                "autoload/events.gd": "extends Node\nsignal player_dashed(direction)\nsignal never_used\n",
                "scripts/hero.gd": "extends Node\nsignal died\nfunc dash():\n\tEvents.player_dashed.emit(Vector2.ZERO)\nfunc kill():\n\tdied.emit()\n",
                "scripts/audio.gd": "extends Node\nfunc _ready():\n\tEvents.player_dashed.connect(_on_dash)\n\tEvents.tree_exiting.connect(_on_exit)\n",
                "scripts/other.gd": "extends Node\nsignal orphan\nfunc _ready():\n\tnode.orphan.connect(_x)\n",
            })
            code, payload = run_json(signal_main, [d])
            unreferenced = {f["message"].split()[1] for f in payload["findings"] if f["code"] == "UnreferencedSignal"}
            self.assertEqual(code, 0)
            self.assertEqual(payload["autoloads"], {"Events": "res://autoload/events.gd"})
            self.assertNotIn("player_dashed", unreferenced)
            self.assertNotIn("died", unreferenced)
            # Unchanged behaviour: truly unused signals and instance-variable receivers stay unresolved.
            self.assertIn("never_used", unreferenced)
            self.assertIn("orphan", unreferenced)
            # Built-in Node signals on an autoload are not reported as undeclared.
            self.assertNotIn("UnknownConnection", [f["code"] for f in payload["findings"]])

    def test_input_map_auditor_ignores_non_input_sections(self):
        with tempfile.TemporaryDirectory() as d:
            write_tree(d, {
                "project.godot": '[input]\n\njump={\n"deadzone": 0.5,\n"events": []\n}\nunused_action={\n"deadzone": 0.5,\n"events": []\n}\n\n[shader_globals]\n\nsg_height_tex={\n"type": "sampler2D",\n"value": ""\n}\n',
                "player.gd": 'extends Node\nfunc _process(_d):\n\tif Input.is_action_just_pressed("jump"):\n\t\tpass\n',
            })
            code, payload = run_json(input_main, [d])
            unused = [f["message"] for f in payload["findings"] if f["code"] == "UnusedInputAction"]
            self.assertEqual(code, 0)
            self.assertEqual(payload["actions"], ["jump", "unused_action"])
            self.assertEqual(unused, ["Action 'unused_action' has no detected script use"])

    def test_asset_health_guard_treats_format_paths_as_dynamic(self):
        with tempfile.TemporaryDirectory() as d:
            write_tree(d, {
                "project.godot": "[application]\n",
                "resources/heroes/sol.tres": "[gd_resource format=3]\n",
                "scripts/hero.gd": 'extends Node\nconst A = "res://resources/heroes/%s.tres"\nconst B = "res://assets/audio/%s"\nconst C = "res://lvl/level_%02d.tscn"\nconst D = "res://items/{0}.tres"\nconst E = "res://items/{name}.tres"\nconst OK = "res://resources/heroes/sol.tres"\nconst GONE = "res://resources/heroes/missing.tres"\n',
            })
            code, payload = run_json(asset_main, [d])
            missing = [f["message"] for f in payload["findings"] if f["code"] == "MissingResource"]
            dynamic = [f for f in payload["findings"] if f["code"] == "DynamicResourcePath"]
            self.assertEqual(code, 2)
            self.assertEqual(missing, ["Missing res://resources/heroes/missing.tres"])
            self.assertEqual(len(dynamic), 5)
            self.assertTrue(all(f["severity"] == "info" for f in dynamic))

    def test_fixture_directory_exists_for_every_command(self):
        self.assertEqual({p.name for p in FIXTURES.iterdir() if p.is_dir()}, set(COMMANDS))

    def test_scene_diff_fixture(self):
        code, payload = run_json(scene_diff_main, [
            FIXTURES / "scene-diff" / "before.tscn",
            FIXTURES / "scene-diff" / "after.tscn",
        ])
        self.assertEqual(code, 0)
        self.assertEqual(payload["addedNodes"], ["Camera"])
        self.assertTrue(any(x["property"] == "position" for x in payload["changedProperties"]))

    def test_asset_guard_fixture_reports_missing_res_path(self):
        code, payload = run_json(asset_health_main, [FIXTURES / "asset-health-guard"])
        self.assertEqual(code, 2)
        self.assertIn("MissingResource", [x["code"] for x in payload["findings"]])

    def test_signal_spy_fixture_flags_unbound_signal(self):
        code, payload = run_json(signal_flow_main, [FIXTURES / "signal-flow-spy"])
        self.assertEqual(code, 0)
        self.assertIn("UnknownConnection", [x["code"] for x in payload["findings"]])

    def test_harness_fixture_captures_child_failure(self):
        fixture = FIXTURES / "godot-test-harness"
        code, payload = run_json(harness_main, [
            fixture, "--godot", sys.executable, "--test-script", "test.gd",
            "--timeout", "5", "--allow-project-code",
        ])
        self.assertEqual(code, 2)
        self.assertFalse(payload["passed"])
        self.assertFalse(payload.get("timedOut", False))

    def test_input_map_fixture_flags_missing_action(self):
        code, payload = run_json(input_map_main, [FIXTURES / "input-map-auditor"])
        self.assertEqual(code, 2)
        self.assertIn("MissingInputAction", [x["code"] for x in payload["findings"]])

    def test_state_machine_fixture_flags_dangling_edge(self):
        code, payload = run_json(state_main, [
            FIXTURES / "state-time-machine-validator" / "state.json", "--expected-version", "2",
        ])
        self.assertEqual(code, 2)
        self.assertIn("DanglingTransition", [x["code"] for x in payload["findings"]])

    def test_toc_fixture_resolves_nested_xml_loads(self):
        code, payload = run_json(toc_main, [
            FIXTURES / "toc-manifest-linter", "--interface", "110200",
        ])
        self.assertEqual(code, 0)
        paths = [x["path"] for x in payload["loadOrder"]]
        self.assertIn("Nested.xml", paths)
        self.assertIn("Main.lua", paths)

    def test_taint_fixture_flags_review_patterns(self):
        code, payload = run_json(taint_main, [FIXTURES / "addon-memory-taint-auditor"])
        self.assertEqual(code, 0)
        codes = {x["code"] for x in payload["findings"]}
        self.assertIn("ProtectedGlobalWrite", codes)
        self.assertIn("CombatFrameMutation", codes)

    def test_saved_variables_fixture_parses_nested_table(self):
        code, payload = run_json(saved_main, [
            FIXTURES / "saved-variables-inspector" / "Saved.lua", "--json-data",
        ])
        self.assertEqual(code, 0)
        self.assertTrue(payload["valid"])
        self.assertTrue(payload["data"]["FixtureDB"]["profile"]["enabled"])

    def test_api_compat_fixture_flags_catalog_symbol(self):
        code, payload = run_json(api_compat_main, [
            FIXTURES / "addon-api-compat-checker", "--interface", "110200",
        ])
        self.assertEqual(code, 0)
        self.assertIn("GetSpellInfo", payload["matchedSymbols"])

    def test_cargo_fixture_parses_rustc_diagnostic_offline(self):
        fixture = FIXTURES / "cargo-semantic-lint" / "diagnostic.jsonl"
        line = fixture.read_text(encoding="utf-8")
        fake = subprocess.CompletedProcess(args=["cargo"], returncode=101, stdout=line, stderr="")
        with patch("ai_tools.cargo_semantic_lint.subprocess.run", return_value=fake) as mocked:
            result = cargo_run(["cargo", "check"], FIXTURES / "cargo-semantic-lint", 5)
        self.assertEqual(result["diagnostics"][0]["line"], 4)
        self.assertEqual(mocked.call_args.kwargs["env"]["CARGO_NET_OFFLINE"], "true")
        self.assertFalse(mocked.call_args.kwargs["shell"])

    def test_module_graph_fixture_finds_cycle(self):
        code, payload = run_json(module_graph_main, [FIXTURES / "module-dep-graph"])
        self.assertEqual(code, 2)
        self.assertTrue(payload["cycles"])

    def test_export_matrix_fixture_validates_all_targets(self):
        fixture = FIXTURES / "export-matrix"
        code, payload = run_json(export_matrix_main, [
            fixture, "--profiles", fixture / "profiles.json",
        ])
        self.assertEqual(code, 0)
        self.assertEqual(payload["profilesChecked"], 3)
        self.assertFalse(payload["buildsRun"])

    def test_portable_env_fixture_reports_network_and_write_markers(self):
        code, payload = run_json(portable_env_main, [FIXTURES / "portable-env-auditor"])
        self.assertEqual(code, 0)
        codes = {x["code"] for x in payload["findings"]}
        self.assertIn("NetworkOrTelemetryMarker", codes)
        self.assertIn("PotentialBroadWrite", codes)

    def test_release_fixture_hashes_payloads_and_suggests_names(self):
        code, payload = run_json(release_main, [FIXTURES / "release-manifest-gen"])
        self.assertEqual(code, 0)
        self.assertEqual(payload["fileCount"], 2)
        self.assertEqual(len(payload["renameSuggestions"]), 2)

if __name__ == "__main__":
    unittest.main()
