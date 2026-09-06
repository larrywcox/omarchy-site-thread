from __future__ import annotations

import importlib.machinery
import importlib.util
import json
from pathlib import Path
import re
import sys
import unittest
from unittest import mock


ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("site_thread", str(ROOT / "bin" / "site-thread"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
SITE_THREAD = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SITE_THREAD)


class BoundedProcessTests(unittest.TestCase):
    def test_stdout_is_rejected_while_child_is_running(self) -> None:
        command = [sys.executable, "-c", "import sys,time; sys.stdout.write('x'*4096); sys.stdout.flush(); time.sleep(30)"]
        with mock.patch.object(
            SITE_THREAD, "terminate_process_group", wraps=SITE_THREAD.terminate_process_group
        ) as terminate:
            with self.assertRaisesRegex(SITE_THREAD.FabricError, "stdout exceeded"):
                SITE_THREAD.run(command, timeout=2, stdout_limit=1024)
        terminate.assert_called_once()

    def test_stderr_is_independently_bounded(self) -> None:
        command = [sys.executable, "-c", "import sys; sys.stderr.write('x'*4096); sys.stderr.flush()"]
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "stderr exceeded"):
            SITE_THREAD.run(command, timeout=2, stderr_limit=1024)

    def test_timeout_is_rejected(self) -> None:
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "timed out"):
            SITE_THREAD.run([sys.executable, "-c", "import time; time.sleep(30)"], timeout=0.05)


class JsonLimitTests(unittest.TestCase):
    def test_valid_json_is_returned(self) -> None:
        payload = {"data": [{"name": "switch"}]}
        self.assertEqual(SITE_THREAD.decode_json(json.dumps(payload)), payload)

    def test_excessive_depth_is_rejected(self) -> None:
        value: object = "leaf"
        for _ in range(SITE_THREAD.MAX_JSON_DEPTH + 1):
            value = [value]
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "nested too deeply"):
            SITE_THREAD.validate_json_limits(value)

    def test_excessive_array_is_rejected(self) -> None:
        value = [0] * (SITE_THREAD.MAX_JSON_COLLECTION_ITEMS + 1)
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "oversized JSON array"):
            SITE_THREAD.validate_json_limits(value)

    def test_excessive_string_is_rejected(self) -> None:
        value = "x" * (SITE_THREAD.MAX_JSON_STRING_CHARS + 1)
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "oversized JSON string"):
            SITE_THREAD.validate_json_limits(value)

    def test_out_of_range_number_is_rejected(self) -> None:
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "out-of-range JSON number"):
            SITE_THREAD.validate_json_limits(float("inf"))

    def test_excessive_row_count_is_rejected(self) -> None:
        payload = {"data": [{}] * (SITE_THREAD.MAX_ROWS_PER_RESPONSE + 1)}
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "too many rows"):
            SITE_THREAD.rows(payload)

    def test_model_strings_have_a_tighter_limit(self) -> None:
        with self.assertRaisesRegex(SITE_THREAD.FabricError, "oversized model field"):
            SITE_THREAD.compact_device({"name": "x" * 257})


class QmlSafetyTests(unittest.TestCase):
    def test_every_text_item_is_plain_text(self) -> None:
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        items = re.findall(r"\bText\s*\{.*?(?=\bText\s*\{|\Z)", source, re.S)
        self.assertTrue(items)
        for item in items:
            self.assertEqual(item.count("textFormat: Text.PlainText"), 1)


if __name__ == "__main__":
    unittest.main()
