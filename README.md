# UniFi SiteThread for Omarchy

UniFi SiteThread is a unified UniFi Network and Protect operations panel for the
Omarchy top bar.

Version 0.4.7 provides:

- A health-aware bar icon with offline-device badges.
- A browser-based UI Account sign-in handoff and masked API-key entry.
- One aggregated view of every site the UI Account owns or administers.
- Per-site device, client, offline, firmware, ISP, and WAN-uptime summaries.
- Green online, yellow backup-WAN, and red unreachable status indicators.
- A fixed high-visibility red for unavailable sites, independent of the Omarchy theme.
- An always-white UniFi SiteThread top-bar icon.
- An always-white SiteThread logo inside the popup.
- A top-bar badge that counts unreachable sites only, never offline devices.
- Two-check outage confirmation so a brief cloud disconnect does not immediately mark a site red.
- Sites ordered by health first (unreachable, failover, healthy), then alphabetically by name.
- An in-plugin site view with Back navigation—site selection never leaves the panel.
- Live per-site Network inventory through UniFi Cloud Connector.
- Per-site Protect detection, camera inventory, and live-refreshing camera views.
- Protect controls are hidden automatically on sites where Protect is not installed.
- The Overview alert names only sites with outages or active WAN failover.
- Overview summary tiles expand into clickable site, device, client, and issue lists.
- Individual offline devices stay in the expandable Issues list.
- Fleet-wide device and Protect inventory through the official Site Manager API.
- An optional direct-console mode for local-only sites and Protect snapshots.
- Certificate fingerprint verification before any credential is transmitted.
- Persistent authentication through the desktop Secret Service.
- Overview cards for devices, clients, cameras, updates, and offline equipment.
- Network device inventory and health.
- Protect camera inventory and live snapshot refresh while the panel is open.
- Bounded API responses and JSON models to prevent remote memory exhaustion.
- Plain-text rendering for all externally sourced labels.

## macOS

The Omarchy plugin is a Quickshell/QML bar widget and does not run on macOS. A
native menu bar app built from the same model, health, and security logic lives
in [`macos/`](macos/README.md):

```bash
cd macos && ./build.sh
```

That produces `macos/dist/UniFi SiteThread.app`. It needs macOS 12 or newer and
the Xcode Command Line Tools, and has no third-party dependencies.

## Security model

UniFi SiteThread does not ask for or store your UniFi password. Sign-in happens in
your normal browser at `unifi.ui.com`; the plugin uses the official Site Manager
API-key flow. The key travels from the masked field to the local helper over
standard input, is stored by `secret-tool`, and never appears in Omarchy's
`shell.json`, process arguments, or logs.

Cloud requests use normal public TLS verification against `api.ui.com`. In the
optional local-console mode, the connection screen displays the console's
SHA-256 certificate fingerprint and every request pins its public key.

Create a dedicated local UniFi user with the minimum permissions needed for
Network viewing and Protect viewing, then create an API key while signed in as
that user.

## Install

Install the latest version directly from the public GitHub repository:

```bash
omarchy plugin add https://github.com/larrywcox/omarchy-site-thread.git --enable
```

To install a local development checkout instead:

```bash
omarchy plugin add /path/to/site-thread --enable
```

## Dependencies

UniFi SiteThread needs the following commands:

- `python3`
- `curl`
- `openssl`
- `secret-tool` from `libsecret`, for secure API-key storage
- `wl-paste` from `wl-clipboard`, for the **Paste API key from clipboard** button

Install any missing dependency through your system package manager before
enabling the plugin.

## Update

```bash
omarchy plugin update larrywcox.site-thread
```

## Remove

```bash
omarchy plugin remove larrywcox.site-thread --yes
```

Removing the plugin does not automatically delete its saved API key from the
desktop Secret Service. To remove that credential too, run:

```bash
secret-tool clear application site-thread profile default
```

## Connect

1. Click the UniFi SiteThread icon in the bar.
2. Select **Sign in at unifi.ui.com**.
3. In Site Manager, open **Settings → API Keys** and create an API key.
4. Return to UniFi SiteThread, paste the key into the masked field, and select
   **Connect all sites**.

If the usual keyboard shortcut is unavailable inside the bar popup, select
**Paste API key from clipboard** below the masked field.

Every site owned by or shared with that UI Account is loaded automatically.
The Sites tab keeps the entire fleet visible at once. Selecting a site opens its
live Network view inside UniFi SiteThread. Use **Back** to return to all sites.
When Protect is installed on that console, its Protect tab shows the site's
cameras and refreshes the selected camera while the panel remains open.

The credential remains available across logins while your desktop keyring is
unlocked.

## Roadmap

The backend and UI are deliberately structured for the next layers:

- Protect motion-event WebSocket and desktop notifications.
- Event filmstrip and low-latency RTSP video.
- WAN latency, VPN, Wi-Fi, and switch-port views.
- Carefully confirmed client, PoE, PTZ, light, siren, relay, and arm-profile actions.
- Side-by-side multi-camera layouts.

Operational actions should use a separate, explicitly privileged credential;
the default monitoring credential should stay read-only.

## License

MIT
