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


def fleet_payload(site_count: int) -> dict:
    """A Site Manager /v1/sites page shaped like the real thing.

    Each site carries a full statistics block, which is the bulk of the JSON
    value count: counts, percentages, ispInfo, and an internetIssues period
    array.
    """
    return {
        "data": [
            {
                "siteId": f"site{index:04d}",
                "hostId": f"console-{index:04d}",
                "isOwner": index % 3 == 0,
                "permission": "admin",
                "meta": {
                    "desc": f"Branch {index}",
                    "name": f"branch-{index}",
                    "timezone": "America/Chicago",
                    "gatewayMac": "aa:bb:cc:dd:ee:ff",
                },
                "statistics": {
                    "counts": {
                        key: index % 17
                        for key in (
                            "totalDevice", "offlineDevice", "gatewayDevice",
                            "offlineGatewayDevice", "wifiDevice", "wiredDevice",
                            "pendingUpdateDevice", "wifiClient", "wiredClient",
                            "guestClient", "criticalNotification",
                        )
                    },
                    "percentages": {"wanUptime": 99.9, "txRetry": 1.2},
                    "ispInfo": {"name": "Acme Fiber", "organization": "Acme"},
                    "internetIssues": [
                        {
                            "index": period,
                            "startTimestamp": "2026-09-01T00:00:00Z",
                            "duration": 12,
                            "wanDowntime": False,
                            "wan2FailoverActive": False,
                            "latencyAvg": 14.2,
                            "packetLoss": 0.0,
                        }
                        for period in range(24)
                    ],
                },
            }
            for index in range(site_count)
        ],
        "nextToken": "",
    }


class FleetSizeTests(unittest.TestCase):
    """Regression: the bounds must not reject a legitimate large fleet.

    These limits guard against hostile responses, so they have to sit clear of
    what Site Manager actually returns. An earlier 20,000-value ceiling broke
    at roughly 74 sites.
    """

    def test_a_large_fleet_page_is_accepted(self) -> None:
        payload = fleet_payload(200)
        body = json.dumps(payload)
        self.assertLess(len(body), SITE_THREAD.MAX_STDOUT_BYTES)
        decoded = SITE_THREAD.decode_json(body)
        self.assertEqual(len(SITE_THREAD.rows(decoded)), 200)

    def test_the_value_ceiling_clears_a_full_page_with_headroom(self) -> None:
        pending: list = [(fleet_payload(200), 0)]
        seen = 0
        while pending:
            value, depth = pending.pop()
            seen += 1
            if isinstance(value, list):
                pending.extend((child, depth + 1) for child in value)
            elif isinstance(value, dict):
                pending.extend((child, depth + 1) for child in value.values())
        # A full page must not land anywhere near the ceiling.
        self.assertLess(seen * 4, SITE_THREAD.MAX_JSON_TOTAL_VALUES)


class QmlSafetyTests(unittest.TestCase):
    def test_every_text_item_is_plain_text(self) -> None:
        source = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        items = re.findall(r"\bText\s*\{.*?(?=\bText\s*\{|\Z)", source, re.S)
        self.assertTrue(items)
        for item in items:
            self.assertEqual(item.count("textFormat: Text.PlainText"), 1)


if __name__ == "__main__":
    unittest.main()
