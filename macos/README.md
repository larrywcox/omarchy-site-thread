# UniFi SiteThread for macOS

A native macOS menu bar app built from the same UniFi SiteThread model, health,
and security logic as the Omarchy bar plugin.

The Omarchy plugin cannot run on macOS: it is a Quickshell/QML widget for a
Wayland bar, and its helper shells out to `secret-tool`, `wl-paste`, `curl`, and
`openssl`. This directory is a port, not a wrapper — the panel is SwiftUI, the
UniFi client is `URLSession`, and the credential lives in the macOS keychain.

## Build

Requirements: macOS 12 or newer and the Xcode Command Line Tools. There are no
third-party dependencies and no Xcode project.

```bash
xcode-select --install     # only if `swift` is missing
cd macos
./build.sh
```

The script produces `macos/dist/UniFi SiteThread.app`, ad-hoc signed so the
keychain treats it as a stable identity.

```bash
open "dist/UniFi SiteThread.app"        # run it
cp -R "dist/UniFi SiteThread.app" /Applications/   # install it
```

## Disk image

To produce a drag-to-install `.dmg` instead:

```bash
cd macos
./package-dmg.sh
```

That writes `macos/dist/UniFi-SiteThread-<version>.dmg`. Open it and drag the
app to Applications.

A disk image is also built by CI on every push that touches `macos/`. Open the
run under the repository's **Actions → macOS app** tab and download the
`UniFi-SiteThread-dmg` artifact — useful when you want the app without
installing a toolchain.

The app is ad-hoc signed, not notarised with an Apple Developer ID. A disk image
you built yourself opens normally. One downloaded from CI or copied from another
Mac carries a quarantine flag, so clear it after installing:

```bash
xattr -dr com.apple.quarantine "/Applications/UniFi SiteThread.app"
```

Alternatively, right-click the app and choose **Open** the first time, then
confirm in the dialog.

To start it at login, add it under **System Settings → General → Login Items**.

### Try it without a console

```bash
SITE_THREAD_DEMO=1 "dist/UniFi SiteThread.app/Contents/MacOS/SiteThread"
```

Demo mode renders a fictional three-site fleet and makes no network requests.

### Tests

```bash
cd macos && swift test
```

These port `tests/test_security.py`: response bounds, credential and identifier
validation, host normalisation, and the site-health rules.

## Connect

1. Click the UniFi SiteThread icon in the menu bar.
2. Select **Sign in at unifi.ui.com** — this opens your normal browser.
3. In Site Manager, open **Settings → API Keys** and create an API key.
4. Return to the panel, paste the key into the masked field (or use **Paste API
   key from clipboard**), and select **Connect all sites**.

Every site owned by or shared with that UI Account is loaded. Selecting a site
opens its live Network view inside the panel; **Back** returns to the fleet.
Protect tabs appear only on consoles where Protect is installed.

Right-clicking the menu bar icon offers Refresh, Open unifi.ui.com, and Quit.

## What carried over

- Fleet-wide site, device, client, offline, firmware, ISP, and WAN-uptime view.
- Green online, yellow backup-WAN, red unreachable indicators, with a fixed red
  that does not follow the system accent colour.
- A menu bar badge that counts unreachable **sites** only, never offline devices.
- Two-check outage confirmation, so a brief cloud disconnect does not
  immediately mark a site red.
- Sites ordered by health first, then alphabetically.
- In-app site drill-down with Back navigation.
- Per-site Protect camera inventory with a snapshot that refreshes every 2.5
  seconds while the panel is open.
- Overview tiles that expand into clickable site, device, client, and issue
  lists.
- The optional local-console mode with certificate verification before any
  credential is transmitted.
- Every response bound — byte size, nesting depth, collection size, string
  length, row count, and pagination pages.

## Security model

No password is ever requested or stored. Sign-in happens in your browser at
`unifi.ui.com`; the app uses the official Site Manager API-key flow.

| Concern | Omarchy plugin (Linux) | This app (macOS) |
| --- | --- | --- |
| Credential store | `secret-tool` / Secret Service | Keychain generic password, `kSecAttrAccessibleWhenUnlocked` |
| Cloud transport | `curl` to `api.ui.com` | `URLSession`, public TLS, TLS 1.2 minimum |
| Local console trust | `curl --pinnedpubkey` (SPKI) | `URLSession` delegate pinning the leaf certificate SHA-256 |
| Clipboard | `wl-paste` | `NSPasteboard` |
| Snapshots | temp file, mode 0600 | held in memory, never written to disk |
| Connection file | `~/.config/site-thread/` | `~/Library/Application Support/UniFi SiteThread/`, 0700/0600 |

Two deliberate differences from the Linux helper:

- **The local-console pin is the leaf certificate's SHA-256, not its public
  key.** That is exactly the value the panel shows you and that the UniFi
  console displays under Settings → System, so what you verify is what gets
  pinned. It also means the pin must be re-established when the console's
  certificate is renewed: reconnect and verify the new fingerprint.
- **The API key travels in-process**, set as a request header rather than piped
  through a `curl` config file. It never appears in process arguments, the
  connection file, or logs.

Cloud requests use ordinary public TLS verification against `api.ui.com` — no
pinning, so Ubiquiti can rotate that certificate freely.

Create a dedicated UniFi user with the minimum permissions needed for Network
viewing and Protect viewing, then create an API key while signed in as that
user.

## Disconnect

**Disconnect** in the panel footer (click twice to confirm) removes both the
keychain item and the connection file. To remove the credential by hand:

```bash
security delete-generic-password -s com.larrywcox.site-thread -a default
```

## Settings

The panel has no settings screen. The two tunables from the Omarchy manifest are
read from user defaults:

```bash
defaults write com.larrywcox.site-thread refreshSeconds -int 60   # 10–600
defaults write com.larrywcox.site-thread panelWidth -int 520      # 360–1200
```

Restart the app to pick them up.

## Layout

```
macos/
├── build.sh                     assembles the .app bundle
├── Package.swift
├── Resources/Info.plist
├── Sources/
│   ├── SiteThreadCore/          no UI: models, limits, keychain, UniFi client
│   │   ├── Limits.swift         response bounds and credential patterns
│   │   ├── Models.swift         device/camera/site projections, health rules
│   │   ├── UniFiClient.swift    transport, pinning, certificate probe
│   │   ├── SummaryBuilder.swift port of the helper's summary builders
│   │   ├── Keychain.swift
│   │   ├── ConnectionStore.swift
│   │   └── Demo.swift
│   └── SiteThread/              AppKit shell + SwiftUI panel
└── Tests/SiteThreadCoreTests/
```

`SiteThreadCore` has no AppKit or SwiftUI dependency, which is what lets the
security-relevant logic be tested with `swift test`.

## License

MIT, same as the plugin.
