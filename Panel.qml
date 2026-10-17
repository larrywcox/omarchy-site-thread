import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "views"
import "components"
import "Model.js" as Model
import "GlobeModel.js" as GlobeModel

Panel {
  id: root
  moduleName: "larrywcox.site-thread"
  ipcTarget: "larrywcox.site-thread"
  manageIpc: false

  readonly property string helper: Qt.resolvedUrl("bin/site-thread").toString().replace(/^file:\/\//, "")
  readonly property color foreground: (bar && bar.barForeground) ? bar.barForeground : ((bar && bar.foreground) ? bar.foreground : (Color.foreground || "#D8DEE9"))
  readonly property color urgent: (bar && bar.urgent) ? bar.urgent : (Color.urgent || "#ff4d5a")
  readonly property color accent: (bar && bar.accent) ? bar.accent : (Color.accent || "#89B4FA")
  readonly property color healthy: "#10b981"
  readonly property color backup: "#f59e0b"

  readonly property bool isLightTheme: {
    var bg = (bar && bar.background) ? bar.background : (Color.background || "#1E1E2E")
    var bgLum = (bg.r * 0.299 + bg.g * 0.587 + bg.b * 0.114)
    var fgLum = (foreground.r * 0.299 + foreground.g * 0.587 + foreground.b * 0.114)
    return bgLum > 0.5 || fgLum < 0.5
  }

  function contrastTextFor(c) {
    if (!c) return "#ffffff"
    var lum = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
    return lum > 0.55 ? "#0f141c" : "#ffffff"
  }
  readonly property color accentForeground: contrastTextFor(accent)
  readonly property color healthyForeground: contrastTextFor(healthy)
  readonly property color backupForeground: contrastTextFor(backup)
  readonly property color urgentForeground: contrastTextFor(urgent)

  readonly property color dim: isLightTheme
    ? Qt.rgba(foreground.r * 0.70 + ((bar && bar.background) ? bar.background.r : 1.0) * 0.30,
              foreground.g * 0.70 + ((bar && bar.background) ? bar.background.g : 1.0) * 0.30,
              foreground.b * 0.70 + ((bar && bar.background) ? bar.background.b : 1.0) * 0.30, 1.0)
    : Qt.darker(foreground, 1.35)
  readonly property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.04 : 0.055)
  readonly property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.08 : 0.085)
  readonly property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.14 : 0.18)
  readonly property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.12 : 0.24)

  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int panelWidth: setting("panelWidth", 450)
  property int refreshSeconds: setting("refreshSeconds", 30)
  property int activeRefreshSeconds: setting("activeRefreshSeconds", 15)
  property int idleRefreshSeconds: setting("idleRefreshSeconds", 120)
  readonly property bool isUiActive: root.opened || root.analyticsOpen
  readonly property int currentRefreshIntervalSec: isUiActive ? Math.max(10, Math.min(15, root.activeRefreshSeconds)) : Math.max(60, Math.min(300, root.idleRefreshSeconds))
  readonly property int currentRefreshIntervalMs: currentRefreshIntervalSec * 1000

  onIsUiActiveChanged: {
    if (typeof refreshTimer !== "undefined" && refreshTimer) {
      refreshTimer.interval = root.currentRefreshIntervalMs
      refreshTimer.restart()
    }
    if (isUiActive) {
      var ageSec = (Date.now() - root.lastRefreshMs) / 1000
      if (ageSec >= root.activeRefreshSeconds) {
        if (root.inSite) root.loadSite()
        else root.refresh()
      }
    }
  }

  onActiveRefreshSecondsChanged: {
    if (typeof refreshTimer !== "undefined" && refreshTimer) refreshTimer.interval = root.currentRefreshIntervalMs
  }
  onIdleRefreshSecondsChanged: {
    if (typeof refreshTimer !== "undefined" && refreshTimer) refreshTimer.interval = root.currentRefreshIntervalMs
  }

  property bool autoRotate: false
  property string issueFilter: "all"
  property string deviceFilter: "all"
  property string sitesSubView: "sites"
  property int refreshAgeSec: 0
  property double lastRefreshMs: Date.now()
  property bool analyticsOpen: false
  property bool settingsMode: false
  property bool enableMultiDot: setting("enableMultiDot", true)
  property string badgeMode: setting("badgeMode", "alerts")
  property string preferredTerminal: setting("terminalCommand", "xdg-terminal-exec")
  property bool enableNotifications: setting("enableNotifications", true)

  property var diagnosticsData: null
  property string lastErrorText: ""
  property bool diagnosticsRunning: false

  property int analyticsTab: 0

  function openSettings() {
    settingsMode = true
    root.runDiagnostics()
  }
  function closeSettings() { settingsMode = false }
  function openAnalytics(tabIndex) {
    root.close()
    // Extended from Math.min(4, tabIndex) to support tabs 0..6 (default to 0 Overview)
    var targetTab = (tabIndex !== undefined && tabIndex !== null) ? Math.max(0, Math.min(6, tabIndex)) : 0
    root.analyticsTab = targetTab
    analyticsOpen = true
    if (analyticsWindowLoader.item) {
      analyticsWindowLoader.item.currentTab = targetTab
    }
  }
  function closeAnalytics() {
    analyticsOpen = false
    root.analyticsTab = 0
    if (analyticsWindowLoader.item) {
      analyticsWindowLoader.item.currentTab = 0
    }
  }
  function toggleAnalytics() {
    if (!analyticsOpen) {
      root.close()
      root.analyticsTab = 0
      analyticsOpen = true
      if (analyticsWindowLoader.item) {
        analyticsWindowLoader.item.currentTab = 0
      }
    } else {
      root.closeAnalytics()
    }
  }

  function goToMainPage() {
    if (root.analyticsOpen) root.closeAnalytics()
    if (root.inSite) root.backToSites()
    root.settingsMode = false
    root.activeTab = 0
    root.sitesSubView = "sites"
  }

  function handleBarClick(b) {
    if (b === Qt.RightButton) {
      if (!root.opened) root.open()
      root.settingsMode = true
    } else if (b === Qt.MiddleButton) {
      if (root.inSite) root.loadSite()
      else root.refresh()
    } else {
      if (root.opened) {
        if (root.inSite || root.settingsMode || root.activeTab !== 0) {
          root.goToMainPage()
        } else {
          root.close()
        }
      } else {
        root.goToMainPage()
        root.open()
      }
    }
  }

  function getBadgeText() {
    if (root.badgeMode === "off") return ""
    if (root.badgeMode === "clients") {
      return String(root.data && root.data.network && root.data.network.clientCount ? root.data.network.clientCount : "")
    } else if (root.badgeMode === "sites") {
      return (root.data && root.data.sites) ? (root.data.sites.length + "/" + root.data.sites.length) : ""
    } else if (root.badgeMode === "updates") {
      return String(root.data && root.data.network && root.data.network.updateCount ? root.data.network.updateCount : "")
    }
    return root.alertCount > 0 ? String(root.alertCount) : ""
  }

  function sendDesktopNotification(title, message, urgency) {
    if (!root.enableNotifications) return
    var u = urgency || "normal"
    var t = title || "UniFi SiteThread"
    var m = message || ""
    Quickshell.execDetached(["notify-send", "--app-name=UniFi SiteThread", "-i", "network-wired", "-u", u, t, m])
  }

  function testNotification() {
    sendDesktopNotification("UniFi SiteThread Alert", "Desktop notifications are working! WAN Failover & Site Outage alerts enabled.", "normal")
  }

  function getTerminalArgs(cmdArgs, workspacePath) {
    var termSetting = root.preferredTerminal || ""
    var ws = workspacePath || ""
    if (ws.indexOf("file://") === 0) ws = decodeURIComponent(ws.substring(7))

    if (!termSetting || termSetting === "xdg-terminal-exec") {
      var args = ["xdg-terminal-exec"]
      if (ws) args.push("--dir=" + ws)
      args.push("--")
      return args.concat(cmdArgs)
    }

    var parts = termSetting.split(/\s+/).filter(function(p) { return p.length > 0 })
    var bin = parts[0].split("/").pop()
    if (bin === "xdg-terminal-exec") {
      if (ws) parts.push("--dir=" + ws)
      parts.push("--")
      return parts.concat(cmdArgs)
    } else if (bin === "foot") {
      if (ws) parts.push("-D", ws)
      return parts.concat(cmdArgs)
    } else if (bin === "kitty") {
      if (ws) parts.push("-d", ws)
      return parts.concat(cmdArgs)
    } else if (bin === "ghostty") {
      if (ws) parts.push("--working-directory=" + ws)
      if (parts.indexOf("-e") === -1) parts.push("-e")
      return parts.concat(cmdArgs)
    } else if (bin === "alacritty") {
      if (ws) parts.push("--working-directory", ws)
      if (parts.indexOf("-e") === -1) parts.push("-e")
      return parts.concat(cmdArgs)
    } else {
      if (parts.indexOf("-e") !== -1 || parts.indexOf("--") !== -1) {
        return parts.concat(cmdArgs)
      }
      return parts.concat(["-e"]).concat(cmdArgs)
    }
  }

  function launchSsh(host, user) {
    var u = user || "root"
    var h = host || ""
    if (!h) return
    var target = u ? (u + "@" + h) : h
    var termArgs = getTerminalArgs(["ssh", target])
    Quickshell.execDetached(termArgs)
  }

  function launchPing(host) {
    if (!host) return
    var termArgs = getTerminalArgs(["ping", host])
    Quickshell.execDetached(termArgs)
  }

  function updateSetting(name, value) {
    if (name === "enableMultiDot") root.enableMultiDot = value
    else if (name === "badgeMode") root.badgeMode = value
    else if (name === "terminalCommand") root.preferredTerminal = value
    else if (name === "autoRotate") root.autoRotate = value
    else if (name === "enableNotifications") root.enableNotifications = value
    else if (name === "activeRefreshSeconds") root.activeRefreshSeconds = value
    else if (name === "idleRefreshSeconds") root.idleRefreshSeconds = value
    else if (name === "refreshSeconds") root.refreshSeconds = value

    var next = Object.assign({}, root.settings || {})
    next[name] = value
    if (typeof root.writeSettings === "function") {
      root.writeSettings(next)
    } else if (root.settings !== undefined) {
      root.settings = next
    }
  }

  function clearResolvedIssues() {
    clearHistoryProc.command = [root.helper, "clear-history"]
    clearHistoryProc.running = true
  }

  function getAllFleetDevices() {
    var out = []
    if (root.data && root.data.network && Array.isArray(root.data.network.devices)) {
      out = out.concat(root.data.network.devices)
    }
    if (root.data && Array.isArray(root.data.devices)) {
      for (var i = 0; i < root.data.devices.length; i++) {
        var d = root.data.devices[i]
        var exists = false
        for (var j = 0; j < out.length; j++) {
          if ((d.mac && out[j].mac === d.mac) || (d.name && out[j].name === d.name && d.ip === out[j].ip)) {
            exists = true
            break
          }
        }
        if (!exists) out.push(d)
      }
    }
    if (root.data && Array.isArray(root.data.sites)) {
      for (var k = 0; k < root.data.sites.length; k++) {
        var s = root.data.sites[k]
        if (s.gatewayModel && s.gatewayIp) {
          var gwFound = false
          for (var m = 0; m < out.length; m++) {
            if (out[m].ip === s.gatewayIp) { gwFound = true; break }
          }
          if (!gwFound) {
            out.unshift({
              name: s.name + " Gateway (" + s.gatewayModel + ")",
              model: s.gatewayModel,
              ip: s.gatewayIp,
              site: s.name,
              online: s.status !== "down",
              category: "gateways"
            })
          }
        }
      }
    }
    return out
  }

  function getSiteConsole(hostId) {
    if (root.siteData && root.siteData.console && root.siteData.console.hostId) {
      return root.siteData.console
    }
    if (root.data && Array.isArray(root.data.consoles)) {
      var hid = String(hostId || (root.selectedSite ? root.selectedSite.hostId : "") || "")
      var sName = root.selectedSite ? String(root.selectedSite.name || "") : ""
      for (var i = 0; i < root.data.consoles.length; i++) {
        var c = root.data.consoles[i]
        if (hid && String(c.hostId || "") === hid) return c
        if (sName && String(c.siteName || "") === sName) return c
      }
    }
    return null
  }

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
  property string priorSnapshotPath: ""
  property string cameraPermissionError: ""
  property bool confirmDisconnect: false
  property bool localSetup: false
  property bool pasteForLocalConsole: false
  property var selectedSite: null
  property var siteData: ({})
  property bool siteLoading: false
  property bool siteLiveRefreshing: false
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
  readonly property var issuesList: data && data.issues ? data.issues : []
  readonly property int activeIssuesCount: {
    var count = 0
    for (var i = 0; i < issuesList.length; i++) {
      if (issuesList[i].active === true) count++
    }
    return count
  }
  readonly property int alertCount: connected
    ? (cloudMode
      ? Math.max(siteDownCount + siteBackupCount, activeIssuesCount)
      : Number((data.network && data.network.offlineCount || 0) + (data.protect && data.protect.offlineCount || 0) + activeIssuesCount))
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
    } else if (parsed.partial && parsed.failedEndpoints && parsed.failedEndpoints.length > 0) {
      parsed.severity = "warning"
      parsed.message = "Partial fleet telemetry (" + parsed.failedEndpoints.join(", ") + " failed)"
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
    if (root.snapshotPath) root.deleteSnapshotFile(root.snapshotPath)
    if (root.priorSnapshotPath) root.deleteSnapshotFile(root.priorSnapshotPath)
    selectedSite = site
    siteData = ({})
    siteTab = 0
    selectedCameraId = ""
    selectedCameraName = ""
    snapshotPath = ""
    priorSnapshotPath = ""
    siteLoading = true
    siteLiveRefreshing = true
    loadSite()
  }

  function loadSite() {
    if (!inSite) return
    notice = ""

    // 1. Immediately request cached data if available (instant response)
    siteCachedProc.command = [helper, "site", String(selectedSite.hostId), String(selectedSite.id), "--cached-only"]
    siteCachedProc.running = true

    // 2. Launch background live refresh
    if (!siteProc.running) {
      siteLoading = (!siteData || !siteData.ok)
      siteLiveRefreshing = true
      siteProc.command = [helper, "site", String(selectedSite.hostId), String(selectedSite.id), "--live"]
      siteProc.running = true
    }
  }

  function backToSites() {
    if (root.snapshotPath) root.deleteSnapshotFile(root.snapshotPath)
    if (root.priorSnapshotPath) root.deleteSnapshotFile(root.priorSnapshotPath)
    selectedSite = null
    siteData = ({})
    siteTab = 0
    selectedCameraId = ""
    selectedCameraName = ""
    snapshotPath = ""
    priorSnapshotPath = ""
    activeTab = 1
    sitesSubView = "sites"
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

  function deleteSnapshotFile(filePath) {
    if (!filePath) return
    var cleanPath = String(filePath).replace(/^file:\/\//, "").split("?")[0].split("#")[0]
    if (cleanPath.indexOf("camera-") !== -1) {
      Quickshell.execDetached(["rm", "-f", cleanPath])
    }
  }

  function cleanupPriorSnapshot() {
    if (root.priorSnapshotPath && root.priorSnapshotPath !== "") {
      var pClean = String(root.priorSnapshotPath).replace(/^file:\/\//, "").split("?")[0].split("#")[0]
      var curClean = String(root.snapshotPath).replace(/^file:\/\//, "").split("?")[0].split("#")[0]
      if (pClean !== curClean) {
        root.deleteSnapshotFile(pClean)
      }
      root.priorSnapshotPath = ""
    }
  }

  function selectCamera(camera) {
    if (!camera) return
    var newCamId = String(camera.id || "")
    if (selectedCameraId !== newCamId) {
      if (root.snapshotPath) root.deleteSnapshotFile(root.snapshotPath)
      if (root.priorSnapshotPath) root.deleteSnapshotFile(root.priorSnapshotPath)
      snapshotPath = ""
      priorSnapshotPath = ""
    }
    selectedCameraId = newCamId
    selectedCameraName = Model.safe(camera.name, "Camera")
    if (selectedCameraId !== "") requestSnapshot()
  }

  function requestSnapshot() {
    var viewingProtect = inSite ? siteTab === 1 : activeTab === 3
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
    else {
      if (root.snapshotPath) root.deleteSnapshotFile(root.snapshotPath)
      if (root.priorSnapshotPath) root.deleteSnapshotFile(root.priorSnapshotPath)
      snapshotPath = ""
      priorSnapshotPath = ""
    }
  }

  onActiveTabChanged: {
    if (!inSite && activeTab !== 3) {
      if (root.snapshotPath) root.deleteSnapshotFile(root.snapshotPath)
      if (root.priorSnapshotPath) root.deleteSnapshotFile(root.priorSnapshotPath)
      snapshotPath = ""
      priorSnapshotPath = ""
    }
    if (!inSite && activeTab === 3 && data.protect && data.protect.cameras && data.protect.cameras.length > 0) {
      if (selectedCameraId === "") selectCamera(data.protect.cameras[0])
      else requestSnapshot()
    }
  }

  onSiteTabChanged: {
    if (inSite && siteTab !== 1) {
      if (root.snapshotPath) root.deleteSnapshotFile(root.snapshotPath)
      if (root.priorSnapshotPath) root.deleteSnapshotFile(root.priorSnapshotPath)
      snapshotPath = ""
      priorSnapshotPath = ""
    }
    if (inSite && siteTab === 1 && siteProtectInstalled && siteData.protect.cameras.length > 0) {
      if (selectedCameraId === "") selectCamera(siteData.protect.cameras[0])
      else requestSnapshot()
    }
  }

  Component.onCompleted: {
    refresh()
  }

  Process {
    id: summaryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, connected: false, error: "Invalid helper response" })
        root.data = root.stabilizeCloudSummary(parsed)
        if (parsed.ok) {
          root.notice = ""
          root.lastErrorText = ""
        } else {
          var errDetail = parsed.error || (summaryStderr.text ? summaryStderr.text.trim() : "Unable to load UniFi")
          root.lastErrorText = errDetail
          root.notice = Model.safe(errDetail, "Unable to load UniFi")
        }
        root.loading = false
        root.refreshAgeSec = 0
        root.lastRefreshMs = Date.now()
      }
    }
    stderr: StdioCollector {
      id: summaryStderr
      waitForEnd: true
    }
    onExited: function(exitCode) { root.loading = false }
  }

  Process {
    id: prefetchProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        // Site prefetch finished
      }
    }
  }

  function prefetchSites() {
    if (prefetchProc.running) return
    prefetchProc.command = [root.helper, "prefetch-sites"]
    prefetchProc.running = true
  }

  Timer {
    id: prefetchTimer
    interval: 600000 // 10 minutes = 600,000 ms
    repeat: true
    running: true
    onTriggered: root.prefetchSites()
  }

  Process {
    id: clearHistoryProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.refresh()
    }
  }

  Process {
    id: siteCachedProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false })
        if (parsed.ok && root.inSite && root.selectedSite && String(parsed.siteId) === String(root.selectedSite.id)) {
          if (!root.siteData || !root.siteData.ok || root.siteData._cached) {
            root.siteData = parsed
            root.siteLoading = false
          }
        }
      }
    }
  }

  Process {
    id: siteProc
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, { ok: false, error: "Invalid site response" })
        if (parsed.ok) {
          if (root.inSite && root.selectedSite && String(parsed.siteId) === String(root.selectedSite.id)) {
            root.siteData = parsed
            root.notice = ""
            root.lastErrorText = ""
            if (root.siteTab === 1 && parsed.protect && parsed.protect.cameras && parsed.protect.cameras.length > 0) {
              var selectedStillExists = false
              for (var index = 0; index < parsed.protect.cameras.length; index++) {
                if (String(parsed.protect.cameras[index].id) === root.selectedCameraId) selectedStillExists = true
              }
              if (!selectedStillExists) root.selectCamera(parsed.protect.cameras[0])
              else root.requestSnapshot()
            }
          }
        } else {
          var errDetail = parsed.error || (siteStderr.text ? siteStderr.text.trim() : "Unable to load this site")
          root.lastErrorText = errDetail
          if (!root.siteData || !root.siteData.ok) {
            root.notice = Model.safe(errDetail, "Unable to load this site")
          }
        }
        root.siteLoading = false
        root.siteLiveRefreshing = false
      }
    }
    stderr: StdioCollector {
      id: siteStderr
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.siteLoading = false
      root.siteLiveRefreshing = false
    }
  }

  Process {
    id: diagProc
    command: [root.helper, "diagnose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parse(text, null)
        if (parsed && parsed.ok) {
          root.diagnosticsData = parsed
          if (parsed.apiError) {
            root.lastErrorText = parsed.apiError
          }
        }
        root.diagnosticsRunning = false
      }
    }
    stderr: StdioCollector {
      waitForEnd: true
    }
    onExited: function(exitCode) {
      root.diagnosticsRunning = false
    }
  }

  function runDiagnostics() {
    if (diagProc.running) return
    root.diagnosticsRunning = true
    diagProc.running = true
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
        if (parsed.ok && parsed.path) {
          root.cameraPermissionError = ""
          if (root.snapshotPath !== "") {
            root.priorSnapshotPath = root.snapshotPath
          }
          root.snapshotPath = "file://" + parsed.path + "?t=" + Date.now()
        } else if (parsed && (parsed.permissionError || (parsed.error && parsed.error.indexOf("protect:stream") >= 0))) {
          root.cameraPermissionError = parsed.error || "Missing 'protect:stream' permission for camera snapshots"
        }
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
    id: refreshTimer
    interval: root.currentRefreshIntervalMs
    running: true
    repeat: true
    triggeredOnStart: false
    onTriggered: root.inSite ? root.loadSite() : root.refresh()
  }

  Timer {
    interval: 2500
    running: root.opened && root.selectedCameraId !== "" && (root.inSite ? root.siteTab === 1 : root.activeTab === 3)
    repeat: true
    triggeredOnStart: false
    onTriggered: root.requestSnapshot()
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.refreshAgeSec = Math.max(0, Math.floor((Date.now() - root.lastRefreshMs) / 1000))
  }


  implicitWidth: button.implicitWidth + (multiDotRow.visible ? multiDotRow.width + Style.space(6) : 0) + (badge.visible ? badge.width + Style.space(4) : 0)
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    parent: root
    x: 0
    y: 0
    height: parent ? parent.height : implicitHeight
    bar: root.bar
    iconComponent: Component {
      Item {
        UnifiIcon {
          anchors.centerIn: parent
          size: Style.space(12)
          color: button.active && button.useActiveColor ? button.activeColor : button.foreground
        }
      }
    }
    text: Model.severityIcon(root.barSeverity)
    foreground: root.foreground
    activeColor: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.foreground)
    useActiveColor: root.connected && root.barSeverity !== "healthy"
    active: root.connected && root.barSeverity !== "healthy"
    dimmed: !root.connected
    tooltipText: !root.connected
      ? "UniFi SiteThread · Connect"
      : ("UniFi SiteThread · " + Model.safe(root.data.message, "Connected") + "\nLeft-click: Dashboard • Right-click: Settings • Middle-click: Refresh")
    onPressed: function(b) {
      root.handleBarClick(b)
    }
  }

  // Multi-Dot Site Status Row on Bar
  Row {
    id: multiDotRow
    parent: root
    visible: Boolean(root.enableMultiDot && root.data && root.data.sites && root.data.sites.length > 0)
    x: button.x + button.width - Style.space(2)
    y: Math.max(0, (root.height - height) / 2)
    height: Style.space(14)
    spacing: Style.space(3)
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined

    Repeater {
      model: root.data && root.data.sites ? root.data.sites : []
      delegate: Item {
        required property var modelData
        width: Style.space(6)
        height: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter

        Rectangle {
          anchors.centerIn: parent
          width: Style.space(5)
          height: Style.space(5)
          radius: width / 2
          color: modelData.status === "down" ? root.urgent : (modelData.status === "backup" ? root.backup : root.healthy)
          opacity: (modelData.status === "down" || modelData.status === "backup") ? 0.9 : 0.85

          SequentialAnimation on opacity {
            running: modelData.status === "down" || modelData.status === "backup"
            loops: Animation.Infinite
            NumberAnimation { from: 0.35; to: 1.0; duration: 600; easing.type: Easing.InOutQuad }
            NumberAnimation { from: 1.0; to: 0.35; duration: 600; easing.type: Easing.InOutQuad }
          }
        }
      }
    }
  }

  Rectangle {
    id: badge
    parent: root
    visible: root.getBadgeText() !== ""
    x: multiDotRow.visible ? multiDotRow.x + multiDotRow.width + Style.space(3) : button.x + button.width - Style.space(4)
    y: Math.max(0, (root.height - height) / 2)
    width: Math.max(height, badgeText.implicitWidth + Style.space(6))
    height: Style.space(15)
    radius: height / 2
    color: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.accent)
    border.width: 1
    border.color: (Color.popups && Color.popups.background) ? Color.popups.background : "#1E1E2E"
    Text { textFormat: Text.PlainText;
      id: badgeText
      anchors.centerIn: parent
      text: root.getBadgeText()
      color: "#ffffff"
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }
  }

  MouseArea {
    id: barExtraMouse
    parent: root
    visible: multiDotRow.visible || badge.visible
    x: multiDotRow.visible ? multiDotRow.x : badge.x
    y: 0
    width: Math.max(0, (root.width > 0 ? root.width : root.implicitWidth) - x)
    height: root.height > 0 ? root.height : (button.height > 0 ? button.height : button.implicitHeight)
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      if (root.bar && button.tooltipText) root.bar.showTooltip(button, button.tooltipText)
    }
    onExited: {
      if (root.bar) root.bar.hideTooltip(button)
    }
    onClicked: function(mouse) {
      if (root.bar) root.bar.hideTooltip(button)
      root.handleBarClick(mouse.button)
    }
  }

  KeyboardPanel {
    id: popup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: popup.fittedContentWidth(Style.space(root.panelWidth))
    contentHeight: popup.fittedContentHeight(Math.min(Style.space(720), content.implicitHeight))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent

      onMoveRequested: function(dx, dy) {
        if (dy !== 0) scroll.contentY = Math.max(0, Math.min(scroll.contentHeight - scroll.height, scroll.contentY + dy * 56))
      }
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r" || t === "R") {
          if (root.inSite) root.loadSite()
          else root.refresh()
        } else if (t === "s" || t === "S") {
          root.settingsMode ? root.closeSettings() : root.openSettings()
        } else if (t === "a" || t === "A" || t === "m" || t === "M") {
          root.toggleAnalytics()
        } else if (t === "w" || t === "W") {
          root.openConsole()
        } else if (t === "q" || t === "Q") {
          root.close()
        } else if (t === "1") {
          root.activeTab = 0
        } else if (t === "2") {
          root.activeTab = 1
        } else if (t === "3") {
          root.activeTab = 2
        } else if (t === "4" && (!root.cloudMode || (root.data && root.data.protect && root.data.protect.available))) {
          root.activeTab = 3
        }
      }

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

          // Agent Hub Style Header Card
          BorderSurface {
            id: mainHeader
            width: parent.width
            color: root.card
            borderSpec: Border.flat(root.isLightTheme ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08), 1)
            padding: Style.space(8)
            radius: Style.cornerRadius
            implicitHeight: headerRow.implicitHeight + contentTopInset + contentBottomInset

            RowLayout {
              id: headerRow
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.topMargin: mainHeader.contentTopInset
              anchors.rightMargin: mainHeader.contentRightInset
              anchors.bottomMargin: mainHeader.contentBottomInset
              anchors.leftMargin: mainHeader.contentLeftInset
              spacing: Style.space(8)

              // Back button if inside site
              Rectangle {
                visible: root.inSite
                radius: 4
                color: backMouse.containsMouse ? root.cardHover : root.track
                Layout.preferredWidth: Style.space(26)
                Layout.preferredHeight: Style.space(26)
                Text {
                  textFormat: Text.PlainText;
                  anchors.centerIn: parent
                  text: ""
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
                MouseArea {
                  id: backMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.backToSites()
                }

                PanelToolTip {
                  visible: backMouse.containsMouse
                  text: "Back to all sites"
                  fontFamily: root.fontFamily
                }
              }

              // UniFi Logo
              UnifiIcon {
                size: Style.space(20)
                color: root.accent
                Layout.alignment: Qt.AlignVCenter
              }

              // Title & Subtitle + Live refresh age / refreshing state
              ColumnLayout {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                spacing: 1

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)
                  Text {
                    textFormat: Text.PlainText;
                    text: root.settingsMode
                      ? "UNIFI SITETHREAD SETTINGS"
                      : (root.inSite
                          ? Model.safe(root.selectedSite.name, "UNIFI SITE")
                          : "UNIFI SITETHREAD")
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: 13
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                  }

                  // Status badge
                  Rectangle {
                    visible: root.connected && !root.inSite && !root.settingsMode
                    radius: 3
                    height: Style.space(16)
                    implicitWidth: statusPillText.implicitWidth + Style.space(8)
                    color: root.barSeverity === "critical"
                      ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18)
                      : (root.barSeverity === "warning"
                          ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18)
                          : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18))
                    border.width: 1
                    border.color: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.healthy)
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                      textFormat: Text.PlainText;
                      id: statusPillText
                      anchors.centerIn: parent
                      text: root.barSeverity === "critical" ? "ATTENTION" : (root.barSeverity === "warning" ? "BACKUP WAN" : "OPERATIONAL")
                      color: root.barSeverity === "critical" ? root.urgent : (root.barSeverity === "warning" ? root.backup : root.healthy)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)

                  Text {
                    textFormat: Text.PlainText;
                    text: root.settingsMode
                      ? "Configuration, Badge Modes & Terminal Launcher"
                      : (root.inSite
                          ? (root.siteLiveRefreshing
                              ? (root.siteData && root.siteData._cached ? "Cached view" : "Connecting to site…")
                              : (root.siteData && root.siteData._cached ? "Cached view · 10m cycle" : Model.safe(root.selectedSite.statusText, "Live site view")))
                          : (root.connected ? Model.summarySubtitle(root.data) : "Network + Protect"))
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                  }

                  // Age indicator
                  RowLayout {
                    spacing: Style.space(3)
                    visible: !root.loading && !(root.inSite && root.siteLiveRefreshing) && root.connected && root.refreshAgeSec >= 0

                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: root.refreshAgeSec > (root.idleRefreshSeconds + 60) ? root.urgent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: {
                        var a = root.refreshAgeSec
                        if (a < 0) return ""
                        if (a < 10) return "Refreshed just now"
                        if (a < 60) return "Refreshed " + a + "s ago"
                        if (a < 3600) return "Refreshed " + Math.floor(a / 60) + "m ago"
                        return "Refreshed " + Math.floor(a / 3600) + "h " + Math.floor((a % 3600) / 60) + "m ago"
                      }
                      color: root.refreshAgeSec > (root.idleRefreshSeconds + 60) ? root.urgent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                    }
                  }

                  // Refreshing spinner text
                  RowLayout {
                    spacing: Style.space(3)
                    visible: root.loading && !(root.inSite && root.siteLiveRefreshing)

                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      transformOrigin: Item.Center

                      RotationAnimation on rotation {
                        running: root.loading
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                      }
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: "Refreshing…"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      opacity: 0.9
                    }
                  }

                  // Site live syncing spinner
                  RowLayout {
                    spacing: Style.space(3)
                    visible: root.inSite && root.siteLiveRefreshing

                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      transformOrigin: Item.Center

                      RotationAnimation on rotation {
                        running: root.inSite && root.siteLiveRefreshing
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 800
                      }
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: "Syncing live…"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      opacity: 0.9
                    }
                  }
                }
              }

              // Header Action Buttons cluster
              RowLayout {
                spacing: Style.space(4)
                Layout.alignment: Qt.AlignVCenter

                // 1. Analytics Floating Window Button
                Rectangle {
                  visible: root.connected && !root.settingsMode
                  radius: 3
                  color: chartMouse.containsMouse ? root.cardHover : root.track
                  Layout.preferredHeight: Style.space(24)
                  Layout.preferredWidth: Style.space(24)

                  Text {
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: ""
                    color: root.analyticsOpen ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: chartMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleAnalytics()
                  }

                  PanelToolTip {
                    visible: chartMouse.containsMouse
                    text: root.analyticsOpen ? "Close telemetry analytics" : "Open telemetry & analytics"
                    fontFamily: root.fontFamily
                  }
                }

                // 2. Open Web UniFi Console Button
                Rectangle {
                  visible: root.connected && !root.settingsMode
                  radius: 3
                  color: webMouse.containsMouse ? root.cardHover : root.track
                  Layout.preferredHeight: Style.space(24)
                  Layout.preferredWidth: Style.space(24)

                  Text {
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: webMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openConsole()
                  }

                  PanelToolTip {
                    visible: webMouse.containsMouse
                    text: "Open UniFi Cloud Portal in browser"
                    fontFamily: root.fontFamily
                  }
                }

                // Direct Connect Button
                Rectangle {
                  id: directConnectSiteBtn
                  visible: root.connected && !root.settingsMode && root.inSite && (root.getSiteConsole(root.selectedSite ? root.selectedSite.hostId : "") !== null)
                  radius: 3
                  color: directConnectMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.track
                  border.width: 1
                  border.color: directConnectMouse.containsMouse ? root.accent : root.outline
                  Layout.preferredHeight: Style.space(24)
                  Layout.preferredWidth: Style.space(24)

                  Text {
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: ""
                    color: directConnectMouse.containsMouse ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: directConnectMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      var c = root.getSiteConsole(root.selectedSite ? root.selectedSite.hostId : "")
                      if (c) {
                        var target = c.directConnectUrl || (c.directConnectDomain ? ("https://" + c.directConnectDomain) : "") || c.localUrl || c.webCloudUrl
                        if (target) Quickshell.execDetached(["xdg-open", target])
                      }
                    }
                  }

                  PanelToolTip {
                    visible: directConnectMouse.containsMouse
                    text: "Direct P2P connect to UniFi OS console"
                    fontFamily: root.fontFamily
                  }
                }

                // 3. Refresh Button
                Rectangle {
                  radius: 3
                  color: refMouse.containsMouse ? root.cardHover : root.track
                  Layout.preferredHeight: Style.space(24)
                  Layout.preferredWidth: Style.space(24)

                  Text {
                    id: refBtnIcon
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: ""
                    color: root.loading ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    transformOrigin: Item.Center

                    RotationAnimation on rotation {
                      running: root.loading
                      loops: Animation.Infinite
                      from: 0
                      to: 360
                      duration: 800
                    }
                  }

                  MouseArea {
                    id: refMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.inSite ? root.loadSite() : root.refresh()
                  }

                  PanelToolTip {
                    visible: refMouse.containsMouse
                    text: root.inSite ? "Refresh live site telemetry" : "Refresh fleet telemetry"
                    fontFamily: root.fontFamily
                  }
                }

                // 4. Settings Button
                Rectangle {
                  radius: 3
                  color: setMouse.containsMouse ? root.cardHover : root.track
                  Layout.preferredHeight: Style.space(24)
                  Layout.preferredWidth: Style.space(24)

                  Text {
                    textFormat: Text.PlainText;
                    anchors.centerIn: parent
                    text: root.settingsMode ? "" : ""
                    color: root.settingsMode ? root.accent : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  MouseArea {
                    id: setMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.settingsMode ? root.closeSettings() : root.openSettings()
                  }

                  PanelToolTip {
                    visible: setMouse.containsMouse
                    text: root.settingsMode ? "Close settings" : "Plugin settings"
                    fontFamily: root.fontFamily
                  }
                }
              }
            }

            // Animated Progress Glow Pill on bottom border during refresh
            Rectangle {
              id: refreshProgressBar
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.bottom: parent.bottom
              anchors.bottomMargin: 1
              height: 2
              color: "transparent"
              clip: true
              visible: root.loading

              Rectangle {
                id: glowPill
                anchors.verticalCenter: parent.verticalCenter
                height: 2
                width: Math.max(50, parent.width * 0.35)
                radius: 1
                color: root.accent

                NumberAnimation on x {
                  running: root.loading && root.opened
                  loops: Animation.Infinite
                  from: -glowPill.width
                  to: refreshProgressBar.width
                  duration: 800
                  easing.type: Easing.InOutQuad
                }
              }
            }
          }

          // Settings View
          SettingsView {
            visible: root.settingsMode
            width: parent.width
            settings: ({
              enableMultiDot: root.enableMultiDot,
              badgeMode: root.badgeMode,
              refreshSeconds: root.refreshSeconds,
              activeRefreshSeconds: root.activeRefreshSeconds,
              idleRefreshSeconds: root.idleRefreshSeconds,
              terminalCommand: root.preferredTerminal,
              autoRotate: root.autoRotate,
              enableNotifications: root.enableNotifications
            })
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            urgent: root.urgent
            healthy: root.healthy
            fontFamily: root.fontFamily
            onSettingChanged: function(key, val) {
              root.updateSetting(key, val)
            }
            onClearHistoryRequested: {
              root.clearResolvedIssues()
            }
            onTestNotifyRequested: {
              root.testNotification()
            }
            diagnostics: root.diagnosticsData
            lastErrorText: root.lastErrorText
            diagnosticsRunning: root.diagnosticsRunning
            onRunDiagnosticsRequested: {
              root.runDiagnostics()
            }
            onCloseSettingsRequested: {
              root.closeSettings()
            }
          }

        Text { textFormat: Text.PlainText;
          visible: root.notice !== ""
          width: parent.width
          text: root.notice
          wrapMode: Text.WordWrap
          horizontalAlignment: Text.AlignHCenter
          color: root.notice.indexOf("failed") >= 0 || root.notice.indexOf("invalid") >= 0 ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }

        Column {
          visible: !root.connected && !root.settingsMode
          width: parent.width
          spacing: Style.space(12)

          PanelSectionHeader {
            width: parent.width
            text: root.localSetup ? "CONNECT TO A LOCAL UNIFI CONSOLE" : "SIGN IN TO UNIFI SITE MANAGER"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Text { textFormat: Text.PlainText;
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
                Text { textFormat: Text.PlainText; id: signInText; anchors.centerIn: parent; text: "Sign in at unifi.ui.com"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                MouseArea { id: signInArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.openAccount() }
              }
              Text { textFormat: Text.PlainText;
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

            Text { textFormat: Text.PlainText;
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
                Text { textFormat: Text.PlainText; id: cloudConnectText; anchors.centerIn: parent; text: cloudConnectProc.running ? "Connecting…" : "Connect all sites"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                MouseArea { anchors.fill: parent; enabled: cloudKeyField.text !== "" && !cloudConnectProc.running; cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: root.connectCloud() }
              }
              Text { textFormat: Text.PlainText;
                anchors.verticalCenter: parent.verticalCenter
                text: "Includes sites shared with your UI Account"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Text { textFormat: Text.PlainText;
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
              Text { textFormat: Text.PlainText;
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
            Text { textFormat: Text.PlainText;
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
              Text { textFormat: Text.PlainText;
                text: "CONSOLE CERTIFICATE · SHA-256"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
              Text { textFormat: Text.PlainText;
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
                  Text { textFormat: Text.PlainText;
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
                Text { textFormat: Text.PlainText;
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

          Text { textFormat: Text.PlainText;
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
              Text { textFormat: Text.PlainText;
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

          Text { textFormat: Text.PlainText;
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
          visible: root.connected && !root.inSite && !root.settingsMode
          width: parent.width
          spacing: Style.space(12)

          Rectangle {
            width: parent.width
            height: Style.space(28)
            color: root.track
            radius: 4
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(2)
              spacing: Style.space(2)

              Repeater {
                model: [
                  { id: 0, label: "Overview", icon: "\uf0e4" },
                  { id: 1, label: root.cloudMode ? "Sites (" + (root.data.sites ? root.data.sites.length : 0) + ")" : "Sites", icon: "\uf132" },
                  { id: 2, label: "Issues (" + root.activeIssuesCount + ")", icon: "\uf071" },
                  { id: 3, label: "Protect (" + (root.data.protect && root.data.protect.cameras ? root.data.protect.cameras.length : 0) + ")", icon: "\uf03d", visible: !root.cloudMode || (root.data.protect && root.data.protect.available) }
                ]
                delegate: Rectangle {
                  required property var modelData
                  visible: modelData.visible !== false
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: 3
                  readonly property bool isSelected: root.activeTab === modelData.id
                  color: isSelected ? root.accent : (tabMouse.containsMouse ? root.cardHover : "transparent")

                  Behavior on color { ColorAnimation { duration: 120 } }

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(3)

                    Text {
                      textFormat: Text.PlainText;
                      text: modelData.icon
                      color: isSelected ? root.accentForeground : (tabMouse.containsMouse ? root.foreground : root.dim)
                      font.family: root.fontFamily
                      font.pixelSize: 9
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: modelData.label
                      color: isSelected ? root.accentForeground : (tabMouse.containsMouse ? root.foreground : root.dim)
                      font.family: root.fontFamily
                      font.pixelSize: 9
                      font.bold: isSelected
                      elide: Text.ElideRight
                    }
                  }

                  MouseArea {
                    id: tabMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = modelData.id
                  }
                }
              }
            }
          }

          // TAB 0: OVERVIEW COCKPIT & ASCII GLOBE
          OverviewView {
            id: overviewView
            visible: root.activeTab === 0
            width: parent.width

            fleetData: root.data
            activeIssuesCount: root.activeIssuesCount
            siteDownCount: root.siteDownCount
            siteBackupCount: root.siteBackupCount
            autoRotate: root.autoRotate
            opened: root.opened
            issuesList: root.issuesList
            isLightTheme: root.isLightTheme
            activeTab: root.activeTab
            sitesSubView: root.sitesSubView

            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            accentForeground: root.accentForeground
            urgent: root.urgent
            healthy: root.healthy
            backup: root.backup
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            fontFamily: root.fontFamily

            onActiveTabChanged: { if (overviewView.activeTab !== undefined) root.activeTab = overviewView.activeTab }
            onSitesSubViewChanged: { if (overviewView.sitesSubView !== undefined) root.sitesSubView = overviewView.sitesSubView }
            onOpenSiteRequested: function(site) { root.openSite(site) }
            onOpenAnalyticsRequested: function(tabIndex) { root.openAnalytics(tabIndex) }
          }
          // TAB 1: SITES & DEVICES (HIGH DENSITY FLEET VIEW)
          SitesView {
            id: sitesView
            visible: root.activeTab === 1
            width: parent.width

            sitesSubView: root.sitesSubView
            fleetData: root.data
            cloudMode: root.cloudMode
            deviceFilter: root.deviceFilter
            fleetDevices: root.getAllFleetDevices()

            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            accentForeground: root.accentForeground
            urgent: root.urgent
            healthy: root.healthy
            backup: root.backup
            backupForeground: root.backupForeground
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            fontFamily: root.fontFamily

            onSitesSubViewChanged: { if (sitesView.sitesSubView !== undefined) root.sitesSubView = sitesView.sitesSubView }
            onOpenSiteRequested: function(site) { root.openSite(site) }
            onOpenAnalyticsRequested: function(tabIndex) { root.openAnalytics(tabIndex) }
            onLaunchSshRequested: function(ip, user) { root.launchSsh(ip, user) }
            onLaunchPingRequested: function(ip) { root.launchPing(ip) }
          }

          // TAB 2: ISSUES & AUDIT TRAIL (HISTORICAL RESOLVED ISSUES GREYED OUT)
          IssuesView {
            id: issuesView
            visible: root.activeTab === 2
            width: parent.width

            issuesList: root.issuesList
            activeIssuesCount: root.activeIssuesCount
            issueFilter: root.issueFilter

            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            accentForeground: root.accentForeground
            urgent: root.urgent
            urgentForeground: root.urgentForeground
            backup: root.backup
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            fontFamily: root.fontFamily

            onIssueFilterChanged: { if (issuesView.issueFilter !== undefined) root.issueFilter = issuesView.issueFilter }
            onClearHistoryRequested: root.clearHistory()
          }

          // TAB 3: PROTECT CAMERAS
          ProtectView {
            id: protectView
            visible: root.activeTab === 3
            width: parent.width

            fleetData: root.data
            cloudMode: root.cloudMode
            selectedCameraId: root.selectedCameraId
            selectedCameraName: root.selectedCameraName
            snapshotPath: root.snapshotPath

            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            urgent: root.urgent
            fontFamily: root.fontFamily

            onSelectCameraRequested: function(camId, camName) { root.selectCamera(camId, camName) }
            onCleanupPriorSnapshotRequested: root.cleanupPriorSnapshot()
          }

          Rectangle { width: parent.width; height: 1; color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.1) }

          RowLayout {
            width: parent.width
            spacing: Style.space(8)
            Text {
              textFormat: Text.PlainText;
              Layout.fillWidth: true
              text: root.cloudMode ? "UI Account key stored in Secret Service" : "Credentials stored in Secret Service"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              elide: Text.ElideRight
            }
            Rectangle {
              id: disconnectButton
              implicitWidth: disconnectText.implicitWidth + Style.space(14)
              implicitHeight: Style.space(24)
              radius: Style.cornerRadius
              color: disconnectArea.containsMouse ? Style.hoverFillFor(root.foreground, root.accent) : "transparent"
              Text { textFormat: Text.PlainText; id: disconnectText; anchors.centerIn: parent; text: root.confirmDisconnect ? "Confirm forget" : "Disconnect"; color: root.confirmDisconnect ? root.urgent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
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
          visible: root.connected && root.inSite && !root.settingsMode
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
                Text { textFormat: Text.PlainText; text: Model.safe(root.selectedSite ? root.selectedSite.statusText : "", "Online"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
                Text { textFormat: Text.PlainText;
                  text: (root.selectedSite && root.selectedSite.isp ? Model.safe(root.selectedSite.isp, "") + "  ·  " : "") + "Live data from this UniFi console"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }
          }

          // Direct Connect Quick-Launch Bar
          BorderSurface {
            id: directConnectBanner
            visible: {
              var c = root.getSiteConsole(root.selectedSite ? root.selectedSite.hostId : "")
              return c !== null && Boolean(c.directConnectDomain || c.directConnectUrl)
            }
            width: parent.width
            implicitHeight: Style.space(34)
            color: directBarMouse.containsMouse ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.12) : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.04)
            radius: Style.cornerRadius
            borderSpec: Border.flat(directBarMouse.containsMouse ? root.accent : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.10), 1)

            MouseArea {
              id: directBarMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                var c = root.getSiteConsole(root.selectedSite ? root.selectedSite.hostId : "")
                if (c && (c.directConnectUrl || c.directConnectDomain)) {
                  Quickshell.execDetached(["xdg-open", c.directConnectUrl || ("https://" + c.directConnectDomain)])
                }
              }
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(10)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                text: ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                textFormat: Text.PlainText;
                text: "Direct P2P:"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                textFormat: Text.PlainText;
                property var sc: root.getSiteConsole(root.selectedSite ? root.selectedSite.hostId : "")
                text: sc && sc.directConnectDomain ? sc.directConnectDomain : ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                elide: Text.ElideMiddle
                Layout.fillWidth: true
              }

              Rectangle {
                radius: 3
                color: directBtnMouse.containsMouse ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                implicitHeight: Style.space(22)
                implicitWidth: directBtnTxt.implicitWidth + Style.space(12)
                Text {
                  id: directBtnTxt
                  textFormat: Text.PlainText;
                  anchors.centerIn: parent
                  text: "Launch ↗"
                  color: directBtnMouse.containsMouse ? root.card : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }
                MouseArea {
                  id: directBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    var c = root.getSiteConsole(root.selectedSite ? root.selectedSite.hostId : "")
                    if (c && (c.directConnectUrl || c.directConnectDomain)) {
                      Quickshell.execDetached(["xdg-open", c.directConnectUrl || ("https://" + c.directConnectDomain)])
                    }
                  }
                }

                PanelToolTip {
                  visible: directBtnMouse.containsMouse
                  text: "Launch direct P2P console connection"
                  fontFamily: root.fontFamily
                }
              }

              Rectangle {
                radius: 3
                color: directHubMouse.containsMouse ? root.cardHover : root.track
                implicitHeight: Style.space(22)
                implicitWidth: directHubTxt.implicitWidth + Style.space(10)
                Text {
                  id: directHubTxt
                  textFormat: Text.PlainText;
                  anchors.centerIn: parent
                  text: "Apps Hub "
                  color: directHubMouse.containsMouse ? root.accent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
                MouseArea {
                  id: directHubMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.openAnalytics(4)
                  }
                }

                PanelToolTip {
                  visible: directHubMouse.containsMouse
                  text: "Open UniFi OS applications hub"
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          Text { textFormat: Text.PlainText;
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
                Text { textFormat: Text.PlainText;
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
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: String(modelData.value); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.title; font.bold: true }
                  Text { textFormat: Text.PlainText; anchors.horizontalCenter: parent.horizontalCenter; text: modelData.label; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                }
              }
            }
          }

          Column {
            visible: root.siteData && root.siteData.ok === true && root.siteTab === 0
            width: parent.width
            spacing: Style.space(8)
            PanelSectionHeader { width: parent.width; text: "NETWORK TOPOLOGY & DEVICES"; foreground: root.foreground; fontFamily: root.fontFamily }

            TopologyTreeView {
              width: parent.width
              site: root.selectedSite
              devices: root.siteData && root.siteData.network && root.siteData.network.devices ? root.siteData.network.devices : []
              clients: (root.siteData && root.siteData.network && root.siteData.network.clients) || (root.siteData && root.siteData.clients) || (root.data && root.data.clients) || []
              preferredTerminal: root.preferredTerminal
              foreground: root.foreground
              dim: root.dim
              accent: root.accent
              card: root.card
              cardHover: root.cardHover
              track: root.track
              outline: root.outline
              urgent: root.urgent
              healthy: root.healthy
              backup: root.backup
              fontFamily: root.fontFamily
              onSshRequested: function(ip, user) { root.launchSsh(ip, user) }
              onPingRequested: function(ip) { root.launchPing(ip) }
              onWebRequested: function(ip) {
                if (ip) Quickshell.execDetached(["xdg-open", "https://" + ip])
              }
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
              Image {
                anchors.fill: parent
                source: root.snapshotPath
                fillMode: Image.PreserveAspectFit
                cache: false
                asynchronous: true
                onStatusChanged: {
                  if (status === Image.Ready) {
                    root.cleanupPriorSnapshot()
                  }
                }
              }
              Text {
                textFormat: Text.PlainText;
                anchors.centerIn: parent;
                visible: root.snapshotPath === "";
                text: root.cameraPermissionError !== ""
                  ? root.cameraPermissionError
                  : ("Loading " + root.selectedCameraName + "…");
                color: root.cameraPermissionError !== "" ? root.urgent : root.foreground;
                font.family: root.fontFamily;
                font.pixelSize: Style.font.body
              }
              Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                width: liveCameraLabel.implicitWidth + Style.space(14)
                height: liveCameraLabel.implicitHeight + Style.space(7)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.68)
                Text { textFormat: Text.PlainText; id: liveCameraLabel; anchors.centerIn: parent; text: "LIVE · " + root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
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
                    Text { textFormat: Text.PlainText; width: parent.width; text: Model.safe(modelData.name, "Camera"); elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { textFormat: Text.PlainText; width: parent.width; text: modelData.online ? "ONLINE" : "OFFLINE"; horizontalAlignment: Text.AlignHCenter; color: modelData.online ? root.healthy : root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                  }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectCamera(modelData) }
                }
              }
            }
            Text { textFormat: Text.PlainText;
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
}

  Loader {
    id: analyticsWindowLoader
    active: root.analyticsOpen
    source: Qt.resolvedUrl("windows/AnalyticsWindow.qml")
    onLoaded: {
      if (item) {
        item.fleetData = Qt.binding(function() { return root.data })
        item.currentTab = root.analyticsTab
        item.visible = Qt.binding(function() { return root.analyticsOpen })
        item.isRefreshing = Qt.binding(function() { return root.loading })
        item.refreshRequested.connect(function() {
          root.refresh()
        })
        item.closed.connect(function() {
          root.closeAnalytics()
        })
      }
    }
  }

  Connections {
    target: analyticsWindowLoader.item
    ignoreUnknownSignals: true
    function onVisibleChanged() {
      if (analyticsWindowLoader.item && !analyticsWindowLoader.item.visible) {
        root.closeAnalytics()
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
    function openSettings(): void { root.open(); root.openSettings() }
    function closeSettings(): void { root.closeSettings() }
    function openAnalytics(): void { root.openAnalytics(0) }
    function openAnalyticsTab(index: int): void { root.openAnalytics(index) }
    function closeAnalytics(): void { root.closeAnalytics() }
    function toggleAnalytics(): void { root.toggleAnalytics() }
    function filterAnalyticsSite(siteName: string): void {
      if (analyticsWindowLoader.item) {
        analyticsWindowLoader.item.toggleSiteSelection({ name: siteName, id: siteName })
      }
    }
    function clearAnalyticsSiteFilter(): void {
      if (analyticsWindowLoader.item) {
        analyticsWindowLoader.item.clearSiteSelection()
      }
    }
    function hoverAnalyticsThroughput(index: int): void {
      if (analyticsWindowLoader.item) {
        analyticsWindowLoader.item.chartHoverIndex = index
        analyticsWindowLoader.item.chartHoverMouseX = 50 + index * 24
        analyticsWindowLoader.item.chartHoverMouseY = 120
      }
    }
    function tab(index: int): void {
      root.activeTab = Math.max(0, Math.min(3, index))
      root.open()
    }
    function setSitesSubView(view: string): void {
      root.sitesSubView = view === "devices" ? "devices" : "sites"
    }
    function setSitesTimeRange(range: string): void {
      if (sitesView) sitesView.timeRange = range
    }
    function openSiteByIndex(index: int): void {
      var sites = root.data && root.data.sites ? root.data.sites : []
      if (index >= 0 && index < sites.length) {
        root.open()
        root.openSite(sites[index])
      }
    }
    function backToSites(): void {
      root.backToSites()
    }
    function rotate(longitude: real): void {
      if (overviewView && overviewView.fleetGlobe) overviewView.fleetGlobe.centreLongitude = GlobeModel.wrapLongitude(longitude)
    }
    function zoomIn(): void { if (overviewView && overviewView.fleetGlobe) overviewView.fleetGlobe.zoomIn() }
    function zoomOut(): void { if (overviewView && overviewView.fleetGlobe) overviewView.fleetGlobe.zoomOut() }
    function setGlobeScale(scale: real): void { if (overviewView && overviewView.fleetGlobe) overviewView.fleetGlobe.globeScale = scale }
    function globeScaleValue(): real { return (overviewView && overviewView.fleetGlobe) ? overviewView.fleetGlobe.globeScale : 1.0 }
    function visibleSitesCount(): int {
      return (overviewView && overviewView.fleetGlobe && overviewView.fleetGlobe.visibleSites) ? overviewView.fleetGlobe.visibleSites.length : 0
    }
    function prefetchSites(): void { root.prefetchSites() }
    function goToMainPage(): void { root.goToMainPage() }
    function handleBarClick(button: int): void { root.handleBarClick(button) }
    function notify(title: string, message: string, urgency: string): void {
      root.sendDesktopNotification(title, message, urgency)
    }
    function testNotification(): void {
      root.testNotification()
    }
    function status(): string {
      return JSON.stringify({
        opened: root.opened,
        settingsMode: root.settingsMode,
        analyticsOpen: root.analyticsOpen,
        analyticsTab: root.analyticsTab,
        analyticsCurrentTab: (analyticsWindowLoader.item ? analyticsWindowLoader.item.currentTab : -1),
        activeTab: root.activeTab,
        sitesSubView: root.sitesSubView,
        sitesTimeRange: (sitesView ? sitesView.timeRange : ""),
        inSite: root.inSite,
        siteLoading: root.siteLoading,
        siteLiveRefreshing: root.siteLiveRefreshing,
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
