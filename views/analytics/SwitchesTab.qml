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

  property string selectedSwitchSite: "all"
  property string selectedSwitchMac: ""
  property var switchSiteOptions: []
  property var switchOptionsForSelectedSite: []
  property var currentSwitch: null
  property bool isLightTheme: false
  property string portFilter: "all"

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

  signal switchSiteSelected(string site)
  signal switchMacSelected(string mac)
  signal cyclePortRequested(string hostId, string mac, var portIdx, string portName, string siteId)

  function cyclePort(hostId, mac, portIdx, portName, siteId) {
    cyclePortRequested(hostId, mac, portIdx, portName, siteId || "")
  }

  property var fleetData: ({})
  property var capabilities: root.fleetData && root.fleetData.capabilities ? root.fleetData.capabilities : null
  readonly property bool canPowerCycle: {
    if (!root.capabilities || !root.capabilities.powerCycle) return true
    return root.capabilities.powerCycle.allowed !== false
  }
  readonly property string powerCycleWarning: {
    if (root.capabilities && root.capabilities.powerCycle && !root.canPowerCycle) {
      return root.capabilities.powerCycle.warning || root.capabilities.powerCycle.missingPermission || "Missing 'devices:write' scope: PoE power cycling disabled for this API key"
    }
    return "Missing 'devices:write' scope: PoE power cycling disabled for this API key"
  }
  readonly property bool partial: !!(root.fleetData && root.fleetData.partial)
  readonly property var failedEndpoints: (root.fleetData && root.fleetData.failedEndpoints) || []
  readonly property var unavailableTelemetry: (root.fleetData && root.fleetData.unavailableTelemetry) || []
  readonly property bool switchesUnavailable: {
    if (root.currentSwitch || (root.switchOptionsForSelectedSite && root.switchOptionsForSelectedSite.length > 0)) return false
    if (!root.partial) return false
    if (root.unavailableTelemetry && (root.unavailableTelemetry.indexOf("switches") >= 0 || root.unavailableTelemetry.indexOf("devices") >= 0)) return true
    if (root.failedEndpoints) {
      for (var i = 0; i < root.failedEndpoints.length; i++) {
        var ep = String(root.failedEndpoints[i])
        if (ep.indexOf("stat/device") >= 0 || ep.indexOf("/v1/devices") >= 0 || ep.indexOf("switches") >= 0) return true
      }
    }
    return false
  }

  spacing: Style.space(10)

  readonly property var portsList: {
    if (!root.currentSwitch || !root.currentSwitch.ports) return []
    var list = root.currentSwitch.ports
    var filter = root.portFilter
    return list.filter(function(p) {
      if (filter === "PoE" && !(p.poePower > 0 || (p.poeMode && p.poeMode !== "off"))) return false
      if (filter === "Active" && !p.up) return false
      return true
    })
  }

  // Switch Selector & Budget Header Card
  SectionCard {
    Layout.fillWidth: true
    clip: false
    title: "SWITCH FLEET SELECTION & POE BUDGET"
    subtitle: (root.currentSwitch ? root.currentSwitch.name : (root.switchesUnavailable ? "Switch telemetry unavailable (endpoint stat/device error)" : "No switch selected")) + (root.currentSwitch ? (" · " + (root.currentSwitch.siteName || "") + " (" + (root.currentSwitch.activePorts || 0) + "/" + (root.currentSwitch.totalPorts || 0) + " ports active)") : "")
    iconText: ""
    titleColor: root.foreground
    fontFamily: root.fontFamily
    badgeText: root.switchesUnavailable ? "UNAVAILABLE" : (root.currentSwitch ? (String(root.currentSwitch.totalPower || 0) + " W / " + String(root.currentSwitch.maxPower || 600) + " W POE") : "0 W POE")
    badgeColor: root.switchesUnavailable ? root.urgent : root.accent

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            // Switch selector toolbar: Site Dropdown (filter) + Switch Dropdown + Filter Pills
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(10)

              // Site Filter Dropdown (acts as a filter)
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
                  Layout.preferredHeight: Style.space(26)
                  radius: Style.cornerRadius
                  color: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                  border.width: 1
                  border.color: root.outline

                  SearchableDropdown {
                    id: switchSiteDropdown
                    anchors.fill: parent
                    rowHeight: Style.space(26)
                    showLabel: false
                    value: root.selectedSwitchSite
                    options: root.switchSiteOptions
                    placeholderText: "Search sites..."
                    emptyText: "No sites match"
                    foreground: root.foreground
                    background: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                    popupBorder: root.accent
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(val) {
                      root.selectedSwitchSite = val
                    }
                  }
                }
              }

              // Switch Selector Dropdown
              RowLayout {
                spacing: Style.space(6)

                Text {
                  textFormat: Text.PlainText;
                  text: "SWITCH:"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }

                Rectangle {
                  Layout.preferredWidth: Style.space(260)
                  Layout.preferredHeight: Style.space(26)
                  radius: Style.cornerRadius
                  color: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                  border.width: 1
                  border.color: root.outline

                  SearchableDropdown {
                    id: switchPickerDropdown
                    anchors.fill: parent
                    rowHeight: Style.space(26)
                    showLabel: false
                    value: root.currentSwitch ? (root.currentSwitch.mac || root.currentSwitch.name || "") : ""
                    options: root.switchOptionsForSelectedSite
                    placeholderText: "Search switches..."
                    emptyText: root.switchesUnavailable ? "Switch telemetry unavailable" : "No switches match"
                    foreground: root.foreground
                    background: root.isLightTheme ? "#ffffff" : "#1e1e2e"
                    popupBorder: root.accent
                    accent: root.accent
                    fontFamily: root.fontFamily
                    onChanged: function(val) {
                      root.selectedSwitchMac = val
                    }
                  }
                }
              }

              Item { Layout.fillWidth: true }

              // Filter pills: All, PoE, Active
              RowLayout {
                spacing: Style.space(4)

                Repeater {
                  model: ["All", "PoE", "Active"]
                  delegate: Rectangle {
                    required property string modelData
                    height: Style.space(24)
                    width: pFilterText.implicitWidth + Style.space(12)
                    radius: 3
                    color: root.portFilter === modelData ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2) : root.track
                    border.width: 1
                    border.color: root.portFilter === modelData ? root.accent : root.outline

                    Text {
                      id: pFilterText
                      textFormat: Text.PlainText;
                      anchors.centerIn: parent
                      text: modelData === "All" ? "All Ports" : (modelData === "PoE" ? "PoE Only" : "Active Only")
                      color: root.portFilter === modelData ? root.accent : root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: root.portFilter === modelData
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: { root.portFilter = modelData }
                    }
                  }
                }
              }
            }

            // Switch Overview & PoE budget bar
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(14)
              visible: Boolean(root.currentSwitch)

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: (root.currentSwitch ? root.currentSwitch.name : "") + " · " + (root.currentSwitch ? root.currentSwitch.model : "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: "IP: " + (root.currentSwitch ? root.currentSwitch.ip : "") + " · MAC: " + (root.currentSwitch ? root.currentSwitch.mac : "") + " · " + (root.currentSwitch ? root.currentSwitch.activePorts : 0) + "/" + (root.currentSwitch ? root.currentSwitch.totalPorts : 0) + " Ports Connected"
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  elide: Text.ElideRight
                  Layout.fillWidth: true
                }
              }

              // PoE Power Consumption Meter
              ColumnLayout {
                Layout.preferredWidth: 240
                Layout.minimumWidth: 240
                Layout.maximumWidth: 240
                Layout.fillWidth: false
                spacing: 2

                RowLayout {
                  Layout.fillWidth: true
                  Text {
                    textFormat: Text.PlainText;
                    text: "PoE Power:"
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                  }
                  Item { Layout.fillWidth: true }
                  Text {
                    textFormat: Text.PlainText;
                    text: String(root.currentSwitch ? root.currentSwitch.totalPower : 0) + " W / " + String(root.currentSwitch ? root.currentSwitch.maxPower : 600) + " W"
                    color: root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                  }
                }

                Rectangle {
                  Layout.fillWidth: true
                  height: 5
                  radius: 2.5
                  color: root.track

                  Rectangle {
                    height: parent.height
                    radius: 2.5
                    width: Math.min(parent.width, Math.max(4, parent.width * ((root.currentSwitch && root.currentSwitch.maxPower > 0) ? (root.currentSwitch.totalPower / root.currentSwitch.maxPower) : 0.05)))
                    color: root.accent
                  }
                }
              }
            }

            // Physical RJ45 Faceplate Port Visualizer (Chassis Strip)
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(32)
              color: root.track
              radius: 4
              border.width: 1
              border.color: root.outline
              visible: Boolean(root.currentSwitch && root.currentSwitch.ports && root.currentSwitch.ports.length > 0)

              Flickable {
                anchors.fill: parent
                anchors.margins: Style.space(3)
                contentWidth: jackRowLayout.width
                contentHeight: height
                clip: true

                RowLayout {
                  id: jackRowLayout
                  spacing: Style.space(3)

                  Repeater {
                    model: root.currentSwitch ? (root.currentSwitch.ports || []) : []
                    delegate: Rectangle {
                      required property var modelData
                      required property int index
                      width: Style.space(18)
                      height: Style.space(24)
                      radius: 2
                      color: modelData.up
                        ? (modelData.poePower > 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.25) : Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2))
                        : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.1)
                      border.width: 1
                      border.color: modelData.up
                        ? (modelData.poePower > 0 ? root.accent : root.healthy)
                        : root.outline

                      ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 1

                        Text {
                          textFormat: Text.PlainText;
                          Layout.alignment: Qt.AlignHCenter
                          text: String(modelData.portIdx)
                          color: modelData.up ? root.foreground : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                          font.bold: true
                        }

                        Rectangle {
                          Layout.alignment: Qt.AlignHCenter
                          width: 4
                          height: 4
                          radius: 2
                          color: modelData.up ? (modelData.poePower > 0 ? root.accent : root.healthy) : root.dim
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

        // Port Matrix Card
        SectionCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          title: "PORT MATRIX & REMOTE POE POWER CYCLING"
          subtitle: "Live link negotiation, PoE power/voltage telemetry, connected endpoints, and remote PoE power cycling"
          iconText: ""
          titleColor: root.foreground
          fontFamily: root.fontFamily

          Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: portGridCol.childrenRect.height + Style.space(16)
            clip: true

            Column {
              id: portGridCol
              width: parent.width
              spacing: Style.space(4)

              // Inline PoE Permission Warning Banner
              Rectangle {
                id: poePermissionBanner
                visible: !root.canPowerCycle
                width: portGridCol.width
                implicitHeight: poePermRow.implicitHeight + Style.space(12)
                radius: 4
                color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.12)
                border.width: 1
                border.color: root.urgent

                RowLayout {
                  id: poePermRow
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
                    text: root.powerCycleWarning
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 1
                    wrapMode: Text.WordWrap
                  }
                }
              }

              Rectangle {
                visible: tab3View.portsList.length === 0
                width: portGridCol.width
                implicitHeight: Style.space(56)
                radius: 5
                color: root.track
                border.width: 1
                border.color: root.switchesUnavailable ? root.urgent : root.outline

                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(3)

                  Text {
                    textFormat: Text.PlainText;
                    Layout.alignment: Qt.AlignHCenter
                    text: root.switchesUnavailable
                      ? "Switch telemetry unavailable (endpoint stat/device error)"
                      : (!root.currentSwitch ? "No switches found in fleet" : "No ports match the selected filter.")
                    color: root.switchesUnavailable ? root.urgent : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: root.switchesUnavailable
                  }

                  Text {
                    textFormat: Text.PlainText;
                    visible: root.switchesUnavailable
                    Layout.alignment: Qt.AlignHCenter
                    text: "Telemetry is partial. Check UI Account permissions or API key."
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                  }
                }
              }

              // 2-Column high-density table headers
              RowLayout {
                width: parent.width
                spacing: Style.space(8)
                visible: tab3View.portsList.length > 0

                // Left Column Header
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredWidth: Math.floor((portGridCol.width - Style.space(8)) / 2)
                  height: Style.space(20)
                  color: "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(32)
                      Layout.maximumWidth: Style.space(32)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(32)
                      text: "PORT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(105)
                      Layout.maximumWidth: Style.space(105)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(105)
                      text: "STATUS & SPEED"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.fillWidth: true
                      Layout.minimumWidth: Style.space(70)
                      text: "ENDPOINT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(56)
                      Layout.maximumWidth: Style.space(56)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(56)
                      text: "POE"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(48)
                      Layout.maximumWidth: Style.space(48)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(48)
                      text: "ACTION"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }

                // Right Column Header
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredWidth: Math.floor((portGridCol.width - Style.space(8)) / 2)
                  height: Style.space(20)
                  color: "transparent"

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(8)
                    anchors.rightMargin: Style.space(8)
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(32)
                      Layout.maximumWidth: Style.space(32)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(32)
                      text: "PORT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(105)
                      Layout.maximumWidth: Style.space(105)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(105)
                      text: "STATUS & SPEED"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.fillWidth: true
                      Layout.minimumWidth: Style.space(70)
                      text: "ENDPOINT"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(56)
                      Layout.maximumWidth: Style.space(56)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(56)
                      text: "POE"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      Layout.minimumWidth: Style.space(48)
                      Layout.maximumWidth: Style.space(48)
                      Layout.fillWidth: false
                      Layout.preferredWidth: Style.space(48)
                      text: "ACTION"
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                    }
                  }
                }
              }

              // 2-Column Port Grid
              Grid {
                id: portGrid
                width: parent.width
                columns: 2
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(2)

                Repeater {
                  model: tab3View.portsList
                  delegate: Rectangle {
                    required property var modelData
                    width: Math.floor((portGrid.width - portGrid.columnSpacing) / 2)
                    height: Style.space(25)
                    radius: 3
                    color: portRowMouse.containsMouse ? root.cardHover : root.track
                    border.width: 1
                    border.color: portRowMouse.containsMouse ? root.accent : (modelData.up ? (modelData.poePower > 0 ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.3) : root.outline) : root.outline)

                    MouseArea {
                      id: portRowMouse
                      anchors.fill: parent
                      hoverEnabled: true
                    }

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(8)
                      anchors.rightMargin: Style.space(8)
                      spacing: Style.space(6)

                      // Col 1: Port Badge
                      Rectangle {
                        Layout.minimumWidth: Style.space(32)
                        Layout.maximumWidth: Style.space(32)
                        Layout.fillWidth: false
                        Layout.preferredWidth: Style.space(32)
                        Layout.preferredHeight: Style.space(18)
                        radius: 3
                        color: modelData.up ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18) : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.12)
                        border.width: 1
                        border.color: modelData.up ? root.healthy : root.outline

                        Text {
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          text: "P" + String(modelData.portIdx)
                          color: modelData.up ? root.healthy : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                        }
                      }

                      // Col 2: Status & Speed (Dense Inline)
                      RowLayout {
                        Layout.minimumWidth: Style.space(105)
                        Layout.maximumWidth: Style.space(105)
                        Layout.fillWidth: false
                        Layout.preferredWidth: Style.space(105)
                        spacing: Style.space(4)

                        Rectangle {
                          width: 5
                          height: 5
                          radius: 2.5
                          color: modelData.up ? root.healthy : root.dim
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.name || ("Port " + modelData.portIdx)
                          color: root.foreground
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }

                        Rectangle {
                          visible: modelData.up
                          height: Style.space(16)
                          radius: 2
                          color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
                          border.width: 1
                          border.color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.35)
                          implicitWidth: spdText.implicitWidth + Style.space(6)

                          Text {
                            id: spdText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            text: modelData.speedText || "1G"
                            color: root.healthy
                            font.family: root.fontFamily
                            font.pixelSize: 7
                            font.bold: true
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          visible: !modelData.up
                          text: "Down"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                        }
                      }

                      // Col 3: Connected Endpoint (Dense Inline)
                      RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: Style.space(70)
                        spacing: Style.space(4)

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.connectedDevice ? "" : ""
                          color: modelData.connectedDevice ? root.accent : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 8
                        }

                        Text {
                          textFormat: Text.PlainText;
                          text: modelData.connectedDevice || "No device"
                          color: modelData.connectedDevice ? root.foreground : root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: Boolean(modelData.connectedDevice)
                          elide: Text.ElideRight
                          Layout.fillWidth: true
                        }
                      }

                      // Col 4: PoE Telemetry (Dense Inline)
                      RowLayout {
                        Layout.minimumWidth: Style.space(56)
                        Layout.maximumWidth: Style.space(56)
                        Layout.fillWidth: false
                        Layout.preferredWidth: Style.space(56)
                        spacing: Style.space(3)

                        Text {
                          textFormat: Text.PlainText;
                          visible: modelData.poePower > 0
                          text: ""
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: 7
                        }

                        Text {
                          textFormat: Text.PlainText;
                          visible: modelData.poePower > 0
                          text: modelData.poePower.toFixed(1) + "W"
                          color: root.accent
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                          font.bold: true
                        }

                        Text {
                          textFormat: Text.PlainText;
                          visible: !(modelData.poePower > 0)
                          text: (modelData.poeMode && modelData.poeMode !== "off") ? "Standby" : "Off"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: Style.font.caption - 2
                        }

                        Item { Layout.fillWidth: true }
                      }

                      // Col 5: Action (Dense Cycle PoE Button with Tooltip)
                      Rectangle {
                        Layout.minimumWidth: Style.space(48)
                        Layout.maximumWidth: Style.space(48)
                        Layout.fillWidth: false
                        Layout.preferredWidth: Style.space(48)
                        Layout.preferredHeight: Style.space(18)
                        radius: 3
                        color: (modelData.poeMode !== "off" || modelData.poePower > 0)
                          ? (cycleBtnMouse.containsMouse ? root.cardHover : root.track)
                          : "transparent"
                        opacity: (modelData.poeMode !== "off" || modelData.poePower > 0) ? (root.canPowerCycle ? 1.0 : 0.45) : 0.35
                        border.width: 1
                        border.color: (modelData.poeMode !== "off" || modelData.poePower > 0)
                          ? (cycleBtnMouse.containsMouse ? (root.canPowerCycle ? root.backup : root.urgent) : root.outline)
                          : "transparent"

                        RowLayout {
                          anchors.centerIn: parent
                          spacing: 2
                          visible: modelData.poeMode !== "off" || modelData.poePower > 0

                          Text {
                            textFormat: Text.PlainText;
                            text: root.canPowerCycle ? "" : ""
                            color: root.canPowerCycle ? root.backup : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 7
                          }

                          Text {
                            textFormat: Text.PlainText;
                            text: "Cycle"
                            color: root.canPowerCycle ? root.foreground : root.dim
                            font.family: root.fontFamily
                            font.pixelSize: 7
                            font.bold: true
                          }
                        }

                        Text {
                          textFormat: Text.PlainText;
                          anchors.centerIn: parent
                          visible: !(modelData.poeMode !== "off" || modelData.poePower > 0)
                          text: "—"
                          color: root.dim
                          font.family: root.fontFamily
                          font.pixelSize: 7
                        }

                        MouseArea {
                          id: cycleBtnMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          cursorShape: (modelData.poeMode !== "off" || modelData.poePower > 0) ? (root.canPowerCycle ? Qt.PointingHandCursor : Qt.ForbiddenCursor) : Qt.ArrowCursor
                          enabled: modelData.poeMode !== "off" || modelData.poePower > 0
                          onClicked: {
                            if (root.canPowerCycle && root.currentSwitch) {
                              root.cyclePort(root.currentSwitch.hostId, root.currentSwitch.mac, modelData.portIdx, modelData.name || ("Port " + modelData.portIdx), root.currentSwitch.siteId || "")
                            }
                          }
                        }

                        Rectangle {
                          z: 20
                          visible: cycleBtnMouse.containsMouse && (modelData.poeMode !== "off" || modelData.poePower > 0)
                          anchors.bottom: parent.top
                          anchors.bottomMargin: 4
                          anchors.right: parent.right
                          width: (root.canPowerCycle ? cycleTipText.implicitWidth : cycleTipDisabledText.implicitWidth) + Style.space(12)
                          height: Style.space(20)
                          radius: 3
                          color: root.isLightTheme ? "#ffffff" : "#161b2a"
                          border.width: 1
                          border.color: root.outline

                          Text {
                            id: cycleTipText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            visible: root.canPowerCycle
                            text: "Power cycle PoE on Port " + modelData.portIdx + (modelData.poePower > 0 ? (" (" + modelData.poePower + "W)") : "")
                            color: root.foreground
                            font.family: root.fontFamily
                            font.pixelSize: 8
                          }

                          Text {
                            id: cycleTipDisabledText
                            textFormat: Text.PlainText;
                            anchors.centerIn: parent
                            visible: !root.canPowerCycle
                            text: "Cannot power cycle: API key lacks 'devices:write' permission"
                            color: root.foreground
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
        }
      }
