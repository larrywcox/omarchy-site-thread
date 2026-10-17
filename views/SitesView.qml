import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."
import "../components"
import "../Model.js" as Model

Column {
  id: root

  property string sitesSubView: "sites"
  property var fleetData: ({})
  property bool cloudMode: false
  property string deviceFilter: "all"
  property var fleetDevices: []
  property string timeRange: "24 hours"
  readonly property var timeOptions: ["24 hours", "12 hours", "6 hours", "1 hour"]

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#f59e0b"
  property color backupForeground: "#ffffff"
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal openSiteRequested(var site)
  function openSite(site) {
    openSiteRequested(site)
  }

  signal openAnalyticsRequested(int tabIndex)
  function openAnalytics(tabIndex) {
    openAnalyticsRequested(tabIndex)
  }

  signal launchSshRequested(string ip, string user)
  function launchSsh(ip, user) {
    launchSshRequested(ip, user)
  }

  signal launchPingRequested(string ip)
  function launchPing(ip) {
    launchPingRequested(ip)
  }

  function getSiteConsole(hostId) {
    if (!hostId || !root.fleetData || !root.fleetData.consoles) return null
    for (var i = 0; i < root.fleetData.consoles.length; i++) {
      var c = root.fleetData.consoles[i]
      if (c && c.hostId === hostId) return c
    }
    return null
  }

  function getAllFleetDevices() {
    return root.fleetDevices || []
  }

            spacing: Style.space(8)

            // Sub-navigation: Sites / Devices toggle
            RowLayout {
              width: root.width
              spacing: Style.space(4)

              Rectangle {
                implicitHeight: Style.space(22)
                implicitWidth: sitesSubPillRow.implicitWidth + Style.space(16)
                radius: 3
                color: root.sitesSubView === "sites" ? root.accent : (subSitesMouse.containsMouse ? root.cardHover : root.track)
                border.width: 1
                border.color: root.sitesSubView === "sites" ? root.accent : root.outline

                RowLayout {
                  id: sitesSubPillRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    textFormat: Text.PlainText;
                    text: "\uf132"
                    color: root.sitesSubView === "sites" ? root.accentForeground : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                  }
                  Text {
                    textFormat: Text.PlainText;
                    id: sitesSubPillText
                    text: root.cloudMode ? "Sites (" + (root.fleetData.sites ? root.fleetData.sites.length : 0) + ")" : "Sites"
                    color: root.sitesSubView === "sites" ? root.accentForeground : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: root.sitesSubView === "sites"
                  }
                }

                MouseArea {
                  id: subSitesMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.sitesSubView = "sites"
                }

                PanelToolTip {
                  visible: subSitesMouse.containsMouse
                  text: "View fleet sites and SD-WAN mesh connections"
                  fontFamily: root.fontFamily
                }
              }

              Rectangle {
                implicitHeight: Style.space(22)
                implicitWidth: devSubPillRow.implicitWidth + Style.space(16)
                radius: 3
                color: root.sitesSubView === "devices" ? root.accent : (subDevMouse.containsMouse ? root.cardHover : root.track)
                border.width: 1
                border.color: root.sitesSubView === "devices" ? root.accent : root.outline
                RowLayout {
                  id: devSubPillRow
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text {
                    textFormat: Text.PlainText;
                    text: "\uf0e8"
                    color: root.sitesSubView === "devices" ? root.accentForeground : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                  }
                  Text {
                    textFormat: Text.PlainText;
                    id: devSubPillText
                    text: "Devices (" + root.getAllFleetDevices().length + ")"
                    color: root.sitesSubView === "devices" ? root.accentForeground : root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: root.sitesSubView === "devices"
                  }
                }

                MouseArea {
                  id: subDevMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.sitesSubView = "devices"
                }

                PanelToolTip {
                  visible: subDevMouse.containsMouse
                  text: "View all network hardware devices across fleet"
                  fontFamily: root.fontFamily
                }
              }

              Item { Layout.fillWidth: true }
            }

            // SITES SUB-VIEW
            Column {
              visible: root.sitesSubView === "sites"
              width: root.width
              spacing: Style.space(8)

              RowLayout {
                width: root.width
                spacing: Style.space(4)

                PanelSectionHeader {
                  text: root.cloudMode ? "ALL SITES (" + (root.fleetData.sites ? root.fleetData.sites.length : 0) + ")" : "SITES"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                  spacing: Style.space(2)
                  Layout.alignment: Qt.AlignVCenter

                  Repeater {
                    model: root.timeOptions
                    delegate: Rectangle {
                      required property string modelData
                      readonly property bool isSelected: root.timeRange === modelData || (root.timeRange === "24h" && modelData === "24 hours") || (root.timeRange === "12h" && modelData === "12 hours") || (root.timeRange === "6h" && modelData === "6 hours") || (root.timeRange === "1h" && modelData === "1 hour")
                      implicitHeight: Style.space(20)
                      implicitWidth: optLabel.implicitWidth + Style.space(12)
                      radius: 3
                      color: isSelected ? root.accent : (optArea.containsMouse ? root.cardHover : root.track)
                      border.width: 1
                      border.color: isSelected ? root.accent : root.outline

                      Text {
                        id: optLabel
                        anchors.centerIn: parent
                        textFormat: Text.PlainText;
                        text: modelData
                        color: isSelected ? root.accentForeground : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        font.bold: isSelected
                      }

                      MouseArea {
                        id: optArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.timeRange = modelData
                        }
                      }

                      PanelToolTip {
                        visible: optArea.containsMouse
                        text: "Show " + modelData + " throughput telemetry"
                        fontFamily: root.fontFamily
                      }
                    }
                  }
                }
              }

              // Site Magic SD-WAN Mesh Banner
            BorderSurface {
              visible: Boolean(root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.available)
              width: root.width
              implicitHeight: sdwanRow.implicitHeight + Style.space(16)
              height: implicitHeight
              color: root.track
              radius: Style.cornerRadius
              borderSpec: Border.flat(root.accent, 1)

              RowLayout {
                id: sdwanRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Rectangle {
                  width: Style.space(8)
                  height: width
                  radius: width / 2
                  color: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.status === "connected") ? root.healthy : root.backup
                  Layout.alignment: Qt.AlignVCenter
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(2)
                  Layout.alignment: Qt.AlignVCenter

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText;
                      text: "Site Magic SD-WAN: " + (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.name ? root.fleetData.sdwan.name : ((root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 0) ? root.fleetData.sites[0].name + " Mesh" : "Inter-Site Mesh"))
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Rectangle {
                      height: Style.space(14)
                      implicitWidth: sdwanStatusText.implicitWidth + Style.space(8)
                      radius: 2
                      color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                      Text {
                        textFormat: Text.PlainText;
                        id: sdwanStatusText
                        anchors.centerIn: parent
                        text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.status === "connected") ? "ACTIVE" : "DEGRADED"
                        color: root.healthy
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections && root.fleetData.sdwan.connections.length > 0)
                      ? (root.fleetData.sdwan.connections[0].siteA + " (" + root.fleetData.sdwan.connections[0].subnetA + ") ⇄ " + root.fleetData.sdwan.connections[0].siteB + " (" + root.fleetData.sdwan.connections[0].subnetB + ") · Latency " + (root.fleetData.sdwan.ping < 1 ? "<1ms" : root.fleetData.sdwan.ping + "ms"))
                      : "Inter-site mesh active · Cross-subnet routing enabled"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                Rectangle {
                  implicitHeight: Style.space(22)
                  implicitWidth: sdwanBtnRow.implicitWidth + Style.space(14)
                  radius: 3
                  color: sdwanBtnMouse.containsMouse ? root.accent : root.card
                  border.width: 1
                  border.color: root.accent
                  Layout.alignment: Qt.AlignVCenter

                  Row {
                    id: sdwanBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: sdwanBtnMouse.containsMouse ? root.accentForeground : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      textFormat: Text.PlainText;
                      id: sdwanBtnText
                      text: "Mesh"
                      color: sdwanBtnMouse.containsMouse ? root.accentForeground : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: sdwanBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAnalytics(0)
                  }

                  PanelToolTip {
                    visible: sdwanBtnMouse.containsMouse
                    text: "Open SD-WAN Site Magic mesh topology and analytics"
                    fontFamily: root.fontFamily
                  }
                }
              }
            }

            // WiFi & RF Spectrum Health Cockpit Card
            BorderSurface {
              id: wifiSpectrumCard
              width: root.width
              implicitHeight: wifiCardRow.implicitHeight + Style.space(16)
              height: implicitHeight
              color: wifiCardMouse.containsMouse ? root.cardHover : root.card
              radius: Style.cornerRadius
              borderSpec: Border.flat(wifiCardMouse.containsMouse ? root.accent : root.outline, 1)

              MouseArea {
                id: wifiCardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openAnalytics(5)
              }

              RowLayout {
                id: wifiCardRow
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText;
                  text: ""
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(2)

                  RowLayout {
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText;
                      text: "WIFI & RF SPECTRUM HEALTH"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    Rectangle {
                      implicitHeight: Style.space(16)
                      implicitWidth: wifiSsidPillText.implicitWidth + Style.space(8)
                      radius: 2
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                      Text {
                        textFormat: Text.PlainText;
                        id: wifiSsidPillText
                        anchors.centerIn: parent
                        text: (root.fleetData && root.fleetData.wlans ? root.fleetData.wlans.length : 0) + " SSIDs"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: {
                      var sp = (root.fleetData && root.fleetData.spectrum && root.fleetData.spectrum.bands) ? root.fleetData.spectrum.bands : []
                      var u24 = sp.length > 0 ? (sp[0].utilization + "%") : "28%"
                      var u5 = sp.length > 1 ? (sp[1].utilization + "%") : "14%"
                      var u6 = sp.length > 2 ? (sp[2].utilization + "%") : "5%"
                      var clients = (root.fleetData && root.fleetData.network && root.fleetData.network.wifiClients !== undefined) ? root.fleetData.network.wifiClients : 0
                      return "RF Congestion: 2.4G " + u24 + " · 5G " + u5 + " · 6G " + u6 + " · " + clients + " WiFi clients"
                    }
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                Rectangle {
                  implicitHeight: Style.space(22)
                  implicitWidth: wifiBtnRow.implicitWidth + Style.space(14)
                  radius: 3
                  color: wifiBtnMouse.containsMouse ? root.accent : root.card
                  border.width: 1
                  border.color: root.accent
                  Layout.alignment: Qt.AlignVCenter

                  Row {
                    id: wifiBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: wifiBtnMouse.containsMouse ? root.accentForeground : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      textFormat: Text.PlainText;
                      id: wifiBtnText
                      text: "WiFi & RF"
                      color: wifiBtnMouse.containsMouse ? root.accentForeground : root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: wifiBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAnalytics(5)
                  }

                  PanelToolTip {
                    visible: wifiBtnMouse.containsMouse
                    text: "View SSID directory, WiFi QR code & RF band analysis"
                    fontFamily: root.fontFamily
                  }
                }
              }
            }

            // Fleet Firmware & Lifecycle Cockpit Card
            BorderSurface {
              id: firmwareCard
              width: root.width
              implicitHeight: fwCardRow.implicitHeight + Style.space(16)
              height: implicitHeight
              color: fwCardMouse.containsMouse ? root.cardHover : root.card
              radius: Style.cornerRadius
              readonly property int pendingUpCount: (root.fleetData && root.fleetData.firmwareUpdates) ? root.fleetData.firmwareUpdates.length : (root.fleetData && root.fleetData.network ? (root.fleetData.network.updateCount || 0) : 0)
              readonly property int backupCount: (root.fleetData && root.fleetData.backups) ? root.fleetData.backups.length : 0
              borderSpec: Border.flat(fwCardMouse.containsMouse ? (pendingUpCount > 0 ? root.backup : root.accent) : root.outline, 1)

              MouseArea {
                id: fwCardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.openAnalytics(6)
              }

              RowLayout {
                id: fwCardRow
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText;
                  text: ""
                  color: firmwareCard.pendingUpCount > 0 ? root.backup : root.healthy
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(2)

                  RowLayout {
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText;
                      text: "FLEET FIRMWARE & BACKUPS"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                    Rectangle {
                      implicitHeight: Style.space(16)
                      implicitWidth: fwPillText.implicitWidth + Style.space(8)
                      radius: 2
                      color: firmwareCard.pendingUpCount > 0 ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                      Text {
                        textFormat: Text.PlainText;
                        id: fwPillText
                        anchors.centerIn: parent
                        text: firmwareCard.pendingUpCount > 0 ? (firmwareCard.pendingUpCount + " UPDATES") : "UP TO DATE"
                        color: firmwareCard.pendingUpCount > 0 ? root.backup : root.healthy
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: {
                      var backupText = firmwareCard.backupCount > 0 ? (firmwareCard.backupCount + " cloud backups protected") : "Cloud backups active"
                      return firmwareCard.pendingUpCount > 0
                        ? (firmwareCard.pendingUpCount + " devices with available firmware · " + backupText)
                        : ("All fleet consoles and devices up to date · " + backupText)
                    }
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }
                }

                Rectangle {
                  implicitHeight: Style.space(22)
                  implicitWidth: fwBtnRow.implicitWidth + Style.space(14)
                  radius: 3
                  color: fwBtnMouse.containsMouse ? (firmwareCard.pendingUpCount > 0 ? root.backup : root.accent) : root.card
                  border.width: 1
                  border.color: firmwareCard.pendingUpCount > 0 ? root.backup : root.accent
                  Layout.alignment: Qt.AlignVCenter

                  Row {
                    id: fwBtnRow
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      textFormat: Text.PlainText;
                      text: ""
                      color: fwBtnMouse.containsMouse ? (firmwareCard.pendingUpCount > 0 ? root.backupForeground : root.accentForeground) : (firmwareCard.pendingUpCount > 0 ? root.backup : root.accent)
                      font.family: root.fontFamily
                      font.pixelSize: 10
                    }
                    Text {
                      textFormat: Text.PlainText;
                      id: fwBtnText
                      text: "Firmware"
                      color: fwBtnMouse.containsMouse ? (firmwareCard.pendingUpCount > 0 ? root.backupForeground : root.accentForeground) : (firmwareCard.pendingUpCount > 0 ? root.backup : root.accent)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                    }
                  }

                  MouseArea {
                    id: fwBtnMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.openAnalytics(6)
                  }

                  PanelToolTip {
                    visible: fwBtnMouse.containsMouse
                    text: "Manage fleet firmware upgrades and automated cloud backups"
                    fontFamily: root.fontFamily
                  }
                }
              }
            }

            Repeater {
              model: root.cloudMode
                ? (root.fleetData.sites || [])
                : (root.fleetData.network && root.fleetData.network.devices ? root.fleetData.network.devices : [])
              delegate: SiteRow {
                id: siteCardSurface
                width: root.width
                cloudMode: root.cloudMode
                timeRange: root.timeRange
                siteConsole: (modelData && modelData.hostId) ? root.getSiteConsole(modelData.hostId) : null
                foreground: root.foreground
                dim: root.dim
                accent: root.accent
                accentForeground: root.accentForeground
                card: root.card
                cardHover: root.cardHover
                track: root.track
                outline: root.outline
                urgent: root.urgent
                healthy: root.healthy
                backup: root.backup
                fontFamily: root.fontFamily

                onSiteClicked: function(s) { root.openSite(s) }
                onLaunchSshRequested: function(ip, user) { root.launchSsh(ip, user) }
                onLaunchPingRequested: function(ip) { root.launchPing(ip) }
                onTimeRangeChanged: {
                  if (siteCardSurface.timeRange && siteCardSurface.timeRange !== root.timeRange) {
                    root.timeRange = siteCardSurface.timeRange
                  }
                }
              }
            }
          }

          // DEVICES SUB-VIEW (FLEET HARDWARE INVENTORY VIEW)
          DeviceInventoryView {
              visible: root.sitesSubView === "devices"
              width: root.width
              devices: root.getAllFleetDevices()
              currentFilter: root.deviceFilter
              partial: !!(root.fleetData && root.fleetData.partial)
              failedEndpoints: (root.fleetData && root.fleetData.failedEndpoints) || []
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
              onSshRequested: function(ip, user) { root.launchSsh(ip, user) }
              onPingRequested: function(ip) { root.launchPing(ip) }
              onWebRequested: function(ip) {
                if (ip) Quickshell.execDetached(["xdg-open", "https://" + ip])
              }
            }
          }
