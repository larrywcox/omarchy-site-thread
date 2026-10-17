# UniFi SiteThread for Omarchy (BoeyCorp Fork)

UniFi SiteThread is a high-density, NOC-style UniFi Network and Protect operations cockpit for the Omarchy top bar. It aggregates every site owned by (or shared with) your UI Account into one popup and a seven-tab fleet analytics window, using only live data from the UniFi APIs.

> Screenshots below have names, IP/MAC addresses, SSIDs, passphrases and other identifying data blurred.

![UniFi SiteThread](preview.png)

![Status bar widget](docs/screenshots/status_bar_widget.png)

## Contents

- [Visual tour](#visual-tour)
  - [Bar popup & cockpit](#bar-popup--cockpit)
  - [Site drill-down & topology tree](#site-drill-down--topology-tree)
  - [Fleet analytics & telemetry window](#fleet-analytics--telemetry-window)
- [Key features](#key-features)
- [Security & permissions model](#security--permissions-model)
- [Install](#install)
- [Dependencies](#dependencies)
- [Connect](#connect)
- [Mouse actions & keyboard shortcuts](#mouse-actions--keyboard-shortcuts)
- [IPC reference](#ipc-reference)
- [Update / Remove](#update--remove)
- [Development & testing](#development--testing)
- [Roadmap](#roadmap)
- [License](#license)

## Visual tour

### Bar popup & cockpit

The bar popup provides a compact 4-tab NOC dashboard designed for fast situational awareness and rapid operator actions.

![Overview](docs/screenshots/panel_overview.png)

**Tab 0: Overview (Cockpit)** – Fleet health at a glance, global topology, and urgent incident monitoring.
- **Fleet KPI Cards**: High-level status counters summarizing total online sites, WAN uplink stability, total hardware counts (highlighting offline units in urgent red), and client load broken down by Wi-Fi and wired connections.
- **Interactive 3D Vector Globe**: A real-time orthographic vector wireframe globe mapping site locations with geographic pins and interconnecting Site Magic SD-WAN links. Supports mouse drag rotation, scroll zooming, and continuous auto-rotation.
- **Fleet WAN Sparklines**: Real 24-hour historical throughput graph (at 5-minute interval fidelity) and bandwidth indicators showing fleet-wide upload and download rates.
- **Priority Attention Banner**: An alert strip highlighting active hardware and connectivity disruptions, detailing affected devices, host locations, and downtime duration.
- **Quick Action Header**: Instant shortcuts to launch the standalone 7-tab Fleet Analytics window, trigger manual background syncs, and open preferences.

![Sites](docs/screenshots/panel_sites.png)

**Tab 1: Sites & Devices (Unified Fleet View)** – Managed installations, site-level network telemetry, and full hardware inventory switchable via subview toggle pills (`Sites` / `Devices`):
- **Fleet Feature Cards**: Pinned summary modules providing instant insight into cross-site services:
  - **Site Magic SD-WAN**: Reports active mesh connectivity across gateways with a quick link to the SD-WAN topology view.
  - **WiFi & RF Spectrum Health**: Fleet SSID counts and real-time tri-band channel utilization across 2.4 GHz, 5 GHz, and 6 GHz spectrums.
  - **Fleet Firmware & Backups**: Upgrade readiness indicators, pending update counts, and cloud backup freshness across all consoles.
- **Per-Site Health Rows**: Detailed cards for each managed site indicating gateway model badges (e.g. UCG Max, UCG Ultra, UXG Pro), online status, device counts, client distribution, WAN uptime percentages, and a 24-hour WAN throughput sparkline.
- **Multi-Protocol Action Chooser**: 1-click launcher buttons to open the site's UniFi OS console web interface, open an SSH terminal session to the gateway, or launch an active ICMP ping latency monitor.
- **Click-to-Drilldown**: Click any site row or card to transition directly into that site's live Network view and Hierarchical Topology Tree.

![Devices](docs/screenshots/panel_devices.png)

*Sites Tab in `Devices` Subview* – Hardware inventory across the entire fleet with operational status and diagnostics:
- **Category Filtering**: Segment hardware instantly across Gateways, Switches, Access Points, and UniFi Protect Storage / NVRs.
- **Operational Status Indicators**: Color-coded connectivity badges, firmware versions, and live uptime tracking.
- **Network Telemetry**: Surfaces assigned IP addresses, hardware MAC addresses, and active uplink topology for every device in the fleet.
- **Integrated Terminal Actions**: Action buttons next to each device allowing operators to launch 1-click SSH terminal sessions, start ICMP ping diagnostic tests, or open local web admin portals without leaving the desktop.
- **Fault Highlighting**: Unreachable or disconnected devices are immediately highlighted with prominent alert indicators.

![Issues](docs/screenshots/panel_issues.png)

**Tab 2: Issues** – Centralized fleet incident logging and historical tracking for network disruptions and hardware failures:
- **Real-Time Outage Tracking**: Logs and surfaces critical incidents such as gateway WAN drops, packet loss spikes, and unreachable access points or switches.
- **Lifecycle Filters**: Filter between `All`, `Active` (unresolved ongoing issues), and `Resolved` historical incidents, with a button to purge historical logs.
- **Downtime Duration**: Displays precise elapsed downtime duration (e.g. "Down for 23h 24m") and device context to distinguish transient blips from prolonged outages.

**Tab 3: Protect** – Fleet surveillance overview (visible when UniFi Protect is present):
- **Camera Inventory**: Direct live overview of cameras and doorbells across managed sites.
- **Status & Diagnostics**: Live snapshot refreshes, camera connection states, and direct links to Protect streams.

![Settings](docs/screenshots/panel_settings.png)

**Settings & Diagnostics** – Comprehensive customization for the Omarchy top bar widget, diagnostic tools, and desktop integration:
- **Bar Badge Mode**: Select what telemetry appears on the top bar next to the UniFi icon: `Alerts Count`, `Fleet Clients`, `Sites Ratio`, `Updates`, or disabled (`Off`).
- **Multi-Dot Site Status**: Optionally displays individual color-coded status indicator dots for each site directly in the top bar.
- **3D Globe Behavior**: Toggle continuous background auto-rotation on the Overview tab or restrict globe interaction to manual mouse dragging.
- **Adaptive Dual-Rate Polling**: Configure active polling frequency (10s–15s, default 15s) while the panel or analytics window is open, and idle polling frequency (60s–300s, default 120s / 2m) when closed in the background.
- **Preferred Terminal**: Configure which installed Linux terminal emulator (`Default`, `Ghostty`, `Kitty`, `Foot`, `Alacritty`) handles 1-click SSH and ping shortcuts.
- **Desktop Notifications**: Enable native `notify-send` desktop alert banners when site outages or WAN failovers occur, with an interactive test notification trigger.
- **Built-In Diagnostics**: Inspect cloud reachability, API key scopes, and local cache health directly in the UI.
- **Maintenance Actions**: Quick options to clear stored incident history or cleanly disconnect the stored API key from the desktop Secret Service keyring.

---

### Site drill-down & topology tree

When clicking into any site from Overview or Sites, SiteThread renders an in-depth view of that specific site:

- **Hierarchical Topology Tree**: Visualizes the site network path as a collapsible tree:
  `Gateway ➔ Core/Distribution Switch ➔ Access Point ➔ Connected Clients`
- **Port & Band Annotations**: Each uplink node clearly denotes its physical port index (e.g. `Port 8 (1 GbE)`), PoE delivery status, and wireless channel bands (`2.4 GHz`, `5 GHz`, `6 GHz`).
- **Secondary Client Collapse Controls**: Client endpoints are collapsed by default beneath their parent AP or switch to keep large rosters clean. Individual device branches can be toggled independently, or globally expanded/collapsed via **Expand All** and **Collapse All**.
- **Multi-Protocol Action Chooser on Tree Nodes**: Launch SSH, ICMP ping, or direct IP browser sessions from any node in the tree.
- **Wired & Wireless Client Inspection**: View signal strength, Wi-Fi generation protocols (`WiFi 7`, `WiFi 6`, `WiFi 5`), link rates, and active data transfer for every client.

---

### Fleet Analytics & Telemetry window

Opened from the header button or keyboard shortcut (`a` / `m`). Includes an instant refresh button, global site filter dropdowns, and live count badges across all 7 tabs:

**1. Overview & Mesh** – 24-hour WAN throughput curves, client density by band, Site Magic SD-WAN mesh topology, and managed site matrix.

![Overview & Mesh](docs/screenshots/analytics_overview.png)

**2. Client Telemetry** – Searchable wired/WiFi client roster with uplink resolution, signal dBm, protocol generation, bandwidth consumption, and uptime.

![Client Telemetry](docs/screenshots/analytics_clients.png)

**3. WAN & Outages** – Gateway WAN interfaces, link speeds, ISP peering/SLA metadata, packet loss detection, and historical outage timelines.

![WAN & Outages](docs/screenshots/analytics_wan.png)

**4. Switch Ports & PoE** – Per-switch port strip, PoE consumption vs max power budget, dense two-column port matrix, and safe remote PoE port power cycling.

![Switch Ports & PoE](docs/screenshots/analytics_switches.png)

**5. UniFi OS & Direct Connect** – Console inventory cards, `*.id.ui.direct` WebRTC P2P direct connectivity, and installed application hub (Network, Protect, Access, Talk, Drive, InnerSpace).

![UniFi OS & Direct Connect](docs/screenshots/analytics_consoles.png)

**6. WiFi & RF Spectrum** – WLAN SSID inventory, WPA security configurations, QR onboarding code generation, per-band RF utilization, and AP radio assignments.

![WiFi & RF Spectrum](docs/screenshots/analytics_wifi.png)

**7. Firmware & Backups** – Pending firmware updates, batch deployment workflow, cloud configuration backup status with 1-click **Create Backup Now**, and a durable operations audit history log.

![Firmware & Backups](docs/screenshots/analytics_firmware.png)

## Key features

- **Top Bar Health Widget**: Dynamic health-aware UniFi icon with optional multi-dot per-site status indicators and configurable badge modes (**Alerts Count**, **Fleet Clients**, **Sites Ratio**, **Updates**, or **Off**). Adapts cleanly to active Omarchy light/dark themes.
- **Interactive 3D Vector Globe**: Natural Earth geometry via [OmaGlobe](https://github.com/zamak/omaglobe) with drag-to-rotate, scroll zoom, site beacons, and Site Magic SD-WAN interconnects.
- **Multi-Protocol Action Chooser**: Standardized quick launcher available across all device rows, site cards, and topology nodes:
  - 1-click SSH terminal session (launching your preferred terminal with configured username/host)
  - Active ICMP ping monitor
  - Device web administration GUI
  - Direct IP browser launch
  - Direct UniFi OS console connection
  - Native Wayland clipboard copying via `wl-copy`
- **Hierarchical Site Topology**: Collapsible `Gateway ➔ Switch ➔ AP ➔ Clients` tree with secondary client collapse controls, port speeds, PoE delivery, and RF band badges.
- **Adaptive Dual-Rate Polling**: Minimizes background resource consumption and cloud API overhead by switching between an active interval (10s–15s) when the UI is open and an idle interval (60s–300s) when closed in the background.
- **24-Hour WAN Sparklines**: Embedded 24-hour historical throughput curves (at 5-minute fidelity) across site rows, site cards, and fleet overview, perfectly matching the 24-hour WAN throughput telemetry in Analytics.
- **Scope Detection & Safe Operations**: Enforces least-privilege API token security with inline permission warning banners, disabled trigger controls, and forbidden cursors when credentials lack required scopes.
- **Durable Operations History**: Persistent audit trail (`~/.config/site-thread/operations_history.json`) mapping hardware MACs to friendly device hostnames and tracking operation acceptance through completion.
- **Full IPC Automation**: Comprehensive Quickshell IPC interface for Hyprland keybindings, shell scripts, and external automation.

## Security & permissions model

UniFi SiteThread does not ask for or store your UniFi password. Sign-in happens in your normal browser at `unifi.ui.com`; the plugin uses the official UniFi Site Manager API-key flow:

- **Keyring Storage**: The API key travels from the masked field to the local helper over standard input, is stored securely by `secret-tool` in your desktop Secret Service keyring, and never appears in Omarchy's `shell.json`, process arguments, or logs.
- **Public Key Pinning & Verification**: Cloud requests use normal public TLS verification against `api.ui.com`. In optional local-console mode, the connection screen displays the console's SHA-256 certificate fingerprint and pins its public key.
- **Least-Privilege Enforcement**: Read-only monitoring works with baseline viewer permissions. Operational actions strictly require explicit API token scopes:
  - **PoE Power Cycling**: Requires `devices:write`. If missing, the UI displays a non-intrusive warning banner and disables the action.
  - **Firmware Upgrades**: Requires `firmware:upgrade`.
  - **Protect Camera Snapshots**: Requires `protect:stream`.
- **Injection Defense**: All remote strings are rendered as plain text to prevent markup or terminal injection.

## Install

```bash
omarchy plugin add https://github.com/larrywcox/omarchy-site-thread.git --enable
```

Local development checkout:

```bash
omarchy plugin add /path/to/omarchy-site-thread --enable
```

## Dependencies

- `python3` (3.10+)
- `curl`
- `openssl`
- `secret-tool` from `libsecret`, for secure API-key storage in the desktop keyring
- `wl-clipboard` (`wl-copy`, `wl-paste`), for clipboard helpers and the **Paste API key from clipboard** button
- `notify-send` (from `libnotify`), for native desktop notifications
- Any supported Linux terminal emulator (`ghostty`, `kitty`, `foot`, `alacritty`, or system default `xdg-terminal-exec`)

## Connect

1. Click the UniFi SiteThread icon in the bar.
2. Select **Sign in at unifi.ui.com**.
3. In Site Manager, open **Settings → API Keys** and create an API key (granting `devices:write` or `firmware:upgrade` only if you wish to use remote PoE cycling and firmware upgrades).
4. Return to UniFi SiteThread, paste the key into the masked field, and select **Connect all sites**.

If the clipboard shortcut is unavailable inside the bar popup, select **Paste API key from clipboard** below the masked field. The credential remains available across logins while your desktop keyring is unlocked.

## Mouse actions & keyboard shortcuts

### Status bar mouse actions

| Mouse Action | Description |
| --- | --- |
| **Left Click** | Toggle the popup panel / return to the main Overview cockpit |
| **Middle Click** | Trigger an immediate manual telemetry refresh |
| **Right Click** | Open directly into Settings & Diagnostics |

### Keyboard shortcuts (when panel is focused)

| Key | Action |
| --- | --- |
| `r` | Refresh fleet telemetry |
| `s` | Toggle settings & diagnostics view |
| `a` / `m` | Toggle Fleet Analytics & Telemetry window |
| `w` | Switch tabs (Overview ➔ Sites ➔ Issues ➔ Protect) |
| `Esc` | Close popup panel or Analytics window |

## IPC reference

All functions are callable over Quickshell IPC using:

```bash
qs -p /usr/share/omarchy/shell ipc call larrywcox.site-thread <function> [args]
```

### Supported IPC functions

| Function | Arguments | Description |
| --- | --- | --- |
| `open` / `show` | None | Open the bar popup panel |
| `close` / `hide` | None | Close the bar popup panel |
| `toggle` | None | Toggle popup open/close state |
| `goToMainPage` | None | Reset navigation, close analytics/settings, and return to Overview |
| `handleBarClick` | `button: int` | Simulate bar clicks (`1` = Left, `2` = Middle/Refresh, `4` = Right/Settings) |
| `tab` | `index: int` | Open specific popup tab (`0` Overview, `1` Sites, `2` Issues, `3` Protect) |
| `setSitesSubView` | `view: string` | Switch Sites tab subview (`sites` or `devices`) |
| `openSiteByIndex` | `index: int` | Open site drilldown view for site at given index |
| `backToSites` | None | Return from site drilldown back to the main Sites view |
| `openSettings` | None | Open the Settings & Diagnostics view |
| `closeSettings` | None | Close the Settings view |
| `openAnalytics` | None | Open the Fleet Analytics window (Overview tab) |
| `openAnalyticsTab` | `index: int` | Open specific analytics tab (`0` to `6`) |
| `closeAnalytics` | None | Close the Fleet Analytics window |
| `toggleAnalytics` | None | Toggle the Fleet Analytics window |
| `filterAnalyticsSite` | `siteName: string` | Filter analytics data to a specific site name |
| `clearAnalyticsSiteFilter` | None | Clear the site filter in Analytics |
| `hoverAnalyticsThroughput` | `index: int` | Highlight a specific timestamp column in the 24h throughput chart |
| `rotate` | `longitude: real` | Set the 3D globe camera center longitude |
| `zoomIn` / `zoomOut` | None | Zoom the 3D globe in or out |
| `setGlobeScale` | `scale: real` | Set explicit 3D globe scale factor |
| `globeScaleValue` | None | Returns the current 3D globe scale factor |
| `visibleSitesCount` | None | Returns the count of sites currently visible on the globe |
| `prefetchSites` | None | Pre-cache site drilldown payloads in background |
| `notify` | `title, message, urgency` | Dispatch a native desktop notification |
| `testNotification` | None | Send an interactive test notification |
| `status` | None | Returns a JSON string with comprehensive UI, panel, and site state |

## Update / Remove

```bash
omarchy plugin update larrywcox.site-thread
omarchy plugin remove larrywcox.site-thread --yes
```

Removing the plugin does not delete the saved API key. To remove it:

```bash
secret-tool clear application site-thread profile default
```

## Development & testing

Run the full automated test suite:

```bash
python3 -m unittest discover -s tests
```

To run feature and integration tests with verbose output:

```bash
python3 -m unittest tests/test_features.py -v
```

## Roadmap

- Protect motion-event WebSocket and real-time desktop event notifications.
- Event filmstrip and low-latency WebRTC/RTSP video player.
- Confirmed client access management, PTZ, chime, siren, and door relay triggers.
- Side-by-side multi-camera matrix layouts.

## License

MIT

