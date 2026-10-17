import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."
import "../components"
import "../Model.js" as Model
import "../GlobeModel.js" as GlobeModel

Column {
  id: root

  property var fleetData: ({})
  property alias fleetGlobe: fleetGlobe
  property int activeIssuesCount: 0
  property int siteDownCount: 0
  property int siteBackupCount: 0
  property bool autoRotate: true
  property bool opened: false
  property var issuesList: []
  property bool isLightTheme: false
  property int activeTab: 0
  property string sitesSubView: "sites"

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

  signal openSiteRequested(var site)
  function openSite(site) {
    openSiteRequested(site)
  }

  signal openAnalyticsRequested(int tabIndex)
  function openAnalytics(tabIndex) {
    openAnalyticsRequested(tabIndex)
  }

            spacing: Style.space(10)

            // 4-Card Cockpit Metric Row using StatBlock
            RowLayout {
              width: root.width
              spacing: Style.space(6)

              StatBlock {
                label: "SITES"
                value: String(root.fleetData.sites ? root.fleetData.sites.length : 1)
                subvalue: root.siteDownCount > 0 ? (root.siteDownCount + " Down") : "All Healthy"
                iconText: "\uf132"
                valColor: root.foreground
                subColor: root.siteDownCount > 0 ? root.urgent : root.healthy
                trackColor: root.track
                fontFamily: root.fontFamily
                isHighlighted: root.siteDownCount > 0
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.activeTab = 1; root.sitesSubView = "sites"; } }
              }

              StatBlock {
                label: "GATEWAYS"
                value: String(root.fleetData.network && root.fleetData.network.gatewaysCount ? root.fleetData.network.gatewaysCount : (root.fleetData.sites ? root.fleetData.sites.length : 1))
                subvalue: root.siteBackupCount > 0 ? (root.siteBackupCount + " Backup WAN") : "WAN Normal"
                iconText: "\uf0e8"
                valColor: root.foreground
                subColor: root.siteBackupCount > 0 ? root.backup : root.healthy
                trackColor: root.track
                fontFamily: root.fontFamily
                isHighlighted: root.siteBackupCount > 0
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.activeTab = 1; root.sitesSubView = "sites"; } }
              }

              StatBlock {
                label: "DEVICES"
                value: String(root.fleetData.network && root.fleetData.network.deviceCount ? root.fleetData.network.deviceCount : (root.fleetData.network && root.fleetData.network.devices ? root.fleetData.network.devices.length : 0))
                subvalue: (root.fleetData.network && root.fleetData.network.offlineCount > 0) ? (root.fleetData.network.offlineCount + " Offline") : "All Online"
                iconText: "\uf233"
                valColor: root.foreground
                subColor: (root.fleetData.network && root.fleetData.network.offlineCount > 0) ? root.urgent : root.healthy
                trackColor: root.track
                fontFamily: root.fontFamily
                isHighlighted: !!(root.fleetData.network && root.fleetData.network.offlineCount > 0)
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.activeTab = 1; root.sitesSubView = "devices"; } }
              }

              StatBlock {
                label: "CLIENTS"
                value: String(root.fleetData.network && root.fleetData.network.clientCount ? root.fleetData.network.clientCount : 0)
                subvalue: "\uf1eb " + (root.fleetData.network ? (root.fleetData.network.wifiClients || 0) : 0) + " · \uf0e8 " + (root.fleetData.network ? (root.fleetData.network.wiredClients || 0) : 0)
                iconText: "\uf109"
                valColor: root.foreground
                subColor: root.dim
                trackColor: root.track
                fontFamily: root.fontFamily
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.activeTab = 1; root.sitesSubView = "devices"; } }
              }
            }

            // Fleet WAN Live Throughput Card
            BorderSurface {
              width: root.width
              implicitHeight: fleetThroughputCardCol.implicitHeight + Style.space(16)
              height: implicitHeight
              color: root.card
              radius: Style.cornerRadius
              borderSpec: Border.flat(root.outline, 1)

              ColumnLayout {
                id: fleetThroughputCardCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(8)
                spacing: Style.space(4)

                WanSparkline {
                  id: fleetWanSparkline
                  Layout.fillWidth: true
                  throughputData: (root.fleetData && root.fleetData.fleetThroughput) ? Model.getFleetThroughput24h(root.fleetData) : null
                  compact: false
                  interactive: true
                  range: "24h"
                }
              }
            }

            // 3D VECTOR GLOBE (OMAGLOBE CANVAS INTEGRATION)
            BorderSurface {
              width: root.width
              implicitHeight: globeCardColumn.implicitHeight + Style.space(20)
              height: implicitHeight
              color: root.card
              radius: Style.cornerRadius
              borderSpec: Border.flat(root.outline, 1)

              Column {
                id: globeCardColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: Style.space(10)
                spacing: Style.space(8)

                // Globe Header Accessory Bar
                Item {
                  width: parent.width
                  height: Style.space(24)

                  Row {
                    spacing: Style.space(6)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    Text { textFormat: Text.PlainText; text: "\uf0ac"; color: root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption; anchors.verticalCenter: parent.verticalCenter }
                    Text { textFormat: Text.PlainText; text: "GLOBAL FLEET TOPOLOGY"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                  }

                  // Controls: Focus, Rotate left/right, Auto-rotate
                  Row {
                    spacing: Style.space(4)
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    // Focus sites
                    Rectangle {
                      width: focusBtnText.implicitWidth + Style.space(14)
                      height: Style.space(22)
                      radius: 3
                      color: focusMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; id: focusBtnText; anchors.centerIn: parent; text: " Focus"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: focusMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          if (root.fleetData && root.fleetData.sites && root.fleetData.sites.length > 0) {
                            fleetGlobe.focusSite(root.fleetData.sites[0])
                          }
                        }
                      }

                      PanelToolTip {
                        visible: focusMouse.containsMouse
                        text: "Center globe on primary site"
                        fontFamily: root.fontFamily
                      }
                    }

                    // Rotate left
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 3
                      color: rotLeftMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "◀"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: rotLeftMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fleetGlobe.centreLongitude = GlobeModel.wrapLongitude(fleetGlobe.centreLongitude - 25)
                      }

                      PanelToolTip {
                        visible: rotLeftMouse.containsMouse
                        text: "Rotate globe left 25°"
                        fontFamily: root.fontFamily
                      }
                    }

                    // Rotate right
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 3
                      color: rotRightMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "▶"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: rotRightMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fleetGlobe.centreLongitude = GlobeModel.wrapLongitude(fleetGlobe.centreLongitude + 25)
                      }

                      PanelToolTip {
                        visible: rotRightMouse.containsMouse
                        text: "Rotate globe right 25°"
                        fontFamily: root.fontFamily
                      }
                    }

                    // Zoom In
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 3
                      color: zoomInMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "＋"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                      MouseArea {
                        id: zoomInMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fleetGlobe.zoomIn()
                      }

                      PanelToolTip {
                        visible: zoomInMouse.containsMouse
                        text: "Zoom in on globe"
                        fontFamily: root.fontFamily
                      }
                    }

                    // Zoom Out
                    Rectangle {
                      width: Style.space(22)
                      height: Style.space(22)
                      radius: 3
                      color: zoomOutMouse.containsMouse ? root.cardHover : root.track
                      Text { textFormat: Text.PlainText; anchors.centerIn: parent; text: "－"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
                      MouseArea {
                        id: zoomOutMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fleetGlobe.zoomOut()
                      }

                      PanelToolTip {
                        visible: zoomOutMouse.containsMouse
                        text: "Zoom out on globe"
                        fontFamily: root.fontFamily
                      }
                    }

                    // Auto-rotate toggle
                    Rectangle {
                      width: autoRotText.implicitWidth + Style.space(10)
                      height: Style.space(22)
                      radius: 3
                      color: root.autoRotate ? root.cardHover : root.track
                      border.width: 1
                      border.color: root.autoRotate ? root.accent : "transparent"
                      Text { textFormat: Text.PlainText; id: autoRotText; anchors.centerIn: parent; text: root.autoRotate ? " Auto" : " Auto"; color: root.autoRotate ? root.accent : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1 }
                      MouseArea {
                        id: autoRotMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.autoRotate = !root.autoRotate
                      }

                      PanelToolTip {
                        visible: autoRotMouse.containsMouse
                        text: root.autoRotate ? "Pause globe auto-rotation" : "Enable continuous globe rotation"
                        fontFamily: root.fontFamily
                      }
                    }
                  }
                }

                // 3D Globe Canvas Container (Full width)
                Rectangle {
                  id: globeContainer
                  width: parent.width
                  height: Style.space(175)
                  color: root.isLightTheme ? "#f1f5f9" : "#080b11"
                  radius: Style.cornerRadius - 2
                  border.width: 1
                  border.color: root.outline
                  clip: true

                  Globe {
                    id: fleetGlobe
                    anchors.fill: parent
                    sites: root.fleetData && root.fleetData.sites ? root.fleetData.sites : []
                    connections: (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.connections) ? root.fleetData.sdwan.connections : []
                    sdwan: root.fleetData ? root.fleetData.sdwan : null
                    autoRotate: root.autoRotate && root.opened && root.activeTab === 0
                    animateTraffic: root.opened && root.activeTab === 0
                    fontFamily: root.fontFamily
                    sphereColor: root.isLightTheme ? "#e2e8f0" : "#0f1520"
                    landColor: root.isLightTheme ? "#94a3b8" : "#1e293b"
                    gridColor: root.isLightTheme ? "#cbd5e1" : "#334155"
                    outlineColor: root.accent
                    textColor: root.foreground
                    healthy: root.healthy
                    backup: root.backup
                    urgent: root.urgent
                    onSiteActivated: function(site) {
                      root.openSite(site)
                    }
                  }
                }

                // In-View Sites Dense Roster
                Column {
                  width: parent.width
                  spacing: Style.space(4)
                  visible: fleetGlobe.visibleSites && fleetGlobe.visibleSites.length > 0

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(6)
                    Text {
                      textFormat: Text.PlainText;
                      text: " IN VIEW (" + (fleetGlobe.visibleSites ? fleetGlobe.visibleSites.length : 0) + ")"
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      font.bold: true
                      Layout.fillWidth: true
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "Click to open"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                    }
                  }

                  RowLayout {
                    width: parent.width
                    spacing: Style.space(6)

                    Repeater {
                      model: fleetGlobe.visibleSites || []
                      delegate: Rectangle {
                        id: cardDelegate
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.minimumWidth: 0
                        implicitHeight: Style.space(34)
                        radius: 4
                        clip: true
                        color: cardMouse.containsMouse
                          ? (root.isLightTheme ? "#f1f5f9" : root.cardHover)
                          : (root.isLightTheme ? "#f8fafc" : Qt.rgba(root.track.r, root.track.g, root.track.b, 0.45))
                        border.width: 1
                        border.color: cardMouse.containsMouse
                          ? root.accent
                          : (fleetGlobe.selectedSite && fleetGlobe.selectedSite.id === modelData.id ? root.accent : root.outline)

                        RowLayout {
                          anchors.fill: parent
                          anchors.leftMargin: Style.space(6)
                          anchors.rightMargin: Style.space(6)
                          spacing: Style.space(4)

                          Rectangle {
                            width: Style.space(6)
                            height: Style.space(6)
                            radius: width / 2
                            color: modelData.status === "down" ? root.urgent : (modelData.status === "backup" ? root.backup : root.healthy)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          ColumnLayout {
                            Layout.fillWidth: true
                            Layout.minimumWidth: 0
                            spacing: 0

                            RowLayout {
                              Layout.fillWidth: true
                              spacing: Style.space(3)
                              Text {
                                textFormat: Text.PlainText;
                                text: Model.safe(modelData.name, "Site")
                                color: root.foreground
                                font.family: root.fontFamily
                                font.pixelSize: Style.font.caption - 1
                                font.bold: true
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                                Layout.minimumWidth: 0
                              }
                              Text {
                                textFormat: Text.PlainText;
                                visible: !!modelData.gatewayModel
                                text: "(" + modelData.gatewayModel + ")"
                                color: root.dim
                                font.family: root.fontFamily
                                font.pixelSize: 8
                                elide: Text.ElideRight
                                Layout.maximumWidth: Style.space(52)
                              }
                            }

                            Text {
                              textFormat: Text.PlainText;
                              text: " " + (modelData.clientCount !== undefined ? modelData.clientCount : 0) + " ·  " + (modelData.deviceCount !== undefined ? modelData.deviceCount : 0) + (modelData.isp ? (" · " + modelData.isp) : "")
                              color: root.dim
                              font.family: root.fontFamily
                              font.pixelSize: 8
                              elide: Text.ElideRight
                              Layout.fillWidth: true
                              Layout.minimumWidth: 0
                            }
                          }

                          WanSparkline {
                            site: cardDelegate.modelData
                            compact: true
                            interactive: false
                            implicitWidth: Style.space(64)
                            Layout.preferredWidth: Style.space(64)
                            Layout.maximumWidth: Style.space(64)
                            implicitHeight: Style.space(20)
                            Layout.alignment: Qt.AlignVCenter
                          }

                          Rectangle {
                            visible: modelData.status !== "up"
                            height: Style.space(13)
                            implicitWidth: itemStatusText.implicitWidth + Style.space(6)
                            radius: 2
                            color: modelData.status === "down" ? root.urgent : root.backup
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                              textFormat: Text.PlainText;
                              id: itemStatusText
                              anchors.centerIn: parent
                              text: modelData.status ? modelData.status.toUpperCase() : ""
                              color: "#ffffff"
                              font.family: root.fontFamily
                              font.pixelSize: 8
                              font.bold: true
                            }
                          }
                        }

                        MouseArea {
                          id: cardMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: root.openSite(cardDelegate.modelData)
                          onEntered: fleetGlobe.selectedSite = cardDelegate.modelData
                          onExited: {
                            if (fleetGlobe.selectedSite && fleetGlobe.selectedSite.id === cardDelegate.modelData.id) {
                              fleetGlobe.selectedSite = null
                            }
                          }
                        }
                      }
                    }
                  }
                }

                // Interactive Telemetry Strip
                Rectangle {
                  width: parent.width
                  height: Style.space(22)
                  radius: 3
                  color: root.track
                  border.width: 1
                  border.color: root.outline

                  Row {
                    anchors.centerIn: parent
                    spacing: Style.space(6)
                    Rectangle {
                      width: Style.space(5)
                      height: width
                      radius: width / 2
                      color: root.healthy
                      anchors.verticalCenter: parent.verticalCenter
                    }
                    Text { textFormat: Text.PlainText;
                      text: (fleetGlobe.visibleSites ? fleetGlobe.visibleSites.length : 0) + " of " + (root.fleetData && root.fleetData.sites ? root.fleetData.sites.length : 0) + " sites in view" + (root.fleetData && root.fleetData.sdwan && root.fleetData.sdwan.available && fleetGlobe.preparedConnections && fleetGlobe.preparedConnections.length > 0 ? "  ·   " + fleetGlobe.preparedConnections.length + " SD-WAN link" + (fleetGlobe.preparedConnections.length > 1 ? "s" : "") : "") + "  ·  Drag to rotate  ·  Scroll to zoom"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }
                }
              }
            }

            // Attention Sites List (if any site or device needs attention)
            Column {
              visible: root.activeIssuesCount > 0
              width: root.width
              spacing: Style.space(6)

              PanelSectionHeader { width: root.width; text: "ATTENTION REQUIRED (" + root.activeIssuesCount + ")"; foreground: root.urgent; fontFamily: root.fontFamily }

              Repeater {
                model: root.issuesList.filter(function(i) { return i.active === true })
                BorderSurface {
                  required property var modelData
                  width: root.width
                  implicitHeight: activeIssueRow.implicitHeight + Style.space(12)
                  height: implicitHeight
                  color: activeIssueMouse.containsMouse ? root.cardHover : root.card
                  radius: Style.cornerRadius
                  borderSpec: Border.flat(modelData.severity === "critical" ? root.urgent : root.backup, 1)

                  RowLayout {
                    id: activeIssueRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Style.space(8)
                    spacing: Style.space(8)

                    Text {
                      textFormat: Text.PlainText;
                      text: "\uf071"
                      color: modelData.severity === "critical" ? root.urgent : root.backup
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      Layout.alignment: Qt.AlignVCenter
                    }

                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 0
                      spacing: 1
                      Layout.alignment: Qt.AlignVCenter

                      Text {
                        textFormat: Text.PlainText;
                        text: Model.safe(modelData.title)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: Model.safe(modelData.site) + (modelData.model ? " · " + Model.safe(modelData.model) : "") + " · " + (modelData.durationSeconds ? ("Down for " + Model.formatDuration(modelData.durationSeconds)) : "Active")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    Rectangle {
                      id: activeIssuePill
                      radius: 3
                      implicitHeight: Style.space(18)
                      implicitWidth: activePillLabel.implicitWidth + Style.space(12)
                      Layout.preferredHeight: Style.space(18)
                      Layout.preferredWidth: activePillLabel.implicitWidth + Style.space(12)
                      color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18)
                      border.width: 1
                      border.color: modelData.severity === "critical" ? root.urgent : root.backup
                      Layout.alignment: Qt.AlignVCenter

                      Text {
                        textFormat: Text.PlainText;
                        id: activePillLabel
                        anchors.centerIn: parent
                        text: "ACTIVE"
                        color: modelData.severity === "critical" ? root.urgent : root.backup
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                      }
                    }
                  }
                  MouseArea {
                    id: activeIssueMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.activeTab = 2
                  }
                }
              }
            }
          }
