"""Offline smoke tests for AI developer utilities; Python standard library only."""
import json
import contextlib
import io
from pathlib import Path
import tempfile
import unittest

from ai_tools.scene_diff import parse
from ai_tools.saved_variables_inspector import Parser
from ai_tools.__main__ import COMMANDS
from ai_tools.toc_manifest_linter import main as toc_main
from ai_tools.saved_variables_inspector import main as saved_main
from ai_tools.godot_test_harness import main as harness_main
from ai_tools.state_time_machine_validator import main as state_main
from ai_tools.release_manifest_gen import main as release_main

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

if __name__ == "__main__":
    unittest.main()
