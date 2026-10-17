from __future__ import annotations

import importlib.machinery
import importlib.util
from contextlib import redirect_stdout
import io
import json
from pathlib import Path
import re
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("site_thread", str(ROOT / "bin" / "site-thread"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
SITE_THREAD = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(SITE_THREAD)


def load_analytics_qml() -> str:
    content = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")
    views_dir = ROOT / "views" / "analytics"
    if views_dir.exists():
        for tab_file in sorted(views_dir.glob("*.qml")):
            content += "\n" + tab_file.read_text(encoding="utf-8")
    return content


def load_panel_qml() -> str:
    content = (ROOT / "Panel.qml").read_text(encoding="utf-8")
    views_dir = ROOT / "views"
    if views_dir.exists():
        for view_file in sorted(views_dir.glob("*.qml")):
            content += "\n" + view_file.read_text(encoding="utf-8")
    components_dir = ROOT / "components"
    if components_dir.exists():
        for comp_file in sorted(components_dir.glob("*.qml")):
            content += "\n" + comp_file.read_text(encoding="utf-8")
    return content



class FeatureTelemetryTests(unittest.TestCase):
    def test_demo_summary_has_coordinates_and_gateways(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertTrue(summary.get("ok"))
        self.assertTrue(summary.get("demo"))
        sites = summary.get("sites", [])
        self.assertEqual(len(sites), 3)

        for site in sites:
            self.assertIn("lat", site)
            self.assertIn("lng", site)
            self.assertIsInstance(site["lat"], (int, float))
            self.assertIsInstance(site["lng"], (int, float))
            self.assertIn("gatewayModel", site)
            self.assertIn("gatewayIp", site)
            self.assertIn("wifiClients", site)
            self.assertIn("wiredClients", site)

        network = summary.get("network", {})
        self.assertIn("wifiClients", network)
        self.assertIn("wiredClients", network)
        self.assertIn("gatewaysCount", network)
        self.assertGreaterEqual(network["gatewaysCount"], 1)

    def test_demo_summary_has_sdwan_and_uplinks(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("sdwan", summary)
        sdwan = summary["sdwan"]
        self.assertTrue(sdwan.get("available"))
        self.assertEqual(sdwan.get("status"), "connected")
        self.assertGreaterEqual(len(sdwan.get("connections", [])), 1)

        devices = summary.get("network", {}).get("devices", [])
        self.assertTrue(any(d.get("parentName") for d in devices))

    def test_demo_summary_has_active_and_resolved_issues(self) -> None:
        summary = SITE_THREAD.demo_summary()
        issues = summary.get("issues", [])
        self.assertTrue(len(issues) >= 2)

        active = [i for i in issues if i.get("active") is True]
        resolved = [i for i in issues if i.get("active") is False]

        self.assertTrue(len(active) >= 1)
        self.assertTrue(len(resolved) >= 1)

        for res in resolved:
            self.assertIn("resolvedAt", res)
            self.assertIn("durationSeconds", res)
            self.assertGreater(res["durationSeconds"], 0)

    def test_timezone_coordinates_resolution(self) -> None:
        # Perth
        lat, lng = SITE_THREAD.site_coordinates({}, "Australia/Perth", 0)
        self.assertAlmostEqual(lat, -31.95, delta=1.0)
        self.assertAlmostEqual(lng, 115.86, delta=1.0)

        # London
        lat, lng = SITE_THREAD.site_coordinates({}, "Europe/London", 0)
        self.assertAlmostEqual(lat, 51.51, delta=1.0)
        self.assertAlmostEqual(lng, -0.13, delta=1.0)

        # Chicago
        lat, lng = SITE_THREAD.site_coordinates({}, "America/Chicago", 0)
        self.assertAlmostEqual(lat, 41.88, delta=1.0)
        self.assertAlmostEqual(lng, -87.63, delta=1.0)

    def test_custom_coordinates_override_timezone(self) -> None:
        meta = {"lat": 12.3456, "lng": 78.9012}
        lat, lng = SITE_THREAD.site_coordinates(meta, "Australia/Perth", 0)
        self.assertEqual(lat, 12.3456)
        self.assertEqual(lng, 78.9012)

    def test_demo_summary_has_clients_telemetry(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("clients", summary)
        clients = summary["clients"]
        self.assertGreaterEqual(len(clients), 3)
        for client in clients:
            self.assertIn("name", client)
            self.assertIn("ip", client)
            self.assertIn("mac", client)
            self.assertIn("uplinkName", client)
            self.assertIn("uplinkPort", client)
            self.assertIn("radioProto", client)

    def test_demo_summary_has_wans_and_outages(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("wans", summary)
        wans = summary["wans"]
        self.assertGreaterEqual(len(wans), 2)
        for wan in wans:
            self.assertIn("interface", wan)
            self.assertIn("speedType", wan)
            self.assertIn("ipv4", wan)
            self.assertIn("type", wan)

        self.assertIn("outages", summary)
        outages = summary["outages"]
        self.assertGreaterEqual(len(outages), 1)
        for outage in outages:
            self.assertIn("siteName", outage)
            self.assertIn("timestamp", outage)
            self.assertIn("durationText", outage)

    def test_demo_summary_has_switches_and_poe_ports(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("switches", summary)
        switches = summary["switches"]
        self.assertGreaterEqual(len(switches), 1)
        sw = switches[0]
        self.assertIn("name", sw)
        self.assertIn("mac", sw)
        self.assertIn("totalPower", sw)
        self.assertIn("ports", sw)
        ports = sw["ports"]
        self.assertGreaterEqual(len(ports), 8)
        self.assertTrue(any(p.get("poePower", 0) > 0 for p in ports))

    def test_demo_summary_has_consoles_and_direct_connect(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("consoles", summary)
        consoles = summary["consoles"]
        self.assertGreaterEqual(len(consoles), 3)

        for c in consoles:
            self.assertIn("hostId", c)
            self.assertIn("name", c)
            self.assertIn("model", c)
            self.assertIn("firmwareVersion", c)
            self.assertIn("directConnectDomain", c)
            self.assertTrue(c["directConnectDomain"].endswith(".id.ui.direct"))
            self.assertIn("directConnectUrl", c)
            self.assertTrue(c["directConnectUrl"].startswith("https://"))
            self.assertIn("applications", c)
            apps = c["applications"]
            self.assertGreaterEqual(len(apps), 1)
            for app in apps:
                self.assertIn("id", app)
                self.assertIn("name", app)
                self.assertIn("version", app)
                self.assertIn("directUrl", app)
                self.assertTrue(app["directUrl"].startswith("https://"))


class BarInteractionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()

    def test_bar_extra_mouse_area_exists_and_configured(self) -> None:
        self.assertIn("id: barExtraMouse", self.panel_qml)
        self.assertIn("cursorShape: Qt.PointingHandCursor", self.panel_qml)
        self.assertIn("acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton", self.panel_qml)
        self.assertIn("root.handleBarClick(mouse.button)", self.panel_qml)

    def test_bar_button_uses_handle_bar_click(self) -> None:
        self.assertIn("root.handleBarClick(b)", self.panel_qml)

    def test_go_to_main_page_function_resets_navigation_state(self) -> None:
        self.assertIn("function goToMainPage()", self.panel_qml)
        self.assertIn("root.activeTab = 0", self.panel_qml)
        self.assertIn("root.settingsMode = false", self.panel_qml)
        self.assertIn("root.backToSites()", self.panel_qml)
        self.assertIn("root.closeAnalytics()", self.panel_qml)

    def test_ipc_handler_exposes_bar_interactions(self) -> None:
        self.assertIn("function goToMainPage(): void", self.panel_qml)
        self.assertIn("function handleBarClick(button: int): void", self.panel_qml)
        self.assertIn("activeTab: root.activeTab", self.panel_qml)
        self.assertIn("inSite: root.inSite", self.panel_qml)


class ConsoleDirectConnectIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.analytics_qml = load_analytics_qml()

    def test_panel_supports_analytics_tab_4(self) -> None:
        self.assertIn("Math.min(4, tabIndex)", self.panel_qml)

    def test_panel_has_direct_connect_button_and_banner(self) -> None:
        self.assertIn("id: directConnectSiteBtn", self.panel_qml)
        self.assertIn("id: directConnectBanner", self.panel_qml)
        self.assertIn("function getSiteConsole(hostId)", self.panel_qml)

    def test_analytics_window_has_tab_4_unifi_os(self) -> None:
        self.assertIn("UniFi OS & Direct Connect", self.analytics_qml)
        self.assertIn("property var fleetConsoles:", self.analytics_qml)
        self.assertIn("function copyToClipboard(text, label)", self.analytics_qml)
        self.assertIn("function openExternalUrl(url)", self.analytics_qml)
        self.assertIn("id: tab4View", self.analytics_qml)

    def test_analytics_window_matches_agent_hub_window_size(self) -> None:
        self.assertIn("minimumSize: Qt.size(860, 580)", self.analytics_qml)
        self.assertIn("implicitWidth: 1080", self.analytics_qml)
        self.assertIn("implicitHeight: 740", self.analytics_qml)
        self.assertIn('title: "UniFi SiteThread — Fleet Analytics & Telemetry"', self.analytics_qml)

    def test_switch_ports_tab_has_searchable_site_and_switch_dropdowns(self) -> None:
        self.assertIn("property string selectedSwitchSite: \"all\"", self.analytics_qml)
        self.assertIn("property string selectedSwitchMac: \"\"", self.analytics_qml)
        self.assertIn("readonly property var switchSiteOptions:", self.analytics_qml)
        self.assertIn("readonly property var switchesForSelectedSite:", self.analytics_qml)
        self.assertIn("readonly property var switchOptionsForSelectedSite:", self.analytics_qml)
        self.assertIn("id: switchSiteDropdown", self.analytics_qml)
        self.assertIn("id: switchPickerDropdown", self.analytics_qml)
        self.assertIn('background: root.isLightTheme ? "#ffffff" : "#1e1e2e"', self.analytics_qml)
        self.assertIn('popupBorder: root.accent', self.analytics_qml)

    def test_switch_ports_tab_has_dense_port_matrix_layout(self) -> None:
        self.assertIn("id: portGrid", self.analytics_qml)
        self.assertIn("columns: 2", self.analytics_qml)
        self.assertIn("rowSpacing: Style.space(2)", self.analytics_qml)
        self.assertIn("height: Style.space(20)", self.analytics_qml)
        self.assertIn("height: Style.space(25)", self.analytics_qml)
        self.assertIn("Layout.preferredWidth: Style.space(32)", self.analytics_qml)
        self.assertIn("Layout.preferredHeight: Style.space(18)", self.analytics_qml)
        self.assertIn("Layout.preferredWidth: Style.space(48)", self.analytics_qml)

    def test_switch_ports_tab_cycle_button_has_tooltip(self) -> None:
        self.assertIn("visible: cycleBtnMouse.containsMouse && (modelData.poeMode !== \"off\" || modelData.poePower > 0)", self.analytics_qml)
        self.assertIn('text: "Power cycle PoE on Port " + modelData.portIdx', self.analytics_qml)

    def test_switch_ports_tab_has_chassis_jack_visualizer(self) -> None:
        self.assertIn("id: jackRowLayout", self.analytics_qml)
        self.assertIn("Physical RJ45 Faceplate Port Visualizer", self.analytics_qml)


class UiDimensionsAndDensityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.statblock_qml = (ROOT / "StatBlock.qml").read_text(encoding="utf-8")
        self.device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")

    def test_panel_width_matches_agent_hub(self) -> None:
        self.assertIn('setting("panelWidth", 450)', self.panel_qml)

    def test_panel_content_height_matches_dense_profile(self) -> None:
        self.assertIn("Math.min(Style.space(720), content.implicitHeight)", self.panel_qml)

    def test_tab_nav_matches_agent_hub_density(self) -> None:
        self.assertIn("height: Style.space(28)", self.panel_qml)

    def test_statblock_dimensions_match_agent_hub(self) -> None:
        self.assertIn("implicitHeight: Style.space(46)", self.statblock_qml)
        self.assertIn("font.pixelSize: 13", self.statblock_qml)

    def test_overview_globe_is_full_width_with_in_view_roster(self) -> None:
        self.assertIn("id: globeContainer", self.panel_qml)
        self.assertIn("height: Style.space(175)", self.panel_qml)
        self.assertIn("IN VIEW", self.panel_qml)

    def test_site_roster_has_compact_action_cluster(self) -> None:
        self.assertIn("id: siteCardSurface", self.panel_qml)
        self.assertIn("id: directSiteMouse", self.panel_qml)
        self.assertIn("id: sshBtnText", self.panel_qml)
        self.assertIn("id: pingBtnText", self.panel_qml)

    def test_device_inventory_uses_flickable_filter_bar(self) -> None:
        self.assertIn("id: catPillsRow", self.device_view_qml)


class GlobeSdwanFeatureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.globe_qml = (ROOT / "Globe.qml").read_text(encoding="utf-8")
        self.globe_model_js = (ROOT / "GlobeModel.js").read_text(encoding="utf-8")
        self.panel_qml = load_panel_qml()

    def test_globe_qml_exposes_connections_and_traffic_properties(self) -> None:
        self.assertIn("property var connections: []", self.globe_qml)
        self.assertIn("property var sdwan: null", self.globe_qml)
        self.assertIn("property bool animateTraffic: true", self.globe_qml)
        self.assertIn("property real flowProgress: 0.0", self.globe_qml)
        self.assertIn("property var preparedConnections: []", self.globe_qml)

    def test_globe_qml_implements_arc_rendering_and_traffic_pulses(self) -> None:
        self.assertIn("function prepareConnectionGeometry()", self.globe_qml)
        self.assertIn("function paintConnections(", self.globe_qml)
        self.assertIn("function drawTrafficPulse(", self.globe_qml)
        self.assertIn("id: flowAnimation", self.globe_qml)

    def test_panel_binds_connections_and_traffic_to_globe(self) -> None:
        self.assertIn("id: fleetGlobe", self.panel_qml)
        self.assertTrue(
            "connections: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections) ? root.fleetData.sdwan.connections : []" in self.panel_qml
            or "connections: (root.data && root.data.sdwan && root.data.sdwan.connections) ? root.data.sdwan.connections : []" in self.panel_qml
        )
        self.assertTrue(
            "sdwan: root.fleetData ? root.fleetData.sdwan : null" in self.panel_qml
            or "sdwan: root.data ? root.data.sdwan : null" in self.panel_qml
        )
        self.assertIn("animateTraffic: root.opened && root.activeTab === 0", self.panel_qml)

    def test_globe_model_has_spherical_arc_and_color_math(self) -> None:
        self.assertIn("function latLngToVector(", self.globe_model_js)
        self.assertIn("function angularDistance(", self.globe_model_js)
        self.assertIn("function interpolateArc(", self.globe_model_js)
        self.assertIn("function generateArcWaypoints(", self.globe_model_js)
        self.assertIn("function latencyColor(", self.globe_model_js)
        self.assertIn("function findSite(", self.globe_model_js)

    def test_demo_summary_sdwan_has_multi_site_connections_and_ping(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("sdwan", summary)
        sdwan = summary["sdwan"]
        connections = sdwan.get("connections", [])
        self.assertGreaterEqual(len(connections), 2)

        pings = [c.get("ping", 0) for c in connections]
        self.assertTrue(any(p < 35 for p in pings))  # healthy/fast (<35ms)
        self.assertTrue(any(p >= 35 for p in pings))  # moderate/backup (>=35ms)

        for conn in connections:
            self.assertIn("siteA", conn)
            self.assertIn("siteB", conn)
            self.assertIn("ping", conn)
            self.assertIn("connected", conn)

    def test_get_sdwan_telemetry_resolves_devices_and_site_ids(self) -> None:
        from unittest.mock import patch
        from typing import Any

        def mock_cloud_json(key: str, path: str, method: str = "GET", payload: Any = None):
            if path == "/v1/sd-wan-configs":
                return 200, {"data": [{"id": "cfg-123", "name": "Site Magic", "type": "s2s-vpn"}]}
            if path == "/v1/sd-wan-configs/cfg-123":
                return 200, {
                    "data": {
                        "id": "cfg-123",
                        "devices": [
                            {
                                "hostId": "host-1",
                                "deviceName": "Catalyse Office",
                                "sites": [{"siteId": "site-1", "siteName": "Default", "networks": [{"subnet": "192.168.1.0/24"}]}]
                            },
                            {
                                "hostId": "host-2",
                                "deviceName": "Lough Stanley Home",
                                "sites": [{"siteId": "site-2", "siteName": "Default", "networks": [{"subnet": "192.168.2.0/24"}]}]
                            }
                        ]
                    }
                }
            if path == "/v1/sd-wan-configs/cfg-123/status":
                return 200, {
                    "data": {
                        "status": {
                            "connections": [
                                {
                                    "sites": [
                                        {"hostId": "host-1", "siteId": "site-1", "status": {"connected": True, "ping": 12}},
                                        {"hostId": "host-2", "siteId": "site-2", "status": {"connected": True, "ping": 12}}
                                    ]
                                }
                            ]
                        }
                    }
                }
            return 404, {}

        sites = [
            {"id": "site-1", "hostId": "host-1", "name": "Catalyse Office"},
            {"id": "site-2", "hostId": "host-2", "name": "Lough Stanley Home"},
        ]
        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_json):
            sdwan = SITE_THREAD.get_sdwan_telemetry("test_key", sites=sites)
            self.assertTrue(sdwan["available"])
            self.assertEqual(sdwan["status"], "connected")
            self.assertEqual(len(sdwan["connections"]), 1)
            conn = sdwan["connections"][0]
            self.assertEqual(conn["siteA"], "Catalyse Office")
            self.assertEqual(conn["siteB"], "Lough Stanley Home")
            self.assertEqual(conn["siteIdA"], "site-1")
            self.assertEqual(conn["siteIdB"], "site-2")
            self.assertEqual(conn["subnetA"], "192.168.1.0/24")
            self.assertEqual(conn["subnetB"], "192.168.2.0/24")
            self.assertTrue(conn["connected"])
            self.assertEqual(conn["ping"], 12)


class GlobeZoomFeatureTests(unittest.TestCase):
    def setUp(self) -> None:
        self.globe_qml = (ROOT / "Globe.qml").read_text(encoding="utf-8")
        self.panel_qml = load_panel_qml()

    def test_globe_scale_range_allows_deep_zoom(self) -> None:
        self.assertIn("property real maximumScale: 160.0", self.globe_qml)
        self.assertIn("property real minimumScale: 0.5", self.globe_qml)

    def test_globe_exposes_zoom_methods(self) -> None:
        self.assertIn("function zoomIn()", self.globe_qml)
        self.assertIn("function zoomOut()", self.globe_qml)
        self.assertIn("function resetZoom()", self.globe_qml)

    def test_globe_mouse_area_has_wheel_and_double_click_zoom(self) -> None:
        self.assertIn("onWheel: function(wheel)", self.globe_qml)
        self.assertIn("onDoubleClicked: function(mouse)", self.globe_qml)
        self.assertIn("root.zoomIn()", self.globe_qml)

    def test_panel_has_zoom_buttons_and_ipc_methods(self) -> None:
        self.assertIn("id: zoomInMouse", self.panel_qml)
        self.assertIn("id: zoomOutMouse", self.panel_qml)
        self.assertIn("function zoomIn(): void", self.panel_qml)
        self.assertIn("function zoomOut(): void", self.panel_qml)
        self.assertIn("function setGlobeScale(scale: real): void", self.panel_qml)
        self.assertIn("function globeScaleValue(): real", self.panel_qml)

    def test_globe_drag_sensitivity_is_fast(self) -> None:
        self.assertIn("property real longitudeSensitivity: 0.65", self.globe_qml)
        self.assertIn("property real latitudeSensitivity: 0.55", self.globe_qml)


class SiteCachingAndPrefetchTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()

    def test_site_cache_path_generation(self) -> None:
        path = SITE_THREAD.site_cache_path("console:123", "site/home")
        self.assertTrue(path.name.startswith("site_console_123_site_home"))
        self.assertTrue(path.name.endswith(".json"))

    def test_save_and_read_site_cache(self) -> None:
        test_payload = {
            "ok": True,
            "connected": True,
            "siteId": "test-site",
            "hostId": "test-host",
            "network": {"deviceCount": 5},
        }
        SITE_THREAD.save_site_cache("test-host", "test-site", test_payload)

        cached = SITE_THREAD.read_site_cache("test-host", "test-site")
        self.assertIsNotNone(cached)
        self.assertTrue(cached.get("_cached"))
        self.assertIn("cachedAt", cached)
        self.assertEqual(cached.get("siteId"), "test-site")
        self.assertEqual(cached.get("network", {}).get("deviceCount"), 5)

    def test_read_site_cache_ttl_expiration(self) -> None:
        test_payload = {"ok": True, "siteId": "exp-site"}
        SITE_THREAD.save_site_cache("exp-host", "exp-site", test_payload)

        # Fresh cache (< 600s) is valid
        self.assertIsNotNone(SITE_THREAD.read_site_cache("exp-host", "exp-site", max_age=600))
        # Zero max_age simulates expired cache
        self.assertIsNone(SITE_THREAD.read_site_cache("exp-host", "exp-site", max_age=0))

    def test_demo_site_generation(self) -> None:
        site = SITE_THREAD.demo_site("console-home", "home")
        self.assertTrue(site.get("ok"))
        self.assertTrue(site.get("demo"))
        self.assertEqual(site.get("siteId"), "home")
        self.assertIn("network", site)
        self.assertIn("protect", site)
        self.assertIn("console", site)
        self.assertGreaterEqual(len(site["network"]["devices"]), 1)

    def test_panel_has_prefetch_timer_and_cached_proc(self) -> None:
        self.assertIn("id: prefetchTimer", self.panel_qml)
        self.assertIn("interval: 600000", self.panel_qml)
        self.assertIn("root.prefetchSites()", self.panel_qml)
        self.assertIn("id: prefetchProc", self.panel_qml)
        self.assertIn("prefetch-sites", self.panel_qml)

        self.assertIn("id: siteCachedProc", self.panel_qml)
        self.assertIn("--cached-only", self.panel_qml)
        self.assertIn("--live", self.panel_qml)
        self.assertIn("property bool siteLiveRefreshing: false", self.panel_qml)


class MergedSitesAndDevicesTabTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()

    def test_top_navigation_has_four_tabs_without_standalone_devices(self) -> None:
        self.assertIn('{ id: 0, label: "Overview"', self.panel_qml)
        self.assertIn('{ id: 1, label: root.cloudMode ? "Sites', self.panel_qml)
        self.assertIn('{ id: 2, label: "Issues (', self.panel_qml)
        self.assertIn('{ id: 3, label: "Protect (', self.panel_qml)
        self.assertNotIn('{ id: 2, label: "Devices', self.panel_qml)

    def test_sites_tab_has_subview_toggle_and_merges_device_inventory(self) -> None:
        self.assertIn('property string sitesSubView: "sites"', self.panel_qml)
        self.assertIn('id: sitesSubPillText', self.panel_qml)
        self.assertIn('id: devSubPillText', self.panel_qml)
        self.assertIn('visible: root.sitesSubView === "sites"', self.panel_qml)
        self.assertIn('visible: root.sitesSubView === "devices"', self.panel_qml)
        self.assertIn('DeviceInventoryView {', self.panel_qml)

    def test_overview_statblocks_route_to_merged_sites_and_devices(self) -> None:
        self.assertIn('root.activeTab = 1; root.sitesSubView = "sites";', self.panel_qml)
        self.assertIn('root.activeTab = 1; root.sitesSubView = "devices";', self.panel_qml)

    def test_ipc_supports_four_tabs_and_sites_subview(self) -> None:
        self.assertIn("root.activeTab = Math.max(0, Math.min(3, index))", self.panel_qml)
        self.assertIn("function setSitesSubView(view: string): void", self.panel_qml)
        self.assertIn("sitesSubView: root.sitesSubView,", self.panel_qml)

    def test_site_row_receives_model_data_and_has_clickable_surface(self) -> None:
        sites_qml = (ROOT / "views" / "SitesView.qml").read_text(encoding="utf-8")
        siterow_qml = (ROOT / "components" / "SiteRow.qml").read_text(encoding="utf-8")
        self.assertIn("delegate: SiteRow", sites_qml)
        self.assertIn("required property var modelData", siterow_qml)
        self.assertIn("height: implicitHeight", siterow_qml)
        self.assertIn("hoverEnabled: true", siterow_qml)
        self.assertIn("onClicked: siteCardSurface.siteClicked", siterow_qml)


class ActionButtonSizingAndOverlapTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")
        self.topology_qml = (ROOT / "TopologyTreeView.qml").read_text(encoding="utf-8")
        self.analytics_qml = load_analytics_qml()

    def test_sdwan_banner_action_button_and_row_layout(self) -> None:
        self.assertIn("id: sdwanRow", self.panel_qml)
        self.assertIn("id: sdwanBtnRow", self.panel_qml)
        self.assertIn("implicitWidth: sdwanBtnRow.implicitWidth + Style.space(14)", self.panel_qml)

    def test_device_inventory_action_buttons_sizing_and_no_overlap(self) -> None:
        self.assertIn("implicitWidth: sshBtnRow.implicitWidth + Style.space(12)", self.device_view_qml)
        self.assertIn("implicitWidth: pingBtnRow.implicitWidth + Style.space(12)", self.device_view_qml)
        self.assertIn("implicitWidth: webBtnRow.implicitWidth + Style.space(12)", self.device_view_qml)
        self.assertIn('text: "IP: "', self.device_view_qml)
        self.assertIn("elide: Text.ElideRight", self.device_view_qml)

    def test_site_cards_action_buttons_padding(self) -> None:
        self.assertIn("implicitWidth: sshBtnText.implicitWidth + Style.space(14)", self.panel_qml)
        self.assertIn("implicitWidth: pingBtnText.implicitWidth + Style.space(14)", self.panel_qml)

    def test_topology_tree_action_buttons_sizing(self) -> None:
        self.assertIn("implicitWidth: gwSshRow.implicitWidth + Style.space(12)", self.topology_qml)
        self.assertIn("implicitWidth: t1ActionRow.implicitWidth + Style.space(10)", self.topology_qml)


class ActionButtonToolTipTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")
        self.topology_qml = (ROOT / "TopologyTreeView.qml").read_text(encoding="utf-8")

    def test_sdwan_banner_mesh_button_has_tooltip(self) -> None:
        self.assertIn("id: sdwanBtnMouse", self.panel_qml)
        self.assertIn("visible: sdwanBtnMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Open SD-WAN Site Magic mesh topology and analytics"', self.panel_qml)

    def test_subview_toggle_pills_have_tooltips(self) -> None:
        self.assertIn("visible: subSitesMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "View fleet sites and SD-WAN mesh connections"', self.panel_qml)
        self.assertIn("visible: subDevMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "View all network hardware devices across fleet"', self.panel_qml)

    def test_site_cards_actions_have_tooltips(self) -> None:
        self.assertIn("visible: directSiteMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Direct P2P connect to UniFi OS console"', self.panel_qml)
        self.assertIn("visible: sshMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Open SSH terminal to gateway (" + siteCardSurface.modelData.gatewayIp + ")"', self.panel_qml)
        self.assertIn("visible: pingMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Ping gateway (" + siteCardSurface.modelData.gatewayIp + ")"', self.panel_qml)

    def test_insite_direct_connect_buttons_have_tooltips(self) -> None:
        self.assertIn("visible: directBtnMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Launch direct P2P console connection"', self.panel_qml)
        self.assertIn("visible: directHubMouse.containsMouse", self.panel_qml)
        self.assertIn('text: "Open UniFi OS applications hub"', self.panel_qml)

    def test_device_inventory_buttons_have_tooltips(self) -> None:
        self.assertIn("visible: catMouse.containsMouse", self.device_view_qml)
        self.assertIn("visible: sshMouse.containsMouse", self.device_view_qml)
        self.assertIn('text: "Open SSH terminal session (" + modelData.ip + ")"', self.device_view_qml)
        self.assertIn("visible: pingMouse.containsMouse", self.device_view_qml)
        self.assertIn('text: "Send ICMP ping to " + modelData.ip', self.device_view_qml)
        self.assertIn("visible: webMouse.containsMouse", self.device_view_qml)
        self.assertIn('text: "Open device web management page (https://" + modelData.ip + ")"', self.device_view_qml)

    def test_topology_tree_buttons_have_tooltips(self) -> None:
        self.assertIn("visible: gwSshMouse.containsMouse", self.topology_qml)
        self.assertIn('text: "Open SSH terminal to gateway (" + (gwCard.gw ? gwCard.gw.ip : "") + ")"', self.topology_qml)
        self.assertIn("visible: t1ActionMouse.containsMouse", self.topology_qml)
        self.assertIn('text: root.isSwitch(modelData) ? ("Open SSH session to switch (" + modelData.ip + ")") : ("Ping device (" + modelData.ip + ")")', self.topology_qml)
        self.assertIn("visible: t2PingMouse.containsMouse", self.topology_qml)
        self.assertIn('text: "Ping device (" + modelData.ip + ")"', self.topology_qml)


class AttentionSectionLayoutTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()

    def test_attention_required_card_uses_row_layout_with_clean_fit(self) -> None:
        self.assertIn("id: activeIssueRow", self.panel_qml)
        import re
        self.assertTrue(re.search(r"RowLayout\s*\{\s*id:\s*activeIssueRow", self.panel_qml))
        self.assertIn("Layout.fillWidth: true", self.panel_qml)
        self.assertIn("Layout.minimumWidth: 0", self.panel_qml)
        self.assertIn("elide: Text.ElideRight", self.panel_qml)

    def test_active_pill_has_explicit_preferred_sizing(self) -> None:
        self.assertIn("id: activeIssuePill", self.panel_qml)
        self.assertIn("implicitWidth: activePillLabel.implicitWidth + Style.space(12)", self.panel_qml)
        self.assertIn("Layout.preferredWidth: activePillLabel.implicitWidth + Style.space(12)", self.panel_qml)
        self.assertIn('text: "ACTIVE"', self.panel_qml)

    def test_active_issue_card_has_hover_and_navigation(self) -> None:
        self.assertIn("id: activeIssueMouse", self.panel_qml)
        self.assertIn("color: activeIssueMouse.containsMouse ? root.cardHover : root.card", self.panel_qml)
        self.assertIn("onClicked: root.activeTab = 2", self.panel_qml)


class WiFiAndRfSpectrumTests(unittest.TestCase):
    def setUp(self) -> None:
        self.analytics_qml = load_analytics_qml()

    def test_demo_summary_has_wlans_and_spectrum(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("wlans", summary)
        self.assertIn("spectrum", summary)
        wlans = summary["wlans"]
        spectrum = summary["spectrum"]
        self.assertGreaterEqual(len(wlans), 3)
        for wlan in wlans:
            self.assertIn("id", wlan)
            self.assertIn("name", wlan)
            self.assertIn("security", wlan)
            self.assertIn("bands", wlan)
            self.assertIn("vlan", wlan)
            self.assertIn("clientCount", wlan)
            self.assertIn("passphrase", wlan)
            self.assertIn("qrCode", wlan)
            self.assertTrue(wlan["qrCode"].startswith("WIFI:S:"))

        self.assertIn("bands", spectrum)
        bands_list = spectrum["bands"]
        self.assertGreaterEqual(len(bands_list), 3)
        bands = [s.get("band") for s in bands_list]
        self.assertIn("2.4 GHz", bands)
        self.assertIn("5 GHz", bands)
        self.assertIn("6 GHz", bands)
        for band_info in bands_list:
            self.assertIn("utilization", band_info)
            self.assertIn("noiseFloor", band_info)
            self.assertIn("interference", band_info)
            self.assertIn("channels", band_info)

    def test_analytics_window_wifi_rf_spectrum_tab_and_state(self) -> None:
        self.assertIn('"WiFi & RF Spectrum ("', self.analytics_qml)
        self.assertIn("id: tab5View", self.analytics_qml)
        self.assertIn("property var fleetWlans:", self.analytics_qml)
        self.assertIn("property var fleetSpectrum:", self.analytics_qml)
        self.assertIn("property string wlanSearch:", self.analytics_qml)
        self.assertIn("property string wlanSiteFilter:", self.analytics_qml)
        self.assertIn("property var selectedWlanForQr:", self.analytics_qml)
        self.assertIn("property bool showQrModal:", self.analytics_qml)
        self.assertIn("id: qrCanvas", self.analytics_qml)
        self.assertIn("WiFi password", self.analytics_qml)

    def test_panel_overview_has_wifi_spectrum_card(self) -> None:
        panel_qml = load_panel_qml()
        self.assertIn("id: wifiSpectrumCard", panel_qml)
        self.assertIn("WIFI & RF SPECTRUM HEALTH", panel_qml)
        self.assertIn("root.openAnalytics(5)", panel_qml)


class LinuxDesktopIntegrationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.settings_qml = (ROOT / "SettingsView.qml").read_text(encoding="utf-8")

    def test_panel_has_notifications_and_settings(self) -> None:
        self.assertIn("property bool enableNotifications:", self.panel_qml)
        self.assertIn("function sendDesktopNotification(title, message, urgency)", self.panel_qml)
        self.assertIn("function testNotification()", self.panel_qml)
        self.assertIn('Quickshell.execDetached(["notify-send", "--app-name=UniFi SiteThread"', self.panel_qml)
        self.assertIn("function notify(title: string, message: string, urgency: string): void", self.panel_qml)

    def test_panel_updates_badge_mode(self) -> None:
        self.assertIn('else if (root.badgeMode === "updates")', self.panel_qml)
        self.assertIn("root.data.network.updateCount", self.panel_qml)

    def test_settings_view_has_notification_toggle_and_test_button(self) -> None:
        self.assertIn("signal testNotifyRequested()", self.settings_qml)
        self.assertIn("LINUX DESKTOP & NOTIFICATIONS", self.settings_qml)
        self.assertIn("Notifications: Enabled", self.settings_qml)
        self.assertIn("Send Test Notification", self.settings_qml)
        self.assertIn('"updates"', self.settings_qml)

    def test_site_thread_notify_command(self) -> None:
        import io
        from contextlib import redirect_stdout
        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_notify("Test Alert", "Unit test alert body", "normal")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("Desktop notification sent", res.get("message", ""))


class FirmwareLifecycleManagementTests(unittest.TestCase):
    def setUp(self) -> None:
        self.analytics_qml = load_analytics_qml()
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
        self.orig_cache = SITE_THREAD.CACHE_DIR
        self.orig_recent = SITE_THREAD.RECENT_OPS_FILE
        self.orig_history = SITE_THREAD.OPERATIONS_HISTORY_FILE
        self.orig_names = SITE_THREAD.DEVICE_NAMES_FILE
        SITE_THREAD.CACHE_DIR = self.temp_path
        SITE_THREAD.RECENT_OPS_FILE = self.temp_path / "recent_operations.json"
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.temp_path / "operations_history.json"
        SITE_THREAD.DEVICE_NAMES_FILE = self.temp_path / "device_names.json"

    def tearDown(self) -> None:
        SITE_THREAD.CACHE_DIR = self.orig_cache
        SITE_THREAD.RECENT_OPS_FILE = self.orig_recent
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.orig_history
        SITE_THREAD.DEVICE_NAMES_FILE = self.orig_names
        self.temp_dir.cleanup()

    def test_demo_summary_has_firmware_updates_and_backups(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("firmwareUpdates", summary)
        self.assertIn("backups", summary)
        updates = summary["firmwareUpdates"]
        backups = summary["backups"]
        self.assertGreaterEqual(len(updates), 2)
        for u in updates:
            self.assertIn("deviceId", u)
            self.assertIn("name", u)
            self.assertIn("model", u)
            self.assertIn("currentVersion", u)
            self.assertIn("targetVersion", u)
            self.assertIn("severity", u)
            self.assertIn("releaseNotes", u)

        self.assertGreaterEqual(len(backups), 2)
        for b in backups:
            self.assertIn("siteName", b)
            self.assertIn("hostId", b)
            self.assertIn("lastBackup", b)
            self.assertIn("status", b)

    def test_bin_site_thread_upgrade_and_backup_commands(self) -> None:
        import io
        from contextlib import redirect_stdout

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_upgrade_device("console-1", "00:11:22:33:44:55")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertTrue(res.get("accepted"))
        self.assertIn("Upgrade request accepted", res.get("message", ""))

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_upgrade_all("all")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertTrue(res.get("accepted"))
        self.assertIn("Upgrade batch request accepted", res.get("message", ""))

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_backup("console-1")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertTrue(res.get("accepted"))
        self.assertIn("Backup request accepted", res.get("message", ""))

    def test_backup_command_rejects_on_api_error(self) -> None:
        import io
        from contextlib import redirect_stdout
        from unittest.mock import patch

        # Non-demo cloud mode with rejected response (HTTP 400)
        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "cloud", "demo": False}):
            with patch.object(SITE_THREAD, "secret_lookup", return_value="dummy_key_12345678"):
                with patch.object(SITE_THREAD, "cloud_json_request", return_value=(400, {"message": "Storage quota exceeded"})):
                    out = io.StringIO()
                    with redirect_stdout(out):
                        with self.assertRaises(SystemExit) as cm:
                            SITE_THREAD.command_backup("A89C6C0623CC0000000009F79A87000000000A8619A40000000069C30A3F:861783942")
                        self.assertEqual(cm.exception.code, 1)
                    res = json.loads(out.getvalue())
                    self.assertFalse(res.get("ok"))
                    self.assertIn("Backup request rejected", res.get("error", ""))
                    self.assertIn("Storage quota exceeded", res.get("error", ""))

        # Non-demo local mode with rejected response (HTTP 500)
        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "local", "host": "https://192.168.1.1", "demo": False}):
            with patch.object(SITE_THREAD, "secret_lookup", return_value="dummy_key_12345678"):
                with patch.object(SITE_THREAD, "api_request", return_value=(500, "Internal Server Error")):
                    out = io.StringIO()
                    with redirect_stdout(out):
                        with self.assertRaises(SystemExit) as cm:
                            SITE_THREAD.command_backup("local-host-id")
                        self.assertEqual(cm.exception.code, 1)
                    res = json.loads(out.getvalue())
                    self.assertFalse(res.get("ok"))
                    self.assertIn("Backup request rejected", res.get("error", ""))

    def test_upgrade_and_backup_status_surfaced_on_refresh(self) -> None:
        # Trigger accepted backup in demo mode
        SITE_THREAD.record_backup_request("console-home")
        backups = SITE_THREAD.get_default_backups()
        home_bk = next(b for b in backups if b["hostId"] == "console-home")
        self.assertEqual(home_bk["status"], "in_progress")
        self.assertIn("Request accepted", home_bk["lastBackup"])

        # Trigger accepted upgrade in demo mode
        SITE_THREAD.record_upgrade_request("74:83:c2:22:33:44")
        updates = SITE_THREAD.get_default_firmware_updates()
        switch_up = next(u for u in updates if u["mac"] == "74:83:c2:22:33:44")
        self.assertTrue(switch_up["upgrading"])
        self.assertEqual(switch_up["status"], "upgrading")
        self.assertTrue(switch_up["requestAccepted"])

    def test_analytics_window_firmware_tab_and_processes(self) -> None:
        self.assertIn('"Firmware & Backups ("', self.analytics_qml)
        self.assertIn("id: tab6View", self.analytics_qml)
        self.assertIn("property var fleetUpdates:", self.analytics_qml)
        self.assertIn("property var fleetBackups:", self.analytics_qml)
        self.assertIn("id: upgradeDevProc", self.analytics_qml)
        self.assertIn("id: upgradeAllProc", self.analytics_qml)
        self.assertIn("id: backupProc", self.analytics_qml)
        self.assertIn("property bool bulkUpdateConfirm:", self.analytics_qml)
        self.assertIn("Update All Devices", self.analytics_qml)
        self.assertIn("Create Backup Now", self.analytics_qml)

    def test_panel_overview_has_firmware_card(self) -> None:
        panel_qml = load_panel_qml()
        self.assertIn("id: firmwareCard", panel_qml)
        self.assertIn("FLEET FIRMWARE & BACKUPS", panel_qml)
        self.assertIn("root.openAnalytics(6)", panel_qml)

    def test_analytics_window_refresh_button_and_connections(self) -> None:
        panel_qml = load_panel_qml()
        self.assertIn("signal refreshRequested()", self.analytics_qml)
        self.assertIn("property bool isRefreshing: false", self.analytics_qml)
        self.assertIn("id: refBtn", self.analytics_qml)
        self.assertIn("id: refBtnIcon", self.analytics_qml)
        self.assertIn("Refresh fleet telemetry & analytics", self.analytics_qml)
        self.assertIn("item.refreshRequested.connect", panel_qml)
        self.assertIn("item.isRefreshing = Qt.binding", panel_qml)

    def test_open_telemetry_analytics_opens_to_overview_tab(self) -> None:
        panel_qml = load_panel_qml()
        self.assertIn("targetTab = (tabIndex !== undefined && tabIndex !== null) ? Math.max(0, Math.min(6, tabIndex)) : 0", panel_qml)
        self.assertIn("root.analyticsTab = 0", panel_qml)
        self.assertIn("analyticsWindowLoader.item.currentTab = 0", panel_qml)
        self.assertIn("Open telemetry & analytics", panel_qml)
        self.assertIn("onClicked: root.openAnalytics(0)", panel_qml)

    def test_real_extraction_functions_exist_and_behave_correctly(self) -> None:
        self.assertTrue(hasattr(SITE_THREAD, "extract_real_wlans"))
        self.assertTrue(hasattr(SITE_THREAD, "extract_real_spectrum"))
        self.assertTrue(hasattr(SITE_THREAD, "extract_real_firmware_updates"))
        self.assertTrue(hasattr(SITE_THREAD, "extract_real_backups"))

        # Empty inputs return expected empty structures
        self.assertEqual(SITE_THREAD.extract_real_wlans({}, {}, {}, {}), [])
        empty_spec = SITE_THREAD.extract_real_spectrum({}, {}, {})
        self.assertIn("autoRf", empty_spec)
        self.assertIn("bands", empty_spec)
        self.assertEqual(empty_spec["accessPoints"], [])
        self.assertEqual(SITE_THREAD.extract_real_firmware_updates([], [], {}), [])
        self.assertEqual(SITE_THREAD.extract_real_backups([], {}), [])

    def test_tab6_empty_state_and_tab5_site_filter(self) -> None:
        self.assertIn("All fleet hardware devices are up to date on official firmware", self.analytics_qml)
        self.assertIn("tab5View.siteFilterOptions", self.analytics_qml)
        self.assertIn("All Devices Up to Date", self.analytics_qml)
        self.assertIn("id: wifiSiteDropdown", self.analytics_qml)
        self.assertIn('placeholderText: "Search sites..."', self.analytics_qml)
        self.assertIn("value: root.wlanSiteFilter", self.analytics_qml)

    def test_diagnose_command_and_qml_observability(self) -> None:
        self.assertTrue(hasattr(SITE_THREAD, "command_diagnose"))
        panel_qml = load_panel_qml()
        settings_qml = (ROOT / "SettingsView.qml").read_text(encoding="utf-8")
        self.assertIn("id: diagProc", panel_qml)
        self.assertIn("id: summaryStderr", panel_qml)
        self.assertIn("function runDiagnostics()", panel_qml)
        self.assertIn("diagnostics: root.diagnosticsData", panel_qml)
        self.assertIn("SYSTEM HEALTH & DIAGNOSTICS", settings_qml)
        self.assertIn("Self-Test", settings_qml)
        self.assertIn("Cache Health:", settings_qml)

        import subprocess
        res = subprocess.run(
            [str(ROOT / "bin" / "site-thread"), "diagnose"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(res.stdout)
        self.assertTrue(data.get("ok"))
        self.assertIn("apiReachable", data)
        self.assertIn("cacheDir", data)
        self.assertIn("cachedSites", data)
        self.assertIn("scope", data)
        self.assertIn("operations", data)
        self.assertIn("diagAgeSec", settings_qml)
        self.assertIn("STALE (> 2m)", settings_qml)
        self.assertIn("RECENT OPERATIONS & ACTION OUTCOMES", settings_qml)

    def test_operations_history_tracking_and_lifecycle(self) -> None:
        import io
        from contextlib import redirect_stdout
        import subprocess

        # Test CLI operations command
        res = subprocess.run(
            [str(ROOT / "bin" / "site-thread"), "operations"],
            capture_output=True,
            text=True,
            check=True,
        )
        data = json.loads(res.stdout)
        self.assertTrue(data.get("ok"))
        self.assertIn("operations", data)

        # Test record_operation directly
        op = SITE_THREAD.record_operation(
            "upgrade",
            "74:83:c2:55:66:77",
            "accepted",
            "Upgrade request accepted for device 74:83:c2:55:66:77.",
        )
        self.assertEqual(op["status"], "accepted")
        self.assertEqual(op["type"], "upgrade")

        # Test PoE power-cycle request output
        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_power_cycle("console-home", "74:83:c2:22:33:44", 4)
            self.assertEqual(cm.exception.code, 0)
        p_res = json.loads(out.getvalue())
        self.assertTrue(p_res.get("ok"))
        self.assertTrue(p_res.get("accepted"))
        self.assertIn("Port restarting; link status updates on refresh", p_res.get("message", ""))

    def test_action_observability_and_non_generic_toasts(self) -> None:
        analytics_qml = load_analytics_qml()
        self.assertIn("pendingCycleTarget", analytics_qml)
        self.assertIn("pendingPingTarget", analytics_qml)
        self.assertIn("pendingUpgradeDeviceTarget", analytics_qml)
        self.assertIn("pendingBackupConsoleTarget", analytics_qml)
        self.assertIn("Submitting PoE power cycle request for ", analytics_qml)
        self.assertIn("PoE power cycle request accepted for ", analytics_qml)
        self.assertIn("Port restarting; link status updates on refresh", analytics_qml)
        self.assertIn("Submitting upgrade request for ", analytics_qml)
        self.assertIn("Submitting fleet upgrade batch request for ", analytics_qml)
        self.assertIn("Submitting backup request for console: ", analytics_qml)
        self.assertIn("Pinging target host ", analytics_qml)
        self.assertIn("RECENT OPERATIONS & ACTION OUTCOMES", analytics_qml)

    def test_reusable_components_and_schema_alignment(self) -> None:
        search_qml = (ROOT / "SearchField.qml").read_text(encoding="utf-8")
        toast_qml = (ROOT / "StatusToast.qml").read_text(encoding="utf-8")
        manifest_raw = (ROOT / "manifest.json").read_text(encoding="utf-8")
        manifest = json.loads(manifest_raw)

        self.assertIn("property alias text: input.text", search_qml)
        self.assertIn("property string placeholderText:", search_qml)
        self.assertIn("signal cleared()", search_qml)

        self.assertIn("property string message:", toast_qml)
        self.assertIn("property string toastType:", toast_qml)

        self.assertIn("SearchField {", self.analytics_qml)
        self.assertIn("StatusToast {", self.analytics_qml)

        schema = manifest["barWidget"]["schema"]
        refresh_field = next(f for f in schema if f["key"] == "refreshSeconds")
        self.assertEqual(refresh_field["min"], 15)
        self.assertEqual(refresh_field["max"], 300)
        self.assertEqual(refresh_field["step"], 15)

        badge_field = next(f for f in schema if f["key"] == "badgeMode")
        self.assertIn("updates", badge_field["options"])

    def test_extracted_views_and_navigation_integrity(self) -> None:
        # 1. FirmwareTab signal and scoping integrity
        fw_tab = (ROOT / "views" / "analytics" / "FirmwareTab.qml").read_text(encoding="utf-8")
        self.assertNotIn("signal bulkUpdateConfirmChanged", fw_tab)
        self.assertIn("updateBtnRect.isPending", fw_tab)
        self.assertIn("createBkBtnRect.isPending", fw_tab)
        self.assertIn('import "../.."', fw_tab)

        # 2. AnalyticsWindow superclass signals and reset behavior
        analytics = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")
        self.assertNotIn("signal closed()", analytics)
        self.assertIn("root.currentTab = 0", analytics)

        # 3. All 7 analytics tabs import root properly
        for tab_name in [
            "OverviewTab.qml",
            "ClientsTab.qml",
            "WanTab.qml",
            "SwitchesTab.qml",
            "ConsolesTab.qml",
            "WifiTab.qml",
            "FirmwareTab.qml",
        ]:
            tab_path = ROOT / "views" / "analytics" / tab_name
            self.assertTrue(tab_path.exists(), f"{tab_name} missing")
            content = tab_path.read_text(encoding="utf-8")
            self.assertIn('import "../.."', content, f"{tab_name} missing root import")

        # 4. FilterBar doesn't override property change signals
        filter_bar = (ROOT / "components" / "FilterBar.qml").read_text(encoding="utf-8")
        self.assertNotIn("signal selectedChanged", filter_bar)
        self.assertIn("signal filterSelected", filter_bar)

        # 5. Core panel views exist
        for view_name in [
            "OverviewView.qml",
            "SitesView.qml",
            "IssuesView.qml",
            "ProtectView.qml",
        ]:
            self.assertTrue((ROOT / "views" / view_name).exists(), f"{view_name} missing")

    def test_extract_real_firmware_updates_identifies_unas_pro_4_and_ignores_up_to_date(self) -> None:
        flattened = [
            {"id": "d1", "mac": "11:22:33:44:55:01", "name": "Living Room", "model": "Nano HD", "version": "6.7.57", "firmwareStatus": "upToDate", "updateAvailable": ""},
            {"id": "d2", "mac": "11:22:33:44:55:02", "name": "Study", "model": "Nano HD", "version": "6.7.57", "firmwareStatus": "upToDate", "updateAvailable": ""},
            {"id": "d3", "mac": "11:22:33:44:55:03", "name": "USW Pro 48 PoE", "model": "USW Pro 48 PoE", "version": "7.5.15", "firmwareStatus": "upToDate", "updateAvailable": ""},
            {"id": "d4", "mac": "A89C6C0623CC", "name": "Catalyse Office - UNAS Pro 4", "model": "UNAS Pro 4", "version": "5.1.33", "firmwareStatus": "updateAvailable", "updateAvailable": "6.0.11+f63375a", "isConsole": True},
        ]
        raw_hosts = [
            {"id": "h1", "reportedState": {"name": "Catalyse Office", "version": "5.1.132", "firmwareUpdate": {"latestAvailableVersion": None}, "hardware": {"mac": "0CEA14F780D5"}}},
            {"id": "h2", "reportedState": {"name": "Lough Stanley Home", "version": "5.1.132", "firmwareUpdate": {"latestAvailableVersion": None}, "hardware": {"mac": "58D61F3DE4BF"}}},
            {"id": "h3", "reportedState": {"name": "Catalyse Office - UNAS Pro 4", "version": "5.1.132", "firmwareUpdate": {"latestAvailableVersion": "6.0.11+f63375a"}, "hardware": {"mac": "A89C6C0623CC"}}},
        ]
        site_map = {"h1": "Catalyse Office", "h2": "Lough Stanley Home", "h3": "Catalyse Office"}

        updates = SITE_THREAD.extract_real_firmware_updates(raw_hosts, flattened, site_map)
        self.assertEqual(len(updates), 1)
        self.assertEqual(updates[0]["name"], "Catalyse Office - UNAS Pro 4")
        self.assertEqual(updates[0]["targetVersion"], "6.0.11+f63375a")
        self.assertEqual(updates[0]["status"], "update_available")
        self.assertEqual(updates[0]["category"], "gateways")
        self.assertEqual(updates[0]["severity"], "critical")

    def test_extract_real_firmware_updates_batch_upgrade_only_targets_upgradable(self) -> None:
        SITE_THREAD.record_upgrade_request("all")

        flattened = [
            {"id": "d1", "mac": "11:22:33:44:55:01", "name": "Living Room", "model": "Nano HD", "version": "6.7.57", "firmwareStatus": "upToDate", "updateAvailable": ""},
            {"id": "d4", "mac": "A89C6C0623CC", "name": "Catalyse Office - UNAS Pro 4", "model": "UNAS Pro 4", "version": "5.1.33", "firmwareStatus": "updateAvailable", "updateAvailable": "6.0.11+f63375a", "isConsole": True},
        ]
        raw_hosts = [
            {"id": "h1", "reportedState": {"name": "Catalyse Office", "version": "5.1.132", "firmwareUpdate": {"latestAvailableVersion": None}, "hardware": {"mac": "0CEA14F780D5"}}},
        ]
        site_map = {"h1": "Catalyse Office"}

        updates = SITE_THREAD.extract_real_firmware_updates(raw_hosts, flattened, site_map)
        self.assertEqual(len(updates), 1)
        self.assertEqual(updates[0]["name"], "Catalyse Office - UNAS Pro 4")
        self.assertTrue(updates[0]["upgrading"])
        self.assertEqual(updates[0]["status"], "upgrading")

    def test_extract_real_firmware_updates_device_does_not_suppress_console_os_update(self) -> None:
        flattened = [
            {
                "id": "dev_switch_1",
                "hostId": "h_console_1",
                "mac": "11:22:33:44:55:01",
                "name": "USW Pro 48 PoE",
                "model": "USW Pro 48 PoE",
                "version": "7.5.15",
                "firmwareStatus": "updateAvailable",
                "updateAvailable": "7.5.20",
            },
        ]
        raw_hosts = [
            {
                "id": "h_console_1",
                "reportedState": {
                    "name": "Catalyse Office Gateway",
                    "version": "4.0.6",
                    "firmwareUpdate": {"latestAvailableVersion": "4.1.9"},
                    "hardware": {"mac": "0C:EA:14:F7:80:D5", "name": "UCG Max"},
                },
            },
        ]
        site_map = {"h_console_1": "Catalyse Office"}

        updates = SITE_THREAD.extract_real_firmware_updates(raw_hosts, flattened, site_map)
        self.assertEqual(len(updates), 2)
        dev_update = next((u for u in updates if u["deviceId"] == "dev_switch_1"), None)
        console_update = next((u for u in updates if u["deviceId"] == "h_console_1"), None)
        self.assertIsNotNone(dev_update)
        self.assertIsNotNone(console_update)
        self.assertEqual(dev_update["name"], "USW Pro 48 PoE")
        self.assertEqual(dev_update["targetVersion"], "7.5.20")
        self.assertEqual(dev_update["category"], "switches")
        self.assertEqual(console_update["name"], "Catalyse Office Gateway")
        self.assertEqual(console_update["targetVersion"], "4.1.9")
        self.assertEqual(console_update["category"], "gateways")

    def test_compact_device_evaluates_update_flag(self) -> None:
        up_to_date_dev = {"id": "d1", "firmwareStatus": "upToDate", "updateAvailable": ""}
        update_avail_dev = {"id": "d2", "firmwareStatus": "updateAvailable", "updateAvailable": "6.0.11+f63375a"}
        legacy_upgradable_dev = {"id": "d3", "upgradable": True}

        self.assertFalse(SITE_THREAD.compact_device(up_to_date_dev)["update"])
        self.assertTrue(SITE_THREAD.compact_device(update_avail_dev)["update"])
        self.assertTrue(SITE_THREAD.compact_device(legacy_upgradable_dev)["update"])


class ConnectionIntegrityAndErrorHandlingTests(unittest.TestCase):
    def setUp(self) -> None:
        import tempfile
        self.tmp_dir = tempfile.TemporaryDirectory()
        self.orig_config_dir = SITE_THREAD.CONFIG_DIR
        self.orig_issues_file = SITE_THREAD.ISSUES_FILE
        self.orig_cache_dir = SITE_THREAD.CACHE_DIR
        SITE_THREAD.CONFIG_DIR = Path(self.tmp_dir.name) / "config"
        SITE_THREAD.CONFIG_DIR.mkdir(parents=True, exist_ok=True)
        SITE_THREAD.ISSUES_FILE = SITE_THREAD.CONFIG_DIR / "issues.json"
        SITE_THREAD.CACHE_DIR = Path(self.tmp_dir.name) / "cache"
        SITE_THREAD.CACHE_DIR.mkdir(parents=True, exist_ok=True)

    def tearDown(self) -> None:
        SITE_THREAD.CONFIG_DIR = self.orig_config_dir
        SITE_THREAD.ISSUES_FILE = self.orig_issues_file
        SITE_THREAD.CACHE_DIR = self.orig_cache_dir
        self.tmp_dir.cleanup()

    def test_command_site_missing_config_returns_json_error(self) -> None:
        import io
        from contextlib import redirect_stdout
        from unittest.mock import patch

        with patch.object(SITE_THREAD, "read_config", return_value=None):
            with patch.object(SITE_THREAD, "read_site_cache", return_value=None):
                out = io.StringIO()
                with redirect_stdout(out):
                    with self.assertRaises(SystemExit) as cm:
                        SITE_THREAD.command_site("nonexistent_host", "nonexistent_site", live=True)
                    self.assertEqual(cm.exception.code, 1)
                res = json.loads(out.getvalue().strip())
                self.assertFalse(res.get("ok"))
                self.assertFalse(res.get("connected"))
                self.assertEqual(res.get("error"), "UniFi SiteThread is not connected")

    def test_command_prefetch_sites_missing_config_returns_json_error(self) -> None:
        import io
        from contextlib import redirect_stdout
        from unittest.mock import patch

        with patch.object(SITE_THREAD, "read_config", return_value=None):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_prefetch_sites()
                self.assertEqual(cm.exception.code, 1)
            res = json.loads(out.getvalue().strip())
            self.assertFalse(res.get("ok"))
            self.assertFalse(res.get("connected"))
            self.assertEqual(res.get("error"), "UniFi SiteThread is not connected")

    def test_fail_function_accepts_extra_kwargs(self) -> None:
        import io
        from contextlib import redirect_stdout

        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.fail("No cached data available for this site", ok=False, cached=False)
            self.assertEqual(cm.exception.code, 1)
        res = json.loads(out.getvalue().strip())
        self.assertFalse(res.get("ok"))
        self.assertFalse(res.get("cached"))
        self.assertEqual(res.get("error"), "No cached data available for this site")

    def test_build_cloud_summary_marks_partial_when_hosts_fails(self) -> None:
        from unittest.mock import patch

        def mock_cloud_rows(key: str, endpoint: str) -> list[dict]:
            if endpoint == "/v1/sites":
                return [{
                    "siteId": "site_1",
                    "hostId": "host_1",
                    "meta": {"name": "Test Site", "desc": "Test Site"},
                    "statistics": {"counts": {"totalDevice": 10, "wifiClient": 5, "wiredClient": 5}},
                }]
            if endpoint == "/v1/hosts":
                raise SITE_THREAD.FabricError("403 Forbidden accessing hosts endpoint")
            if endpoint == "/v1/devices":
                return [{
                    "id": "dev_1",
                    "hostId": "host_1",
                    "name": "Switch 1",
                    "model": "USW Pro 24 PoE",
                    "online": True,
                }]
            return []

        with patch.object(SITE_THREAD, "cloud_rows", side_effect=mock_cloud_rows):
            with patch.object(SITE_THREAD, "get_sdwan_telemetry", return_value={"available": False}):
                with patch.object(SITE_THREAD, "extract_telemetry_details", return_value=([], [], [], [], [], [], {})):
                    res = SITE_THREAD.build_cloud_summary("mock_key")
                    self.assertTrue(res.get("ok"))
                    self.assertTrue(res.get("connected"))
                    self.assertTrue(res.get("partial"))
                    self.assertEqual(res.get("failedEndpoints"), ["/v1/hosts"])
                    self.assertIn("/v1/hosts", res.get("endpointErrors", {}))
                    self.assertEqual(res.get("severity"), "warning")
                    self.assertIn("Partial fleet telemetry", res.get("message", ""))
                    self.assertIn("/v1/hosts", res.get("message", ""))

    def test_build_cloud_summary_marks_partial_when_devices_fails(self) -> None:
        from unittest.mock import patch

        def mock_cloud_rows(key: str, endpoint: str) -> list[dict]:
            if endpoint == "/v1/sites":
                return [{
                    "siteId": "site_1",
                    "hostId": "host_1",
                    "meta": {"name": "Test Site", "desc": "Test Site"},
                    "statistics": {"counts": {"totalDevice": 10, "wifiClient": 5, "wiredClient": 5}},
                }]
            if endpoint == "/v1/hosts":
                return [{
                    "id": "host_1",
                    "reportedState": {"name": "Test Console", "wans": []},
                    "type": "udm",
                }]
            if endpoint == "/v1/devices":
                raise SITE_THREAD.FabricError("500 Internal Server Error accessing devices endpoint")
            return []

        with patch.object(SITE_THREAD, "cloud_rows", side_effect=mock_cloud_rows):
            with patch.object(SITE_THREAD, "get_sdwan_telemetry", return_value={"available": False}):
                with patch.object(SITE_THREAD, "extract_telemetry_details", return_value=([], [], [], [], [], [], {})):
                    res = SITE_THREAD.build_cloud_summary("mock_key")
                    self.assertTrue(res.get("ok"))
                    self.assertTrue(res.get("connected"))
                    self.assertTrue(res.get("partial"))
                    self.assertEqual(res.get("failedEndpoints"), ["/v1/devices"])
                    self.assertIn("/v1/devices", res.get("endpointErrors", {}))
                    self.assertTrue(res["network"].get("partial"))
                    self.assertTrue(res["protect"].get("partial"))
                    self.assertEqual(res.get("severity"), "warning")
                    self.assertIn("Partial fleet telemetry", res.get("message", ""))
                    self.assertIn("/v1/devices", res.get("message", ""))

    def test_build_cloud_summary_marks_both_failed_when_both_fail(self) -> None:
        from unittest.mock import patch

        def mock_cloud_rows(key: str, endpoint: str) -> list[dict]:
            if endpoint == "/v1/sites":
                return [{
                    "siteId": "site_1",
                    "hostId": "host_1",
                    "meta": {"name": "Test Site", "desc": "Test Site"},
                    "statistics": {"counts": {"totalDevice": 0}},
                }]
            if endpoint == "/v1/hosts":
                raise SITE_THREAD.FabricError("Host API down")
            if endpoint == "/v1/devices":
                raise SITE_THREAD.FabricError("Device API down")
            return []

        with patch.object(SITE_THREAD, "cloud_rows", side_effect=mock_cloud_rows):
            with patch.object(SITE_THREAD, "get_sdwan_telemetry", return_value={"available": False}):
                with patch.object(SITE_THREAD, "extract_telemetry_details", return_value=([], [], [], [], [], [], {})):
                    res = SITE_THREAD.build_cloud_summary("mock_key")
                    self.assertTrue(res.get("partial"))
                    self.assertEqual(res.get("failedEndpoints"), ["/v1/hosts", "/v1/devices"])
                    self.assertEqual(res.get("severity"), "warning")
                    self.assertIn("/v1/hosts", res.get("message", ""))
                    self.assertIn("/v1/devices", res.get("message", ""))

    def test_extract_telemetry_details_records_stat_failures_in_partial_status(self) -> None:
        from unittest.mock import patch

        raw_hosts = [{
            "id": "602232938174",
            "name": "UDM-Pro",
            "reportedState": {
                "state": "connected",
                "hostname": "UDM-Pro",
                "hardware": {"name": "UniFi Dream Machine Pro"},
                "wans": [],
            },
        }]
        sites = [{
            "id": "site_default_1",
            "hostId": "602232938174",
            "name": "Default",
            "siteSlug": "default",
        }]

        def mock_cloud_json_request(key: str, path: str, method: str = "GET", payload: Any = None) -> tuple[int, Any]:
            if "stat/sta" in path:
                return 403, {"error": "Forbidden: insufficient permissions"}
            if "stat/device" in path:
                return 500, {"message": "Internal error"}
            if "rest/wlanconf" in path:
                return 200, {"data": [{"_id": "w1", "name": "Corporate-WiFi", "security": "wpapsk"}]}
            return 200, {"data": []}

        failed_endpoints: list[str] = []
        endpoint_errors: dict[str, str] = {}
        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_json_request):
            res = SITE_THREAD.extract_telemetry_details(
                "mock_key", raw_hosts, sites,
                failed_endpoints=failed_endpoints,
                endpoint_errors=endpoint_errors,
            )
            wans, outages, clients, switches, consoles, wlans, spectrum = res[:7]
            self.assertEqual(len(clients), 0)
            self.assertEqual(len(switches), 0)
            self.assertEqual(len(wlans), 1)

            # Failures must be recorded in failed_endpoints and endpoint_errors
            sta_ep = SITE_THREAD.connector_path("602232938174", "/network/api/s/default/stat/sta")
            dev_ep = SITE_THREAD.connector_path("602232938174", "/network/api/s/default/stat/device")
            self.assertIn(sta_ep, failed_endpoints)
            self.assertIn(dev_ep, failed_endpoints)
            self.assertIn("HTTP 403", endpoint_errors[sta_ep])
            self.assertIn("HTTP 500", endpoint_errors[dev_ep])

            # Metadata attributes on returned TelemetryDetails
            self.assertIn(sta_ep, res.failed_endpoints)
            self.assertIn("clients", res.unavailable_telemetry)
            self.assertIn("switches", res.unavailable_telemetry)
            self.assertNotIn("wlans", res.unavailable_telemetry)

    def test_build_cloud_summary_marks_partial_when_stat_requests_fail(self) -> None:
        from unittest.mock import patch

        def mock_cloud_rows(key: str, endpoint: str) -> list[dict]:
            if endpoint == "/v1/sites":
                return [{
                    "id": "site_1",
                    "hostId": "host_1",
                    "meta": {"desc": "HQ", "name": "default"},
                    "statistics": {"counts": {"totalDevice": 1, "wifiClient": 10, "wiredClient": 2, "offlineDevice": 0, "pendingUpdateDevice": 0}},
                }]
            if endpoint == "/v1/hosts":
                return [{"id": "host_1", "name": "Host 1", "reportedState": {"state": "connected"}}]
            if endpoint == "/v1/devices":
                return [{"id": "dev_1", "name": "USW-24", "model": "USW-24", "mac": "00:11:22:33:44:55", "hostId": "host_1"}]
            return []

        def mock_cloud_json_request(key: str, path: str, method: str = "GET", payload: Any = None) -> tuple[int, Any]:
            if "stat/sta" in path:
                return 401, {"error": "Unauthorized"}
            return 200, {"data": []}

        with patch.object(SITE_THREAD, "cloud_rows", side_effect=mock_cloud_rows):
            with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_json_request):
                with patch.object(SITE_THREAD, "get_sdwan_telemetry", return_value={"available": False}):
                    res = SITE_THREAD.build_cloud_summary("mock_key")
                    self.assertTrue(res.get("partial"))
                    sta_ep = SITE_THREAD.connector_path("host_1", "/network/api/s/default/stat/sta")
                    self.assertIn(sta_ep, res.get("failedEndpoints", []))
                    self.assertIn(sta_ep, res.get("endpointErrors", {}))
                    self.assertEqual(res.get("severity"), "warning")
                    self.assertIn("Partial fleet telemetry", res.get("message", ""))
                    self.assertIn(sta_ep, res.get("message", ""))
                    self.assertTrue(res["network"].get("partial"))
                    self.assertIn("clients", res.get("unavailableTelemetry", []))

    def test_qml_and_manifest_observability_for_partial_telemetry(self) -> None:
        panel_qml = load_panel_qml()
        analytics_qml = load_analytics_qml()

        # Panel.qml handles partial telemetry
        self.assertIn("parsed.partial", panel_qml)
        self.assertIn("Partial fleet telemetry", panel_qml)

        # DeviceInventoryView has empty/partial banner distinguishing endpoint error
        device_view_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")
        self.assertIn("endpoint /v1/devices error", device_view_qml)
        self.assertIn("No devices discovered in fleet", device_view_qml)

        # ConsolesTab has empty/partial banner distinguishing endpoint error
        self.assertIn("endpoint /v1/hosts error", analytics_qml)
        self.assertIn("No consoles found", analytics_qml)

        # ClientsTab, SwitchesTab, WifiTab have empty/partial banners distinguishing endpoint errors
        self.assertIn("endpoint stat/sta error", analytics_qml)
        self.assertIn("Client telemetry unavailable", analytics_qml)
        self.assertIn("No clients discovered in fleet", analytics_qml)

        self.assertIn("endpoint stat/device error", analytics_qml)
        self.assertIn("Switch telemetry unavailable", analytics_qml)
        self.assertIn("No switches found in fleet", analytics_qml)

        self.assertIn("endpoint rest/wlanconf error", analytics_qml)
        self.assertIn("WLAN telemetry unavailable", analytics_qml)
        self.assertIn("No wireless networks discovered in fleet", analytics_qml)

        # Manifest version
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest.get("version"), "0.5.1")


class IssueTrackingAndNotificationAlertTests(unittest.TestCase):
    def setUp(self) -> None:
        import tempfile
        self.tmp_dir = tempfile.TemporaryDirectory()
        self.orig_config_dir = SITE_THREAD.CONFIG_DIR
        self.orig_issues_file = SITE_THREAD.ISSUES_FILE
        SITE_THREAD.CONFIG_DIR = Path(self.tmp_dir.name)
        SITE_THREAD.ISSUES_FILE = Path(self.tmp_dir.name) / "issues.json"

    def tearDown(self) -> None:
        SITE_THREAD.CONFIG_DIR = self.orig_config_dir
        SITE_THREAD.ISSUES_FILE = self.orig_issues_file
        self.tmp_dir.cleanup()

    def test_track_issues_does_not_notify_for_offline_devices(self) -> None:
        from unittest.mock import patch
        devices = [{
            "id": "dev_offline_1",
            "name": "Games Room",
            "site": "Home",
            "model": "Nano HD",
            "online": False,
        }]
        with patch.object(SITE_THREAD, "is_notifications_enabled", return_value=True):
            with patch("subprocess.run") as mock_run:
                issues = SITE_THREAD.track_issues([], devices, is_demo=False)
                mock_run.assert_not_called()

        self.assertEqual(len(issues), 1)
        self.assertEqual(issues[0]["type"], "device_offline")
        self.assertTrue(issues[0]["active"])

    def test_track_issues_notifies_for_site_outage_only_once(self) -> None:
        from unittest.mock import patch
        sites = [{
            "id": "site_down_1",
            "name": "Warehouse",
            "status": "down",
        }]
        with patch.object(SITE_THREAD, "is_notifications_enabled", return_value=True):
            with patch("subprocess.run") as mock_run:
                # First detection triggers notification
                issues1 = SITE_THREAD.track_issues(sites, [], is_demo=False)
                self.assertEqual(mock_run.call_count, 1)
                cmd = mock_run.call_args[0][0]
                self.assertEqual(cmd[0], "notify-send")
                self.assertIn("Warehouse", cmd[-2])

                mock_run.reset_mock()

                # Second detection while still down does NOT re-notify
                issues2 = SITE_THREAD.track_issues(sites, [], is_demo=False)
                mock_run.assert_not_called()
                self.assertEqual(issues2[0]["id"], "site:site_down_1:down")
                self.assertTrue(issues2[0]["active"])

    def test_track_issues_resolved_items_do_not_clobber_active_items(self) -> None:
        pre_existing = [
            {
                "id": "device:dev_1:offline",
                "type": "device_offline",
                "title": "Games Room offline",
                "site": "Home",
                "model": "Nano HD",
                "severity": "critical",
                "active": True,
                "startedAt": 1000,
                "durationSeconds": 500,
            },
            {
                "id": "device:dev_1:offline",
                "type": "device_offline",
                "title": "Games Room offline",
                "site": "Home",
                "model": "Nano HD",
                "severity": "critical",
                "active": False,
                "startedAt": 200,
                "resolvedAt": 300,
                "durationSeconds": 100,
            },
        ]
        SITE_THREAD.ISSUES_FILE.write_text(json.dumps(pre_existing), encoding="utf-8")

        devices = [{
            "id": "dev_1",
            "name": "Games Room",
            "site": "Home",
            "model": "Nano HD",
            "online": False,
        }]
        issues = SITE_THREAD.track_issues([], devices, is_demo=False)
        active_items = [i for i in issues if i.get("active")]
        self.assertEqual(len(active_items), 1)
        self.assertEqual(active_items[0]["startedAt"], 1000)
        self.assertGreater(active_items[0]["durationSeconds"], 500)

    def test_track_issues_preserves_device_issue_when_partial_devices_is_true(self) -> None:
        pre_existing = [{
            "id": "device:dev_1:offline",
            "type": "device_offline",
            "title": "Games Room offline",
            "site": "Home",
            "model": "Nano HD",
            "severity": "critical",
            "active": True,
            "startedAt": 1000,
            "durationSeconds": 500,
        }]
        SITE_THREAD.ISSUES_FILE.write_text(json.dumps(pre_existing), encoding="utf-8")

        # When /v1/devices fails, devices is empty but partial_devices is True
        issues = SITE_THREAD.track_issues([], [], is_demo=False, partial_devices=True)
        active_items = [i for i in issues if i.get("active")]
        self.assertEqual(len(active_items), 1)
        self.assertEqual(active_items[0]["id"], "device:dev_1:offline")
        self.assertTrue(active_items[0]["active"])

        # When /v1/devices succeeds and device is actually back online, it resolves
        issues_resolved = SITE_THREAD.track_issues([], [{"id": "dev_1", "online": True}], is_demo=False, partial_devices=False)
        active_items_resolved = [i for i in issues_resolved if i.get("active")]
        self.assertEqual(len(active_items_resolved), 0)
        resolved_items = [i for i in issues_resolved if not i.get("active")]
        self.assertEqual(len(resolved_items), 1)
        self.assertEqual(resolved_items[0]["id"], "device:dev_1:offline")

    def test_track_issues_resolves_confirmed_online_device_when_partial_devices_is_true(self) -> None:
        pre_existing = [{
            "id": "device:18E829B0B5C0:offline",
            "type": "device_offline",
            "title": "Games Room offline",
            "site": "Lough Stanley Home",
            "model": "Nano HD",
            "severity": "critical",
            "active": True,
            "startedAt": 1000,
            "durationSeconds": 500,
        }]
        SITE_THREAD.ISSUES_FILE.write_text(json.dumps(pre_existing), encoding="utf-8")

        # Even if partial_devices=True (e.g. another console's stat/device failed),
        # a device positively confirmed online in `devices` must immediately resolve its offline alert.
        issues = SITE_THREAD.track_issues(
            [],
            [{"id": "18E829B0B5C0", "name": "Games Room", "site": "Lough Stanley Home", "online": True}],
            is_demo=False,
            partial_devices=True,
        )
        active_items = [i for i in issues if i.get("active")]
        self.assertEqual(len(active_items), 0)
        resolved_items = [i for i in issues if not i.get("active")]
        self.assertEqual(len(resolved_items), 1)
        self.assertEqual(resolved_items[0]["id"], "device:18E829B0B5C0:offline")
        self.assertFalse(resolved_items[0]["active"])
        self.assertIn("resolvedAt", resolved_items[0])

    def test_extract_telemetry_details_resolves_unas_pro_site_and_hostname(self) -> None:
        from unittest.mock import patch
        raw_hosts = [
            {
                "id": "h_gw",
                "reportedState": {
                    "state": "connected",
                    "name": "Catalyse Office",
                    "hostname": "Catalyse-Office",
                    "wans": [
                        {"interface": "eth4", "port": 4, "speedType": "2.5GbE", "plugged": True, "ipv4": "58.169.41.158", "type": "WAN"}
                    ]
                }
            },
            {
                "id": "h_unas",
                "reportedState": {
                    "state": "connected",
                    "name": "Catalyse Office - UNAS Pro 4",
                    "hostname": "Catalyse-Office-UNAS-Pro-4",
                    "consolesOnSameLocalNetwork": ["h_gw"],
                    "hardware": {
                        "name": "UniFi Network Attached Storage Pro 4",
                        "shortname": "UNASPRO4"
                    },
                    "controllers": [
                        {"name": "drive", "isInstalled": True, "isRunning": True}
                    ],
                    "wans": [
                        {"interface": "enp0s0", "port": 0, "speedType": "10GbE", "plugged": True, "ipv4": "192.168.15.250", "type": "WAN"},
                        {"interface": "enp0s1", "port": 1, "speedType": "10G SFP+", "plugged": False, "type": "WAN2"},
                        {"interface": "enp0s2", "port": 2, "speedType": "10G SFP+", "plugged": False, "type": "WAN2"},
                    ]
                }
            }
        ]
        sites = [
            {
                "id": "s1",
                "hostId": "h_gw",
                "name": "Catalyse Office",
                "gatewayModel": "UCG Max",
                "gatewayIp": "58.169.41.158",
                "isp": "Telstra Internet",
            }
        ]

        called_endpoints: list[str] = []
        def fake_cloud_json(key: str, ep: str):
            called_endpoints.append(ep)
            if "h_unas" in ep:
                return 404, {"message": "Not Found"}
            return 200, {"data": []}

        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=fake_cloud_json):
            details = SITE_THREAD.extract_telemetry_details("fake_key", raw_hosts, sites)
        wans, outages, _, _, consoles, _, _ = details
        self.assertEqual(details.failed_endpoints, [])
        self.assertFalse(any("h_unas" in ep for ep in called_endpoints))
        self.assertEqual(len(wans), 4)

        gw_wan = wans[0]
        self.assertEqual(gw_wan["siteName"], "Catalyse Office")
        self.assertEqual(gw_wan["gatewayModel"], "UCG Max")

        unas_wans = [w for w in wans if w["hostId"] == "h_unas"]
        self.assertEqual(len(unas_wans), 3)
        for w in unas_wans:
            self.assertEqual(w["siteName"], "Catalyse Office")
            self.assertEqual(w["gatewayModel"], "Catalyse-Office-UNAS-Pro-4")
            self.assertEqual(w["hostname"], "Catalyse-Office-UNAS-Pro-4")
            self.assertEqual(w["isp"], "Telstra Internet")

    def test_wan_site_attribution_does_not_guess_by_name_or_subnet(self) -> None:
        raw_hosts = [
            {
                "id": "h_gw",
                "reportedState": {
                    "name": "Catalyse Office",
                    "hostname": "Catalyse-Office",
                    "wans": [
                        {"interface": "eth4", "port": 4, "speedType": "2.5GbE", "plugged": True, "ipv4": "192.168.1.1", "type": "WAN"}
                    ]
                }
            },
            {
                # Has matching name fragment ("Office") and matching /24 subnet (192.168.1.x)
                # but no direct site match, no explicit host_to_site, and no consolesOnSameLocalNetwork
                "id": "h_unrelated",
                "reportedState": {
                    "name": "Office Remote Unassociated",
                    "hostname": "Office-Remote",
                    "ip": "192.168.1.50",
                    "hardware": {
                        "name": "UniFi Cloud Gateway Ultra",
                        "shortname": "UCGULTRA"
                    },
                    "wans": [
                        {"interface": "eth0", "port": 0, "speedType": "1GbE", "plugged": True, "ipv4": "192.168.1.50", "type": "WAN"}
                    ]
                }
            }
        ]
        sites = [
            {
                "id": "s1",
                "hostId": "h_gw",
                "name": "Catalyse Office",
                "gatewayModel": "UCG Max",
                "gatewayIp": "192.168.1.1",
                "isp": "Telstra Internet",
            }
        ]

        wans, _, _, _, consoles, _, _ = SITE_THREAD.extract_telemetry_details("", raw_hosts, sites)
        self.assertEqual(len(wans), 2)

        gw_wan = next(w for w in wans if w["hostId"] == "h_gw")
        self.assertEqual(gw_wan["siteName"], "Catalyse Office")
        self.assertEqual(gw_wan["gatewayModel"], "UCG Max")
        self.assertEqual(gw_wan["isp"], "Telstra Internet")

        unrelated_wan = next(w for w in wans if w["hostId"] == "h_unrelated")
        # Must be marked as Unknown, NOT attributed to "Catalyse Office" with "UCG Max" and "Telstra Internet"
        self.assertEqual(unrelated_wan["siteName"], "Unknown")
        self.assertEqual(unrelated_wan["gatewayModel"], "Unknown")
        self.assertEqual(unrelated_wan["isp"], "Unknown")

    def test_wan_site_attribution_with_explicit_host_to_site_mapping(self) -> None:
        raw_hosts = [
            {
                "id": "h_branch",
                "reportedState": {
                    "name": "Branch Gateway",
                    "hostname": "branch-gw",
                    "wans": [
                        {"interface": "eth0", "port": 0, "speedType": "1GbE", "plugged": True, "ipv4": "10.0.0.1", "type": "WAN"}
                    ]
                }
            }
        ]
        sites = [
            {
                "id": "site_branch_id",
                "siteSlug": "branch",
                "hostId": "different_host_id",
                "name": "Branch Office",
                "gatewayModel": "UXG Pro",
                "isp": "Starlink",
            }
        ]

        # 1. With explicit host_to_site mapping
        host_to_site = {"h_branch": "branch"}
        wans, _, _, _, _, _, _ = SITE_THREAD.extract_telemetry_details("", raw_hosts, sites, host_to_site=host_to_site)
        self.assertEqual(len(wans), 1)
        self.assertEqual(wans[0]["siteName"], "Branch Office")

        # 2. With explicit siteId directly on the host dict
        raw_hosts_with_site = [
            {
                "id": "h_branch_2",
                "siteId": "site_branch_id",
                "reportedState": {
                    "name": "Branch Gateway 2",
                    "wans": [
                        {"interface": "eth0", "port": 0, "speedType": "1GbE", "plugged": True, "type": "WAN"}
                    ]
                }
            }
        ]
        wans2, _, _, _, _, _, _ = SITE_THREAD.extract_telemetry_details("", raw_hosts_with_site, sites)
        self.assertEqual(wans2[0]["siteName"], "Branch Office")

    def test_wan_tab_qml_renders_gateway_model_or_hostname(self) -> None:
        wan_qml = (ROOT / "views" / "analytics" / "WanTab.qml").read_text(encoding="utf-8")
        self.assertIn("modelData.gatewayModel || modelData.hostname || \"UniFi Gateway\"", wan_qml)

    def test_wan_tab_qml_filters_to_plugged_interfaces_only(self) -> None:
        wan_qml = (ROOT / "views" / "analytics" / "WanTab.qml").read_text(encoding="utf-8")
        self.assertIn("readonly property var pluggedWans:", wan_qml)
        self.assertIn("return Boolean(item && item.plugged);", wan_qml)
        self.assertIn("model: root.pluggedWans", wan_qml)
        self.assertIn("String(root.pluggedWans.length) + \" INTERFACES\"", wan_qml)


    def test_consoles_tab_applications_buttons_aligned_right(self) -> None:
        consoles_qml = (ROOT / "views" / "analytics" / "ConsolesTab.qml").read_text(encoding="utf-8")
        self.assertIn("Layout.alignment: Qt.AlignRight | Qt.AlignVCenter", consoles_qml)
        self.assertIn("Item {\n                              Layout.fillWidth: true\n                            }", consoles_qml)



class TableColumnAlignmentTests(unittest.TestCase):
    def test_clients_tab_header_and_row_columns_align(self) -> None:
        clients_qml = (ROOT / "views" / "analytics" / "ClientsTab.qml").read_text(encoding="utf-8")
        # Col 1: Type icon pill width should match in header and row (28)
        self.assertIn('Layout.preferredWidth: 28\n                    text: "TYPE"\n                    color: root.dim\n                    font.family: root.fontFamily\n                    font.pixelSize: 8\n                    font.bold: true\n                    horizontalAlignment: Text.AlignHCenter', clients_qml)
        self.assertIn("Layout.preferredWidth: 28\n                      Layout.preferredHeight: 24", clients_qml)
        # Verify subsequent column dimensions match
        self.assertIn("Layout.fillWidth: true\n                    Layout.minimumWidth: 140\n                    Layout.preferredWidth: 190\n                    text: \"CLIENT / IP & MAC\"", clients_qml)
        self.assertIn("Layout.fillWidth: true\n                      Layout.minimumWidth: 140\n                      Layout.preferredWidth: 190", clients_qml)
        self.assertIn("Layout.preferredWidth: 130\n                    text: \"SIGNAL / PROTOCOL\"", clients_qml)
        self.assertIn("Layout.preferredWidth: 130\n                      spacing: 1", clients_qml)
        self.assertIn("Layout.preferredWidth: 140\n                    text: \"TRAFFIC & UPTIME\"", clients_qml)
        self.assertIn("Layout.preferredWidth: 140\n                      spacing: 1", clients_qml)
        self.assertIn("Layout.preferredWidth: 58\n                    text: \"ACTION\"", clients_qml)
        self.assertIn("Layout.preferredWidth: 58\n                      Layout.preferredHeight: 22", clients_qml)

    def test_wan_tab_header_and_row_columns_align(self) -> None:
        wan_qml = (ROOT / "views" / "analytics" / "WanTab.qml").read_text(encoding="utf-8")
        self.assertIn("Layout.preferredWidth: 88\n                    text: \"STATE\"", wan_qml)
        self.assertIn("Layout.preferredWidth: 88\n                      spacing: 6", wan_qml)
        self.assertIn("Layout.preferredWidth: 100\n                    text: \"INTERFACE\"", wan_qml)
        self.assertIn("Layout.preferredWidth: 100\n                      spacing: 1", wan_qml)
        self.assertIn("Layout.preferredWidth: 58\n                    text: \"ACTION\"", wan_qml)
        self.assertIn("Layout.preferredWidth: 58\n                      Layout.preferredHeight: 22", wan_qml)

    def test_switches_tab_header_and_row_columns_align(self) -> None:
        switches_qml = (ROOT / "views" / "analytics" / "SwitchesTab.qml").read_text(encoding="utf-8")
        self.assertIn("Layout.preferredWidth: Style.space(32)\n                      text: \"PORT\"", switches_qml)
        self.assertIn("Layout.preferredWidth: Style.space(32)\n                        Layout.preferredHeight: Style.space(18)", switches_qml)
        self.assertIn("Layout.preferredWidth: Style.space(105)\n                      text: \"STATUS & SPEED\"", switches_qml)
        self.assertIn("Layout.preferredWidth: Style.space(105)\n                        spacing: Style.space(4)", switches_qml)
        self.assertIn("Layout.preferredWidth: Style.space(48)\n                      text: \"ACTION\"", switches_qml)
        self.assertIn("Layout.preferredWidth: Style.space(48)\n                        Layout.preferredHeight: Style.space(18)", switches_qml)

    def test_wifi_tab_header_and_row_columns_align(self) -> None:
        wifi_qml = (ROOT / "views" / "analytics" / "WifiTab.qml").read_text(encoding="utf-8")
        self.assertIn('text: "ACCESS POINT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 160', wifi_qml)
        self.assertIn('Layout.preferredWidth: 160 }', wifi_qml)
        self.assertIn('text: "SITE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100', wifi_qml)
        self.assertIn('Layout.preferredWidth: 100 }', wifi_qml)


class CameraSnapshotTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
        self.orig_runtime = SITE_THREAD.RUNTIME_DIR
        SITE_THREAD.RUNTIME_DIR = self.temp_path

    def tearDown(self) -> None:
        SITE_THREAD.RUNTIME_DIR = self.orig_runtime
        self.temp_dir.cleanup()

    def test_cleanup_old_snapshots_removes_expired_and_tmp_files(self) -> None:
        import time

        now = time.time()
        old_file = self.temp_path / "camera-old.jpg"
        old_file.write_bytes(b"old")
        import os
        os.utime(old_file, (now - 120, now - 120))

        fresh_file = self.temp_path / "camera-fresh.jpg"
        fresh_file.write_bytes(b"fresh")
        os.utime(fresh_file, (now - 10, now - 10))

        tmp_file = self.temp_path / "camera-active.tmp.1234"
        tmp_file.write_bytes(b"tmp")
        os.utime(tmp_file, (now, now))

        other_file = self.temp_path / "other-file.txt"
        other_file.write_bytes(b"keep")
        os.utime(other_file, (now - 120, now - 120))

        SITE_THREAD.cleanup_old_snapshots(current_target=None, max_age_seconds=60.0)

        self.assertFalse(old_file.exists())
        self.assertTrue(fresh_file.exists())
        self.assertFalse(tmp_file.exists())
        self.assertTrue(other_file.exists())

    def test_cleanup_old_snapshots_preserves_current_target(self) -> None:
        import os
        import time

        now = time.time()
        active_target = self.temp_path / "camera-active.jpg"
        active_target.write_bytes(b"current")
        os.utime(active_target, (now - 120, now - 120))

        SITE_THREAD.cleanup_old_snapshots(current_target=active_target, max_age_seconds=60.0)
        self.assertTrue(active_target.exists())

    def test_command_snapshot_uses_stable_target_and_reuses_file(self) -> None:
        from unittest.mock import patch
        import io
        from contextlib import redirect_stdout

        def mock_api_request(config: dict, key: str, endpoint: str, output: Path | None = None) -> tuple[int, dict]:
            if output:
                output.write_bytes(b"fake_jpeg_content")
            return 200, {}

        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "local", "host": "192.168.1.1"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="test_key"), \
             patch.object(SITE_THREAD, "api_request", side_effect=mock_api_request):

            # First invocation
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_snapshot("camera1", None)
                self.assertEqual(cm.exception.code, 0)

            res = json.loads(out.getvalue())
            self.assertTrue(res.get("ok"))
            expected_target = self.temp_path / "camera-camera1.jpg"
            self.assertEqual(res.get("path"), str(expected_target))
            self.assertTrue(expected_target.exists())
            self.assertEqual(expected_target.read_bytes(), b"fake_jpeg_content")

            # Check that no temporary files were left
            tmp_files = list(self.temp_path.glob("camera-*.tmp.*"))
            self.assertEqual(len(tmp_files), 0)

            # Second invocation reuses the same stable file
            out2 = io.StringIO()
            with redirect_stdout(out2):
                with self.assertRaises(SystemExit) as cm2:
                    SITE_THREAD.command_snapshot("camera1", None)
                self.assertEqual(cm2.exception.code, 0)

            res2 = json.loads(out2.getvalue())
            self.assertEqual(res2.get("path"), str(expected_target))

            # Directory should only have 1 file for this camera
            cam_files = list(self.temp_path.glob("camera-*"))
            self.assertEqual(len(cam_files), 1)
            self.assertEqual(cam_files[0], expected_target)

    def test_command_disconnect_cleans_up_snapshots(self) -> None:
        from unittest.mock import patch
        import io
        from contextlib import redirect_stdout

        cam_file = self.temp_path / "camera-cam1.jpg"
        cam_file.write_bytes(b"data")

        orig_cfg = SITE_THREAD.CONFIG_FILE
        orig_legacy = SITE_THREAD.LEGACY_CONFIG_FILE
        SITE_THREAD.CONFIG_FILE = self.temp_path / "connection.json"
        SITE_THREAD.LEGACY_CONFIG_FILE = self.temp_path / "legacy_connection.json"
        try:
            with patch.object(SITE_THREAD, "secret_clear"):
                out = io.StringIO()
                with redirect_stdout(out):
                    with self.assertRaises(SystemExit) as cm:
                        SITE_THREAD.command_disconnect()
                    self.assertEqual(cm.exception.code, 0)
        finally:
            SITE_THREAD.CONFIG_FILE = orig_cfg
            SITE_THREAD.LEGACY_CONFIG_FILE = orig_legacy

        self.assertFalse(cam_file.exists())

    def test_panel_and_protect_view_qml_snapshot_cleanup_logic(self) -> None:
        panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        protect_qml = (ROOT / "views" / "ProtectView.qml").read_text(encoding="utf-8")

        # Stable property & deletion helper
        self.assertIn("property string priorSnapshotPath: \"\"", panel_qml)
        self.assertIn("function deleteSnapshotFile(filePath)", panel_qml)
        self.assertIn("if (cleanPath.indexOf(\"camera-\") !== -1)", panel_qml)
        self.assertIn("Quickshell.execDetached([\"rm\", \"-f\", cleanPath])", panel_qml)
        self.assertIn("function cleanupPriorSnapshot()", panel_qml)

        # Cache busting timestamp so QtQuick Image detects updates to the stable file
        self.assertIn('root.snapshotPath = "file://" + parsed.path + "?t=" + Date.now()', panel_qml)
        self.assertIn('root.priorSnapshotPath = root.snapshotPath', panel_qml)

        # ProtectView signal and trigger on Image.Ready
        self.assertIn("signal cleanupPriorSnapshotRequested()", protect_qml)
        self.assertIn("if (status === Image.Ready) {\n                    root.cleanupPriorSnapshotRequested()\n                  }", protect_qml)
        self.assertIn("onCleanupPriorSnapshotRequested: root.cleanupPriorSnapshot()", panel_qml)


class NetworkSiteIdPropagationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
        self.orig_cache = SITE_THREAD.CACHE_DIR
        self.orig_recent = SITE_THREAD.RECENT_OPS_FILE
        self.orig_history = SITE_THREAD.OPERATIONS_HISTORY_FILE
        self.orig_names = SITE_THREAD.DEVICE_NAMES_FILE
        SITE_THREAD.CACHE_DIR = self.temp_path
        SITE_THREAD.RECENT_OPS_FILE = self.temp_path / "recent_operations.json"
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.temp_path / "operations_history.json"
        SITE_THREAD.DEVICE_NAMES_FILE = self.temp_path / "device_names.json"

    def tearDown(self) -> None:
        SITE_THREAD.CACHE_DIR = self.orig_cache
        SITE_THREAD.RECENT_OPS_FILE = self.orig_recent
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.orig_history
        SITE_THREAD.DEVICE_NAMES_FILE = self.orig_names
        self.temp_dir.cleanup()

    def test_extract_telemetry_details_uses_actual_site_id_for_stats_requests(self) -> None:
        from unittest.mock import patch

        raw_hosts = [
            {"id": "host_hq", "reportedState": {"state": "connected"}}
        ]
        sites = [
            {"id": "site_corp", "hostId": "host_hq", "name": "Corporate HQ"}
        ]

        requested_paths: list[str] = []

        def mock_cloud_request(key: str, path: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
            requested_paths.append(path)
            if "stat/sta" in path:
                return 200, {"data": [{"name": "Laptop", "mac": "aa:bb:cc:dd:ee:01", "is_wired": True}]}
            if "stat/device" in path:
                return 200, {"data": [{"name": "HQ Switch", "mac": "aa:bb:cc:dd:ee:02", "port_table": [{"port_idx": 1, "up": True}]}]}
            if "rest/wlanconf" in path:
                return 200, {"data": [{"name": "Staff WiFi", "security": "wpapsk"}]}
            return 200, {"data": []}

        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_request):
            wans, outages, clients, switches, consoles, wlans, spectrum = SITE_THREAD.extract_telemetry_details(
                "mock_key", raw_hosts, sites
            )

        # Verify stat requests used site_corp slug instead of hardcoded default
        stat_paths = [p for p in requested_paths if "network/api/s/" in p]
        self.assertTrue(len(stat_paths) >= 3)
        for p in stat_paths:
            self.assertIn("/network/api/s/site_corp/", p)
            self.assertNotIn("/network/api/s/default/", p)

        # Verify siteId was correctly attached to extracted items
        self.assertEqual(len(clients), 1)
        self.assertEqual(clients[0]["siteId"], "site_corp")
        self.assertEqual(clients[0]["siteName"], "Corporate HQ")

        self.assertEqual(len(switches), 1)
        self.assertEqual(switches[0]["siteId"], "site_corp")
        self.assertEqual(switches[0]["siteName"], "Corporate HQ")

        self.assertEqual(len(wlans), 1)
        self.assertEqual(wlans[0]["siteId"], "site_corp")
        self.assertEqual(wlans[0]["siteName"], "Corporate HQ")

    def test_extract_telemetry_details_with_cloud_hex_id_and_fallback(self) -> None:
        from unittest.mock import patch

        raw_hosts = [
            {"id": "host_hq", "reportedState": {"state": "connected"}}
        ]
        # Cloud hex ID with explicit siteSlug "default"
        sites = [
            {"id": "6a1ecc183d90e85f54ef8a43", "siteSlug": "default", "hostId": "host_hq", "name": "Corporate HQ"}
        ]

        requested_paths: list[str] = []

        def mock_cloud_request(key: str, path: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
            requested_paths.append(path)
            if "stat/sta" in path:
                return 200, {"data": [{"name": "Laptop", "mac": "aa:bb:cc:dd:ee:01", "is_wired": True}]}
            if "stat/device" in path:
                return 200, {"data": [{"name": "HQ Switch", "mac": "aa:bb:cc:dd:ee:02", "port_table": [{"port_idx": 1, "up": True}]}]}
            return 200, {"data": []}

        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_request):
            wans, outages, clients, switches, consoles, wlans, spectrum = SITE_THREAD.extract_telemetry_details(
                "mock_key", raw_hosts, sites
            )

        self.assertTrue(any("/network/api/s/default/stat/sta" in p for p in requested_paths))
        self.assertEqual(len(clients), 1)
        self.assertEqual(clients[0]["siteId"], "6a1ecc183d90e85f54ef8a43")
        self.assertEqual(clients[0]["siteName"], "Corporate HQ")
        self.assertEqual(len(switches), 1)
        self.assertEqual(switches[0]["siteId"], "6a1ecc183d90e85f54ef8a43")
        self.assertEqual(switches[0]["siteName"], "Corporate HQ")

        # Test fallback on 401 for custom slug
        custom_sites = [
            {"id": "site_hex", "siteSlug": "custom_slug", "hostId": "host_hq", "name": "Branch Office"}
        ]
        fallback_paths: list[str] = []

        def mock_cloud_request_with_401(key: str, path: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
            fallback_paths.append(path)
            if "/custom_slug/" in path:
                return 401, {"meta": {"rc": "error", "msg": "api.err.NoSiteContext"}}
            if "/default/" in path and "stat/sta" in path:
                return 200, {"data": [{"name": "Laptop2", "mac": "aa:bb:cc:dd:ee:03", "is_wired": False}]}
            return 200, {"data": []}

        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_request_with_401):
            wans, outages, clients, switches, consoles, wlans, spectrum = SITE_THREAD.extract_telemetry_details(
                "mock_key", raw_hosts, custom_sites
            )

        self.assertTrue(any("/custom_slug/" in p for p in fallback_paths))
        self.assertTrue(any("/default/" in p for p in fallback_paths))
        self.assertEqual(len(clients), 1)
        self.assertEqual(clients[0]["siteName"], "Branch Office")

    def test_command_power_cycle_passes_actual_site_id(self) -> None:
        from unittest.mock import patch
        import io
        from contextlib import redirect_stdout

        # 1. Cloud mode
        requested_urls: list[str] = []

        def mock_cloud_request(key: str, path: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
            requested_urls.append(path)
            return 200, {"ok": True}

        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "cloud"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="key123"), \
             patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_request):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_power_cycle("host_hq", "00:11:22:33:44:55", 3, "site_warehouse")
                self.assertEqual(cm.exception.code, 0)

        self.assertTrue(any("/network/api/s/site_warehouse/cmd/devmgr" in u for u in requested_urls))
        self.assertFalse(any("/network/api/s/default/cmd/devmgr" in u for u in requested_urls))

        # 2. Local mode
        local_requested_urls: list[str] = []

        def mock_api_request(config: dict, key: str, endpoint: str, method: str = "GET", payload: dict | None = None, output=None) -> tuple[int, str]:
            local_requested_urls.append(endpoint)
            return 200, '{"meta": {"rc": "ok"}}'

        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "local", "hostname": "192.168.1.1"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="key123"), \
             patch.object(SITE_THREAD, "api_request", side_effect=mock_api_request):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_power_cycle("host_hq", "00:11:22:33:44:55", 3, "site_warehouse")
                self.assertEqual(cm.exception.code, 0)

        self.assertIn("/proxy/network/api/s/site_warehouse/cmd/devmgr", local_requested_urls)

    def test_command_upgrade_device_passes_actual_site_id(self) -> None:
        from unittest.mock import patch
        import io
        from contextlib import redirect_stdout

        # 1. Cloud mode
        requested_urls: list[str] = []

        def mock_cloud_request(key: str, path: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
            requested_urls.append(path)
            return 200, {"ok": True}

        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "cloud"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="key123"), \
             patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_request):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_upgrade_device("host_hq", "00:11:22:33:44:55", "site_branch")
                self.assertEqual(cm.exception.code, 0)

        self.assertTrue(any("/network/api/s/site_branch/cmd/devmgr" in u for u in requested_urls))
        self.assertFalse(any("/network/api/s/default/cmd/devmgr" in u for u in requested_urls))

        # 2. Local mode
        local_requested_urls: list[str] = []

        def mock_api_request(config: dict, key: str, endpoint: str, method: str = "GET", payload: dict | None = None, output=None) -> tuple[int, str]:
            local_requested_urls.append(endpoint)
            return 200, '{"meta": {"rc": "ok"}}'

        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "local", "hostname": "192.168.1.1"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="key123"), \
             patch.object(SITE_THREAD, "api_request", side_effect=mock_api_request):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_upgrade_device("host_hq", "00:11:22:33:44:55", "site_branch")
                self.assertEqual(cm.exception.code, 0)

        self.assertIn("/proxy/network/api/s/site_branch/cmd/devmgr", local_requested_urls)

    def test_build_cloud_site_uses_local_site_id_for_device_stat(self) -> None:
        from unittest.mock import patch

        requested_urls: list[str] = []

        def mock_cloud_request(key: str, path: str, method: str = "GET", payload: dict | None = None) -> tuple[int, dict]:
            requested_urls.append(path)
            if "/network/integration/v1/sites" in path and not path.endswith("devices") and not path.endswith("clients"):
                return 200, [{"id": "custom_site_id", "name": "Custom Site"}]
            if "/devices" in path or "/clients" in path:
                return 200, []
            if "stat/device" in path:
                return 200, {"data": []}
            return 200, {}

        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_request):
            SITE_THREAD.build_cloud_site("key123", "host_1", "custom_site_id")

        stat_reqs = [u for u in requested_urls if "stat/device" in u]
        self.assertEqual(len(stat_reqs), 1)
        self.assertIn("/network/api/s/custom_site_id/stat/device", stat_reqs[0])

    def test_qml_components_propagate_site_id_for_device_actions(self) -> None:
        switches_qml = (ROOT / "views" / "analytics" / "SwitchesTab.qml").read_text(encoding="utf-8")
        firmware_qml = (ROOT / "views" / "analytics" / "FirmwareTab.qml").read_text(encoding="utf-8")
        analytics_qml = (ROOT / "windows" / "AnalyticsWindow.qml").read_text(encoding="utf-8")

        # SwitchesTab signal and invocation includes siteId
        self.assertIn("signal cyclePortRequested(string hostId, string mac, var portIdx, string portName, string siteId)", switches_qml)
        self.assertIn("root.cyclePort(root.currentSwitch.hostId, root.currentSwitch.mac, modelData.portIdx, modelData.name || (\"Port \" + modelData.portIdx), root.currentSwitch.siteId || \"\")", switches_qml)

        # FirmwareTab signal and invocation includes siteId
        self.assertIn("signal upgradeDeviceRequested(string hostId, string mac, string deviceName, string siteId)", firmware_qml)
        self.assertIn("root.upgradeDeviceRequested(modelData.hostId, modelData.mac, modelData.name, modelData.siteId || \"\")", firmware_qml)

        # AnalyticsWindow functions and handlers pass siteId to CLI process commands
        self.assertIn("function upgradeDevice(hostId, mac, deviceName, siteId)", analytics_qml)
        self.assertIn("if (siteId && String(siteId).trim() !== \"\") cmd.push(String(siteId))", analytics_qml)
        self.assertIn("function cyclePort(hostId, mac, portIdx, portName, siteId)", analytics_qml)
        self.assertIn("onCyclePortRequested: function(hId, mac, pIdx, name, sId) { root.cyclePort(hId, mac, pIdx, name, sId) }", analytics_qml)
        self.assertIn("onUpgradeDeviceRequested: function(hId, mac, name, sId) { root.upgradeDevice(hId, mac, name, sId) }", analytics_qml)


class RecentOperationsHostnameDisplayTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
        self.orig_history = SITE_THREAD.OPERATIONS_HISTORY_FILE
        self.orig_cache = SITE_THREAD.CACHE_DIR
        self.orig_history = SITE_THREAD.OPERATIONS_HISTORY_FILE
        self.orig_recent = SITE_THREAD.RECENT_OPS_FILE
        self.orig_names = SITE_THREAD.DEVICE_NAMES_FILE
        SITE_THREAD.CACHE_DIR = self.temp_path
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.temp_path / "operations_history.json"
        SITE_THREAD.RECENT_OPS_FILE = self.temp_path / "recent_operations.json"
        SITE_THREAD.DEVICE_NAMES_FILE = self.temp_path / "device_names.json"

    def tearDown(self) -> None:
        SITE_THREAD.CACHE_DIR = self.orig_cache
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.orig_history
        SITE_THREAD.RECENT_OPS_FILE = self.orig_recent
        SITE_THREAD.DEVICE_NAMES_FILE = self.orig_names
        self.temp_dir.cleanup()

    def test_default_operations_do_not_expose_raw_macs(self) -> None:
        ops = SITE_THREAD.get_default_operations()
        for op in ops:
            # Check target and title do not contain raw MAC addresses
            self.assertFalse(re.search(r"\b[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5}\b", op["target"]), f"MAC found in target: {op['target']}")
            self.assertFalse(re.search(r"\b[0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5}\b", op["title"]), f"MAC found in title: {op['title']}")
        # op_demo_2 target must be Port 4 on USW Pro 24 PoE
        self.assertEqual(ops[1]["target"], "Port 4 on USW Pro 24 PoE")

    def test_get_operations_history_resolves_mac_to_hostname(self) -> None:
        from unittest.mock import patch
        history_entry = {
            "id": "op_test_1",
            "type": "upgrade",
            "title": "Firmware Upgrade: 74:83:c2:22:33:44",
            "target": "74:83:c2:22:33:44",
            "status": "completed",
            "message": "Firmware upgrade completed for 74:83:c2:22:33:44. Device active on target firmware.",
            "timestamp": int(time.time()),
        }
        SITE_THREAD.OPERATIONS_HISTORY_FILE.write_text(json.dumps([history_entry]), encoding="utf-8")
        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True}):
            ops = SITE_THREAD.get_operations_history(limit=5)
        self.assertEqual(len(ops), 1)
        self.assertEqual(ops[0]["target"], "USW Pro 24 PoE")
        self.assertEqual(ops[0]["title"], "Firmware Upgrade: USW Pro 24 PoE")
        self.assertIn("USW Pro 24 PoE", ops[0]["message"])
        self.assertNotIn("74:83:c2:22:33:44", ops[0]["message"])

    def test_command_upgrade_device_records_hostname(self) -> None:
        from unittest.mock import patch
        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_upgrade_device("console-home", "74:83:c2:22:33:44", name="USW Pro 24 PoE")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("USW Pro 24 PoE", res.get("message", ""))
        self.assertNotIn("74:83:c2:22:33:44", res.get("message", ""))

        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True}):
            ops = SITE_THREAD.get_operations_history(limit=1)
        self.assertEqual(len(ops), 1)
        self.assertEqual(ops[0]["target"], "USW Pro 24 PoE")
        self.assertEqual(ops[0]["title"], "Firmware Upgrade: USW Pro 24 PoE")

    def test_command_power_cycle_records_hostname(self) -> None:
        from unittest.mock import patch
        out = io.StringIO()
        with redirect_stdout(out):
            with self.assertRaises(SystemExit) as cm:
                SITE_THREAD.command_power_cycle("console-home", "74:83:c2:22:33:44", 2, name="USW Pro 24 PoE")
            self.assertEqual(cm.exception.code, 0)
        res = json.loads(out.getvalue())
        self.assertTrue(res.get("ok"))
        self.assertIn("USW Pro 24 PoE", res.get("message", ""))

        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True}):
            ops = SITE_THREAD.get_operations_history(limit=1)
        self.assertEqual(len(ops), 1)
        self.assertEqual(ops[0]["target"], "Port 2 on USW Pro 24 PoE")
        self.assertEqual(ops[0]["title"], "PoE Power Cycle: Port 2 on USW Pro 24 PoE")

    def test_reconcile_operations_uses_hostname_in_message(self) -> None:
        from unittest.mock import patch
        now = int(time.time()) - 40
        history_entry = {
            "id": "op_test_upgrade",
            "type": "upgrade",
            "title": "Firmware Upgrade: USW Pro 24 PoE",
            "target": "USW Pro 24 PoE",
            "status": "accepted",
            "message": "Upgrade request accepted for USW Pro 24 PoE.",
            "mac": "74:83:c2:22:33:44",
            "deviceName": "USW Pro 24 PoE",
            "timestamp": now,
        }
        SITE_THREAD.OPERATIONS_HISTORY_FILE.write_text(json.dumps([history_entry]), encoding="utf-8")
        SITE_THREAD.reconcile_operations(backups=[], updates=[])
        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True}):
            ops = SITE_THREAD.get_operations_history(limit=1)
        self.assertEqual(ops[0]["status"], "completed")
        self.assertIn("Firmware upgrade completed for USW Pro 24 PoE.", ops[0]["message"])
        self.assertNotIn("74:83:c2:22:33:44", ops[0]["message"])

    def test_firmware_tab_qml_contains_hostname_formatters(self) -> None:
        qml_path = ROOT / "views" / "analytics" / "FirmwareTab.qml"
        content = qml_path.read_text(encoding="utf-8")
        self.assertIn("formatOperationTitle(modelData)", content)
        self.assertIn("formatOperationMessage(modelData)", content)
        self.assertIn("function replaceMacsWithHostnames", content)
        self.assertIn("function resolveDeviceName", content)

    def test_analytics_window_qml_passes_name_option(self) -> None:
        qml_path = ROOT / "windows" / "AnalyticsWindow.qml"
        content = qml_path.read_text(encoding="utf-8")
        self.assertIn('if (deviceName && String(deviceName).trim() !== "") cmd.push("--name", String(deviceName).trim())', content)
        self.assertIn('if (swName && String(swName).trim() !== "") cmd.push("--name", String(swName).trim())', content)
        self.assertIn('if (cName && String(cName).trim() !== "") cmd.push("--name", String(cName).trim())', content)


class AdaptiveDualRatePollingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.settings_qml = (ROOT / "SettingsView.qml").read_text(encoding="utf-8")
        self.manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))

    def test_panel_dual_rate_properties_and_timer(self) -> None:
        self.assertIn("property int activeRefreshSeconds:", self.panel_qml)
        self.assertIn("property int idleRefreshSeconds:", self.panel_qml)
        self.assertIn("readonly property bool isUiActive: root.opened || root.analyticsOpen", self.panel_qml)
        self.assertIn("readonly property int currentRefreshIntervalSec:", self.panel_qml)
        self.assertIn("readonly property int currentRefreshIntervalMs:", self.panel_qml)
        self.assertIn("id: refreshTimer", self.panel_qml)
        self.assertIn("interval: root.currentRefreshIntervalMs", self.panel_qml)
        self.assertIn("onIsUiActiveChanged:", self.panel_qml)
        self.assertIn("refreshTimer.restart()", self.panel_qml)

    def test_manifest_schema_and_defaults(self) -> None:
        defaults = self.manifest["barWidget"]["defaults"]
        self.assertEqual(defaults.get("activeRefreshSeconds"), 15)
        self.assertEqual(defaults.get("idleRefreshSeconds"), 120)

        schema = self.manifest["barWidget"]["schema"]
        active_field = next(f for f in schema if f["key"] == "activeRefreshSeconds")
        self.assertEqual(active_field["min"], 10)
        self.assertEqual(active_field["max"], 15)

        idle_field = next(f for f in schema if f["key"] == "idleRefreshSeconds")
        self.assertEqual(idle_field["min"], 60)
        self.assertEqual(idle_field["max"], 300)
        self.assertEqual(idle_field["defaultValue"], 120)

    def test_settings_view_adaptive_controls(self) -> None:
        self.assertIn("ADAPTIVE DUAL-RATE POLLING", self.settings_qml)
        self.assertIn("Active rate (while popup panel or Analytics window is open)", self.settings_qml)
        self.assertIn("Idle rate (while closed in background)", self.settings_qml)
        self.assertIn("activeRefreshSeconds", self.settings_qml)
        self.assertIn("idleRefreshSeconds", self.settings_qml)
        self.assertIn('"1m"', self.settings_qml)
        self.assertIn('"2m (default)"', self.settings_qml)


class LiveWanSparklinesTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = load_panel_qml()
        self.sparkline_qml = (ROOT / "components" / "WanSparkline.qml").read_text(encoding="utf-8")
        self.siterow_qml = (ROOT / "components" / "SiteRow.qml").read_text(encoding="utf-8")
        self.overview_qml = (ROOT / "views" / "OverviewView.qml").read_text(encoding="utf-8")
        self.sites_qml = (ROOT / "views" / "SitesView.qml").read_text(encoding="utf-8")
        self.model_js = (ROOT / "Model.js").read_text(encoding="utf-8")

    def test_demo_summary_has_throughput(self) -> None:
        summary = SITE_THREAD.demo_summary()
        self.assertIn("fleetThroughput", summary)
        ft = summary["fleetThroughput"]
        self.assertIn("rxRate", ft)
        self.assertIn("txRate", ft)
        self.assertGreater(ft["rxRate"], 0)
        self.assertGreater(ft["txRate"], 0)

        sites = summary.get("sites", [])
        self.assertTrue(len(sites) >= 2)
        for s in sites:
            self.assertIn("rxRate", s)
            self.assertIn("txRate", s)
            if s.get("status") == "down":
                self.assertEqual(s["rxRate"], 0.0)
                self.assertEqual(s["txRate"], 0.0)

    def test_model_js_sparkline_functions(self) -> None:
        self.assertIn("function formatRate(mbps)", self.model_js)
        self.assertIn("function getSiteWanSparkline(site, range)", self.model_js)
        self.assertIn("wanHistory60s", self.model_js)
        self.assertIn("wanHistory1h", self.model_js)

    def test_wan_sparkline_component_features(self) -> None:
        self.assertIn("property var site: null", self.sparkline_qml)
        self.assertIn("property var throughputData: null", self.sparkline_qml)
        self.assertIn('property string range: "24h"', self.sparkline_qml)
        self.assertIn("property bool compact: false", self.sparkline_qml)
        self.assertIn("Canvas {", self.sparkline_qml)
        self.assertIn("id: sparkCanvas", self.sparkline_qml)
        self.assertIn("id: rollingTick", self.sparkline_qml)
        self.assertIn("24-HOUR WAN THROUGHPUT", self.sparkline_qml)
        self.assertIn("downloadColor", self.sparkline_qml)
        self.assertIn("uploadColor", self.sparkline_qml)

    def test_siterow_embeds_compact_sparkline(self) -> None:
        self.assertIn("WanSparkline {", self.siterow_qml)
        self.assertIn('range: "24h"', self.siterow_qml)
        self.assertIn("site: siteCardSurface.rowData", self.siterow_qml)
        self.assertIn("throughputData: siteCardSurface.rowData ? Model.getSiteThroughput24h(siteCardSurface.rowData) : null", self.siterow_qml)

    def test_overview_embeds_fleet_sparkline_and_card_sparklines(self) -> None:
        self.assertIn("24-HOUR WAN THROUGHPUT", self.overview_qml + self.sparkline_qml)
        self.assertIn("id: fleetWanSparkline", self.overview_qml)
        self.assertIn("Model.getFleetThroughput24h", self.overview_qml)
        self.assertIn("site: cardDelegate.modelData", self.overview_qml)

    def test_sites_tab_individual_sparklines_match_overview(self) -> None:
        self.assertNotIn("id: sitesFleetWanSparkline", self.sites_qml)
        self.assertIn("throughputData: siteCardSurface.rowData ? Model.getSiteThroughput24h(siteCardSurface.rowData) : null", self.siterow_qml)
        self.assertIn("compact: false", self.siterow_qml)
        self.assertIn("interactive: true", self.siterow_qml)
        self.assertIn("implicitHeight: Style.space(100)", self.siterow_qml)
        self.assertIn("downloadColor: siteCardSurface.accent", self.siterow_qml)
        self.assertIn("uploadColor: siteCardSurface.healthy", self.siterow_qml)
        self.assertIn("Math.max(40, Math.ceil(root.peakRx / 20) * 20)", self.sparkline_qml)
        self.assertIn("getThroughputDate", self.sparkline_qml)
        self.assertIn("getThroughputTime", self.sparkline_qml)
        self.assertIn("id: infoCard", self.sparkline_qml)
        self.assertIn('text: root.range || "24h"', self.sparkline_qml)
        self.assertIn('"24h ago", "18h", "12h", "6h", "Now"', self.sparkline_qml)

    def test_sites_tab_time_options(self) -> None:
        self.assertIn('"24 hours", "12 hours", "6 hours", "1 hour"', self.sites_qml)
        self.assertIn('property string timeRange: "24 hours"', self.sites_qml)
        self.assertIn('timeRange: root.timeRange', self.sites_qml)
        self.assertIn('property string timeRange: "24 hours"', self.siterow_qml)
        self.assertIn('["24h", "12h", "6h", "1h"]', self.sparkline_qml)
        self.assertIn('12-HOUR WAN THROUGHPUT', self.sparkline_qml)
        self.assertIn('6-HOUR WAN THROUGHPUT', self.sparkline_qml)
        self.assertIn('1-HOUR WAN THROUGHPUT', self.sparkline_qml)
        self.assertIn('["12h ago", "9h", "6h", "3h", "Now"]', self.sparkline_qml)
        self.assertIn('["6h ago", "4.5h", "3h", "1.5h", "Now"]', self.sparkline_qml)
        self.assertIn('["1h ago", "45m", "30m", "15m", "Now"]', self.sparkline_qml)

    def test_demo_summary_has_differentiated_24h_history(self) -> None:
        summary = SITE_THREAD.demo_summary()
        sites_by_name = {s["name"]: s for s in summary.get("sites", [])}
        self.assertIn("Home", sites_by_name)
        self.assertIn("Main Office", sites_by_name)
        self.assertIn("Warehouse", sites_by_name)

        home = sites_by_name["Home"]
        office = sites_by_name["Main Office"]
        warehouse = sites_by_name["Warehouse"]

        self.assertIn("wanHistory24h", home)
        self.assertIn("wanHistory24h", office)
        self.assertIn("wanHistory24h", warehouse)

        home_rx = home["wanHistory24h"]["rx"]
        office_rx = office["wanHistory24h"]["rx"]
        wh_rx = warehouse["wanHistory24h"]["rx"]

        self.assertEqual(len(home_rx), 288)
        self.assertEqual(len(office_rx), 288)
        self.assertEqual(len(wh_rx), 288)
        self.assertEqual(home["wanHistory24h"].get("intervalMinutes"), 5)
        self.assertEqual(office["wanHistory24h"].get("intervalMinutes"), 5)
        self.assertEqual(warehouse["wanHistory24h"].get("intervalMinutes"), 5)

        # Home and Office must have distinct curves and peak rates
        self.assertNotEqual(home_rx, office_rx)
        self.assertEqual(home_rx[-1], home["rxRate"])
        self.assertEqual(office_rx[-1], office["rxRate"])

        # Warehouse is down, must show 0.0 for outage period
        self.assertEqual(wh_rx[-1], 0.0)
        self.assertEqual(wh_rx[-2], 0.0)
        self.assertEqual(wh_rx[-3], 0.0)
        self.assertEqual(wh_rx[-4], 0.0)

        # OverviewTab and Model.js integration
        overview_tab_qml = (ROOT / "views" / "analytics" / "OverviewTab.qml").read_text(encoding="utf-8")
        self.assertIn("function getSiteThroughput24h(site)", self.model_js)
        self.assertIn("Model.getSiteThroughput24h", overview_tab_qml)

    def test_cloud_summary_populates_real_24h_wan_throughput_from_five_minutes_site(self) -> None:
        from unittest.mock import patch
        raw_hosts = [
            {
                "id": "h_gw",
                "reportedState": {
                    "state": "connected",
                    "name": "Catalyse Office",
                    "controllers": [{"name": "network", "isInstalled": True, "isRunning": True}],
                }
            }
        ]
        sites = [
            {
                "id": "s1",
                "hostId": "h_gw",
                "name": "Catalyse Office",
                "gatewayModel": "UCG Max",
                "gatewayIp": "58.169.41.158",
                "status": "up",
                "rxRate": 25.5,
                "txRate": 6.8,
            }
        ]

        # Fake 5minutes.site data with 288 intervals of wan-rx_bytes / wan-tx_bytes
        # 37_500_000 bytes/5min = 1.0 Mbps
        five_min_data = [
            {"wan-rx_bytes": 37_500_000 * (i + 1), "wan-tx_bytes": 37_500_000 * ((i + 1) * 0.3)}
            for i in range(288)
        ]

        def fake_cloud_json(key, ep, method="GET", payload=None):
            if "5minutes.site" in ep:
                return 200, {"data": five_min_data}
            return 200, {"data": []}

        with patch.object(SITE_THREAD, "cloud_json_request", side_effect=fake_cloud_json):
            details = SITE_THREAD.extract_telemetry_details("fake_key", raw_hosts, sites)

        self.assertIn("s1", details.wan_history)
        hist = details.wan_history["s1"]
        self.assertEqual(len(hist["rx"]), 288)
        self.assertEqual(len(hist["tx"]), 288)
        self.assertEqual(hist["rx"][0], 1.0)
        self.assertEqual(hist["rx"][1], 2.0)
        self.assertEqual(hist["rx"][-1], 288.0)
        self.assertEqual(hist["intervalMinutes"], 5)


class MultiProtocolChooserTests(unittest.TestCase):
    def setUp(self) -> None:
        self.chooser_qml = (ROOT / "components" / "MultiProtocolChooser.qml").read_text(encoding="utf-8")
        self.qmldir = (ROOT / "components" / "qmldir").read_text(encoding="utf-8")
        self.device_inv_qml = (ROOT / "DeviceInventoryView.qml").read_text(encoding="utf-8")
        self.device_row_qml = (ROOT / "components" / "DeviceRow.qml").read_text(encoding="utf-8")
        self.topology_qml = (ROOT / "TopologyTreeView.qml").read_text(encoding="utf-8")
        self.site_row_qml = (ROOT / "components" / "SiteRow.qml").read_text(encoding="utf-8")

    def test_multiprotocol_chooser_qml_exists_and_registered(self) -> None:
        self.assertTrue((ROOT / "components" / "MultiProtocolChooser.qml").exists())
        self.assertIn("MultiProtocolChooser 1.0 MultiProtocolChooser.qml", self.qmldir)

    def test_multiprotocol_chooser_defines_signals_and_protocols(self) -> None:
        self.assertIn("signal launchSsh(string ip, string user)", self.chooser_qml)
        self.assertIn("signal launchPing(string ip)", self.chooser_qml)
        self.assertIn("signal openWeb(string url)", self.chooser_qml)
        self.assertIn("signal closeRequested()", self.chooser_qml)

        # Protocols
        self.assertIn('"ssh"', self.chooser_qml)
        self.assertIn('"ping"', self.chooser_qml)
        self.assertIn('"web"', self.chooser_qml)
        self.assertIn('"direct_ip"', self.chooser_qml)
        self.assertIn('"unifi_os"', self.chooser_qml)

        # Copy clipboard helper using wl-copy
        self.assertIn("wl-copy", self.chooser_qml)
        self.assertIn("feedbackNotice", self.chooser_qml)

    def test_device_inventory_integrates_chooser(self) -> None:
        self.assertIn("id: actionChooserBtn", self.device_inv_qml)
        self.assertIn("MultiProtocolChooser", self.device_inv_qml)
        self.assertIn("activeChooserIndex", self.device_inv_qml)

    def test_device_row_integrates_chooser(self) -> None:
        self.assertIn("id: actionChooserBtn", self.device_row_qml)
        self.assertIn("MultiProtocolChooser", self.device_row_qml)
        self.assertIn("isChooserOpen", self.device_row_qml)

    def test_topology_tree_integrates_chooser(self) -> None:
        self.assertIn("id: gwChooserBtn", self.topology_qml)
        self.assertIn("id: t1ChooserBtn", self.topology_qml)
        self.assertIn("id: t2ChooserBtn", self.topology_qml)
        self.assertIn("MultiProtocolChooser", self.topology_qml)
        self.assertIn("activeChooserNode", self.topology_qml)

    def test_site_row_integrates_chooser(self) -> None:
        self.assertIn("id: actionChooserBtn", self.site_row_qml)
        self.assertIn("MultiProtocolChooser", self.site_row_qml)
        self.assertIn("isChooserOpen", self.site_row_qml)


class HierarchicalTopologyTreeTests(unittest.TestCase):
    def setUp(self) -> None:
        self.topology_qml = (ROOT / "TopologyTreeView.qml").read_text(encoding="utf-8")
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")

    def test_topology_has_collapsible_tree_controls(self) -> None:
        self.assertIn("property var collapsedNodes", self.topology_qml)
        self.assertIn("function isCollapsed", self.topology_qml)
        self.assertIn("function toggleCollapse", self.topology_qml)
        self.assertIn("function expandAll", self.topology_qml)
        self.assertIn("function collapseAll", self.topology_qml)
        self.assertIn("Gateway ➔ Switch ➔ AP ➔ Clients", self.topology_qml)
        self.assertIn("id: gwCollapseBtn", self.topology_qml)
        self.assertIn("id: t1CollapseBtn", self.topology_qml)
        self.assertIn("id: t2CollapseBtn", self.topology_qml)
        self.assertIn("Expand All", self.topology_qml)
        self.assertIn("Collapse All", self.topology_qml)

    def test_topology_displays_port_numbers_and_channel_bands(self) -> None:
        # Port numbers
        self.assertIn("function portSpeedLabel", self.topology_qml)
        self.assertIn("id: t1PortText", self.topology_qml)
        self.assertIn("id: t2PortText", self.topology_qml)
        self.assertIn("id: wiredPortText", self.topology_qml)

        # Channel bands
        self.assertIn("function apBandsLabel", self.topology_qml)
        self.assertIn("id: t1BandsText", self.topology_qml)
        self.assertIn("id: t2BandsText", self.topology_qml)
        self.assertIn("id: clientBandText", self.topology_qml)
        self.assertIn("id: clientProtoText", self.topology_qml)
        self.assertIn("id: clientSignalText", self.topology_qml)

    def test_topology_renders_connected_clients_with_actions(self) -> None:
        self.assertIn("function getClientsForDevice", self.topology_qml)
        self.assertIn("id: clientPingMouse", self.topology_qml)
        self.assertIn("id: clientCopyMouse", self.topology_qml)
        self.assertIn("id: wiredPingMouse", self.topology_qml)
        self.assertIn("id: wiredCopyMouse", self.topology_qml)
        self.assertIn("wl-copy", self.topology_qml)

    def test_dynamic_hierarchy_and_client_nesting(self) -> None:
        self.assertIn("function buildFlatTree", self.topology_qml)
        self.assertIn("function getRootDevices", self.topology_qml)
        self.assertIn("function getChildDevices", self.topology_qml)
        self.assertIn("modelData.type === \"client\"", self.topology_qml)
        self.assertIn("modelData.type === \"device\"", self.topology_qml)
        self.assertIn("c.uplinkDeviceId", self.topology_qml)
        self.assertIn("Layout.leftMargin: Style.space(14) * modelData.depth", self.topology_qml)

        # Verify daisy chaining and client parent resolution in python logic
        site = SITE_THREAD.demo_site("console-home", "home")
        devices = site["network"]["devices"]
        clients = site["network"]["clients"]
        dev_ids = {d["id"] for d in devices}
        for c in clients:
            self.assertIn("uplinkDeviceId", c)
            self.assertIn(c["uplinkDeviceId"], dev_ids)

    def test_secondary_client_collapse_controls(self) -> None:
        self.assertIn("property var collapsedClientNodes", self.topology_qml)
        self.assertIn("function toggleClientsCollapse", self.topology_qml)
        self.assertIn("function isClientsCollapsed", self.topology_qml)
        self.assertIn("id: gwClientsCollapseBtn", self.topology_qml)
        self.assertIn("id: t1ClientsCollapseBtn", self.topology_qml)
        self.assertIn("id: t2ClientsCollapseBtn", self.topology_qml)
        self.assertIn("id: gwCollapseBtn", self.topology_qml)
        self.assertIn("id: t1CollapseBtn", self.topology_qml)
        self.assertIn("id: t2CollapseBtn", self.topology_qml)
        self.assertIn("modelData.hasClients", self.topology_qml)
        self.assertIn("modelData.hasChildDevs", self.topology_qml)
        self.assertIn("By default, clients are collapsed", self.topology_qml)
        self.assertIn('root.collapsedClientNodes = { "*": false }', self.topology_qml)


class PermissionAndCapabilityWarningsTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.temp_path = Path(self.temp_dir.name)
        self.orig_config = SITE_THREAD.CONFIG_FILE
        self.orig_recent = SITE_THREAD.RECENT_OPS_FILE
        self.orig_history = SITE_THREAD.OPERATIONS_HISTORY_FILE
        self.orig_runtime = SITE_THREAD.RUNTIME_DIR
        SITE_THREAD.CONFIG_FILE = self.temp_path / "config.json"
        SITE_THREAD.RECENT_OPS_FILE = self.temp_path / "recent_operations.json"
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.temp_path / "operations_history.json"
        SITE_THREAD.RUNTIME_DIR = self.temp_path

        self.switches_qml = (ROOT / "views" / "analytics" / "SwitchesTab.qml").read_text(encoding="utf-8")
        self.firmware_qml = (ROOT / "views" / "analytics" / "FirmwareTab.qml").read_text(encoding="utf-8")
        self.protect_qml = (ROOT / "views" / "ProtectView.qml").read_text(encoding="utf-8")
        self.panel_qml = load_panel_qml()
        self.settings_qml = (ROOT / "SettingsView.qml").read_text(encoding="utf-8")

    def tearDown(self) -> None:
        SITE_THREAD.CONFIG_FILE = self.orig_config
        SITE_THREAD.RECENT_OPS_FILE = self.orig_recent
        SITE_THREAD.OPERATIONS_HISTORY_FILE = self.orig_history
        SITE_THREAD.RUNTIME_DIR = self.orig_runtime
        self.temp_dir.cleanup()

    def test_build_capabilities_structure_and_scope_detection(self) -> None:
        # Default with full permissions
        caps = SITE_THREAD.build_capabilities()
        self.assertTrue(caps["powerCycle"]["allowed"])
        self.assertEqual(caps["powerCycle"]["requiredScope"], "devices:write")
        self.assertTrue(caps["firmwareUpgrade"]["allowed"])
        self.assertEqual(caps["firmwareUpgrade"]["requiredScope"], "firmware:upgrade")
        self.assertTrue(caps["protectStreams"]["allowed"])
        self.assertEqual(caps["protectStreams"]["requiredScope"], "protect:stream")

        # Missing PoE power cycling scope
        caps_no_poe = SITE_THREAD.build_capabilities(config={"missingScopes": ["devices:write"]})
        self.assertFalse(caps_no_poe["powerCycle"]["allowed"])
        self.assertIn("devices:write", caps_no_poe["powerCycle"]["missingPermission"])
        self.assertTrue(caps_no_poe["firmwareUpgrade"]["allowed"])

        # Missing firmware upgrade scope
        caps_no_fw = SITE_THREAD.build_capabilities(config={"missingScopes": ["firmware:upgrade"]})
        self.assertFalse(caps_no_fw["firmwareUpgrade"]["allowed"])
        self.assertIn("firmware:upgrade", caps_no_fw["firmwareUpgrade"]["missingPermission"])

        # Missing Protect scope
        caps_no_prot = SITE_THREAD.build_capabilities(config={"missingScopes": ["protect:stream"]})
        self.assertFalse(caps_no_prot["protectStreams"]["allowed"])
        self.assertIn("protect:stream", caps_no_prot["protectStreams"]["missingPermission"])

        # Viewer role restrictions
        caps_viewer = SITE_THREAD.build_capabilities(sites=[{"permission": "viewer"}])
        self.assertFalse(caps_viewer["powerCycle"]["allowed"])
        self.assertFalse(caps_viewer["firmwareUpgrade"]["allowed"])

    def test_summary_and_site_include_capabilities(self) -> None:
        demo_summary = SITE_THREAD.demo_summary()
        self.assertIn("capabilities", demo_summary)
        self.assertIn("powerCycle", demo_summary["capabilities"])
        self.assertIn("firmwareUpgrade", demo_summary["capabilities"])
        self.assertIn("protectStreams", demo_summary["capabilities"])

        demo_site = SITE_THREAD.demo_site("console-home", "home")
        self.assertIn("capabilities", demo_site)
        self.assertIn("powerCycle", demo_site["capabilities"])

    def test_command_power_cycle_missing_scope_rejection(self) -> None:
        import io
        from contextlib import redirect_stdout

        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True, "missingScopes": ["devices:write"]}):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_power_cycle("console-home", "74:83:c2:22:33:44", 2)
                self.assertEqual(cm.exception.code, 1)

            res = json.loads(out.getvalue())
            self.assertFalse(res.get("ok"))
            self.assertTrue(res.get("permissionError"))
            self.assertEqual(res.get("requiredScope"), "devices:write")
            self.assertIn("devices:write", res.get("error", ""))

    def test_command_power_cycle_401_403_returns_permission_warning(self) -> None:
        import io
        from contextlib import redirect_stdout

        def mock_cloud_json(*args, **kwargs):
            return 403, {"error": "api.err.NoPermission", "message": "Forbidden"}

        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "cloud"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="fake_key"), \
             patch.object(SITE_THREAD, "cloud_json_request", side_effect=mock_cloud_json):

            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_power_cycle("host1234567890abcdef", "74:83:c2:22:33:44", 1)
                self.assertEqual(cm.exception.code, 1)

            res = json.loads(out.getvalue())
            self.assertFalse(res.get("ok"))
            self.assertTrue(res.get("permissionError"))
            self.assertEqual(res.get("requiredScope"), "devices:write")
            self.assertIn("devices:write", res.get("error", ""))

    def test_command_upgrade_device_missing_scope_rejection(self) -> None:
        import io
        from contextlib import redirect_stdout

        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True, "missingScopes": ["firmware:upgrade"]}):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_upgrade_device("console-home", "74:83:c2:22:33:44", name="USW Pro")
                self.assertEqual(cm.exception.code, 1)

            res = json.loads(out.getvalue())
            self.assertFalse(res.get("ok"))
            self.assertTrue(res.get("permissionError"))
            self.assertEqual(res.get("requiredScope"), "firmware:upgrade")
            self.assertIn("firmware:upgrade", res.get("error", ""))

    def test_command_upgrade_all_missing_scope_rejection(self) -> None:
        import io
        from contextlib import redirect_stdout

        with patch.object(SITE_THREAD, "read_config", return_value={"demo": True, "missingScopes": ["firmware:upgrade"]}):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_upgrade_all("all")
                self.assertEqual(cm.exception.code, 1)

            res = json.loads(out.getvalue())
            self.assertFalse(res.get("ok"))
            self.assertTrue(res.get("permissionError"))
            self.assertEqual(res.get("requiredScope"), "firmware:upgrade")

    def test_command_snapshot_missing_scope_and_401_rejection(self) -> None:
        import io
        from contextlib import redirect_stdout

        # Missing scope in config
        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "local", "missingScopes": ["protect:stream"]}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="fake_key"):
            out = io.StringIO()
            with redirect_stdout(out):
                with self.assertRaises(SystemExit) as cm:
                    SITE_THREAD.command_snapshot("cam1", None)
                self.assertEqual(cm.exception.code, 1)

            res = json.loads(out.getvalue())
            self.assertFalse(res.get("ok"))
            self.assertTrue(res.get("permissionError"))
            self.assertEqual(res.get("requiredScope"), "protect:stream")

        # HTTP 403 response
        with patch.object(SITE_THREAD, "read_config", return_value={"mode": "local"}), \
             patch.object(SITE_THREAD, "secret_lookup", return_value="fake_key"), \
             patch.object(SITE_THREAD, "api_request", return_value=(403, {})):
            out2 = io.StringIO()
            with redirect_stdout(out2):
                with self.assertRaises(SystemExit) as cm2:
                    SITE_THREAD.command_snapshot("cam1", None)
                self.assertEqual(cm2.exception.code, 1)

            res2 = json.loads(out2.getvalue())
            self.assertFalse(res2.get("ok"))
            self.assertTrue(res2.get("permissionError"))
            self.assertEqual(res2.get("requiredScope"), "protect:stream")

    def test_qml_inline_permission_warnings_and_controls(self) -> None:
        # 1. Switches Tab PoE power cycle banner & controls
        self.assertIn("property var capabilities:", self.switches_qml)
        self.assertIn("readonly property bool canPowerCycle:", self.switches_qml)
        self.assertIn("readonly property string powerCycleWarning:", self.switches_qml)
        self.assertIn("id: poePermissionBanner", self.switches_qml)
        self.assertIn("text: root.powerCycleWarning", self.switches_qml)
        self.assertIn("Cannot power cycle: API key lacks 'devices:write' permission", self.switches_qml)
        self.assertIn("cursorShape: (modelData.poeMode !== \"off\" || modelData.poePower > 0) ? (root.canPowerCycle ? Qt.PointingHandCursor : Qt.ForbiddenCursor) : Qt.ArrowCursor", self.switches_qml)

        # 2. Firmware Tab firmware upgrades banner & controls
        self.assertIn("property var capabilities:", self.firmware_qml)
        self.assertIn("readonly property bool canUpgradeFirmware:", self.firmware_qml)
        self.assertIn("readonly property string firmwareWarning:", self.firmware_qml)
        self.assertIn("id: firmwarePermissionBanner", self.firmware_qml)
        self.assertIn("text: root.firmwareWarning", self.firmware_qml)
        self.assertIn("Cannot upgrade: API key lacks 'firmware:upgrade' permission", self.firmware_qml)
        self.assertIn("cursorShape: !root.canUpgradeFirmware ? Qt.ForbiddenCursor :", self.firmware_qml)

        # 3. Protect View live streams banner & camera snapshot placeholder
        self.assertIn("property var capabilities:", self.protect_qml)
        self.assertIn("readonly property bool canStreamProtect:", self.protect_qml)
        self.assertIn("readonly property string protectWarning:", self.protect_qml)
        self.assertIn("id: protectPermissionBanner", self.protect_qml)
        self.assertIn("Missing 'protect:stream' permission for camera snapshots", self.protect_qml)

        # 4. Panel snapshot error handling
        self.assertIn("property string cameraPermissionError:", self.panel_qml)
        self.assertIn("parsed.permissionError", self.panel_qml)

        # 5. Settings diagnostics view permissions checklist
        self.assertIn("API PERMISSIONS & SCOPES", self.settings_qml)
        self.assertIn("devices:write (PoE)", self.settings_qml)
        self.assertIn("firmware:upgrade", self.settings_qml)
        self.assertIn("protect:stream", self.settings_qml)


class PerformanceOptimizationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.panel_qml = (ROOT / "Panel.qml").read_text(encoding="utf-8")
        self.clients_qml = (ROOT / "views" / "analytics" / "ClientsTab.qml").read_text(encoding="utf-8")

    def test_panel_does_not_prefetch_on_summary_completed_or_diagnose_at_startup(self) -> None:
        # summaryProc handler must not trigger prefetchSites
        summary_proc_block = self.panel_qml[self.panel_qml.find("id: summaryProc"):self.panel_qml.find("id: prefetchProc")]
        self.assertNotIn("root.prefetchSites()", summary_proc_block)

        # Component.onCompleted must not trigger runDiagnostics
        on_completed_block = self.panel_qml[self.panel_qml.find("Component.onCompleted:"):self.panel_qml.find("id: summaryProc")]
        self.assertNotIn("runDiagnostics()", on_completed_block)
        self.assertIn("refresh()", on_completed_block)

        # 10-minute prefetch timer and on-demand function are preserved
        self.assertIn("id: prefetchTimer", self.panel_qml)
        self.assertIn("interval: 600000", self.panel_qml)
        self.assertIn("function prefetchSites()", self.panel_qml)

    def test_clients_tab_uses_virtualized_list_view(self) -> None:
        # Must use virtualized ListView rather than eager Repeater in Flickable
        self.assertIn("id: clientListView", self.clients_qml)
        self.assertIn("model: tab1View.filteredClients", self.clients_qml)
        self.assertIn("boundsBehavior: Flickable.StopAtBounds", self.clients_qml)
        self.assertNotIn("id: clientListCol", self.clients_qml)

    def test_telemetry_cache_helpers(self) -> None:
        import tempfile
        from pathlib import Path
        with tempfile.TemporaryDirectory() as tmp_dir:
            orig_dir = SITE_THREAD.TELEMETRY_CACHE_DIR
            SITE_THREAD.TELEMETRY_CACHE_DIR = Path(tmp_dir)
            try:
                # Save item
                SITE_THREAD.save_telemetry_cache("host1", "stat/report/5minutes.site", [{"val": 123}])
                # Read valid cache
                cached = SITE_THREAD.read_telemetry_cache("host1", "stat/report/5minutes.site", max_age=60)
                self.assertEqual(cached, [{"val": 123}])
                # Expired cache returns None
                expired = SITE_THREAD.read_telemetry_cache("host1", "stat/report/5minutes.site", max_age=-1)
                self.assertIsNone(expired)
                # Non-existent returns None
                non_existent = SITE_THREAD.read_telemetry_cache("host1", "other/path", max_age=60)
                self.assertIsNone(non_existent)
            finally:
                SITE_THREAD.TELEMETRY_CACHE_DIR = orig_dir


if __name__ == "__main__":
    unittest.main()





