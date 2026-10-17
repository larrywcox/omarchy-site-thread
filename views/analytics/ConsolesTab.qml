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

  property var fleetConsoles: []
  property var fleetData: null
  readonly property bool partial: !!(root.fleetData && root.fleetData.partial)
  readonly property var failedEndpoints: (root.fleetData && root.fleetData.failedEndpoints) || []
  property string consoleSearch: ""
  property string consoleSiteFilter: "All"
  property int selectedConsoleIndex: 0
  readonly property var currentConsole: (fleetConsoles && fleetConsoles.length > root.selectedConsoleIndex && root.selectedConsoleIndex >= 0) ? fleetConsoles[root.selectedConsoleIndex] : (fleetConsoles && fleetConsoles.length > 0 ? fleetConsoles[0] : null)

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#f59e0b"
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal openExternalUrlRequested(string url)
  function openExternalUrl(url) {
    openExternalUrlRequested(url)
  }

  signal copyToClipboardRequested(string text, string label)
  function copyToClipboard(text, label) {
    copyToClipboardRequested(text, label)
  }

        spacing: Style.space(8)

        readonly property var rawConsoles: root.fleetConsoles || []
        readonly property var filteredConsoles: {
          var list = []
          for (var i = 0; i < rawConsoles.length; i++) {
            var c = rawConsoles[i]
            if (root.consoleSiteFilter !== "All" && c.siteName !== root.consoleSiteFilter) continue
            if (root.consoleSearch.trim() !== "") {
              var q = root.consoleSearch.toLowerCase()
              var nameMatch = String(c.name || "").toLowerCase().indexOf(q) >= 0
              var modelMatch = String(c.model || "").toLowerCase().indexOf(q) >= 0
              var domainMatch = String(c.directConnectDomain || "").toLowerCase().indexOf(q) >= 0
              var ipMatch = String(c.ip || "").toLowerCase().indexOf(q) >= 0
              if (!nameMatch && !modelMatch && !domainMatch && !ipMatch) continue
            }
            list.push(c)
          }
          return list
        }

        // Top KPI Strip (High density 4 metrics)
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Metric 1: Consoles Online
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var online = 0
                    for (var i = 0; i < tab4View.rawConsoles.length; i++) {
                      if (tab4View.rawConsoles[i].isOnline) online++
                    }
                    return online + " / " + tab4View.rawConsoles.length + " Online"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "UniFi OS Gateway Consoles"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          // Metric 2: Applications Active
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var totalApps = 0
                    for (var i = 0; i < tab4View.rawConsoles.length; i++) {
                      totalApps += (tab4View.rawConsoles[i].activeAppCount || 0)
                    }
                    return totalApps + " Running"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "Active Applications & Controllers"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          // Metric 3: P2P Direct Connect
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: "P2P WebRTC Direct"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "Zero-Relay Direct Domain Access"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }

          // Metric 4: Direct Domains Active
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(52)
            radius: 6
            color: root.track
            border.width: 1
            border.color: root.outline

            RowLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(10)

              Rectangle {
                width: Style.space(32)
                height: Style.space(32)
                radius: 6
                color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: ""; color: root.healthy; font.family: root.fontFamily; font.pixelSize: Style.space(14) }
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: {
                    var count = 0
                    for (var i = 0; i < tab4View.rawConsoles.length; i++) {
                      if (tab4View.rawConsoles[i].directConnectDomain) count++
                    }
                    return count + " Domains Active"
                  }
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "*.id.ui.direct Endpoints"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                }
              }
            }
          }
        }

        // Search & Filter Row
        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(8)

          // Search Box
          SearchField {
            Layout.fillWidth: false
            Layout.preferredWidth: Style.space(260)
            placeholderText: "Filter consoles, apps, domains..."
            text: root.consoleSearch
            foreground: root.foreground
            dim: root.dim
            track: root.track
            outline: root.outline
            accent: root.accent
            fontFamily: root.fontFamily
            onTextChanged: root.consoleSearch = text
            onCleared: root.consoleSearch = ""
          }

          // Direct Connect Explainer Badge
          Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Style.space(28)
            radius: 4
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
            border.width: 1
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25)

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                text: "⚡"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Text {
                textFormat: Text.PlainText;
                text: "Direct Connect uses *.id.ui.direct for end-to-end encrypted WebRTC P2P browser sessions with zero cloud relays."
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }
        }

        // Master-Detail Split Area
        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: Style.space(8)

          // Left Panel: Consoles Roster
          Rectangle {
            Layout.preferredWidth: Style.space(310)
            Layout.fillHeight: true
            radius: 6
            color: root.card
            border.width: 1
            border.color: root.outline

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(8)
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                text: "GATEWAY CONSOLES (" + tab4View.filteredConsoles.length + ")"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }

              Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: width
                contentHeight: consolesCol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                  id: consolesCol
                  width: parent.width
                  spacing: Style.space(4)

                  Rectangle {
                    visible: tab4View.filteredConsoles.length === 0
                    width: consolesCol.width
                    implicitHeight: Style.space(56)
                    radius: 5
                    color: root.track
                    border.width: 1
                    border.color: (root.partial && root.failedEndpoints && root.failedEndpoints.indexOf("/v1/hosts") >= 0) ? root.urgent : root.outline

                    ColumnLayout {
                      anchors.centerIn: parent
                      spacing: Style.space(3)

                      Text {
                        textFormat: Text.PlainText;
                        Layout.alignment: Qt.AlignHCenter
                        text: (root.partial && root.failedEndpoints && root.failedEndpoints.indexOf("/v1/hosts") >= 0)
                          ? "Console telemetry unavailable (endpoint /v1/hosts error)"
                          : "No consoles found"
                        color: (root.partial && root.failedEndpoints && root.failedEndpoints.indexOf("/v1/hosts") >= 0) ? root.urgent : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: (root.partial && root.failedEndpoints && root.failedEndpoints.indexOf("/v1/hosts") >= 0)
                      }

                      Text {
                        textFormat: Text.PlainText;
                        visible: (root.partial && root.failedEndpoints && root.failedEndpoints.indexOf("/v1/hosts") >= 0)
                        Layout.alignment: Qt.AlignHCenter
                        text: "Telemetry is partial. Check UI Account permissions or API key."
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                      }
                    }
                  }

                  Repeater {
                    model: tab4View.filteredConsoles
                    delegate: Rectangle {
                      id: consoleCard
                      required property var modelData
                      required property int index

                      width: consolesCol.width
                      implicitHeight: cInner.implicitHeight + Style.space(12)
                      radius: 5
                      color: (root.selectedConsoleIndex === index)
                        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                        : (cMouse.containsMouse ? root.cardHover : root.track)
                      border.width: 1
                      border.color: (root.selectedConsoleIndex === index) ? root.accent : root.outline

                      MouseArea {
                        id: cMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.selectedConsoleIndex = consoleCard.index }
                      }

                      ColumnLayout {
                        id: cInner
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Style.space(6)
                        spacing: 2

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(6)

                          Rectangle {
                            width: Style.space(6)
                            height: Style.space(6)
                            radius: 3
                            color: consoleCard.modelData.isOnline ? root.healthy : root.urgent
                          }

                          Text {
                            textFormat: Text.PlainText;
                            text: consoleCard.modelData.name || "UniFi Console"
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          Rectangle {
                            radius: 3
                            color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                            border.width: 1
                            border.color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.4)
                            Layout.preferredHeight: Style.space(16)
                            Layout.preferredWidth: cAppCountText.implicitWidth + Style.space(8)

                            Text {
                              textFormat: Text.PlainText;
                              id: cAppCountText
                              anchors.centerIn: parent
                              text: (consoleCard.modelData.activeAppCount || 0) + " Apps"
                              color: root.healthy
                              font.family: root.fontFamily
                              font.pixelSize: 8
                              font.bold: true
                            }
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: consoleCard.modelData.model || "Gateway"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        RowLayout {
                          Layout.fillWidth: true
                          spacing: Style.space(4)

                          Text {
                            textFormat: Text.PlainText;
                            text: "⚡ " + (consoleCard.modelData.directConnectDomain ? (consoleCard.modelData.directConnectDomain.substring(0, 16) + "…") : "No Direct P2P")
                            color: consoleCard.modelData.directConnectDomain ? root.accent : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          Text {
                            textFormat: Text.PlainText;
                            text: consoleCard.modelData.ip || ""
                            color: root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 8
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }

          // Right Panel: Console Detail & Applications Matrix
          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 6
            color: root.card
            border.width: 1
            border.color: root.outline

            Flickable {
              anchors.fill: parent
              anchors.margins: Style.space(10)
              contentWidth: width
              contentHeight: detailMainCol.implicitHeight + Style.space(12)
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              ColumnLayout {
                id: detailMainCol
                width: parent.width
                spacing: Style.space(10)

                // Console Header Banner
                Rectangle {
                  Layout.fillWidth: true
                  radius: 6
                  color: root.track
                  border.width: 1
                  border.color: root.outline
                  Layout.preferredHeight: Style.space(64)

                  RowLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(10)
                    spacing: Style.space(10)

                    Rectangle {
                      Layout.preferredWidth: Style.space(42)
                      Layout.preferredHeight: Style.space(42)
                      radius: 6
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
                      border.width: 1
                      border.color: root.accent

                      Text {
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: ""
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.space(20)
                      }
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: 2

                      RowLayout {
                        spacing: Style.space(6)

                        Text {
                          textFormat: Text.PlainText;
                          text: root.currentConsole ? (root.currentConsole.name + " (" + root.currentConsole.model + ")") : "No Console Selected"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.body
                          font.bold: true
                        }

                        Rectangle {
                          radius: 3
                          color: (root.currentConsole && root.currentConsole.isOnline)
                            ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18)
                            : Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18)
                          Layout.preferredHeight: Style.space(16)
                          Layout.preferredWidth: onlinePillText.implicitWidth + Style.space(8)

                          Text {
                            textFormat: Text.PlainText;
                            id: onlinePillText
                            anchors.centerIn: parent
                            text: (root.currentConsole && root.currentConsole.isOnline) ? "● ONLINE" : "● OFFLINE"
                            color: (root.currentConsole && root.currentConsole.isOnline) ? root.healthy : root.urgent
                            font.family: root.fontFamily
                            font.pixelSize: 8
                            font.bold: true
                          }
                        }
                      }

                      RowLayout {
                        spacing: Style.space(12)

                        Text {
                          textFormat: Text.PlainText;
                          text: "Firmware: " + (root.currentConsole ? ("UniFi OS " + (root.currentConsole.firmwareVersion || "v5.1.x")) : "—")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "Local IP: " + (root.currentConsole ? (root.currentConsole.ip || "—") : "—")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "MAC: " + (root.currentConsole ? (root.currentConsole.mac || "—") : "—")
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 1
                        }
                      }
                    }
                  }
                }

                // Direct Connect Control Banner
                Rectangle {
                  Layout.fillWidth: true
                  radius: 6
                  color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.07)
                  border.width: 1
                  border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                  Layout.preferredHeight: Style.space(78)

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Style.space(8)
                    spacing: Style.space(6)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText;
                        text: "⚡ P2P DIRECT CONNECT DOMAIN"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Rectangle {
                        radius: 3
                        color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                        Layout.preferredHeight: Style.space(16)
                        Layout.preferredWidth: p2pPillText.implicitWidth + Style.space(8)
                        Text {
                          textFormat: Text.PlainText;
                          id: p2pPillText
                          anchors.centerIn: parent
                          text: (root.currentConsole && root.currentConsole.directConnectDomain) ? "WebRTC Direct Active" : "Direct P2P Unavailable"
                          color: (root.currentConsole && root.currentConsole.directConnectDomain) ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      Item { Layout.fillWidth: true }

                      Text {
                        textFormat: Text.PlainText;
                        text: root.currentConsole ? (root.currentConsole.directConnectDomain || "None") : "—"
                        color: root.foreground
                        font.family: "Monospace"
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                    }

                    // Action Buttons Row
                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      // Button 1: Launch Direct Connect
                      Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: launchDirectMouse.containsMouse ? Qt.darker(root.accent, 1.15) : root.accent

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: "⚡"; color: root.accentForeground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                          Text { textFormat: Text.PlainText; text: "Launch Direct Connect"; color: root.accentForeground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                        }

                        MouseArea {
                          id: launchDirectMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.directConnectUrl) {
                              root.openExternalUrl(root.currentConsole.directConnectUrl)
                            }
                          }
                        }
                      }

                      // Button 2: Copy Direct URL
                      Rectangle {
                        Layout.preferredWidth: Style.space(120)
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: copyDirectMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: "📋"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                          Text { textFormat: Text.PlainText; text: "Copy Domain"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                        }

                        MouseArea {
                          id: copyDirectMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.directConnectUrl) {
                              root.copyToClipboard(root.currentConsole.directConnectUrl, "Direct Connect URL")
                            }
                          }
                        }
                      }

                      // Button 3: Local IP Launch
                      Rectangle {
                        Layout.preferredWidth: Style.space(110)
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: localLaunchMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                          Text { textFormat: Text.PlainText; text: "Local HTTPS"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                        }

                        MouseArea {
                          id: localLaunchMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.localUrl) {
                              root.openExternalUrl(root.currentConsole.localUrl)
                            }
                          }
                        }
                      }

                      // Button 4: Cloud Site Manager
                      Rectangle {
                        Layout.preferredWidth: Style.space(110)
                        Layout.preferredHeight: Style.space(26)
                        radius: 4
                        color: cloudLaunchMouse.containsMouse ? root.cardHover : root.track
                        border.width: 1
                        border.color: root.outline

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 4
                          Text { textFormat: Text.PlainText; text: "☁"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                          Text { textFormat: Text.PlainText; text: "Cloud Relay"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                        }

                        MouseArea {
                          id: cloudLaunchMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            if (root.currentConsole && root.currentConsole.webCloudUrl) {
                              root.openExternalUrl(root.currentConsole.webCloudUrl)
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // Applications Matrix Card
                Rectangle {
                  Layout.fillWidth: true
                  radius: 6
                  color: root.track
                  border.width: 1
                  border.color: root.outline
                  implicitHeight: appsContentCol.implicitHeight + Style.space(16)

                  ColumnLayout {
                    id: appsContentCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(8)
                    spacing: Style.space(6)

                    RowLayout {
                      Layout.fillWidth: true

                      Text {
                        textFormat: Text.PlainText;
                        text: "INSTALLED UNIFI OS APPLICATIONS (" + (root.currentConsole && root.currentConsole.applications ? root.currentConsole.applications.length : 0) + ")"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }

                      Item { Layout.fillWidth: true }

                      Text {
                        textFormat: Text.PlainText;
                        text: "Direct launch bypasses cloud proxy"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 8
                      }
                    }

                    // Applications List
                    Column {
                      width: appsContentCol.width
                      Layout.fillWidth: true
                      spacing: Style.space(4)

                      Repeater {
                        model: (root.currentConsole && root.currentConsole.applications) ? root.currentConsole.applications : []
                        delegate: Rectangle {
                          id: appRowRect
                          required property var modelData
                          required property int index

                          width: appsContentCol.width
                          height: Style.space(38)
                          implicitHeight: height
                          radius: 4
                          color: appRowMouse.containsMouse ? root.cardHover : root.card
                          border.width: 1
                          border.color: appRowMouse.containsMouse ? root.accent : root.outline

                          MouseArea {
                            id: appRowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                          }

                          RowLayout {
                            id: appRowLayout
                            anchors.fill: parent
                            anchors.leftMargin: Style.space(8)
                            anchors.rightMargin: Style.space(8)
                            anchors.topMargin: Style.space(4)
                            anchors.bottomMargin: Style.space(4)
                            spacing: Style.space(8)

                            // App Icon
                            Rectangle {
                              Layout.preferredWidth: Style.space(26)
                              Layout.preferredHeight: Style.space(26)
                              radius: 4
                              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
                              Text {
                                textFormat: Text.PlainText;
                                anchors.centerIn: parent
                                text: appRowRect.modelData.id === "network" ? "\uf0e8"
                                  : (appRowRect.modelData.id === "protect" ? ""
                                  : (appRowRect.modelData.id === "drive" ? ""
                                  : (appRowRect.modelData.id === "innerspace" ? ""
                                  : (appRowRect.modelData.id === "access" ? ""
                                  : (appRowRect.modelData.id === "talk" ? "" : "")))))
                                color: root.accent
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption
                              }
                            }

                            // App Details
                            ColumnLayout {
                              Layout.fillWidth: true
                              spacing: 1

                              RowLayout {
                                spacing: Style.space(6)

                                Text {
                                  textFormat: Text.PlainText;
                                  text: appRowRect.modelData.name || "UniFi Application"
                                  color: root.foreground
                                  font.family: root.fontFamily
                                  font.pixelSize: Style.font.caption
                                  font.bold: true
                                }

                                Rectangle {
                                  radius: 3
                                  color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                                  Layout.preferredHeight: Style.space(14)
                                  Layout.preferredWidth: appVerText.implicitWidth + Style.space(6)
                                  Text {
                                    textFormat: Text.PlainText;
                                    id: appVerText
                                    anchors.centerIn: parent
                                    text: appRowRect.modelData.version || "Active"
                                    color: root.healthy
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                  }
                                }

                                Rectangle {
                                  visible: appRowRect.modelData.updateAvailable !== ""
                                  radius: 3
                                  color: Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.22)
                                  border.width: 1
                                  border.color: root.backup
                                  Layout.preferredHeight: Style.space(14)
                                  Layout.preferredWidth: appUpdText.implicitWidth + Style.space(6)
                                  Text {
                                    textFormat: Text.PlainText;
                                    id: appUpdText
                                    anchors.centerIn: parent
                                    text: "UPDATE: v" + appRowRect.modelData.updateAvailable
                                    color: root.backup
                                    font.family: root.fontFamily
                                    font.pixelSize: 8
                                    font.bold: true
                                  }
                                }
                              }

                              Text {
                                textFormat: Text.PlainText;
                                text: (appRowRect.modelData.port > 0 ? ("Port " + appRowRect.modelData.port + " · ") : "") + (appRowRect.modelData.isRunning ? "Running & Active" : "Inactive")
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                              }
                            }

                            Item {
                              Layout.fillWidth: true
                            }

                            // App Action Buttons
                            RowLayout {
                              Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                              spacing: Style.space(4)

                              // Direct App Launch Button
                              Rectangle {
                                Layout.preferredWidth: Style.space(100)
                                Layout.preferredHeight: Style.space(22)
                                radius: 4
                                color: appLaunchMouse.containsMouse ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)
                                border.width: 1
                                border.color: root.accent

                                RowLayout {
                                  anchors.centerIn: parent
                                  spacing: 4
                                  Text { textFormat: Text.PlainText; text: "⚡"; color: appLaunchMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
                                  Text { textFormat: Text.PlainText; text: "Direct Launch"; color: appLaunchMouse.containsMouse ? root.accentForeground : root.foreground; font.family: root.fontFamily; font.pixelSize: 8; font.bold: true }
                                }

                                MouseArea {
                                  id: appLaunchMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var targetUrl = appRowRect.modelData.directUrl || (root.currentConsole ? root.currentConsole.directConnectUrl : "")
                                    if (targetUrl) root.openExternalUrl(targetUrl)
                                  }
                                }
                              }

                              // Local App Launch Button
                              Rectangle {
                                Layout.preferredWidth: Style.space(70)
                                Layout.preferredHeight: Style.space(22)
                                radius: 4
                                color: appLocalMouse.containsMouse ? root.cardHover : root.track
                                border.width: 1
                                border.color: root.outline

                                RowLayout {
                                  anchors.centerIn: parent
                                  spacing: 4
                                  Text { textFormat: Text.PlainText; text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 8 }
                                  Text { textFormat: Text.PlainText; text: "Local"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 8 }
                                }

                                MouseArea {
                                  id: appLocalMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var targetUrl = appRowRect.modelData.localUrl || (root.currentConsole ? root.currentConsole.localUrl : "")
                                    if (targetUrl) root.openExternalUrl(targetUrl)
                                  }
                                }
                              }

                              // Copy App URL
                              Rectangle {
                                Layout.preferredWidth: Style.space(24)
                                Layout.preferredHeight: Style.space(22)
                                radius: 4
                                color: appCopyMouse.containsMouse ? root.cardHover : root.track
                                border.width: 1
                                border.color: root.outline

                                Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "📋"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: 8 }

                                MouseArea {
                                  id: appCopyMouse
                                  anchors.fill: parent
                                  hoverEnabled: true
                                  cursorShape: Qt.PointingHandCursor
                                  onClicked: {
                                    var targetUrl = appRowRect.modelData.directUrl || (root.currentConsole ? root.currentConsole.directConnectUrl : "")
                                    if (targetUrl) root.copyToClipboard(targetUrl, appRowRect.modelData.name + " URL")
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
