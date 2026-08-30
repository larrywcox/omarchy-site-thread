import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "larrywcox.site-thread"
  ipcTarget: "larrywcox.site-thread"
  manageIpc: false

  readonly property string helper: Qt.resolvedUrl("bin/site-thread").toString().replace(/^file:\/\//, "")
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: "#ff4d5a"
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color accent: Color.accent
  readonly property color healthy: "#42d66b"
  readonly property color backup: "#f2c94c"
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int panelWidth: setting("panelWidth", 760)
  readonly property int refreshSeconds: setting("refreshSeconds", 30)

  property var data: ({ connected: false })
  property bool loading: false
  property string notice: ""
  property int activeTab: 0
  property string pendingSecret: ""
  property string probeFingerprint: ""
  property bool certificateAccepted: false
  property string selectedCameraId: ""
  property string selectedCameraName: ""
  property string snapshotPath: ""
  property bool confirmDisconnect: false
  property bool localSetup: false
  property bool pasteForLocalConsole: false
  property var selectedSite: null
  property var siteData: ({})
  property bool siteLoading: false
  property int siteTab: 0
  property string overviewSelection: ""
  property var downConfirmations: ({})

  readonly property bool connected: data && data.connected === true
  readonly property bool cloudMode: connected && data.mode === "cloud"
  readonly property bool inSite: selectedSite !== null
  readonly property bool siteProtectInstalled: siteData !== null && siteData.protect !== undefined && siteData.protect.installed === true
  readonly property string severity: connected ? String(data.severity || "healthy") : "disconnected"
  readonly property int siteDownCount: connected && cloudMode ? countSitesWithStatus("down") : 0
  readonly property int siteBackupCount: connected && cloudMode ? countSitesWithStatus("backup") : 0
  readonly property string barSeverity: cloudMode
    ? (siteDownCount > 0 ? "critical" : (siteBackupCount > 0 ? "warning" : "healthy"))
    : severity
  readonly property int alertCount: connected
    ? (cloudMode
      ? siteDownCount
      : Number((data.network && data.network.offlineCount || 0) + (data.protect && data.protect.offlineCount || 0)))
    : 0

  function countSitesWithStatus(status) {
    var count = 0
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      if (String(sites[index].status || "up") === status) count++
    }
    return count
  }

  function countPendingSites() {
    var count = 0
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      if (sites[index].pendingDown === true) count++
    }
    return count
  }

  function stabilizeCloudSummary(parsed) {
    if (!parsed || parsed.ok !== true || parsed.mode !== "cloud" || !parsed.sites) return parsed
    var nextConfirmations = ({})
    for (var index = 0; index < parsed.sites.length; index++) {
      var site = parsed.sites[index]
      var key = String(site.hostId || "") + ":" + String(site.id || "")
      if (String(site.status || "up") === "down") {
        var failures = Number(downConfirmations[key] || 0) + 1
        nextConfirmations[key] = Math.min(2, failures)
        if (failures < 2) {
          site.status = "up"
          site.statusText = "Checking connectivity"
          site.pendingDown = true
        }
      }
    }
    downConfirmations = nextConfirmations

    var priority = ({ down: 0, backup: 1, up: 2 })
    parsed.sites.sort(function(left, right) {
      var leftRank = priority[String(left.status || "up")]
      var rightRank = priority[String(right.status || "up")]
      if (leftRank !== rightRank) return leftRank - rightRank
      var leftName = String(left.name || "").toLowerCase()
      var rightName = String(right.name || "").toLowerCase()
      return leftName < rightName ? -1 : (leftName > rightName ? 1 : 0)
    })

    var confirmedDown = 0
    var backupActive = 0
    for (var siteIndex = 0; siteIndex < parsed.sites.length; siteIndex++) {
      if (parsed.sites[siteIndex].status === "down") confirmedDown++
      else if (parsed.sites[siteIndex].status === "backup") backupActive++
    }
    var offlineDevices = Number(parsed.network && parsed.network.offlineCount || 0)
    var updates = Number(parsed.network && parsed.network.updateCount || 0)
    if (confirmedDown > 0) {
      parsed.severity = "critical"
      parsed.message = String(confirmedDown) + " site(s) unreachable"
    } else if (backupActive > 0) {
      parsed.severity = "warning"
      parsed.message = String(backupActive) + " site(s) using backup WAN"
    } else if (offlineDevices > 0) {
      parsed.severity = "critical"
      parsed.message = String(offlineDevices) + " device(s) offline across " + String(parsed.sites.length) + " sites"
    } else if (updates > 0) {
      parsed.severity = "warning"
      parsed.message = String(updates) + " firmware update(s) across " + String(parsed.sites.length) + " sites"
    } else {
      parsed.severity = "healthy"
      parsed.message = "All " + String(parsed.sites.length) + " sites operational"
    }
    return parsed
  }

  function refresh() {
    if (summaryProc.running) return
    loading = true
    notice = ""
    summaryProc.command = [helper, "summary"]
    summaryProc.running = true
  }

  function openSite(site) {
    if (!site || !site.hostId || !site.id) return
    selectedSite = site
    siteData = ({})
    siteTab = 0
    selectedCameraId = ""
    selectedCameraName = ""
    snapshotPath = ""
    loadSite()
  }

  function loadSite() {
    if (!inSite || siteProc.running) return
    siteLoading = true
    notice = ""
    siteProc.command = [helper, "site", String(selectedSite.hostId), String(selectedSite.id)]
    siteProc.running = true
  }

  function backToSites() {
    selectedSite = null
    siteData = ({})
    siteTab = 0
    selectedCameraId = ""
    selectedCameraName = ""
    snapshotPath = ""
    activeTab = 1
    notice = ""
  }

  function attentionSites() {
    var result = []
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      var site = sites[index]
      if (String(site.status || "up") !== "up") result.push(site)
    }
    return result
  }

  function siteAttentionColor(site) {
    if (site && String(site.status || "up") === "up" && Number(site.offlineCount || 0) > 0) return urgent
    return Model.siteColor(site ? site.status : "up", healthy, backup, urgent)
  }

  function overviewSiteItems(kind) {
    var result = []
    var sites = data && data.sites ? data.sites : []
    for (var index = 0; index < sites.length; index++) {
      var site = sites[index]
      if (kind === "sites"
          || (kind === "clients" && Number(site.clientCount || 0) > 0)
          || (kind === "offline" && String(site.status || "up") !== "up")) {
        result.push(site)
      }
    }
    if (kind === "clients") result.sort(function(left, right) { return Number(right.clientCount || 0) - Number(left.clientCount || 0) })
    return result
  }

  function overviewDeviceItems(kind) {
    var result = []
    var devices = data && data.network && data.network.devices ? data.network.devices : []
    for (var index = 0; index < devices.length; index++) {
      if (kind === "devices" || (kind === "offline" && devices[index].online !== true)) result.push(devices[index])
    }
    if (!cloudMode && kind === "cameras") {
      return data && data.protect && data.protect.cameras ? data.protect.cameras : []
    }
    return result
  }

  function selectOverview(kind) {
    overviewSelection = overviewSelection === kind ? "" : kind
  }

  function inspectCertificate() {
    if (probeProc.running || hostField.text.trim() === "") return
    probeFingerprint = ""
    certificateAccepted = false
    notice = "Inspecting the console certificate…"
    probeProc.command = [helper, "probe", hostField.text.trim()]
    probeProc.running = true
  }

  function connect() {
    if (connectProc.running || !certificateAccepted || probeFingerprint === "" || apiKeyField.text === "") return
    pendingSecret = apiKeyField.text
    apiKeyField.text = ""
    notice = "Authenticating securely…"
    connectProc.command = [helper, "connect", hostField.text.trim(), probeFingerprint]
    connectProc.running = true
  }

  function connectCloud() {
    if (cloudConnectProc.running || cloudKeyField.text === "") return
    pendingSecret = cloudKeyField.text
    cloudKeyField.text = ""
    notice = "Connecting to all UniFi sites…"
    cloudConnectProc.command = [helper, "connect-cloud"]
    cloudConnectProc.running = true
  }

  function pasteApiKey(forLocalConsole) {
    if (pasteProc.running) return
    pasteForLocalConsole = forLocalConsole === true
    notice = "Reading the clipboard…"
    pasteProc.running = true
  }

  function selectCamera(camera) {
    if (!camera) return
    selectedCameraId = String(camera.id || "")
    selectedCameraName = Model.safe(camera.name, "Camera")
    snapshotPath = ""
    if (selectedCameraId !== "") requestSnapshot()
  }

  function requestSnapshot() {
    var viewingProtect = inSite ? siteTab === 1 : activeTab === 2
    if (!opened || !viewingProtect || selectedCameraId === "" || snapshotProc.running) return
    snapshotProc.command = inSite
      ? [helper, "snapshot", selectedCameraId, String(selectedSite.hostId)]
      : [helper, "snapshot", selectedCameraId]
    snapshotProc.running = true
  }

  function openConsole() {
    if (!connected) return
    Quickshell.execDetached(["xdg-open", String(data.baseUrl || ("https://" + String(data.host || "")))])
  }

  function openAccount() {
    Quickshell.execDetached(["xdg-open", "https://unifi.ui.com"])
  }

  onOpenedChanged: {
    if (opened) {
      if (inSite) loadSite()
      else refresh()
    }
    else snapshotPath = ""
  }

  onActiveTabChanged: {
    if (!inSite && activeTab === 2 && data.protect && data.protect.cameras && data.protect.cameras.length > 0) {
      if (selectedCameraId === "") selectCamera(data.protect.cameras[0])
      else requestSnapshot()
    }
  }

  onSiteTabChanged: {
    if (inSite && siteTab === 1 && siteProtectInstalled && siteData.protect.cameras.length > 0) {
      if (selectedCameraId === "") selectCamera(siteData.protect.cameras[0])
      else requestSnapshot()
    }
  }

  Component.onCompleted: refresh()

  Process {
    id: summaryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Invalid helper response" })
        root.data = root.stabilizeCloudSummary(parsed)
        root.notice = parsed.ok ? "" : Model.safe(parsed.error, "Unable to load UniFi")
        root.loading = false
      }
    }
    onExited: function(exitCode) { root.loading = false }
  }

  Process {
    id: siteProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, error: "Invalid site response" })
        if (parsed.ok) {
          root.siteData = parsed
          root.notice = ""
          if (root.siteTab === 1 && parsed.protect && parsed.protect.cameras && parsed.protect.cameras.length > 0) {
            var selectedStillExists = false
            for (var index = 0; index < parsed.protect.cameras.length; index++) {
              if (String(parsed.protect.cameras[index].id) === root.selectedCameraId) selectedStillExists = true
            }
            if (!selectedStillExists) root.selectCamera(parsed.protect.cameras[0])
            else root.requestSnapshot()
          }
        } else root.notice = Model.safe(parsed.error, "Unable to load this site")
        root.siteLoading = false
      }
    }
    onExited: function(exitCode) { root.siteLoading = false }
  }

  Process {
    id: probeProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, error: "Certificate inspection failed" })
        if (parsed.ok) {
          root.probeFingerprint = String(parsed.fingerprint || "")
          root.certificateAccepted = parsed.trusted === true
          root.notice = parsed.trusted ? "Console identity already trusted" : "Compare this fingerprint with your UniFi console"
        } else root.notice = Model.safe(parsed.error, "Certificate inspection failed")
      }
    }
  }

  Process {
    id: connectProc
    stdinEnabled: true
    onStarted: {
      write(root.pendingSecret + "\n")
      root.pendingSecret = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Authentication failed" })
        root.data = root.stabilizeCloudSummary(parsed)
        if (parsed.ok) {
          root.notice = "Connected securely"
          root.probeFingerprint = ""
          root.certificateAccepted = false
        } else root.notice = Model.safe(parsed.error, "Authentication failed")
      }
    }
    onExited: root.pendingSecret = ""
  }

  Process {
    id: cloudConnectProc
    stdinEnabled: true
    onStarted: {
      write(root.pendingSecret + "\n")
      root.pendingSecret = ""
    }
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Site Manager authentication failed" })
        root.data = root.stabilizeCloudSummary(parsed)
        if (parsed.ok) {
          root.notice = "Connected to all accessible sites"
          root.activeTab = 0
        } else root.notice = Model.safe(parsed.error, "Site Manager authentication failed")
      }
    }
    onExited: root.pendingSecret = ""
  }

  Process {
    id: pasteProc
    command: ["wl-paste", "--no-newline", "--type", "text"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var value = String(text || "").trim()
        if (value === "") {
          root.notice = "No text was found on the clipboard"
          return
        }
        if (root.pasteForLocalConsole) apiKeyField.text = value
        else cloudKeyField.text = value
        root.notice = "API key pasted securely"
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.notice = "Clipboard access failed"
    }
  }

  Process {
    id: snapshotProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false })
        if (parsed.ok && parsed.path) root.snapshotPath = "file://" + parsed.path
      }
    }
  }

  Process {
    id: disconnectProc
    command: [root.helper, "disconnect"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.confirmDisconnect = false
        root.data = ({ connected: false })
        root.notice = "Connection removed"
      }
    }
  }

  Timer {
    interval: Math.max(10, root.refreshSeconds) * 1000
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.inSite ? root.loadSite() : root.refresh()
  }

  Timer {
    interval: 2500
    running: root.opened && root.selectedCameraId !== "" && (root.inSite ? root.siteTab === 1 : root.activeTab === 2)
    repeat: true
    triggeredOnStart: false
    onTriggered: root.requestSnapshot()
  }

  implicitWidth: button.implicitWidth + (badge.visible ? badge.width : 0)
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    parent: root
    x: 0
    y: 0
    height: parent ? parent.height : implicitHeight
    bar: root.bar
    text: Model.severityIcon(root.barSeverity)
    foreground: "#ffffff"
    activeColor: "#ffffff"
    useActiveColor: false
    active: root.connected && root.barSeverity !== "healthy"
    dimmed: false
    tooltipText: !root.connected
      ? "UniFi SiteThread · Connect"
      : "UniFi SiteThread · " + Model.safe(root.data.message, "Connected")
    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.refresh()
      else root.toggle()
    }
  }

  Rectangle {
    id: badge
    parent: root
    visible: root.alertCount > 0
    x: button.x + button.width - Style.space(4)
    y: Math.max(0, (root.height - height) / 2)
    width: Math.max(height, badgeText.implicitWidth + Style.space(6))
    height: Style.space(15)
    radius: height / 2
    color: root.urgent
    Text {
      id: badgeText
      anchors.centerIn: parent
      text: String(root.alertCount)
      color: "#ffffff"
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  PopupCard {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    triggerMode: "click"
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(Math.min(Style.space(650), content.implicitHeight))

    Flickable {
      id: scroll
      anchors.fill: parent
      contentWidth: width
      contentHeight: content.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height

      Column {
        id: content
        width: scroll.width
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(12)
          PanelActionButton {
            visible: root.inSite
            iconText: "\uf060"
            tooltipText: "Back to all sites"
            foreground: root.foreground
            fontFamily: root.fontFamily
            size: Style.space(28)
            onClicked: root.backToSites()
          }
          Text {
            text: "\uf233"
            color: "#ffffff"
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }
          Column {
            width: parent.width - Style.space(root.inSite ? 140 : 100)
            spacing: Style.space(2)
            Text {
              text: root.inSite ? Model.safe(root.selectedSite.name, "UNIFI SITE") : "UNIFI SITETHREAD"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }
            Text {
              text: root.inSite
                ? Model.safe(root.selectedSite.statusText, "Live site view")
                : (root.connected ? Model.summarySubtitle(root.data) : "Network + Protect")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }
          PanelActionButton {
            iconText: "\uf021"
            tooltipText: "Refresh"
            foreground: root.foreground
            fontFamily: root.fontFamily
            size: Style.space(28)
            onClicked: root.inSite ? root.loadSite() : root.refresh()
          }
          PanelActionButton {
            visible: root.connected && !root.inSite
            iconText: "\uf35d"
            tooltipText: "Open UniFi"
            foreground: root.foreground
            fontFamily: root.fontFamily
            size: Style.space(28)
            onClicked: root.openConsole()
          }
        }

        Text {
          visible: root.notice !== ""
          width: parent.width
          text: root.notice
          textFormat: Text.PlainText
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: root.notice.indexOf("failed") >= 0 || root.notice.indexOf("invalid") >= 0 ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Column {
          visible: !root.connected
          width: parent.width
          spacing: Style.space(12)

          PanelSectionHeader {
            width: parent.width
            text: root.localSetup ? "CONNECT TO A LOCAL UNIFI CONSOLE" : "SIGN IN TO UNIFI SITE MANAGER"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text {
            width: parent.width
            text: root.localSetup
              ? "Use this only for a console that is not available through your UI Account. The key stays in your encrypted desktop credential store."
              : "Sign in safely in your browser, create a UI Account API key, and UniFi SiteThread will combine every site you own or administer into one view. Your password never enters this plugin."
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Column {
            visible: !root.localSetup
            width: parent.width
            spacing: Style.space(10)

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: signInText.implicitWidth + Style.space(24)
                height: Style.space(36)
                radius: Style.cornerRadius
                color: signInArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                border.width: 1
                border.color: root.accent
                Text { id: signInText; anchors.centerIn: parent; text: "Sign in at unifi.ui.com"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                MouseArea { id: signInArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openAccount() }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Then open Settings → API Keys → Create New API Key"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            TextField {
              id: cloudKeyField
              width: parent.width
              password: true
              placeholderText: "UI Account API key"
              foreground: root.foreground
              accent: root.accent
              font.family: root.fontFamily
              Keys.onReturnPressed: root.connectCloud()
            }

            Text {
              width: parent.width
              text: pasteProc.running && !root.pasteForLocalConsole ? "Pasting…" : "Paste API key from clipboard"
              color: root.accent
              horizontalAlignment: Text.AlignRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.underline: cloudPasteArea.containsMouse
              MouseArea {
                id: cloudPasteArea
                anchors.fill: parent
                enabled: !pasteProc.running
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.pasteApiKey(false)
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(10)
              Rectangle {
                width: cloudConnectText.implicitWidth + Style.space(24)
                height: Style.space(36)
                radius: Style.cornerRadius
                opacity: cloudKeyField.text !== "" ? 1 : 0.45
                color: root.accent
                Text { id: cloudConnectText; anchors.centerIn: parent; text: cloudConnectProc.running ? "Connecting…" : "Connect all sites"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                MouseArea { anchors.fill: parent; enabled: cloudKeyField.text !== "" && !cloudConnectProc.running; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.connectCloud() }
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Includes sites shared with your UI Account"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text {
              width: parent.width
              text: "Use a local console connection instead"
              color: root.accent
              horizontalAlignment: Text.AlignRight
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.underline: localSetupArea.containsMouse
              MouseArea { id: localSetupArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.localSetup = true }
            }
          }

          TextField {
            id: hostField
            visible: root.localSetup
            width: parent.width
            placeholderText: "Console address · 192.168.1.1 or unifi.local"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            onTextChanged: {
              root.probeFingerprint = ""
              root.certificateAccepted = false
            }
            Keys.onReturnPressed: root.inspectCertificate()
          }

          Row {
            visible: root.localSetup
            width: parent.width
            spacing: Style.space(10)
            Rectangle {
              width: inspectText.implicitWidth + Style.space(20)
              height: Style.space(34)
              radius: Style.cornerRadius
              color: inspectArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
              border.width: 1
              border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.18)
              Text {
                id: inspectText
                anchors.centerIn: parent
                text: probeProc.running ? "Inspecting…" : "Inspect certificate"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
              }
              MouseArea {
                id: inspectArea
                anchors.fill: parent
                enabled: !probeProc.running
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.inspectCertificate()
              }
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "No credential is sent during this check"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          BorderSurface {
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            implicitHeight: fingerprintColumn.implicitHeight + Style.space(20)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14), 1)
            Column {
              id: fingerprintColumn
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(10)
              spacing: Style.space(8)
              Text {
                text: "CONSOLE CERTIFICATE · SHA-256"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Text {
                width: parent.width
                text: root.probeFingerprint
                color: root.foreground
                font.family: "monospace"
                font.pixelSize: Style.font.caption
                wrapMode: Text.WrapAnywhere
              }
              Row {
                spacing: Style.space(8)
                Rectangle {
                  width: Style.space(20)
                  height: width
                  radius: Style.space(4)
                  color: root.certificateAccepted ? root.accent : "transparent"
                  border.width: 1
                  border.color: root.certificateAccepted ? root.accent : root.dim
                  Text {
                    anchors.centerIn: parent
                    visible: root.certificateAccepted
                    text: "✓"
                    color: root.foreground
                    font.bold: true
                  }
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.certificateAccepted = !root.certificateAccepted
                  }
                }
                Text {
                  width: fingerprintColumn.width - Style.space(35)
                  text: "I verified this fingerprint in UniFi Console → Settings → System → Advanced"
                  wrapMode: Text.WordWrap
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          TextField {
            id: apiKeyField
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            password: true
            placeholderText: "UniFi API key"
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            Keys.onReturnPressed: root.connect()
          }

          Text {
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            text: pasteProc.running && root.pasteForLocalConsole ? "Pasting…" : "Paste API key from clipboard"
            color: root.accent
            horizontalAlignment: Text.AlignRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.underline: localPasteArea.containsMouse
            MouseArea {
              id: localPasteArea
              anchors.fill: parent
              enabled: !pasteProc.running
              hoverEnabled: true
              cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
              onClicked: root.pasteApiKey(true)
            }
          }

          Row {
            visible: root.localSetup && root.probeFingerprint !== ""
            width: parent.width
            spacing: Style.space(10)
            Rectangle {
              width: connectText.implicitWidth + Style.space(24)
              height: Style.space(36)
              radius: Style.cornerRadius
              opacity: root.certificateAccepted && apiKeyField.text !== "" ? 1 : 0.45
              color: root.accent
              Text {
                id: connectText
                anchors.centerIn: parent
                text: connectProc.running ? "Connecting…" : "Connect securely"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              MouseArea {
                anchors.fill: parent
                enabled: root.certificateAccepted && apiKeyField.text !== "" && !connectProc.running
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.connect()
              }
            }
          }

          Text {
            visible: root.localSetup
            width: parent.width
            text: "Use UI Account to show all sites"
            color: root.accent
            horizontalAlignment: Text.AlignRight
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            font.underline: cloudSetupArea.containsMouse
            MouseArea { id: cloudSetupArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.localSetup = false }
          }

        }

        Column {
          visible: root.connected && !root.inSite
          width: parent.width
          spacing: Style.space(12)

          Row {
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.cloudMode ? 2 : 3
              Rectangle {
                required property int index
                width: Math.floor((content.width - Style.space(root.cloudMode ? 6 : 12)) / (root.cloudMode ? 2 : 3))
                height: Style.space(34)
                radius: Style.cornerRadius
                color: root.activeTab === index
                  ? Style.selectedFillFor(root.foreground, root.accent)
                  : Style.normalFillFor(root.foreground, root.accent)
                border.width: root.activeTab === index ? 1 : 0
                border.color: root.accent
                Text {
                  anchors.centerIn: parent
                  text: Model.tabLabel(index, root.cloudMode)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: root.activeTab === index
                }
                MouseArea {
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.activeTab = index
                }
              }
            }
          }

          Column {
            visible: root.activeTab === 0
            width: parent.width
            spacing: Style.space(12)

            BorderSurface {
              width: parent.width
              implicitHeight: healthRow.implicitHeight + Style.space(24)
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
              radius: Style.cornerRadius
              borderSpec: Border.flat(root.severity === "critical" ? root.urgent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12), 1)
              Row {
                id: healthRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(12)
                spacing: Style.space(12)
                Text {
                  text: Model.severityIcon(root.severity)
                  color: root.severity === "critical" ? root.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
                Column {
                  width: parent.width - Style.space(50)
                  Text {
                    text: root.severity === "healthy" ? "All sites healthy" : (root.severity === "critical" ? "Attention required" : "UniFi SiteThread notice")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }
                  Text {
                    text: Model.safe(root.data.message, "Connected")
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                  }
                  Repeater {
                    model: root.cloudMode ? root.attentionSites() : []
                    Rectangle {
                      required property var modelData
                      width: parent.width
                      height: Style.space(27)
                      radius: Style.cornerRadius
                      color: attentionArea.containsMouse
                        ? Style.hoverFillFor(root.foreground, root.accent)
                        : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
                      Row {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: Style.space(7)
                        spacing: Style.space(8)
                        Rectangle {
                          width: Style.space(8)
                          height: width
                          radius: width / 2
                          color: root.siteAttentionColor(modelData)
                          anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                          width: parent.width - attentionState.implicitWidth - Style.space(25)
                          text: Model.safe(modelData.name, "UniFi site")
                          elide: Text.ElideRight
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.bodySmall
                          font.bold: true
                        }
                        Text {
                          id: attentionState
                          text: String(modelData.status || "up") !== "up"
                            ? String(modelData.statusText || "Needs attention")
                            : String(modelData.offlineCount || 0) + " device(s) offline"
                          color: root.siteAttentionColor(modelData)
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption
                        }
                      }
                      MouseArea {
                        id: attentionArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openSite(modelData)
                      }
                    }
                  }
                }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(8)
              Repeater {
                model: root.cloudMode ? [
                  { key: "sites", label: "SITES", value: root.data.sites ? root.data.sites.length : 0, icon: "\uf3c5" },
                  { key: "devices", label: "DEVICES", value: root.data.network ? root.data.network.deviceCount || 0 : 0, icon: "\uf233" },
                  { key: "clients", label: "CLIENTS", value: root.data.network ? root.data.network.clientCount || 0 : 0, icon: "\uf0c0" },
                  { key: "offline", label: "ISSUES", value: root.attentionSites().length + root.overviewDeviceItems("offline").length, icon: "\uf071" }
                ] : [
                  { key: "devices", label: "DEVICES", value: root.data.network ? root.data.network.deviceCount || 0 : 0, icon: "\uf233" },
                  { key: "clients", label: "CLIENTS", value: root.data.network ? root.data.network.clientCount || 0 : 0, icon: "\uf0c0" },
                  { key: "cameras", label: "CAMERAS", value: root.data.protect ? root.data.protect.cameraCount || 0 : 0, icon: "\uf03d" },
                  { key: "offline", label: "OFFLINE", value: root.alertCount, icon: "\uf071" }
                ]
                BorderSurface {
                  required property var modelData
                  width: Math.floor((content.width - Style.space(24)) / 4)
                  implicitHeight: statColumn.implicitHeight + Style.space(18)
                  color: root.overviewSelection === String(modelData.key || "")
                    ? Style.selectedFillFor(root.foreground, root.accent)
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                  radius: Style.cornerRadius
                  borderSpec: Border.flat(root.overviewSelection === String(modelData.key || "") ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10), 1)
                  Column {
                    id: statColumn
                    anchors.centerIn: parent
                    spacing: Style.space(3)
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.icon; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.subtitle }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(modelData.value); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                    Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectOverview(String(modelData.key || ""))
                  }
                }
              }
            }

            Column {
              visible: root.overviewSelection !== ""
              width: parent.width
              spacing: Style.space(8)

              PanelSectionHeader {
                width: parent.width
                text: root.overviewSelection === "sites" ? "ALL SITES"
                  : (root.overviewSelection === "devices" ? "DEVICES"
                  : (root.overviewSelection === "clients" ? "CLIENTS BY SITE"
                  : (root.overviewSelection === "cameras" ? "CAMERAS" : "SITES AND DEVICES NEEDING ATTENTION")))
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Repeater {
                model: root.cloudMode ? root.overviewSiteItems(root.overviewSelection) : []
                BorderSurface {
                  required property var modelData
                  width: content.width
                  implicitHeight: overviewSiteRow.implicitHeight + Style.space(14)
                  color: overviewSiteArea.containsMouse
                    ? Style.hoverFillFor(root.foreground, root.accent)
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
                  radius: Style.cornerRadius
                  borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09), 1)
                  Row {
                    id: overviewSiteRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(8)
                    spacing: Style.space(9)
                    Rectangle {
                      width: Style.space(9)
                      height: width
                      radius: width / 2
                      color: root.siteAttentionColor(modelData)
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                      width: parent.width - overviewSiteValue.implicitWidth - Style.space(30)
                      Text { width: parent.width; text: Model.safe(modelData.name, "UniFi site"); elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                      Text { width: parent.width; text: Model.safe(modelData.isp, "") + (modelData.isp ? "  ·  " : "") + Model.safe(modelData.statusText, "Online"); elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    }
                    Text {
                      id: overviewSiteValue
                      text: root.overviewSelection === "clients"
                        ? String(modelData.clientCount || 0) + " CLIENTS"
                        : (root.overviewSelection === "offline" && Number(modelData.offlineCount || 0) > 0
                          ? String(modelData.offlineCount) + " OFFLINE"
                          : String(modelData.deviceCount || 0) + " DEVICES")
                      color: root.overviewSelection === "offline" ? root.siteAttentionColor(modelData) : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                  MouseArea {
                    id: overviewSiteArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openSite(modelData)
                  }
                }
              }

              Repeater {
                model: root.overviewDeviceItems(root.overviewSelection)
                BorderSurface {
                  required property var modelData
                  width: content.width
                  implicitHeight: overviewDeviceRow.implicitHeight + Style.space(14)
                  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
                  radius: Style.cornerRadius
                  borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09), 1)
                  Row {
                    id: overviewDeviceRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(8)
                    spacing: Style.space(9)
                    Rectangle { width: Style.space(9); height: width; radius: width / 2; color: modelData.online ? root.healthy : root.urgent; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                      width: parent.width - Style.space(125)
                      Text { width: parent.width; text: Model.safe(modelData.name, root.overviewSelection === "cameras" ? "Camera" : "UniFi device"); elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                      Text { width: parent.width; text: Model.safe(modelData.site, Model.safe(modelData.model, "")); elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    }
                    Text { text: modelData.online ? (modelData.update ? "UPDATE" : "ONLINE") : "OFFLINE"; color: modelData.online ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                  }
                }
              }

              Text {
                visible: root.overviewSiteItems(root.overviewSelection).length === 0
                  && root.overviewDeviceItems(root.overviewSelection).length === 0
                width: parent.width
                text: root.overviewSelection === "clients"
                  ? "Client totals are available by site after connecting through UI Account"
                  : "No matching items"
                horizontalAlignment: Text.AlignHCenter
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }
            }

          }

          Column {
            visible: root.activeTab === 1
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: root.cloudMode ? "ALL SITES" : "NETWORK DEVICES"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.cloudMode
                ? (root.data.sites || [])
                : (root.data.network && root.data.network.devices ? root.data.network.devices : [])
              BorderSurface {
                required property var modelData
                width: content.width
                implicitHeight: deviceRow.implicitHeight + Style.space(16)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09), 1)
                Row {
                  id: deviceRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(9)
                  spacing: Style.space(10)
                  Rectangle {
                    width: Style.space(9)
                    height: width
                    radius: width / 2
                    color: root.cloudMode
                      ? Model.siteColor(modelData.status, root.healthy, root.backup, root.urgent)
                      : (modelData.online ? root.healthy : root.urgent)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                  Column {
                    width: parent.width - Style.space(root.cloudMode ? 250 : 130)
                    Text { text: Model.safe(modelData.name, root.cloudMode ? "UniFi site" : "UniFi device"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                    Text {
                      text: root.cloudMode
                        ? String(modelData.deviceCount || 0) + " devices  ·  " + String(modelData.clientCount || 0) + " clients" + (modelData.isp ? "  ·  " + Model.safe(modelData.isp, "") : "") + "  ·  WAN " + Number(modelData.wanUptime || 0).toFixed(2) + "%"
                        : Model.safe(modelData.model, "") + (modelData.ip ? "  ·  " + Model.safe(modelData.ip, "") : "")
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                  Text { visible: !root.cloudMode && modelData.update === true; text: "UPDATE"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                  Text {
                    text: root.cloudMode
                      ? String(modelData.statusText || "Online").toUpperCase()
                      : (modelData.online ? "ONLINE" : "OFFLINE")
                    color: root.cloudMode
                      ? Model.siteColor(modelData.status, root.healthy, root.backup, root.urgent)
                      : (modelData.online ? root.dim : root.urgent)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
                MouseArea { anchors.fill: parent; enabled: root.cloudMode; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.openSite(modelData) }
              }
            }
            Text { visible: !root.data.network || !root.data.network.available; width: parent.width; text: "UniFi Network is unavailable for this connection"; horizontalAlignment: Text.AlignHCenter; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }

          Column {
            visible: root.activeTab === 2
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: root.cloudMode ? "PROTECT ACROSS ALL SITES" : "PROTECT CAMERAS"; foreground: root.foreground; fontFamily: root.fontFamily }

            Rectangle {
              visible: root.selectedCameraId !== ""
              width: parent.width
              height: Math.round(width * 9 / 16)
              radius: Style.cornerRadius
              color: Qt.rgba(0, 0, 0, 0.35)
              clip: true
              Image { anchors.fill: parent; source: root.snapshotPath; fillMode: Image.PreserveAspectCrop; cache: false; asynchronous: true }
              Text { anchors.centerIn: parent; visible: root.snapshotPath === ""; text: root.cloudMode ? "Open Site Manager for live video" : "Loading " + root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                width: cameraLabel.implicitWidth + Style.space(12)
                height: cameraLabel.implicitHeight + Style.space(6)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.62)
                Text { id: cameraLabel; anchors.centerIn: parent; text: root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            Row {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.data.protect && root.data.protect.cameras ? root.data.protect.cameras : []
                Rectangle {
                  required property var modelData
                  width: Math.max(Style.space(110), Math.floor((content.width - Style.space(18)) / Math.min(4, root.data.protect.cameras.length)))
                  height: Style.space(52)
                  radius: Style.cornerRadius
                  color: String(modelData.id) === root.selectedCameraId ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                  border.width: String(modelData.id) === root.selectedCameraId ? 1 : 0
                  border.color: root.accent
                  Column {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(12)
                    Text { width: parent.width; text: Model.safe(modelData.name, "Camera"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
                    Text { width: parent.width; text: modelData.online ? "ONLINE" : "OFFLINE"; color: modelData.online ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; horizontalAlignment: Text.AlignHCenter }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectCamera(modelData) }
                }
              }
            }
            Text { visible: !root.data.protect || !root.data.protect.available; width: parent.width; text: root.cloudMode ? "Site Manager did not report Protect devices for this account" : "UniFi Protect is unavailable for this connection"; horizontalAlignment: Text.AlignHCenter; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) }

          Row {
            width: parent.width
            spacing: Style.space(10)
            Text {
              width: parent.width - disconnectButton.width - Style.space(10)
              text: root.cloudMode ? "UI Account key stored securely in Secret Service" : "Credentials stored securely in Secret Service"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }
            Rectangle {
              id: disconnectButton
              width: disconnectText.implicitWidth + Style.space(18)
              height: Style.space(30)
              radius: Style.cornerRadius
              color: disconnectArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
              Text { id: disconnectText; anchors.centerIn: parent; text: root.confirmDisconnect ? "Click again to forget" : "Disconnect"; color: root.confirmDisconnect ? root.urgent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              MouseArea {
                id: disconnectArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!root.confirmDisconnect) root.confirmDisconnect = true
                  else disconnectProc.running = true
                }
              }
            }
          }
        }

        Column {
          visible: root.connected && root.inSite
          width: parent.width
          spacing: Style.space(12)

          BorderSurface {
            width: parent.width
            implicitHeight: siteHealthRow.implicitHeight + Style.space(22)
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.045)
            radius: Style.cornerRadius
            borderSpec: Border.flat(Model.siteColor(root.selectedSite ? root.selectedSite.status : "up", root.healthy, root.backup, root.urgent), 1)
            Row {
              id: siteHealthRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              anchors.margins: Style.space(11)
              spacing: Style.space(10)
              Rectangle {
                width: Style.space(12)
                height: width
                radius: width / 2
                color: Model.siteColor(root.selectedSite ? root.selectedSite.status : "up", root.healthy, root.backup, root.urgent)
                anchors.verticalCenter: parent.verticalCenter
              }
              Column {
                width: parent.width - Style.space(32)
                Text { text: Model.safe(root.selectedSite ? root.selectedSite.statusText : "", "Online"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                Text {
                  text: (root.selectedSite && root.selectedSite.isp ? Model.safe(root.selectedSite.isp, "") + "  ·  " : "") + "Live data from this UniFi console"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          Text {
            visible: root.siteLoading
            width: parent.width
            text: "Loading live site data…"
            horizontalAlignment: Text.AlignHCenter
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Row {
            visible: root.siteData && root.siteData.ok === true
            width: parent.width
            spacing: Style.space(6)
            Repeater {
              model: root.siteProtectInstalled ? 2 : 1
              Rectangle {
                required property int index
                width: Math.floor((content.width - (root.siteProtectInstalled ? Style.space(6) : 0)) / (root.siteProtectInstalled ? 2 : 1))
                height: Style.space(34)
                radius: Style.cornerRadius
                color: root.siteTab === index ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                border.width: root.siteTab === index ? 1 : 0
                border.color: root.accent
                Text {
                  anchors.centerIn: parent
                  text: index === 0 ? "Network" : "Protect"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: root.siteTab === index
                }
                MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.siteTab = index }
              }
            }
          }

          Row {
            visible: root.siteData && root.siteData.ok === true
            width: parent.width
            spacing: Style.space(8)
            Repeater {
              model: [
                { label: "DEVICES", value: root.siteData.network ? root.siteData.network.deviceCount || 0 : 0 },
                { label: "CLIENTS", value: root.siteData.network ? root.siteData.network.clientCount || 0 : 0 },
                { label: "OFFLINE", value: root.siteData.network ? root.siteData.network.offlineCount || 0 : 0 },
                { label: "CAMERAS", value: root.siteProtectInstalled && root.siteData.protect ? root.siteData.protect.cameraCount || 0 : 0 }
              ]
              BorderSurface {
                required property var modelData
                width: Math.floor((content.width - Style.space(24)) / 4)
                implicitHeight: siteStat.implicitHeight + Style.space(16)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10), 1)
                Column {
                  id: siteStat
                  anchors.centerIn: parent
                  spacing: Style.space(2)
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: String(modelData.value); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                }
              }
            }
          }

          Column {
            visible: root.siteData && root.siteData.ok === true && root.siteTab === 0
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "LIVE NETWORK DEVICES"; foreground: root.foreground; fontFamily: root.fontFamily }
            Repeater {
              model: root.siteData.network && root.siteData.network.devices ? root.siteData.network.devices : []
              BorderSurface {
                required property var modelData
                width: content.width
                implicitHeight: siteDeviceRow.implicitHeight + Style.space(16)
                color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.035)
                radius: Style.cornerRadius
                borderSpec: Border.flat(Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.09), 1)
                Row {
                  id: siteDeviceRow
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.margins: Style.space(9)
                  spacing: Style.space(10)
                  Rectangle { width: Style.space(9); height: width; radius: width / 2; color: modelData.online ? root.healthy : root.urgent; anchors.verticalCenter: parent.verticalCenter }
                  Column {
                    width: parent.width - Style.space(125)
                    Text { width: parent.width; text: Model.safe(modelData.name, "UniFi device"); elide: Text.ElideRight; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                    Text { width: parent.width; text: Model.safe(modelData.model, "") + (modelData.ip ? "  ·  " + Model.safe(modelData.ip, "") : ""); elide: Text.ElideRight; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  Text { text: modelData.online ? (modelData.update ? "UPDATE" : "ONLINE") : "OFFLINE"; color: modelData.online ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                }
              }
            }
            Text {
              visible: !root.siteData.network || root.siteData.network.devices.length === 0
              width: parent.width
              text: "No Network devices were returned for this site"
              horizontalAlignment: Text.AlignHCenter
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }

          Column {
            visible: root.siteProtectInstalled && root.siteTab === 1
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "LIVE PROTECT CAMERAS"; foreground: root.foreground; fontFamily: root.fontFamily }
            Rectangle {
              visible: root.selectedCameraId !== ""
              width: parent.width
              height: Math.round(width * 9 / 16)
              radius: Style.cornerRadius
              color: Qt.rgba(0, 0, 0, 0.45)
              clip: true
              Image { anchors.fill: parent; source: root.snapshotPath; fillMode: Image.PreserveAspectFit; cache: false; asynchronous: true }
              Text { anchors.centerIn: parent; visible: root.snapshotPath === ""; text: "Loading " + root.selectedCameraName + "…"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body }
              Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                width: liveCameraLabel.implicitWidth + Style.space(14)
                height: liveCameraLabel.implicitHeight + Style.space(7)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.68)
                Text { id: liveCameraLabel; anchors.centerIn: parent; text: "LIVE · " + root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }
            Flow {
              width: parent.width
              spacing: Style.space(6)
              Repeater {
                model: root.siteData.protect && root.siteData.protect.cameras ? root.siteData.protect.cameras : []
                Rectangle {
                  required property var modelData
                  width: Math.floor((content.width - Style.space(18)) / 4)
                  height: Style.space(52)
                  radius: Style.cornerRadius
                  color: String(modelData.id) === root.selectedCameraId ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                  border.width: String(modelData.id) === root.selectedCameraId ? 1 : 0
                  border.color: root.accent
                  Column {
                    anchors.centerIn: parent
                    width: parent.width - Style.space(10)
                    Text { width: parent.width; text: Model.safe(modelData.name, "Camera"); elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { width: parent.width; text: modelData.online ? "ONLINE" : "OFFLINE"; horizontalAlignment: Text.AlignHCenter; color: modelData.online ? root.healthy : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectCamera(modelData) }
                }
              }
            }
            Text {
              visible: root.siteProtectInstalled && root.siteData.protect.cameras.length === 0
              width: parent.width
              text: "Protect is installed, but no cameras were returned"
              horizontalAlignment: Text.AlignHCenter
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function tab(index: int): void {
      root.activeTab = Math.max(0, Math.min(2, index))
      root.open()
    }
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        hasBar: root.bar !== null,
        rootWindow: root.QsWindow.window !== null,
        buttonWindow: button.QsWindow.window !== null,
        buttonParentIsRoot: button.parent === root,
        contentParentExists: content.parent !== null,
        contentWidth: content.width,
        popupVisible: popup.visible,
        popupOpen: popup.open,
        popupWidth: popup.width,
        popupHeight: popup.height,
        contentHeight: content.implicitHeight,
        downSiteCount: root.siteDownCount,
        pendingDownCount: root.countPendingSites()
      })
    }
  }
}
