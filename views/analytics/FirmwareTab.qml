import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../.."
import "../../components"
import "../../Model.js" as Model

ColumnLayout {
  id: root

  property var fleetUpdates: []
  property var fleetBackups: []
  property var fleetOperations: []
  property var fleetSwitches: []
  property var fleetConsoles: []
  property string updateSearch: ""
  property string updateSiteFilter: "All"
  property string updateSeverityFilter: "All"
  property bool bulkUpdateConfirm: false
  property var fleetData: ({})
  property var capabilities: root.fleetData && root.fleetData.capabilities ? root.fleetData.capabilities : null
  readonly property bool canUpgradeFirmware: {
    if (!root.capabilities || !root.capabilities.firmwareUpgrade) return true
    return root.capabilities.firmwareUpgrade.allowed !== false
  }
  readonly property string firmwareWarning: {
    if (root.capabilities && root.capabilities.firmwareUpgrade && !root.canUpgradeFirmware) {
      return root.capabilities.firmwareUpgrade.warning || root.capabilities.firmwareUpgrade.missingPermission || "Missing 'firmware:upgrade' scope: Firmware upgrades are restricted for this API key"
    }
    return "Missing 'firmware:upgrade' scope: Firmware upgrades are restricted for this API key"
  }

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color urgent: (Color.urgent || "#FF4D5A")
  property color urgentForeground: "#ffffff"
  property color healthy: "#10B981"
  property color healthyForeground: "#ffffff"
  property color backup: "#f59e0b"
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal upgradeDeviceRequested(string hostId, string mac, string deviceName, string siteId)
  signal upgradeAllRequested()
  signal triggerBackupRequested(string hostId, string consoleName)

  spacing: Style.space(8)

  readonly property var rawUpdates: root.fleetUpdates || []
  readonly property var filteredUpdates: {
    var list = []
    for (var i = 0; i < rawUpdates.length; i++) {
      var u = rawUpdates[i]
      if (root.updateSiteFilter !== "All" && u.siteName !== root.updateSiteFilter) continue
      if (root.updateSeverityFilter !== "All" && u.category !== root.updateSeverityFilter.toLowerCase()) continue
      if (root.updateSearch.trim() !== "") {
        var q = root.updateSearch.toLowerCase()
        var nameMatch = String(u.name || "").toLowerCase().indexOf(q) >= 0
        var modelMatch = String(u.model || "").toLowerCase().indexOf(q) >= 0
        var siteMatch = String(u.siteName || "").toLowerCase().indexOf(q) >= 0
        var verMatch = String(u.targetVersion || "").toLowerCase().indexOf(q) >= 0
        if (!nameMatch && !modelMatch && !siteMatch && !verMatch) continue
      }
      list.push(u)
    }
    return list
  }

  function resolveDeviceName(macOrId) {
    if (!macOrId) return ""
    var str = String(macOrId).trim()
    var strLower = str.toLowerCase()

    if (root.fleetUpdates && root.fleetUpdates.length) {
      for (var i = 0; i < root.fleetUpdates.length; i++) {
        var u = root.fleetUpdates[i]
        if (!u) continue
        if (u.mac && String(u.mac).toLowerCase() === strLower && u.name) return u.name
        if (u.hostId && String(u.hostId).toLowerCase() === strLower && u.name) return u.name
        if (u.deviceId && String(u.deviceId).toLowerCase() === strLower && u.name) return u.name
      }
    }

    if (root.fleetSwitches && root.fleetSwitches.length) {
      for (var s = 0; s < root.fleetSwitches.length; s++) {
        var sw = root.fleetSwitches[s]
        if (!sw) continue
        if (sw.mac && String(sw.mac).toLowerCase() === strLower && sw.name) return sw.name
        if (sw.hostId && String(sw.hostId).toLowerCase() === strLower && sw.name) return sw.name
        if (sw.id && String(sw.id).toLowerCase() === strLower && sw.name) return sw.name
      }
    }

    if (root.fleetConsoles && root.fleetConsoles.length) {
      for (var c = 0; c < root.fleetConsoles.length; c++) {
        var con = root.fleetConsoles[c]
        if (!con) continue
        if (con.hostId && String(con.hostId).toLowerCase() === strLower && con.name) return con.name
        if (con.mac && String(con.mac).toLowerCase() === strLower && con.name) return con.name
        if (con.name && String(con.name).toLowerCase() === strLower) return con.name
      }
    }

    if (root.fleetBackups && root.fleetBackups.length) {
      for (var j = 0; j < root.fleetBackups.length; j++) {
        var b = root.fleetBackups[j]
        if (!b) continue
        if (b.hostId && String(b.hostId).toLowerCase() === strLower && b.name) return b.name
        if (b.name && String(b.name).toLowerCase() === strLower) return b.name
      }
    }

    var fallbacks = {
      "74:83:c2:22:33:44": "USW Pro 24 PoE",
      "74:83:c2:55:66:77": "Living Room AP",
      "74:83:c2:88:99:aa": "Main Office Gateway",
      "74:83:c2:bb:cc:dd": "Driveway AI Pro",
      "68:d7:9a:11:00:01": "Home Gateway",
      "68:d7:9a:11:22:33": "Living Room AP",
      "a8:9c:6c:06:23:cc": "Main Office Gateway",
      "a8:9c:6c:06:23:cd": "Main Office Gateway",
      "f0:9f:c2:11:22:33": "Warehouse Gateway",
      "console-home": "Home Gateway",
      "console-office": "Main Office Gateway",
      "console-warehouse": "Warehouse Gateway",
      "local-gateway": "Local Gateway"
    }
    if (fallbacks[strLower]) return fallbacks[strLower]

    return ""
  }

  function replaceMacsWithHostnames(text) {
    if (!text) return ""
    var s = String(text)
    var defaultSwitchName = (root.fleetSwitches && root.fleetSwitches.length > 0 && root.fleetSwitches[0].name)
      ? root.fleetSwitches[0].name
      : "Switch"
    s = s.replace(/Core\s+Switch/gi, defaultSwitchName)
    s = s.replace(/Port\s+(\d+)\s*\(([0-9a-fA-F:]{17})\)/gi, function(match, portNum, macStr) {
      var resolved = root.resolveDeviceName(macStr)
      return "Port " + portNum + " on " + (resolved || macStr)
    })
    var macRegex = /\b([0-9a-fA-F]{2}(?::[0-9a-fA-F]{2}){5})\b/g
    return s.replace(macRegex, function(match) {
      var resolved = root.resolveDeviceName(match)
      return resolved ? resolved : match
    })
  }

  function formatOperationTitle(modelData) {
    if (!modelData) return ""
    var dName = modelData.deviceName || modelData.device_name || ""
    if (dName && String(dName).trim()) {
      var nameStr = String(dName).trim()
      if (modelData.type === "upgrade") return "Firmware Upgrade: " + nameStr
      if (modelData.type === "power_cycle" && modelData.title) {
        return root.replaceMacsWithHostnames(modelData.title)
      }
      if (modelData.type === "backup") return "Cloud Backup: " + nameStr
    }
    var rawTitle = modelData.title || modelData.target || ""
    return root.replaceMacsWithHostnames(rawTitle)
  }

  function formatOperationMessage(modelData) {
    if (!modelData) return ""
    var rawMsg = modelData.message || ""
    return root.replaceMacsWithHostnames(rawMsg)
  }

  Flickable {
    Layout.fillWidth: true
    Layout.fillHeight: true
    contentWidth: width
    contentHeight: tab6ContentCol.implicitHeight + Style.space(20)
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    ColumnLayout {
      id: tab6ContentCol
      width: parent.width
      spacing: Style.space(10)

      // Top KPI Strip
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        // Metric 1: Pending Updates
        BorderSurface {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(48)
          color: root.card
          radius: 6
          borderSpec: Border.flat(root.fleetUpdates.length > 0 ? root.backup : root.healthy, 1)

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Text { textFormat: Text.PlainText; text: ""; color: root.fleetUpdates.length > 0 ? root.backup : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.title }
            ColumnLayout {
              spacing: 1
              Text { textFormat: Text.PlainText; text: "PENDING UPDATES"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
              Text { textFormat: Text.PlainText; text: String(root.fleetUpdates.length) + " Devices"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            }
          }
        }

        // Metric 2: Release Channel
        BorderSurface {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(48)
          color: root.card
          radius: 6
          borderSpec: Border.flat(root.outline, 1)

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.title }
            ColumnLayout {
              spacing: 1
              Text { textFormat: Text.PlainText; text: "RELEASE CHANNEL"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
              Text { textFormat: Text.PlainText; text: "Official (GA)"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true }
            }
          }
        }

        // Metric 3: Automated Backups
        BorderSurface {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(48)
          color: root.card
          radius: 6
          borderSpec: Border.flat(root.healthy, 1)

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.title }
            ColumnLayout {
              spacing: 1
              Text { textFormat: Text.PlainText; text: "CLOUD BACKUPS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
              Text { textFormat: Text.PlainText; text: String(root.fleetBackups.length) + " Consoles Protected"; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
            }
          }
        }

        // Metric 4: Auto-Scheduled Maintenance
        BorderSurface {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.space(48)
          color: root.card
          radius: 6
          borderSpec: Border.flat(root.outline, 1)

          RowLayout {
            anchors.fill: parent
            anchors.margins: Style.space(8)
            spacing: Style.space(8)

            Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.title }
            ColumnLayout {
              spacing: 1
              Text { textFormat: Text.PlainText; text: "MAINTENANCE WINDOW"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
              Text { textFormat: Text.PlainText; text: "Sundays at 03:00"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }
            }
          }
        }
      }

      // Bulk Action Banner
      BorderSurface {
        Layout.fillWidth: true
        implicitHeight: bulkRow.implicitHeight + Style.space(16)
        color: root.track
        radius: 6
        borderSpec: Border.flat(root.accent, 1)

        RowLayout {
          id: bulkRow
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(10)

          Rectangle {
            width: Style.space(32)
            height: Style.space(32)
            radius: 6
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
            Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body }
          }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            Text { textFormat: Text.PlainText; text: "FLEET FIRMWARE BATCH DEPLOYMENT"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
            Text {
              textFormat: Text.PlainText;
              text: root.fleetUpdates.length > 0 ? (root.fleetUpdates.length + " hardware devices have official UniFi firmware updates ready to install.") : "All fleet devices are current on official UniFi firmware releases."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }

          // Update All Button
          Rectangle {
            readonly property bool hasUpdates: root.fleetUpdates.length > 0
            implicitHeight: Style.space(28)
            implicitWidth: updateAllBtnText.implicitWidth + Style.space(18)
            radius: 4
            opacity: !root.canUpgradeFirmware ? 0.45 : 1.0
            color: !hasUpdates ? root.track : (!root.canUpgradeFirmware ? root.track : (root.bulkUpdateConfirm ? (updateAllMouse.containsMouse ? Qt.lighter(root.urgent, 1.1) : root.urgent) : (updateAllMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent)))
            border.width: 1
            border.color: !hasUpdates ? root.outline : (!root.canUpgradeFirmware ? root.outline : (root.bulkUpdateConfirm ? root.urgent : root.accent))

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text {
                textFormat: Text.PlainText;
                text: !root.canUpgradeFirmware ? "" : (!parent.parent.hasUpdates ? "" : (root.bulkUpdateConfirm ? "" : ""))
                color: !parent.parent.hasUpdates ? root.healthy : (!root.canUpgradeFirmware ? root.dim : (root.bulkUpdateConfirm ? root.urgentForeground : root.accentForeground))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                textFormat: Text.PlainText;
                id: updateAllBtnText
                text: !root.canUpgradeFirmware ? "Upgrades Restricted" : (!parent.parent.hasUpdates ? "All Devices Up to Date" : (root.bulkUpdateConfirm ? "Confirm Update All" : "Update All Devices"))
                color: !parent.parent.hasUpdates ? root.dim : (!root.canUpgradeFirmware ? root.dim : (root.bulkUpdateConfirm ? root.urgentForeground : root.accentForeground))
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
            }

            MouseArea {
              id: updateAllMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: !root.canUpgradeFirmware ? Qt.ForbiddenCursor : (parent.hasUpdates ? Qt.PointingHandCursor : Qt.ArrowCursor)
              onClicked: {
                if (!root.canUpgradeFirmware || !parent.hasUpdates) return
                if (!root.bulkUpdateConfirm) {
                  root.bulkUpdateConfirm = true
                } else {
                  root.bulkUpdateConfirm = false
                  root.upgradeAllRequested()
                }
              }
            }

            PanelToolTip {
              visible: updateAllMouse.containsMouse
              text: !root.canUpgradeFirmware
                ? "Cannot upgrade: API key lacks 'firmware:upgrade' permission"
                : (!parent.hasUpdates ? "All fleet devices are running current firmware" : (root.bulkUpdateConfirm ? "Click again to confirm batch upgrade of " + root.fleetUpdates.length + " devices" : "Batch deploy official firmware to all " + root.fleetUpdates.length + " devices"))
              fontFamily: root.fontFamily
            }
          }
        }
      }

      // Inline Firmware Permission Warning Banner
      Rectangle {
        id: firmwarePermissionBanner
        visible: !root.canUpgradeFirmware
        Layout.fillWidth: true
        implicitHeight: fwPermRow.implicitHeight + Style.space(12)
        radius: 4
        color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.12)
        border.width: 1
        border.color: root.urgent

        RowLayout {
          id: fwPermRow
          anchors.fill: parent
          anchors.margins: Style.space(6)
          spacing: Style.space(8)

          Text {
            textFormat: Text.PlainText;
            text: ""
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            textFormat: Text.PlainText;
            Layout.fillWidth: true
            text: root.firmwareWarning
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            wrapMode: Text.WordWrap
          }
        }
      }

      // Filters row
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        SearchField {
          placeholderText: "Search by device model, site, or version..."
          text: root.updateSearch
          foreground: root.foreground
          dim: root.dim
          track: root.track
          outline: root.outline
          accent: root.accent
          fontFamily: root.fontFamily
          onTextChanged: root.updateSearch = text
          onCleared: root.updateSearch = ""
        }

        FilterBar {
          model: ["All", "Gateways", "Switches", "APs", "Cameras"]
          selected: root.updateSeverityFilter
          foreground: root.foreground
          accent: root.accent
          accentForeground: root.accentForeground
          cardHover: root.cardHover
          track: root.track
          outline: root.outline
          fontFamily: root.fontFamily
          onFilterSelected: function(opt) { root.updateSeverityFilter = opt }
        }
      }

      // Section: Pending Updates List
      Text {
        textFormat: Text.PlainText;
        text: "PENDING FIRMWARE UPDATES (" + root.filteredUpdates.length + ")"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        BorderSurface {
          visible: root.filteredUpdates.length === 0
          Layout.fillWidth: true
          implicitHeight: Style.space(56)
          color: root.card
          radius: 6
          borderSpec: Border.flat(root.outline, 1)

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(8)
            Text {
              textFormat: Text.PlainText;
              text: ""
              color: root.healthy
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText;
              text: "All fleet hardware devices are up to date on official firmware"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }
        }

        Repeater {
          model: root.filteredUpdates
          delegate: BorderSurface {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: upRow.implicitHeight + Style.space(16)
            color: root.card
            radius: 6
            borderSpec: Border.flat(modelData.severity === "critical" ? root.urgent : (modelData.severity === "important" ? root.backup : root.accent), 1)

            RowLayout {
              id: upRow
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(10)

              Text { textFormat: Text.PlainText; text: ""; color: modelData.severity === "critical" ? root.urgent : (modelData.severity === "important" ? root.backup : root.accent); font.family: root.fontFamily; font.pixelSize: Style.font.body }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(6)
                  Text { textFormat: Text.PlainText; text: modelData.name + " (" + modelData.model + ")"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                  Rectangle {
                    implicitHeight: Style.space(16)
                    implicitWidth: upSiteText.implicitWidth + Style.space(8)
                    radius: 3
                    color: root.track
                    Text { textFormat: Text.PlainText; id: upSiteText; anchors.centerIn: parent; text: modelData.siteName; color: root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
                  }
                  Rectangle {
                    implicitHeight: Style.space(16)
                    implicitWidth: sevText.implicitWidth + Style.space(8)
                    radius: 3
                    color: (modelData.upgrading || modelData.status === "upgrading") ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : (modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : (modelData.severity === "important" ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)))
                    Text {
                      textFormat: Text.PlainText;
                      id: sevText;
                      anchors.centerIn: parent;
                      text: (modelData.upgrading || modelData.status === "upgrading") ? "REQUEST ACCEPTED" : modelData.severity.toUpperCase();
                      color: (modelData.upgrading || modelData.status === "upgrading") ? root.accent : (modelData.severity === "critical" ? root.urgent : (modelData.severity === "important" ? root.backup : root.accent));
                      font.family: root.fontFamily;
                      font.pixelSize: 8;
                      font.bold: true
                    }
                  }
                  Item { Layout.fillWidth: true }
                }

                Text {
                  textFormat: Text.PlainText;
                  text: "Current: " + modelData.currentVersion + "  ➜  Target: " + modelData.targetVersion + " (" + modelData.releaseChannel + ")"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  textFormat: Text.PlainText;
                  text: modelData.releaseNotes
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              // Update Device Button
              Rectangle {
                id: updateBtnRect
                implicitHeight: Style.space(26)
                implicitWidth: upBtnText.implicitWidth + Style.space(16)
                radius: 4
                property bool isPending: Boolean(modelData.upgrading || modelData.status === "upgrading")
                opacity: !root.canUpgradeFirmware ? 0.45 : 1.0
                color: updateBtnRect.isPending ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15) : (upBtnMouse.containsMouse ? (root.canUpgradeFirmware ? root.accent : root.track) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15))
                border.width: 1
                border.color: !root.canUpgradeFirmware ? root.outline : root.accent

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    textFormat: Text.PlainText;
                    text: !root.canUpgradeFirmware ? "" : (updateBtnRect.isPending ? "" : "");
                    color: !root.canUpgradeFirmware ? root.dim : (updateBtnRect.isPending ? root.accent : (upBtnMouse.containsMouse ? root.accentForeground : root.accent));
                    font.family: root.fontFamily;
                    font.pixelSize: 8
                  }
                  Text {
                    textFormat: Text.PlainText;
                    id: upBtnText;
                    text: !root.canUpgradeFirmware ? "Restricted" : (updateBtnRect.isPending ? "Request Accepted" : "Update Device");
                    color: !root.canUpgradeFirmware ? root.dim : (updateBtnRect.isPending ? root.accent : (upBtnMouse.containsMouse ? root.accentForeground : root.accent));
                    font.family: root.fontFamily;
                    font.pixelSize: Style.font.caption - 1;
                    font.bold: true
                  }
                }

                MouseArea {
                  id: upBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: !root.canUpgradeFirmware ? Qt.ForbiddenCursor : (updateBtnRect.isPending ? Qt.ArrowCursor : Qt.PointingHandCursor)
                  onClicked: {
                    if (!root.canUpgradeFirmware || updateBtnRect.isPending) return
                    root.upgradeDeviceRequested(modelData.hostId, modelData.mac, modelData.name, modelData.siteId || "")
                  }
                }

                PanelToolTip {
                  visible: upBtnMouse.containsMouse
                  text: !root.canUpgradeFirmware
                    ? "Cannot upgrade: API key lacks 'firmware:upgrade' permission"
                    : (updateBtnRect.isPending ? ("Upgrade request accepted for " + modelData.name + " · Status updates on refresh") : ("Submit firmware upgrade request (" + modelData.targetVersion + ") for " + modelData.name + " · Status updates on refresh"))
                  fontFamily: root.fontFamily
                }
              }
            }
          }
        }
      }

      // Section: Automated Cloud Configuration Backups
      Text {
        textFormat: Text.PlainText;
        text: "AUTOMATED CLOUD CONFIGURATION BACKUPS (" + root.fleetBackups.length + ")"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(8)

        Repeater {
          model: root.fleetBackups
          delegate: BorderSurface {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: bkCol.implicitHeight + Style.space(16)
            color: root.card
            radius: 6
            borderSpec: Border.flat(modelData.status === "healthy" ? root.healthy : root.backup, 1)

            ColumnLayout {
              id: bkCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(6)

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)
                Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                Text { textFormat: Text.PlainText; text: modelData.consoleName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                Rectangle {
                  implicitHeight: Style.space(16)
                  implicitWidth: bkStatusText.implicitWidth + Style.space(8)
                  radius: 3
                  color: modelData.status === "healthy" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  Text {
                    textFormat: Text.PlainText;
                    id: bkStatusText;
                    anchors.centerIn: parent;
                    text: modelData.status === "in_progress" ? "REQUEST ACCEPTED" : modelData.status.toUpperCase();
                    color: modelData.status === "healthy" ? root.healthy : root.accent;
                    font.family: root.fontFamily;
                    font.pixelSize: 8;
                    font.bold: true
                  }
                }
              }

              Text { textFormat: Text.PlainText; text: modelData.siteName + " · UniFi OS " + modelData.unifiOsVersion; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
              Text { textFormat: Text.PlainText; text: "Last Backup: " + modelData.lastBackup + " (" + modelData.sizeText + ")"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true }

              RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }

                Rectangle {
                  id: createBkBtnRect
                  implicitHeight: Style.space(26)
                  implicitWidth: createBkText.implicitWidth + Style.space(18)
                  radius: 4
                  property bool isPending: modelData.status === "in_progress"
                  color: createBkBtnRect.isPending ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15) : (createBkMouse.containsMouse ? root.healthy : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15))
                  border.width: 1
                  border.color: createBkBtnRect.isPending ? root.accent : root.healthy

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(5)
                    Text {
                      textFormat: Text.PlainText;
                      text: createBkBtnRect.isPending ? "" : "";
                      color: createBkBtnRect.isPending ? root.accent : (createBkMouse.containsMouse ? root.healthyForeground : root.healthy);
                      font.family: root.fontFamily;
                      font.pixelSize: 8
                    }
                    Text {
                      textFormat: Text.PlainText;
                      id: createBkText;
                      text: createBkBtnRect.isPending ? "Request Accepted" : "Create Backup Now";
                      color: createBkBtnRect.isPending ? root.accent : (createBkMouse.containsMouse ? root.healthyForeground : root.healthy);
                      font.family: root.fontFamily;
                      font.pixelSize: Style.font.caption - 1;
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: createBkMouse
                    anchors.fill: parent
                    hoverEnabled: !createBkBtnRect.isPending
                    cursorShape: createBkBtnRect.isPending ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: {
                      if (!createBkBtnRect.isPending) {
                        root.triggerBackupRequested(modelData.hostId, modelData.consoleName)
                      }
                    }
                  }

                  PanelToolTip {
                    visible: createBkMouse.containsMouse
                    text: createBkBtnRect.isPending ? ("Backup request accepted for " + modelData.consoleName + " · Status updates on refresh") : ("Submit cloud configuration backup request for " + modelData.consoleName + " · Status updates on refresh")
                    fontFamily: root.fontFamily
                  }
                }
              }
            }
          }
        }
      }

      // Section: Operations & Action Outcomes History
      Text {
        textFormat: Text.PlainText;
        text: "RECENT OPERATIONS & ACTION OUTCOMES (" + (root.fleetOperations ? root.fleetOperations.length : 0) + ")"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Repeater {
          model: root.fleetOperations || []
          delegate: BorderSurface {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: opHistCol.implicitHeight + Style.space(16)
            color: root.card
            radius: 6
            borderSpec: Border.flat(
              modelData.status === "completed" ? root.healthy :
              (modelData.status === "failed" ? root.urgent : root.accent),
              1
            )

            ColumnLayout {
              id: opHistCol
              anchors.fill: parent
              anchors.margins: Style.space(10)
              spacing: Style.space(4)

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                Rectangle {
                  implicitHeight: Style.space(18)
                  implicitWidth: opTagText.implicitWidth + Style.space(10)
                  radius: 3
                  color: {
                    if (modelData.status === "completed") return Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                    if (modelData.status === "failed") return Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2)
                    return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                  }

                  Text {
                    id: opTagText
                    anchors.centerIn: parent
                    textFormat: Text.PlainText;
                    text: {
                      if (modelData.status === "completed") return "COMPLETED"
                      if (modelData.status === "failed") return "FAILED"
                      if (modelData.status === "accepted") return "REQUEST ACCEPTED"
                      if (modelData.status === "in_progress") return "IN PROGRESS"
                      return String(modelData.status || "UNKNOWN").toUpperCase()
                    }
                    color: {
                      if (modelData.status === "completed") return root.healthy
                      if (modelData.status === "failed") return root.urgent
                      return root.accent
                    }
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }
                }

                Text {
                  textFormat: Text.PlainText;
                  text: root.formatOperationTitle(modelData)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }

                Text {
                  textFormat: Text.PlainText;
                  text: modelData.relativeTime || modelData.timeText || ""
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }

              Text {
                textFormat: Text.PlainText;
                text: root.formatOperationMessage(modelData)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }

              Text {
                visible: !!modelData.error
                textFormat: Text.PlainText;
                text: "Error details: " + modelData.error
                color: root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }
            }
          }
        }

        Text {
          visible: !(root.fleetOperations && root.fleetOperations.length > 0)
          textFormat: Text.PlainText;
          text: "No recent operations recorded in this session."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
        }
      }
    }
  }
}
