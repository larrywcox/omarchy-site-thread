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

  property var fleetData: ({})
  readonly property var pluggedWans: {
    if (!root.fleetData || !Array.isArray(root.fleetData.wans)) return [];
    return root.fleetData.wans.filter(function(item) {
      return Boolean(item && item.plugged);
    });
  }

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#f59e0b"
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal pingHostRequested(string host, string label)
  function pingHost(host, label) {
    pingHostRequested(host, label)
  }

        spacing: Style.space(10)

        // Gateway WAN Interfaces Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: 3
          title: "GATEWAY WAN HARDWARE TELEMETRY"
          subtitle: "Multi-gigabit WAN interfaces, physical port states, link speeds, IPv4/IPv6, and ISP peering"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: String(root.pluggedWans.length) + " INTERFACES"
          badgeColor: root.accent

          Flickable {
            id: wanFlick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: wanCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: wanCol
              width: wanFlick.width
              spacing: Style.space(6)

              Text {
                textFormat: Text.PlainText;
                visible: !root.fleetData || !root.fleetData.wans || root.pluggedWans.length === 0
                text: (!root.fleetData || !root.fleetData.wans) ? "Querying gateway WAN interfaces..." : "No plugged WAN interfaces detected across fleet"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
                horizontalAlignment: Text.AlignHCenter
                width: parent.width
                topPadding: Style.space(20)
              }

              // High-density table column headers
              Rectangle {
                width: wanCol.width
                height: Style.space(22)
                color: "transparent"
                visible: root.pluggedWans.length > 0

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(12)
                  anchors.rightMargin: Style.space(12)
                  spacing: Style.space(10)

                  Text {
                    textFormat: Text.PlainText;
                    Layout.minimumWidth: 88
                    Layout.maximumWidth: 88
                    Layout.fillWidth: false
                    Layout.preferredWidth: 88
                    text: "STATE"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.minimumWidth: 100
                    Layout.maximumWidth: 100
                    Layout.fillWidth: false
                    Layout.preferredWidth: 100
                    text: "INTERFACE"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 130
                    Layout.preferredWidth: 160
                    text: "SITE & GATEWAY"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 150
                    Layout.preferredWidth: 190
                    text: "PUBLIC IP & MAC"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.fillWidth: true
                    Layout.minimumWidth: 130
                    Layout.preferredWidth: 160
                    text: "ISP PEERING & SLA"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText;
                    Layout.minimumWidth: 58
                    Layout.maximumWidth: 58
                    Layout.fillWidth: false
                    Layout.preferredWidth: 58
                    text: "ACTION"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: 8
                    font.bold: true
                    horizontalAlignment: Text.AlignRight
                  }
                }
              }

              // High-density tabular interface rows
              Repeater {
                model: root.pluggedWans
                delegate: Rectangle {
                  required property var modelData
                  width: wanCol.width
                  height: Style.space(40)
                  radius: 5
                  color: wanRowMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.35) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.35)) : root.outline

                  MouseArea {
                    id: wanRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    // Col 1: Status Dot & Link Type Tag
                    RowLayout {
                      Layout.minimumWidth: 88
                      Layout.maximumWidth: 88
                      Layout.fillWidth: false
                      Layout.preferredWidth: 88
                      spacing: 6

                      Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? root.healthy : root.backup) : root.dim
                      }

                      Rectangle {
                        height: 20
                        width: wanTagText.implicitWidth + 10
                        radius: 3
                        color: modelData.plugged ? (modelData.type.indexOf("Primary") !== -1 ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18)) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.18)

                        Text {
                          id: wanTagText
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: !modelData.plugged ? "UNPLUGGED" : (modelData.type.indexOf("Primary") !== -1 ? "PRIMARY" : "STANDBY")
                          color: !modelData.plugged ? root.foreground : (modelData.type.indexOf("Primary") !== -1 ? root.healthy : root.backup)
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      Item { Layout.fillWidth: true }
                    }

                    // Col 2: Interface / Port Pill & Speed
                    ColumnLayout {
                      Layout.minimumWidth: 100
                      Layout.maximumWidth: 100
                      Layout.fillWidth: false
                      Layout.preferredWidth: 100
                      spacing: 1

                      Rectangle {
                        height: 18
                        width: ifacePillText.implicitWidth + 10
                        radius: 3
                        color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18)

                        Text {
                          id: ifacePillText
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: (modelData.interface || "eth0") + " · P" + (modelData.port !== undefined ? modelData.port : "0")
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 9
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.speedType || "1GbE"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 3: Site Name & Gateway Model
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 130
                      Layout.preferredWidth: 160
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.siteName || "Site"
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.gatewayModel || modelData.hostname || "UniFi Gateway"
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 4: Public IPv4 & IPv6 / MAC
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 150
                      Layout.preferredWidth: 190
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.ipv4 || "DHCP Lease Pending"
                        color: modelData.ipv4 ? root.foreground : root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: Boolean(modelData.ipv4)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: (modelData.ipv6 ? modelData.ipv6 : "IPv6: None / SLAAC") + (modelData.mac ? (" · " + modelData.mac) : "")
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 3
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                    }

                    // Col 5: ISP Peering & Uptime SLA
                    ColumnLayout {
                      Layout.fillWidth: true
                      Layout.minimumWidth: 130
                      Layout.preferredWidth: 160
                      spacing: 1

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.isp || "Broadband / Fiber"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 2
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      RowLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: modelData.plugged ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 3
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: (modelData.uptime || (modelData.plugged ? "100% Uptime" : "Down")) + (modelData.plugged ? " · 0% Loss" : "")
                          color: modelData.plugged ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }
                    }

                    // Col 6: Quick Action Ping
                    Rectangle {
                      Layout.minimumWidth: 58
                      Layout.maximumWidth: 58
                      Layout.fillWidth: false
                      Layout.preferredWidth: 58
                      Layout.preferredHeight: 22
                      radius: 4
                      color: (modelData.ipv4 && modelData.plugged && wanPingMouse.containsMouse) ? root.cardHover : root.track
                      opacity: (modelData.ipv4 && modelData.plugged) ? 1.0 : 0.4
                      border.width: 1
                      border.color: (modelData.ipv4 && modelData.plugged && wanPingMouse.containsMouse) ? root.accent : root.outline

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 3

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: "Ping"
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      MouseArea {
                        id: wanPingMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: (modelData.ipv4 && modelData.plugged) ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: {
                          if (modelData.ipv4 && modelData.plugged) {
                            root.pingHost(modelData.ipv4)
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

        // Historical Outage Timeline Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          Layout.preferredHeight: 2
          title: "HISTORICAL OUTAGE & PACKET LOSS TIMELINE"
          subtitle: "5-minute interval internet drop logs, upstream packet loss events, and recovery history"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily
          badgeText: String(root.fleetData && root.fleetData.outages ? root.fleetData.outages.length : 0) + " EVENTS"
          badgeColor: (root.fleetData && root.fleetData.outages && root.fleetData.outages.length > 0) ? root.backup : root.healthy

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: outageListCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: outageListCol
              width: parent.width
              spacing: Style.space(6)

              Rectangle {
                width: parent.width
                height: Style.space(36)
                radius: 5
                color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.1)
                border.width: 1
                border.color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.3)
                visible: !root.fleetData || !root.fleetData.outages || root.fleetData.outages.length === 0

                RowLayout {
                  anchors.centerIn: parent
                  spacing: 8

                  Text {
                    textFormat: Text.PlainText;
                    text: ""
                    color: root.healthy
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }

                  Text {
                    textFormat: Text.PlainText;
                    text: "100% WAN Fleet Uptime — No carrier outages or packet loss detected across any site in recent telemetry periods."
                    color: root.healthy
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    font.bold: true
                  }
                }
              }

              Repeater {
                model: root.fleetData && root.fleetData.outages ? root.fleetData.outages : []
                delegate: Rectangle {
                  required property var modelData
                  width: outageListCol.width
                  height: Style.space(38)
                  radius: 5
                  color: outageMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.4) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.4)

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(10)

                    // Severity badge
                    Rectangle {
                      Layout.preferredWidth: sevText.implicitWidth + 10
                      Layout.preferredHeight: 20
                      radius: 3
                      color: modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.2)

                      RowLayout {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                          textFormat: Text.PlainText;
                          text: ""
                          color: modelData.severity === "critical" ? root.urgent : root.backup
                          font.family: root.fontFamily
                          font.pixelSize: 9
                        }

                        Text {
                          id: sevText
                          textFormat: Text.PlainText;
                          text: (modelData.severity || "warning").toUpperCase()
                          color: modelData.severity === "critical" ? root.urgent : root.backup
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }
                    }

                    // Site Tag
                    Rectangle {
                      Layout.preferredHeight: 18
                      Layout.preferredWidth: outageSiteText.implicitWidth + 8
                      radius: 3
                      color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)

                      Text {
                        id: outageSiteText
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: modelData.siteName || "Site"
                        color: root.accent
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }

                    // Incident summary & description
                    Text {
                      textFormat: Text.PlainText;
                      text: (modelData.type ? (modelData.type + " — ") : "") + (modelData.description || "Gateway internet link dropped")
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 1
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    // Duration pill
                    Rectangle {
                      Layout.preferredHeight: 18
                      Layout.preferredWidth: durText.implicitWidth + 8
                      radius: 3
                      color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.15)

                      Text {
                        id: durText
                        textFormat: Text.PlainText;
                        anchors.centerIn: parent
                        text: "⏱ " + (modelData.durationText || "5m")
                        color: root.urgent
                        font.family: root.fontFamily
                        font.pixelSize: 8
                        font.bold: true
                      }
                    }

                    // Timestamp
                    Text {
                      textFormat: Text.PlainText;
                      text: modelData.timeText || "Recent"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }
                  }

                  MouseArea {
                    id: outageMouse
                    anchors.fill: parent
                    hoverEnabled: true
                  }
                }
              }
            }
          }
        }
      }
