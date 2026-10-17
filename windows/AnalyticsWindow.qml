import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import ".."
import "../views/analytics"
import "../components"
import "../Model.js" as Model

FloatingWindow {
  id: root
  title: "UniFi SiteThread — Fleet Analytics & Telemetry"
  color: root.background
  minimumSize: Qt.size(860, 580)
  implicitWidth: 1080
  implicitHeight: 740

  signal refreshRequested()
  property bool isRefreshing: false

  property var fleetData: null
  property color foreground: (Color.popups && Color.popups.foreground) ? Color.popups.foreground : (Color.foreground || "#D8DEE9")
  property color background: (Color.popups && Color.popups.background) ? Color.popups.background : (Color.background || "#1E1E2E")
  property color accent: Color.accent || "#89B4FA"
  property color healthy: "#10B981"
  property color backup: "#F59E0B"
  property color urgent: "#FF4D5A"
  property string fontFamily: Style.font.family

  property int currentTab: 0
  onVisibleChanged: {
    if (!visible) {
      root.currentTab = 0
    }
  }
  property string clientSearch: ""
  property string clientSiteFilter: "All"
  property string clientMediumFilter: "All"
  property string selectedSwitchSite: "all"
  property string selectedSwitchMac: ""
  property string portFilter: "All"
  property string statusToast: ""
  property string toastType: "info"
  property var selectedSiteIds: []
  property int chartHoverIndex: -1
  property real chartHoverMouseX: 0
  property real chartHoverMouseY: 0
  property string consoleSearch: ""
  property string consoleSiteFilter: "All"
  property int selectedConsoleIndex: 0

  property string wlanSearch: ""
  property string wlanSiteFilter: "All"
  property var selectedWlanForQr: null
  property bool showQrModal: false

  property string updateSearch: ""
  property string updateSiteFilter: "All"
  property string updateSeverityFilter: "All"
  property bool bulkUpdateConfirm: false

  readonly property var fleetConsoles: root.fleetData && root.fleetData.consoles ? root.fleetData.consoles : []
  readonly property var currentConsole: (fleetConsoles.length > root.selectedConsoleIndex && root.selectedConsoleIndex >= 0) ? fleetConsoles[root.selectedConsoleIndex] : (fleetConsoles.length > 0 ? fleetConsoles[0] : null)
  readonly property var fleetWlans: root.fleetData && root.fleetData.wlans ? root.fleetData.wlans : []
  readonly property var fleetSpectrum: root.fleetData && root.fleetData.spectrum ? root.fleetData.spectrum : null
  readonly property var fleetUpdates: root.fleetData && root.fleetData.firmwareUpdates ? root.fleetData.firmwareUpdates : []
  readonly property var fleetBackups: root.fleetData && root.fleetData.backups ? root.fleetData.backups : []
  readonly property var fleetOperations: root.fleetData && root.fleetData.operations ? root.fleetData.operations : []
  property string pendingCycleTarget: ""
  property string pendingPingTarget: ""
  property string pendingUpgradeDeviceTarget: ""
  property string pendingBackupConsoleTarget: ""

  readonly property string helper: Qt.resolvedUrl("../bin/site-thread").toString().replace(/^file:\/\//, "")

  readonly property bool isLightTheme: {
    var bgLum = (background.r * 0.299 + background.g * 0.587 + background.b * 0.114)
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
    ? Qt.rgba(foreground.r * 0.70 + background.r * 0.30,
              foreground.g * 0.70 + background.g * 0.30,
              foreground.b * 0.70 + background.b * 0.30, 1.0)
    : Qt.darker(foreground, 1.35)
  readonly property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.04 : 0.055)
  readonly property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.08 : 0.085)
  readonly property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.12 : 0.24)
  readonly property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, isLightTheme ? 0.14 : 0.18)

  readonly property var availableSwitches: root.fleetData && root.fleetData.switches ? root.fleetData.switches : []

  readonly property var switchSiteOptions: {
    var opts = [{ value: "all", label: "All Sites", description: (root.availableSwitches ? root.availableSwitches.length : 0) + " switches total" }]
    var siteMap = {}
    var swList = root.availableSwitches || []
    for (var i = 0; i < swList.length; i++) {
      var sn = swList[i].siteName || "Default Site"
      siteMap[sn] = (siteMap[sn] || 0) + 1
    }
    if (root.fleetData && root.fleetData.sites) {
      for (var j = 0; j < root.fleetData.sites.length; j++) {
        var s = root.fleetData.sites[j]
        var sName = s.name || s.id || "Site"
        if (siteMap[sName] === undefined) siteMap[sName] = 0
      }
    }
    var keys = Object.keys(siteMap).sort()
    for (var k = 0; k < keys.length; k++) {
      var c = siteMap[keys[k]]
      opts.push({
        value: keys[k],
        label: keys[k],
        description: c + (c === 1 ? " switch" : " switches")
      })
    }
    return opts
  }

  readonly property var switchesForSelectedSite: {
    var list = root.availableSwitches || []
    if (root.selectedSwitchSite && root.selectedSwitchSite !== "all") {
      return list.filter(function(s) {
        return (s.siteName || "Default Site") === root.selectedSwitchSite
      })
    }
    return list
  }

  readonly property var switchOptionsForSelectedSite: {
    var list = root.switchesForSelectedSite || []
    var opts = []
    for (var i = 0; i < list.length; i++) {
      var sw = list[i]
      var val = sw.mac || sw.name || ("sw-" + i)
      var activeCount = sw.activePorts !== undefined ? sw.activePorts : (sw.ports ? sw.ports.filter(function(p){ return p.up }).length : 0)
      var totalCount = sw.totalPorts !== undefined ? sw.totalPorts : (sw.ports ? sw.ports.length : 0)
      var pwr = sw.totalPower !== undefined ? (sw.totalPower + "W PoE") : ""
      opts.push({
        value: val,
        label: sw.name || ("Switch " + (i + 1)),
        description: (sw.model ? sw.model + " · " : "") + (sw.siteName ? sw.siteName + " · " : "") + activeCount + "/" + totalCount + " ports" + (pwr ? " · " + pwr : "")
      })
    }
    if (opts.length === 0) {
      opts.push({ value: "", label: "No switches found", description: "No switches in " + (root.selectedSwitchSite === "all" ? "fleet" : root.selectedSwitchSite) })
    }
    return opts
  }

  readonly property var currentSwitch: {
    var list = root.switchesForSelectedSite || []
    if (list.length === 0) return null
    if (root.selectedSwitchMac !== "") {
      for (var i = 0; i < list.length; i++) {
        var key = list[i].mac || list[i].name || ("sw-" + i)
        if (key === root.selectedSwitchMac) {
          return list[i]
        }
      }
    }
    return list[0]
  }

  readonly property int selectedSwitchIndex: {
    var list = root.availableSwitches || []
    if (!root.currentSwitch) return 0
    for (var i = 0; i < list.length; i++) {
      if ((list[i].mac && list[i].mac === root.currentSwitch.mac) ||
          (list[i].name && list[i].name === root.currentSwitch.name)) {
        return i
      }
    }
    return 0
  }

  onSelectedSwitchSiteChanged: {
    var list = root.switchesForSelectedSite || []
    if (list.length > 0) {
      var found = false
      for (var i = 0; i < list.length; i++) {
        var k = list[i].mac || list[i].name || ("sw-" + i)
        if (k === root.selectedSwitchMac) {
          found = true
          break
        }
      }
      if (!found) {
        root.selectedSwitchMac = list[0].mac || list[0].name || ""
      }
    } else {
      root.selectedSwitchMac = ""
    }
  }

  onAvailableSwitchesChanged: {
    if (root.availableSwitches && root.availableSwitches.length > 0 && root.selectedSwitchMac === "") {
      root.selectedSwitchMac = root.availableSwitches[0].mac || root.availableSwitches[0].name || ""
    }
  }

  Process {
    id: powerCycleProc
    stdout: StdioCollector { id: powerCycleOut; waitForEnd: true }
    stderr: StdioCollector { id: powerCycleErr; waitForEnd: true }
    onExited: function(code) {
      var target = root.pendingCycleTarget || "port"
      if (code === 0) {
        var pSuccess = Model.parse(powerCycleOut.text, null)
        root.statusToast = (pSuccess && pSuccess.message) ? pSuccess.message : ("PoE power cycle request accepted for " + target + ". Port restarting; link status updates on refresh.")
        root.toastType = "info"
        root.refreshRequested()
      } else {
        var pFail = Model.parse(powerCycleOut.text, null)
        var msg = (pFail && pFail.error) ? pFail.error : (powerCycleErr.text ? powerCycleErr.text.trim() : ("code " + code))
        root.statusToast = "PoE power cycle request rejected for " + target + ": " + msg
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: pingProc
    stdout: StdioCollector { id: pingOut; waitForEnd: true }
    stderr: StdioCollector { id: pingErr; waitForEnd: true }
    onExited: function(code) {
      var target = root.pendingPingTarget || "Host"
      if (code === 0) {
        root.statusToast = "Ping test completed: " + target + " reachable (<5ms)"
        root.toastType = "success"
      } else {
        root.statusToast = "Ping test completed: " + target + " unreachable or timeout"
        root.toastType = "warning"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: upgradeDevProc
    stdout: StdioCollector { id: upgradeDevOut; waitForEnd: true }
    stderr: StdioCollector { id: upgradeDevErr; waitForEnd: true }
    onExited: function(code) {
      var target = root.pendingUpgradeDeviceTarget || "device"
      if (code === 0) {
        var pSuccess = Model.parse(upgradeDevOut.text, null)
        root.statusToast = (pSuccess && pSuccess.message) ? pSuccess.message : ("Upgrade request accepted for " + target + ". Refresh to monitor device status.")
        root.toastType = "info"
        root.refreshRequested()
      } else {
        var pFail = Model.parse(upgradeDevOut.text, null)
        var msg = (pFail && pFail.error) ? pFail.error : (upgradeDevErr.text ? upgradeDevErr.text.trim() : ("code " + code))
        root.statusToast = "Upgrade request rejected for " + target + ": " + msg
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: upgradeAllProc
    stdout: StdioCollector { id: upgradeAllOut; waitForEnd: true }
    stderr: StdioCollector { id: upgradeAllErr; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        var pSuccess = Model.parse(upgradeAllOut.text, null)
        root.statusToast = (pSuccess && pSuccess.message) ? pSuccess.message : "Upgrade batch request accepted. Refresh to monitor fleet progress."
        root.toastType = "info"
        root.refreshRequested()
      } else {
        var pFail = Model.parse(upgradeAllOut.text, null)
        var msg = (pFail && pFail.error) ? pFail.error : (upgradeAllErr.text ? upgradeAllErr.text.trim() : ("code " + code))
        root.statusToast = "Upgrade batch request rejected: " + msg
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: backupProc
    stdout: StdioCollector { id: backupOut; waitForEnd: true }
    stderr: StdioCollector { id: backupErr; waitForEnd: true }
    onExited: function(code) {
      var target = root.pendingBackupConsoleTarget || "console"
      if (code === 0) {
        var pSuccess = Model.parse(backupOut.text, null)
        root.statusToast = (pSuccess && pSuccess.message) ? pSuccess.message : ("Backup request accepted for " + target + ". Refresh to verify backup completion.")
        root.toastType = "info"
        root.refreshRequested()
      } else {
        var pFail = Model.parse(backupOut.text, null)
        var msg = (pFail && pFail.error) ? pFail.error : (backupErr.text ? backupErr.text.trim() : ("code " + code))
        root.statusToast = "Backup request rejected for " + target + ": " + msg
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Process {
    id: notifyProc
    stdout: StdioCollector { id: notifyOut; waitForEnd: true }
    stderr: StdioCollector { id: notifyErr; waitForEnd: true }
    onExited: function(code) {
      if (code === 0) {
        root.statusToast = "Desktop notification sent successfully!"
        root.toastType = "success"
      } else {
        root.statusToast = "Desktop notification dispatch failed"
        root.toastType = "error"
      }
      toastTimer.restart()
    }
  }

  Timer {
    id: toastTimer
    interval: 5000
    onTriggered: { root.statusToast = "" }
  }

  function upgradeDevice(hostId, mac, deviceName, siteId) {
    if (!mac) return
    var targetLabel = (deviceName || mac)
    root.pendingUpgradeDeviceTarget = targetLabel
    root.statusToast = "Submitting upgrade request for " + targetLabel + "..."
    root.toastType = "info"
    var cmd = [root.helper, "upgrade-device", String(hostId || "console-home"), String(mac)]
    if (siteId && String(siteId).trim() !== "") cmd.push(String(siteId))
    if (deviceName && String(deviceName).trim() !== "") cmd.push("--name", String(deviceName).trim())
    upgradeDevProc.command = cmd
    upgradeDevProc.running = true
  }

  function upgradeAllDevices() {
    var count = (root.fleetUpdates && root.fleetUpdates.length) ? root.fleetUpdates.length : 0
    var targetLabel = count > 0 ? (count + " pending devices") : "all devices"
    root.statusToast = "Submitting fleet upgrade batch request for " + targetLabel + "..."
    root.toastType = "info"
    upgradeAllProc.command = [root.helper, "upgrade-all"]
    upgradeAllProc.running = true
  }

  function triggerBackup(hostId, consoleName) {
    var cName = consoleName || hostId || "console"
    root.pendingBackupConsoleTarget = cName
    root.statusToast = "Submitting backup request for console: " + cName + "..."
    root.toastType = "info"
    var cmd = [root.helper, "backup", String(hostId || "console-home")]
    if (cName && String(cName).trim() !== "") cmd.push("--name", String(cName).trim())
    backupProc.command = cmd
    backupProc.running = true
  }

  function sendDesktopNotification(title, message, urgency) {
    notifyProc.command = [root.helper, "notify", "--title", String(title || "UniFi SiteThread"), "--message", String(message || "Test"), "--urgency", String(urgency || "normal")]
    notifyProc.running = true
  }

  function cyclePort(hostId, mac, portIdx, portName, siteId) {
    if (!hostId || !mac) return
    var swName = (root.currentSwitch && root.currentSwitch.name) ? root.currentSwitch.name : mac
    var pName = portName || ("Port " + portIdx)
    var sid = siteId || (root.currentSwitch ? root.currentSwitch.siteId : "") || ""
    root.pendingCycleTarget = pName + " on " + swName
    root.statusToast = "Submitting PoE power cycle request for " + pName + " on " + swName + "..."
    root.toastType = "info"
    var cmd = [root.helper, "power-cycle", String(hostId), String(mac), String(portIdx)]
    if (sid && String(sid).trim() !== "") cmd.push(String(sid))
    if (swName && String(swName).trim() !== "") cmd.push("--name", String(swName).trim())
    powerCycleProc.command = cmd
    powerCycleProc.running = true
  }

  function pingHost(ip) {
    if (!ip) return
    root.pendingPingTarget = String(ip)
    root.statusToast = "Pinging target host " + ip + "..."
    root.toastType = "info"
    pingProc.command = ["ping", "-c", "3", "-W", "2", String(ip)]
    pingProc.running = true
  }

  function copyToClipboard(text, label) {
    if (!text) return
    Quickshell.execDetached(["wl-copy", String(text)])
    root.statusToast = "Copied " + (label || "link") + " to clipboard!"
    root.toastType = "success"
    toastTimer.restart()
  }

  function openExternalUrl(url) {
    if (!url) return
    Quickshell.execDetached(["xdg-open", String(url)])
    root.statusToast = "Opening " + String(url) + "..."
    root.toastType = "info"
    toastTimer.restart()
  }

  function toggleSiteSelection(site) {
    if (tab0View && typeof tab0View.toggleSiteSelection === "function") {
      tab0View.toggleSiteSelection(site)
    }
  }

  function clearSiteSelection() {
    if (tab0View && typeof tab0View.clearSiteSelection === "function") {
      tab0View.clearSiteSelection()
    }
  }

  FocusScope {
    id: windowFocusScope
    anchors.fill: parent
    focus: true

    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root.visible = false
        root.closed()
        event.accepted = true
      }
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.space(16)
      spacing: Style.space(12)

      // Top Header
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(10)

        UnifiIcon {
          size: Style.space(24)
          color: root.accent
          Layout.alignment: Qt.AlignVCenter
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 1

          Text {
            textFormat: Text.PlainText;
            text: "UNIFI FLEET ANALYTICS & TELEMETRY"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          Text {
            textFormat: Text.PlainText;
            text: "Aggregate WAN Uptime, Traffic Throughput, Client Distribution & Switch PoE Matrix"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        // Action buttons: Refresh and Close
        RowLayout {
          Layout.fillWidth: false
          Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
          spacing: Style.space(6)

          // Refresh button
          Rectangle {
            id: refBtn
            radius: 4
            color: refMouse.containsMouse ? root.cardHover : root.track
            Layout.preferredWidth: Style.space(26)
            Layout.preferredHeight: Style.space(26)

            Text {
              id: refBtnIcon
              textFormat: Text.PlainText;
              anchors.centerIn: parent
              text: ""
              color: root.isRefreshing ? root.accent : (refMouse.containsMouse ? root.foreground : root.dim)
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              transformOrigin: Item.Center

              RotationAnimation on rotation {
                running: root.isRefreshing
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
              onClicked: {
                root.refreshRequested()
              }
            }

            PanelToolTip {
              visible: refMouse.containsMouse
              text: "Refresh fleet telemetry & analytics"
              fontFamily: root.fontFamily
            }
          }

          // Close button
          Rectangle {
            radius: 4
            color: closeMouse.containsMouse ? root.cardHover : root.track
            Layout.preferredWidth: Style.space(26)
            Layout.preferredHeight: Style.space(26)

            Text {
              textFormat: Text.PlainText;
              anchors.centerIn: parent
              text: "✕"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            MouseArea {
              id: closeMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.visible = false
                root.closed()
              }
            }

            PanelToolTip {
              visible: closeMouse.containsMouse
              text: "Close analytics window"
              fontFamily: root.fontFamily
            }
          }
        }
      }

      // Tab Bar (7 evenly-spaced tabs spanning the window width)
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        // Tab 0: Overview & Mesh
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab0Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 0 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 0 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "Overview & Mesh"
              color: root.currentTab === 0 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 0
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: tab0Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 0 }
          }

          PanelToolTip {
            visible: tab0Mouse.containsMouse
            text: "Overview & Mesh"
            fontFamily: root.fontFamily
          }
        }

        // Tab 1: Client Telemetry
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 1 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab1Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 1 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 1 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "Client Telemetry (" + (root.fleetData && root.fleetData.clients ? root.fleetData.clients.length : (root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 0)) + ")"
              color: root.currentTab === 1 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 1
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: tab1Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 1 }
          }

          PanelToolTip {
            visible: tab1Mouse.containsMouse
            text: "Client Telemetry (" + (root.fleetData && root.fleetData.clients ? root.fleetData.clients.length : (root.fleetData && root.fleetData.network ? root.fleetData.network.clientCount : 0)) + ")"
            fontFamily: root.fontFamily
          }
        }

        // Tab 2: WAN & Outages
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 2 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab2Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 2 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 2 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "WAN & Outages (" + (root.fleetData && root.fleetData.wans ? root.fleetData.wans.length : 0) + ")"
              color: root.currentTab === 2 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 2
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: tab2Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 2 }
          }

          PanelToolTip {
            visible: tab2Mouse.containsMouse
            text: "WAN & Outages (" + (root.fleetData && root.fleetData.wans ? root.fleetData.wans.length : 0) + ")"
            fontFamily: root.fontFamily
          }
        }

        // Tab 3: Switch Ports & PoE
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 3 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab3Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 3 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 3 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "Switch Ports & PoE (" + (root.availableSwitches ? root.availableSwitches.length : 0) + ")"
              color: root.currentTab === 3 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 3
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: tab3Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 3 }
          }

          PanelToolTip {
            visible: tab3Mouse.containsMouse
            text: "Switch Ports & PoE (" + (root.availableSwitches ? root.availableSwitches.length : 0) + ")"
            fontFamily: root.fontFamily
          }
        }

        // Tab 4: UniFi OS & Direct Connect
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 4 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab4Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 4 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 4 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "UniFi OS & Direct Connect (" + (root.fleetConsoles ? root.fleetConsoles.length : 0) + ")"
              color: root.currentTab === 4 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 4
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: tab4Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 4 }
          }

          PanelToolTip {
            visible: tab4Mouse.containsMouse
            text: "UniFi OS & Direct Connect (" + (root.fleetConsoles ? root.fleetConsoles.length : 0) + ")"
            fontFamily: root.fontFamily
          }
        }

        // Tab 5: WiFi & RF Spectrum
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 5 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab5Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 5 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 5 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "WiFi & RF Spectrum (" + (root.fleetWlans ? root.fleetWlans.length : 0) + ")"
              color: root.currentTab === 5 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 5
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: tab5Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 5 }
          }

          PanelToolTip {
            visible: tab5Mouse.containsMouse
            text: "WiFi & RF Spectrum (" + (root.fleetWlans ? root.fleetWlans.length : 0) + ")"
            fontFamily: root.fontFamily
          }
        }

        // Tab 6: Firmware & Backups
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredWidth: 1
          Layout.minimumWidth: 0
          Layout.preferredHeight: Style.space(34)
          radius: 6
          clip: true
          color: root.currentTab === 6 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18) : (tab6Mouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.currentTab === 6 ? root.accent : root.outline

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(5)
            anchors.rightMargin: Style.space(5)
            spacing: Style.space(3)
            Text {
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: ""
              color: root.currentTab === 6 ? root.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }
            Text {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              textFormat: Text.PlainText;
              text: "Firmware & Backups (" + (root.fleetUpdates ? root.fleetUpdates.length : 0) + ")"
              color: root.currentTab === 6 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: root.currentTab === 6
              elide: Text.ElideMiddle
            }
          }

          MouseArea {
            id: tab6Mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.currentTab = 6 }
          }

          PanelToolTip {
            visible: tab6Mouse.containsMouse
            text: "Firmware & Backups (" + (root.fleetUpdates ? root.fleetUpdates.length : 0) + ")"
            fontFamily: root.fontFamily
          }
        }
      }

      // Status Toast (Inline banner when active)
      StatusToast {
        message: root.statusToast
        toastType: root.toastType
        foreground: root.foreground
        accent: root.accent
        healthy: root.healthy
        urgent: root.urgent
        fontFamily: root.fontFamily
      }

      // ==========================================
      // TAB 0: OVERVIEW & WAN MESH
      // ==========================================
      OverviewTab {
        id: tab0View
        visible: root.currentTab === 0
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetData: root.fleetData
        isLightTheme: root.isLightTheme
        selectedSiteIds: root.selectedSiteIds
        chartHoverIndex: root.chartHoverIndex
        chartHoverMouseX: root.chartHoverMouseX
        chartHoverMouseY: root.chartHoverMouseY

        foreground: root.foreground
        dim: root.dim
        accent: root.accent
        accentForeground: root.accentForeground
        urgent: root.urgent
        healthy: root.healthy
        backup: root.backup
        cardHover: root.cardHover
        track: root.track
        outline: root.outline
        fontFamily: root.fontFamily
      }

      // ==========================================
      // TAB 1: GRANULAR CLIENT TELEMETRY & UPLINK
      // ==========================================
      ClientsTab {
        id: tab1View
        visible: root.currentTab === 1
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetData: root.fleetData
        clientSearch: root.clientSearch
        clientSiteFilter: root.clientSiteFilter
        clientMediumFilter: root.clientMediumFilter

        foreground: root.foreground
        dim: root.dim
        accent: root.accent
        urgent: root.urgent
        healthy: root.healthy
        backup: root.backup
        cardHover: root.cardHover
        track: root.track
        outline: root.outline
        fontFamily: root.fontFamily

        onClientSearchChanged: { root.clientSearch = tab1View.clientSearch }
        onClientSiteFilterChanged: { root.clientSiteFilter = tab1View.clientSiteFilter }
        onClientMediumFilterChanged: { root.clientMediumFilter = tab1View.clientMediumFilter }
        onPingHostRequested: function(host, label) { root.pingHost(host, label) }
      }

      // ==========================================
      // TAB 2: WAN INTERFACES & OUTAGES
      // ==========================================
      WanTab {
        id: tab2View
        visible: root.currentTab === 2
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetData: root.fleetData

        foreground: root.foreground
        dim: root.dim
        accent: root.accent
        urgent: root.urgent
        healthy: root.healthy
        backup: root.backup
        cardHover: root.cardHover
        track: root.track
        outline: root.outline
        fontFamily: root.fontFamily

        onPingHostRequested: function(host, label) { root.pingHost(host, label) }
      }

      // ==========================================
      // TAB 3: SWITCH PORTS & POE POWER CYCLING
      // ==========================================
      SwitchesTab {
        id: tab3View
        visible: root.currentTab === 3
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetData: root.fleetData
        selectedSwitchSite: root.selectedSwitchSite
        selectedSwitchMac: root.selectedSwitchMac
        switchSiteOptions: root.switchSiteOptions
        switchOptionsForSelectedSite: root.switchOptionsForSelectedSite
        currentSwitch: root.currentSwitch
        isLightTheme: root.isLightTheme
        portFilter: root.portFilter

        foreground: root.foreground
        dim: root.dim
        accent: root.accent
        urgent: root.urgent
        healthy: root.healthy
        backup: root.backup
        cardHover: root.cardHover
        track: root.track
        outline: root.outline
        fontFamily: root.fontFamily

        onSelectedSwitchSiteChanged: { root.selectedSwitchSite = tab3View.selectedSwitchSite }
        onSelectedSwitchMacChanged: { root.selectedSwitchMac = tab3View.selectedSwitchMac }
        onSwitchSiteSelected: function(site) { root.selectedSwitchSite = site }
        onSwitchMacSelected: function(mac) { root.selectedSwitchMac = mac }
        onCyclePortRequested: function(hId, mac, pIdx, name, sId) { root.cyclePort(hId, mac, pIdx, name, sId) }
      }

      // ==========================================
      // TAB 4: UNIFI OS APPLICATIONS & DIRECT CONNECT
      // ==========================================
      ConsolesTab {
        id: tab4View
        visible: root.currentTab === 4
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetConsoles: root.fleetConsoles
        fleetData: root.fleetData
        consoleSearch: root.consoleSearch
        consoleSiteFilter: root.consoleSiteFilter
        selectedConsoleIndex: root.selectedConsoleIndex

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

        onConsoleSearchChanged: { root.consoleSearch = tab4View.consoleSearch }
        onConsoleSiteFilterChanged: { root.consoleSiteFilter = tab4View.consoleSiteFilter }
        onSelectedConsoleIndexChanged: { root.selectedConsoleIndex = tab4View.selectedConsoleIndex }
        onOpenExternalUrlRequested: function(url) { root.openExternalUrl(url) }
        onCopyToClipboardRequested: function(text, label) { root.copyToClipboard(text, label) }
      }

      // ==========================================
      // TAB 5: WIFI & RF SPECTRUM HEALTH
      // ==========================================
      WifiTab {
        id: tab5View
        visible: root.currentTab === 5
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetWlans: root.fleetWlans
        fleetSpectrum: root.fleetSpectrum
        fleetData: root.fleetData
        wlanSearch: root.wlanSearch
        wlanSiteFilter: root.wlanSiteFilter
        selectedWlanForQr: root.selectedWlanForQr
        showQrModal: root.showQrModal

        foreground: root.foreground
        dim: root.dim
        accent: root.accent
        accentForeground: root.accentForeground
        urgent: root.urgent
        healthy: root.healthy
        healthyForeground: root.healthyForeground
        backup: root.backup
        card: root.card
        cardHover: root.cardHover
        track: root.track
        outline: root.outline
        fontFamily: root.fontFamily
        isLightTheme: root.isLightTheme

        onWlanSearchChanged: { root.wlanSearch = tab5View.wlanSearch }
        onWlanSiteFilterChanged: { root.wlanSiteFilter = tab5View.wlanSiteFilter }
        onSelectedWlanForQrChanged: { root.selectedWlanForQr = tab5View.selectedWlanForQr }
        onShowQrModalChanged: { root.showQrModal = tab5View.showQrModal }
        onCopyToClipboardRequested: function(text, label) { root.copyToClipboard(text, label) }
      }

      // ==========================================
      // TAB 6: FIRMWARE & LIFECYCLE MANAGEMENT
      // ==========================================
      FirmwareTab {
        id: tab6View
        visible: root.currentTab === 6
        Layout.fillWidth: true
        Layout.fillHeight: true

        fleetData: root.fleetData
        fleetUpdates: root.fleetUpdates
        fleetBackups: root.fleetBackups
        fleetOperations: root.fleetOperations
        fleetSwitches: root.availableSwitches
        fleetConsoles: root.fleetConsoles
        updateSearch: root.updateSearch
        updateSiteFilter: root.updateSiteFilter
        updateSeverityFilter: root.updateSeverityFilter
        bulkUpdateConfirm: root.bulkUpdateConfirm

        foreground: root.foreground
        dim: root.dim
        accent: root.accent
        accentForeground: root.accentForeground
        urgent: root.urgent
        urgentForeground: root.urgentForeground
        healthy: root.healthy
        healthyForeground: root.healthyForeground
        backup: root.backup
        card: root.card
        cardHover: root.cardHover
        track: root.track
        outline: root.outline
        fontFamily: root.fontFamily

        onUpgradeDeviceRequested: function(hId, mac, name, sId) { root.upgradeDevice(hId, mac, name, sId) }
        onUpgradeAllRequested: root.upgradeAllDevices()
        onTriggerBackupRequested: function(hId, name) { root.triggerBackup(hId, name) }
        onBulkUpdateConfirmChanged: { root.bulkUpdateConfirm = tab6View.bulkUpdateConfirm }
      }
    }
  }
}
