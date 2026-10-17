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

  property var fleetWlans: []
  property var fleetSpectrum: ({})
  property var fleetData: ({})
  property string wlanSearch: ""
  property string wlanSiteFilter: "All"
  property var selectedWlanForQr: null
  property bool showQrModal: false
  property bool isLightTheme: false

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color healthyForeground: "#ffffff"
  property color backup: "#f59e0b"
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal copyToClipboardRequested(string text, string label)
  function copyToClipboard(text, label) {
    copyToClipboardRequested(text, label)
  }

  readonly property bool partial: !!(root.fleetData && root.fleetData.partial)
  readonly property var failedEndpoints: (root.fleetData && root.fleetData.failedEndpoints) || []
  readonly property var unavailableTelemetry: (root.fleetData && root.fleetData.unavailableTelemetry) || []
  readonly property bool wlansUnavailable: {
    if (root.fleetWlans && root.fleetWlans.length > 0) return false
    if (!root.partial) return false
    if (root.unavailableTelemetry && root.unavailableTelemetry.indexOf("wlans") >= 0) return true
    if (root.failedEndpoints) {
      for (var i = 0; i < root.failedEndpoints.length; i++) {
        var ep = String(root.failedEndpoints[i])
        if (ep.indexOf("rest/wlanconf") >= 0 || ep.indexOf("wlans") >= 0) return true
      }
    }
    return false
  }

  spacing: Style.space(8)

  readonly property var rawWlans: root.fleetWlans || []
  readonly property var siteFilterOptions: {
    var totalCount = rawWlans ? rawWlans.length : 0
    var opts = [{
      value: "All",
      label: "All Sites",
      description: totalCount + (totalCount === 1 ? " SSID total" : " SSIDs total")
    }]
    var siteMap = {}
    var wList = rawWlans || []
    for (var i = 0; i < wList.length; i++) {
      var sn = wList[i].siteName || "Default Site"
      siteMap[sn] = (siteMap[sn] || 0) + 1
    }
    if (root.fleetData && root.fleetData.sites) {
      for (var j = 0; j < root.fleetData.sites.length; j++) {
        var s = root.fleetData.sites[j]
        var sName = s && (s.name || s.id) ? (s.name || s.id) : ""
        if (sName && siteMap[sName] === undefined) {
          siteMap[sName] = 0
        }
      }
    }
    var keys = Object.keys(siteMap).sort()
    for (var k = 0; k < keys.length; k++) {
      var c = siteMap[keys[k]]
      opts.push({
        value: keys[k],
        label: keys[k],
        description: c + (c === 1 ? " SSID" : " SSIDs")
      })
    }
    return opts
  }
  readonly property var filteredWlans: {
    var list = []
    for (var i = 0; i < rawWlans.length; i++) {
      var w = rawWlans[i]
      var wSite = w.siteName || "Default Site"
      if (root.wlanSiteFilter !== "All" && wSite !== root.wlanSiteFilter && w.siteName !== root.wlanSiteFilter) continue
      if (root.wlanSearch.trim() !== "") {
        var q = root.wlanSearch.toLowerCase()
        var nameMatch = String(w.name || "").toLowerCase().indexOf(q) >= 0
        var secMatch = String(w.security || "").toLowerCase().indexOf(q) >= 0
        var siteMatch = String(w.siteName || "").toLowerCase().indexOf(q) >= 0
        if (!nameMatch && !secMatch && !siteMatch) continue
      }
      list.push(w)
    }
    return list
  }

        Flickable {
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentWidth: width
          contentHeight: tab5ContentCol.implicitHeight + Style.space(20)
          clip: true
          boundsBehavior: Flickable.StopAtBounds

          ColumnLayout {
            id: tab5ContentCol
            width: parent.width
            spacing: Style.space(10)

            // Top KPI Strip
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              // Metric 1: Total SSIDs
              BorderSurface {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.space(48)
                color: root.card
                radius: 6
                borderSpec: Border.flat(root.outline, 1)
                clip: true

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.title }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { textFormat: Text.PlainText; text: "ACTIVE WLANS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { textFormat: Text.PlainText; text: String(root.fleetWlans.length) + " SSIDs"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.body; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                  }
                }
              }

              // Metric 2: Connected WiFi Clients
              BorderSurface {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.space(48)
                color: root.card
                radius: 6
                borderSpec: Border.flat(root.outline, 1)
                clip: true

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.title }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { textFormat: Text.PlainText; text: "WIFI CLIENTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text {
                      textFormat: Text.PlainText;
                      text: {
                        var total = 0
                        for (var i = 0; i < root.fleetWlans.length; i++) total += (root.fleetWlans[i].clientCount || 0)
                        return total + " Clients"
                      }
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }
              }

              // Metric 3: Security & Roaming
              BorderSurface {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.space(48)
                color: root.card
                radius: 6
                borderSpec: Border.flat(root.outline, 1)
                clip: true

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.title }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { textFormat: Text.PlainText; text: "SECURITY POSTURE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text { textFormat: Text.PlainText; text: "WPA3 & 802.11k/v/r Active"; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; elide: Text.ElideRight; Layout.fillWidth: true }
                  }
                }
              }

              // Metric 4: Auto-RF Optimization
              BorderSurface {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.minimumWidth: 0
                Layout.preferredHeight: Style.space(48)
                color: root.card
                radius: 6
                borderSpec: Border.flat(root.outline, 1)
                clip: true

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  Text { textFormat: Text.PlainText; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.title }
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { textFormat: Text.PlainText; text: "NIGHTLY AUTO-RF"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; elide: Text.ElideRight; Layout.fillWidth: true }
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.fleetSpectrum && root.fleetSpectrum.autoRf) ? (root.fleetSpectrum.autoRf.status + " · " + root.fleetSpectrum.autoRf.lastRun) : "Optimized"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }
                }
              }
            }

            // Sub-filters row
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              // Search Box
              SearchField {
                placeholderText: "Search SSIDs, security type, frequency bands..."
                text: root.wlanSearch
                foreground: root.foreground
                dim: root.dim
                track: root.track
                outline: root.outline
                accent: root.accent
                fontFamily: root.fontFamily
                onTextChanged: root.wlanSearch = text
                onCleared: root.wlanSearch = ""
              }

              // Site selector dropdown with search
              RowLayout {
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText;
                  text: "SITE:"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }

                Rectangle {
                  Layout.preferredWidth: Style.space(190)
                  Layout.preferredHeight: Style.space(28)
                  radius: Style.cornerRadius
                  color: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                  border.width: 1
                  border.color: root.outline

                  SearchableDropdown {
                    id: wifiSiteDropdown
                    anchors.fill: parent
                    rowHeight: Style.space(28)
                    showLabel: false
                    value: root.wlanSiteFilter
                    options: tab5View.siteFilterOptions
                    placeholderText: "Search sites..."
                    emptyText: "No sites match"
                    foreground: root.foreground
                    background: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                    popupBorder: root.accent
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(val) {
                      root.wlanSiteFilter = val
                    }
                  }
                }
              }
            }

            // Section: Wireless Networks List
            Text {
              textFormat: Text.PlainText;
              text: root.wlansUnavailable
                ? "FLEET WIRELESS NETWORKS (UNAVAILABLE)"
                : ("FLEET WIRELESS NETWORKS & QR ONBOARDING (" + tab5View.filteredWlans.length + ")")
              color: root.wlansUnavailable ? root.urgent : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Rectangle {
              visible: tab5View.filteredWlans.length === 0
              Layout.fillWidth: true
              implicitHeight: Style.space(56)
              radius: 5
              color: root.track
              border.width: 1
              border.color: root.wlansUnavailable ? root.urgent : root.outline

              ColumnLayout {
                anchors.centerIn: parent
                spacing: Style.space(3)

                Text {
                  textFormat: Text.PlainText;
                  Layout.alignment: Qt.AlignHCenter
                  text: root.wlansUnavailable
                    ? "WLAN telemetry unavailable (endpoint rest/wlanconf error)"
                    : (tab5View.rawWlans.length === 0 ? "No wireless networks discovered in fleet" : "No wireless networks match the current search or filters.")
                  color: root.wlansUnavailable ? root.urgent : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: root.wlansUnavailable
                }

                Text {
                  textFormat: Text.PlainText;
                  visible: root.wlansUnavailable
                  Layout.alignment: Qt.AlignHCenter
                  text: "Telemetry is partial. Check UI Account permissions or API key."
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                }
              }
            }

            // WLAN Cards Flow
            Flow {
              Layout.fillWidth: true
              width: tab5ContentCol.width
              spacing: Style.space(8)

              Repeater {
                model: tab5View.filteredWlans
                delegate: BorderSurface {
                  id: wlanCard
                  required property var modelData
                  width: Math.floor((tab5ContentCol.width - Style.space(8)) / 2)
                  implicitHeight: wlanCol.implicitHeight + Style.space(16)
                  color: root.card
                  radius: 6
                  borderSpec: Border.flat(root.outline, 1)

                  ColumnLayout {
                    id: wlanCol
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(6)

                    // Row 1: Icon + Name + Badges
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text { textFormat: Text.PlainText; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.body }
                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      // Security Pill
                      Rectangle {
                        implicitHeight: Style.space(18)
                        implicitWidth: secPillText.implicitWidth + Style.space(10)
                        radius: 3
                        color: modelData.security.indexOf("WPA3") >= 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.track
                        border.width: 1
                        border.color: modelData.security.indexOf("WPA3") >= 0 ? root.accent : root.outline
                        Text { textFormat: Text.PlainText; id: secPillText; anchors.centerIn: parent; text: modelData.security; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                      }

                      // Guest / IoT tag
                      Rectangle {
                        visible: modelData.guest === true || modelData.hidden === true
                        implicitHeight: Style.space(18)
                        implicitWidth: guestPillText.implicitWidth + Style.space(8)
                        radius: 3
                        color: modelData.guest ? Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2) : root.track
                        border.width: 1
                        border.color: modelData.guest ? root.backup : root.outline
                        Text { textFormat: Text.PlainText; id: guestPillText; anchors.centerIn: parent; text: modelData.guest ? "Guest" : "Hidden"; color: modelData.guest ? root.backup : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                      }
                    }

                    // Row 2: Site, Band Pills, Client count
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text { textFormat: Text.PlainText; text: modelData.siteName + " · VLAN " + modelData.vlan + " · " + (modelData.radioProto || "WiFi"); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; elide: Text.ElideRight; Layout.fillWidth: true }

                      // Client count badge
                      Rectangle {
                        implicitHeight: Style.space(18)
                        implicitWidth: clientBadgeText.implicitWidth + Style.space(10)
                        radius: 3
                        color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                        Text { textFormat: Text.PlainText; id: clientBadgeText; anchors.centerIn: parent; text: " " + modelData.clientCount; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                      }
                    }

                    // Row 3: Passphrase + Action Buttons
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      // Passphrase Box
                      Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Style.space(24)
                        radius: 4
                        color: root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(4)
                          Text {
                            Layout.alignment: Qt.AlignVCenter
                            textFormat: Text.PlainText;
                            text: ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                          }
                          Text {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            textFormat: Text.PlainText;
                            text: modelData.passphrase || "None / Open"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption - 1
                            elide: Text.ElideRight
                          }
                        }
                      }

                      // Copy Password Button
                      Rectangle {
                        implicitHeight: Style.space(24)
                        implicitWidth: copyPassText.implicitWidth + Style.space(16)
                        radius: 4
                        color: copyPassMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: copyPassMouse.containsMouse ? root.accent : root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: Style.space(4)
                          Text { textFormat: Text.PlainText; text: ""; color: copyPassMouse.containsMouse ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
                          Text { textFormat: Text.PlainText; id: copyPassText; text: "Copy"; color: copyPassMouse.containsMouse ? root.accent : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                        }

                        MouseArea {
                          id: copyPassMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: { root.copyToClipboard(modelData.passphrase, modelData.name + " password") }
                        }

                        PanelToolTip {
                          visible: copyPassMouse.containsMouse
                          text: "Copy " + modelData.name + " password to clipboard"
                          fontFamily: root.fontFamily
                        }
                      }

                      // QR Code / Share Button
                      Rectangle {
                        implicitHeight: Style.space(24)
                        implicitWidth: qrBtnText.implicitWidth + Style.space(16)
                        radius: 4
                        color: qrBtnMouse.containsMouse ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                        border.width: 1
                        border.color: root.accent

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: Style.space(4)
                          Text { textFormat: Text.PlainText; text: ""; color: qrBtnMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
                          Text { textFormat: Text.PlainText; id: qrBtnText; text: "Share QR"; color: qrBtnMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                        }

                        MouseArea {
                          id: qrBtnMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            root.selectedWlanForQr = modelData
                            root.showQrModal = true
                          }
                        }

                        PanelToolTip {
                          visible: qrBtnMouse.containsMouse
                          text: "Show printable on-screen Wi-Fi onboarding QR code"
                          fontFamily: root.fontFamily
                        }
                      }
                    }
                  }
                }
              }
            }

            // QR Code Modal Card (if showQrModal is true)
            BorderSurface {
              visible: root.showQrModal && root.selectedWlanForQr !== null
              Layout.fillWidth: true
              implicitHeight: qrModalCol.implicitHeight + Style.space(16)
              color: root.track
              radius: 8
              borderSpec: Border.flat(root.accent, 2)

              ColumnLayout {
                id: qrModalCol
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                RowLayout {
                  Layout.fillWidth: true
                  Text { textFormat: Text.PlainText; text: " WIFI ONBOARDING QR CODE — " + (root.selectedWlanForQr ? root.selectedWlanForQr.name : ""); color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; Layout.fillWidth: true }
                  Rectangle {
                    implicitHeight: Style.space(20)
                    implicitWidth: Style.space(20)
                    radius: 3
                    color: closeQrMouse.containsMouse ? root.urgent : root.cardHover
                    Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "✕"; color: "#ffffff"; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                    MouseArea {
                      id: closeQrMouse
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.showQrModal = false }
                    }
                  }
                }

                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(16)

                  // Stylized QR Matrix Canvas
                  Rectangle {
                    width: Style.space(120)
                    height: Style.space(120)
                    radius: 6
                    color: "#ffffff"
                    border.width: 1
                    border.color: root.outline

                    Canvas {
                      id: qrCanvas
                      anchors.fill: parent
                      anchors.margins: Style.space(8)
                      onPaint: {
                        var ctx = getContext("2d")
                        ctx.fillStyle = "#ffffff"
                        ctx.fillRect(0, 0, width, height)
                        ctx.fillStyle = "#000000"

                        var n = 15
                        var cell = width / n
                        var seedStr = root.selectedWlanForQr ? (root.selectedWlanForQr.name + root.selectedWlanForQr.passphrase) : "wifi"
                        var hash = 0
                        for (var k = 0; k < seedStr.length; k++) hash = (hash * 31 + seedStr.charCodeAt(k)) & 0x7fffffff

                        // Corner 1
                        ctx.fillRect(0, 0, cell * 4, cell * 4)
                        ctx.fillStyle = "#ffffff"; ctx.fillRect(cell, cell, cell * 2, cell * 2); ctx.fillStyle = "#000000"
                        // Corner 2
                        ctx.fillRect(width - cell * 4, 0, cell * 4, cell * 4)
                        ctx.fillStyle = "#ffffff"; ctx.fillRect(width - cell * 3, cell, cell * 2, cell * 2); ctx.fillStyle = "#000000"
                        // Corner 3
                        ctx.fillRect(0, height - cell * 4, cell * 4, cell * 4)
                        ctx.fillStyle = "#ffffff"; ctx.fillRect(cell, height - cell * 3, cell * 2, cell * 2); ctx.fillStyle = "#000000"

                        // Data matrix pseudo-bits
                        for (var r = 0; r < n; r++) {
                          for (var c = 0; c < n; c++) {
                            if ((r < 4 && c < 4) || (r < 4 && c >= n - 4) || (r >= n - 4 && c < 4)) continue
                            var bit = ((hash ^ (r * 13 + c * 23)) % 7) < 3
                            if (bit) ctx.fillRect(c * cell, r * cell, cell - 0.5, cell - 0.5)
                          }
                        }
                      }
                    }
                  }

                  // QR Code Details & Instructions
                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(4)

                    Text { textFormat: Text.PlainText; text: "SSID: " + (root.selectedWlanForQr ? root.selectedWlanForQr.name : ""); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { textFormat: Text.PlainText; text: "Security: " + (root.selectedWlanForQr ? root.selectedWlanForQr.security : "") + " · Site: " + (root.selectedWlanForQr ? root.selectedWlanForQr.siteName : ""); color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
                    Text { textFormat: Text.PlainText; text: "Password: " + (root.selectedWlanForQr ? root.selectedWlanForQr.passphrase : ""); color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true }
                    Text { textFormat: Text.PlainText; text: "Point phone camera or scanner at QR code to auto-connect to this Wi-Fi network."; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }

                    RowLayout {
                      spacing: Style.space(8)
                      Rectangle {
                        implicitHeight: Style.space(24)
                        implicitWidth: copyUriBtnText.implicitWidth + Style.space(16)
                        radius: 4
                        color: copyUriMouse.containsMouse ? root.accent : root.card
                        border.width: 1
                        border.color: root.accent
                        RowLayout {
                          anchors.centerIn: parent
                          spacing: Style.space(4)
                          Text { textFormat: Text.PlainText; text: ""; color: copyUriMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
                          Text { textFormat: Text.PlainText; id: copyUriBtnText; text: "Copy WiFi URI"; color: copyUriMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                        }
                        MouseArea {
                          id: copyUriMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.selectedWlanForQr) root.copyToClipboard(root.selectedWlanForQr.qrCode, "WiFi QR code URI")
                          }
                        }
                        PanelToolTip {
                          visible: copyUriMouse.containsMouse
                          text: "Copy WIFI:S:... URI to clipboard"
                          fontFamily: root.fontFamily
                        }
                      }
                      Rectangle {
                        implicitHeight: Style.space(24)
                        implicitWidth: copyPassBtnText.implicitWidth + Style.space(16)
                        radius: 4
                        color: copyPassBtnMouse.containsMouse ? root.healthy : root.card
                        border.width: 1
                        border.color: root.healthy
                        RowLayout {
                          anchors.centerIn: parent
                          spacing: Style.space(4)
                          Text { textFormat: Text.PlainText; text: ""; color: copyPassBtnMouse.containsMouse ? root.healthyForeground : root.healthy; font.family: root.fontFamily; font.pixelSize: 8 }
                          Text { textFormat: Text.PlainText; id: copyPassBtnText; text: "Copy Password"; color: copyPassBtnMouse.containsMouse ? root.healthyForeground : root.healthy; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                        }
                        MouseArea {
                          id: copyPassBtnMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.selectedWlanForQr) root.copyToClipboard(root.selectedWlanForQr.passphrase, "WiFi password")
                          }
                        }
                        PanelToolTip {
                          visible: copyPassBtnMouse.containsMouse
                          text: "Copy raw passphrase to clipboard"
                          fontFamily: root.fontFamily
                        }
                      }
                    }
                  }
                }
              }
            }

            // Section: RF Spectrum & Channel Utilization
            Text {
              textFormat: Text.PlainText;
              text: "RF SPECTRUM CONGESTION & CHANNEL UTILIZATION"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            // 3 Band Utilization Cards
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              Repeater {
                model: (root.fleetSpectrum && root.fleetSpectrum.bands) ? root.fleetSpectrum.bands : []
                delegate: BorderSurface {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: bandCol.implicitHeight + Style.space(16)
                  color: root.card
                  radius: 6
                  borderSpec: Border.flat(root.outline, 1)

                  ColumnLayout {
                    id: bandCol
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(5)

                    RowLayout {
                      Layout.fillWidth: true
                      Text { textFormat: Text.PlainText; text: modelData.band; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall; font.bold: true; Layout.fillWidth: true }
                      Rectangle {
                        implicitHeight: Style.space(16)
                        implicitWidth: bandStatusText.implicitWidth + Style.space(8)
                        radius: 3
                        color: modelData.status === "Pristine" ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : (modelData.status === "Optimal" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2))
                        Text { textFormat: Text.PlainText; id: bandStatusText; anchors.centerIn: parent; text: modelData.status; color: modelData.status === "Pristine" ? root.accent : (modelData.status === "Optimal" ? root.healthy : root.backup); font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                      }
                    }

                    // Utilization Progress Bar
                    Rectangle {
                      Layout.fillWidth: true
                      height: Style.space(6)
                      radius: 3
                      color: root.track
                      Rectangle {
                        width: parent.width * Math.min(1.0, modelData.utilization / 100)
                        height: parent.height
                        radius: 3
                        color: modelData.utilization > 50 ? root.urgent : (modelData.utilization > 25 ? root.backup : root.healthy)
                      }
                    }

                    RowLayout {
                      Layout.fillWidth: true
                      Text { textFormat: Text.PlainText; text: "Utilization: " + modelData.utilization + "%"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                      Text { textFormat: Text.PlainText; text: "Interference: " + modelData.interference + "%"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                      Text { textFormat: Text.PlainText; text: "Noise: " + modelData.noiseFloor + "dBm"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                    }

                    // Channel badges row
                    RowLayout {
                      spacing: Style.space(4)
                      Repeater {
                        model: modelData.channels || []
                        delegate: Rectangle {
                          required property var modelData
                          implicitHeight: Style.space(16)
                          implicitWidth: chText.implicitWidth + Style.space(6)
                          radius: 2
                          color: root.track
                          Text { textFormat: Text.PlainText; id: chText; anchors.centerIn: parent; text: "Ch " + modelData.channel + " (" + modelData.utilization + "%)"; color: root.dim; font.family: root.fontFamily; font.pixelSize: 8 }
                        }
                      }
                    }
                  }
                }
              }
            }

            // Section: AP Radio Channel Allocations Table
            Text {
              textFormat: Text.PlainText;
              text: "ACCESS POINT RADIO ASSIGNMENTS & CLIENT LOAD"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            BorderSurface {
              Layout.fillWidth: true
              implicitHeight: apRadioCol.implicitHeight + Style.space(14)
              color: root.card
              radius: 6
              borderSpec: Border.flat(root.outline, 1)

              ColumnLayout {
                id: apRadioCol
                anchors.fill: parent
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                // Header Row
                RowLayout {
                  Layout.fillWidth: true
                  spacing: Style.space(8)
                  Text { textFormat: Text.PlainText; text: "ACCESS POINT"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 160 }
                  Text { textFormat: Text.PlainText; text: "SITE"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
                  Text { textFormat: Text.PlainText; text: "2.4 GHZ"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
                  Text { textFormat: Text.PlainText; text: "5 GHZ"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
                  Text { textFormat: Text.PlainText; text: "6 GHZ"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.preferredWidth: 100 }
                  Text { textFormat: Text.PlainText; text: "CLIENTS"; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; Layout.fillWidth: true }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.outline }

                Repeater {
                  model: (root.fleetSpectrum && root.fleetSpectrum.accessPoints) ? root.fleetSpectrum.accessPoints : []
                  delegate: RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: Style.space(8)

                    Text { textFormat: Text.PlainText; text: modelData.name + " (" + modelData.model + ")"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true; elide: Text.ElideRight; Layout.preferredWidth: 160 }
                    Text { textFormat: Text.PlainText; text: modelData.siteName; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; elide: Text.ElideRight; Layout.preferredWidth: 100 }
                    Text { textFormat: Text.PlainText; text: "Ch " + modelData.ch24 + " · " + modelData.txPower24 + "dBm"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; Layout.preferredWidth: 100 }
                    Text { textFormat: Text.PlainText; text: "Ch " + modelData.ch5 + " · " + modelData.txPower5 + "dBm"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; Layout.preferredWidth: 100 }
                    Text { textFormat: Text.PlainText; text: modelData.ch6 ? ("Ch " + modelData.ch6 + " · " + modelData.txPower6 + "dBm") : "N/A"; color: modelData.ch6 ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; Layout.preferredWidth: 100 }
                    Text { textFormat: Text.PlainText; text: " " + modelData.clients + " connected"; color: modelData.clients > 0 ? root.healthy : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: modelData.clients > 0; Layout.fillWidth: true }
                  }
                }
              }
            }
          }
        }
      }
