import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "components"

ColumnLayout {
  id: root

  property var devices: []
  property string currentFilter: "all"
  property bool partial: false
  property var failedEndpoints: []
  property int activeChooserIndex: -1
  property string preferredTerminal: "xdg-terminal-exec"
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  function contrastTextFor(c) {
    if (!c) return "#ffffff"
    var lum = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
    return lum > 0.55 ? "#0f141c" : "#ffffff"
  }
  readonly property color accentForeground: contrastTextFor(accent)
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property string fontFamily: Style.font.family

  signal sshRequested(string ip, string user)
  signal pingRequested(string ip)
  signal webRequested(string ip)

  spacing: Style.space(10)

  function deviceCategory(d) {
    if (!d || !d.model) return "other"
    var m = String(d.model).toLowerCase()
    if (m.indexOf("ucg") >= 0 || m.indexOf("udm") >= 0 || m.indexOf("uxg") >= 0 || m.indexOf("gateway") >= 0) return "gateways"
    if (m.indexOf("usw") >= 0 || m.indexOf("switch") >= 0) return "switches"
    if (m.indexOf("u7") >= 0 || m.indexOf("u6") >= 0 || m.indexOf("nano") >= 0 || m.indexOf("ap") >= 0 || m.indexOf("hd") >= 0) return "aps"
    if (m.indexOf("unas") >= 0 || m.indexOf("nvr") >= 0 || m.indexOf("storage") >= 0) return "storage"
    return "other"
  }

  function filteredDevices() {
    var list = Array.isArray(root.devices) ? root.devices : []
    if (root.currentFilter === "all") return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      if (deviceCategory(list[i]) === root.currentFilter) out.push(list[i])
    }
    return out
  }

  function countCategory(cat) {
    var list = Array.isArray(root.devices) ? root.devices : []
    if (cat === "all") return list.length
    var count = 0
    for (var i = 0; i < list.length; i++) {
      if (deviceCategory(list[i]) === cat) count++
    }
    return count
  }

  // Filter Bar
  Flickable {
    Layout.fillWidth: true
    implicitHeight: Style.space(22)
    contentWidth: catPillsRow.implicitWidth
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    RowLayout {
      id: catPillsRow
      spacing: Style.space(4)

      Repeater {
        model: [
          { id: "all", label: "All (" + countCategory("all") + ")" },
          { id: "gateways", label: "Gateways (" + countCategory("gateways") + ")" },
          { id: "switches", label: "Switches (" + countCategory("switches") + ")" },
          { id: "aps", label: "APs (" + countCategory("aps") + ")" },
          { id: "storage", label: "Storage (" + countCategory("storage") + ")" }
        ]
        delegate: Rectangle {
          required property var modelData
          readonly property bool isSelected: root.currentFilter === modelData.id
          implicitHeight: Style.space(20)
          implicitWidth: catPillText.implicitWidth + Style.space(10)
          radius: 3
          color: isSelected ? root.accent : (catMouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: isSelected ? root.accent : root.outline

          Text {
            textFormat: Text.PlainText;
            id: catPillText
            anchors.centerIn: parent
            text: modelData.label
            color: isSelected ? root.accentForeground : root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
            font.bold: isSelected
          }

          MouseArea {
            id: catMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.currentFilter = modelData.id
          }

          PanelToolTip {
            visible: catMouse.containsMouse
            text: modelData.id === "all" ? "Show all fleet devices" : ("Filter to " + modelData.label.split(" (")[0])
            fontFamily: root.fontFamily
          }
        }
      }
    }
  }

  // Device List
  ColumnLayout {
    Layout.fillWidth: true
    spacing: Style.space(6)

    // Empty or Partial state banner
    Rectangle {
      id: emptyStateRect
      visible: root.filteredDevices().length === 0
      Layout.fillWidth: true
      implicitHeight: Style.space(56)
      radius: 4
      color: root.track
      border.width: 1

      readonly property bool devicesUnavailable: {
        if (!root.partial || !root.failedEndpoints) return false
        for (var i = 0; i < root.failedEndpoints.length; i++) {
          var ep = String(root.failedEndpoints[i])
          if (ep.indexOf("/v1/devices") >= 0 || ep.indexOf("stat/device") >= 0) return true
        }
        return false
      }

      border.color: emptyStateRect.devicesUnavailable ? root.urgent : root.outline

      ColumnLayout {
        anchors.centerIn: parent
        spacing: Style.space(3)

        Text {
          textFormat: Text.PlainText;
          Layout.alignment: Qt.AlignHCenter
          text: emptyStateRect.devicesUnavailable
            ? (root.failedEndpoints && root.failedEndpoints.indexOf("/v1/devices") >= 0 ? "Device inventory unavailable (endpoint /v1/devices error)" : "Device inventory unavailable (endpoint stat/device error)")
            : (root.currentFilter !== "all" ? "No devices matching filter" : "No devices discovered in fleet")
          color: emptyStateRect.devicesUnavailable ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: emptyStateRect.devicesUnavailable
        }

        Text {
          textFormat: Text.PlainText;
          visible: emptyStateRect.devicesUnavailable
          Layout.alignment: Qt.AlignHCenter
          text: "Telemetry is partial. Check UI Account permissions or API key."
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }
      }
    }

    Repeater {
      model: root.filteredDevices()
      delegate: Rectangle {
        id: devCard
        required property var modelData
        required property int index
        readonly property bool isChooserOpen: root.activeChooserIndex === index

        Layout.fillWidth: true
        implicitHeight: devInnerCol.implicitHeight + Style.space(16)
        radius: 4
        color: devCard.isChooserOpen ? root.cardHover : (devCardMouse.containsMouse ? root.cardHover : root.card)
        border.width: 1
        border.color: devCard.isChooserOpen ? root.accent : (devCardMouse.containsMouse ? root.accent : root.outline)

        MouseArea {
          id: devCardMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            root.activeChooserIndex = (root.activeChooserIndex === index) ? -1 : index
          }
        }

        ColumnLayout {
          id: devInnerCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          // Top Row: Status Dot, Device Model & Name, Site Badge
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Rectangle {
              width: Style.space(8)
              height: Style.space(8)
              radius: width / 2
              color: modelData.online ? root.healthy : root.urgent
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText;
              text: modelData.name || modelData.model || "UniFi Device"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
              Layout.maximumWidth: Style.space(165)
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText;
              visible: !!(modelData.model && modelData.name !== modelData.model)
              text: "· " + (modelData.model || "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              elide: Text.ElideRight
              Layout.maximumWidth: Style.space(95)
              Layout.alignment: Qt.AlignVCenter
            }

            Item { Layout.fillWidth: true }

            // Site Badge
            Rectangle {
              visible: !!modelData.site
              height: Style.space(16)
              implicitWidth: Math.min(Style.space(115), siteBadgeText.implicitWidth + Style.space(10))
              radius: 3
              color: root.track
              border.width: 1
              border.color: root.outline
              Layout.alignment: Qt.AlignVCenter
              clip: true

              Text {
                textFormat: Text.PlainText;
                id: siteBadgeText
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Style.space(5)
                anchors.rightMargin: Style.space(5)
                horizontalAlignment: Text.AlignHCenter
                text: modelData.site || ""
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                elide: Text.ElideRight
              }
            }
          }

          // Bottom Row: IP, MAC, Action Buttons
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText;
              text: "IP: " + (modelData.ip || "DHCP") + (modelData.id ? " · MAC: " + modelData.id : "")
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              elide: Text.ElideRight
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
            }

            // 1-Click Action Buttons
            RowLayout {
              spacing: Style.space(4)
              Layout.alignment: Qt.AlignVCenter

              // SSH Button (for Gateways and Switches)
              Rectangle {
                visible: !!modelData.ip && (deviceCategory(modelData) === "gateways" || deviceCategory(modelData) === "switches")
                implicitHeight: Style.space(20)
                implicitWidth: sshBtnRow.implicitWidth + Style.space(12)
                radius: 3
                color: sshMouse.containsMouse ? root.accent : root.track
                border.width: 1
                border.color: root.accent

                RowLayout {
                  id: sshBtnRow
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text { textFormat: Text.PlainText; text: ""; color: sshMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                  Text { textFormat: Text.PlainText; id: sshText; text: "SSH"; color: sshMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                }

                MouseArea {
                  id: sshMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.sshRequested(modelData.ip, "root")
                }

                PanelToolTip {
                  visible: sshMouse.containsMouse
                  text: "Open SSH terminal session (" + modelData.ip + ")"
                  fontFamily: root.fontFamily
                }
              }

              // Ping Button
              Rectangle {
                visible: !!modelData.ip
                implicitHeight: Style.space(20)
                implicitWidth: pingBtnRow.implicitWidth + Style.space(12)
                radius: 3
                color: pingMouse.containsMouse ? root.cardHover : root.track
                border.width: 1
                border.color: root.outline

                RowLayout {
                  id: pingBtnRow
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text { textFormat: Text.PlainText; text: ""; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                  Text { textFormat: Text.PlainText; id: pingText; text: "Ping"; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                }

                MouseArea {
                  id: pingMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.pingRequested(modelData.ip)
                }

                PanelToolTip {
                  visible: pingMouse.containsMouse
                  text: "Send ICMP ping to " + modelData.ip
                  fontFamily: root.fontFamily
                }
              }

              // Web UI Link
              Rectangle {
                visible: !!modelData.ip
                implicitHeight: Style.space(20)
                implicitWidth: webBtnRow.implicitWidth + Style.space(12)
                radius: 3
                color: webMouse.containsMouse ? root.cardHover : root.track
                border.width: 1
                border.color: root.outline

                RowLayout {
                  id: webBtnRow
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text { textFormat: Text.PlainText; text: ""; color: webMouse.containsMouse ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                  Text { textFormat: Text.PlainText; id: webText; text: "Web"; color: webMouse.containsMouse ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                }

                MouseArea {
                  id: webMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.webRequested(modelData.ip)
                }

                PanelToolTip {
                  visible: webMouse.containsMouse
                  text: "Open device web management page (https://" + modelData.ip + ")"
                  fontFamily: root.fontFamily
                }
              }

              // Multi-Protocol Action Chooser Button
              Rectangle {
                id: actionChooserBtn
                implicitHeight: Style.space(20)
                implicitWidth: actionChooserBtnRow.implicitWidth + Style.space(12)
                radius: 3
                color: devCard.isChooserOpen ? root.accent : (chooserMouse.containsMouse ? root.cardHover : root.track)
                border.width: 1
                border.color: devCard.isChooserOpen ? root.accent : root.outline

                RowLayout {
                  id: actionChooserBtnRow
                  anchors.centerIn: parent
                  spacing: Style.space(3)
                  Text {
                    textFormat: Text.PlainText;
                    text: "⚡"
                    color: devCard.isChooserOpen ? root.accentForeground : root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 3
                  }
                  Text {
                    textFormat: Text.PlainText;
                    id: actionChooserText
                    text: "Actions"
                    color: devCard.isChooserOpen ? root.accentForeground : root.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption - 2
                    font.bold: true
                  }
                }

                MouseArea {
                  id: chooserMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.activeChooserIndex = (root.activeChooserIndex === index) ? -1 : index
                  }
                }

                PanelToolTip {
                  visible: chooserMouse.containsMouse
                  text: "Open multi-protocol action chooser (SSH, Ping, Web Console, Direct IP, UniFi OS)"
                  fontFamily: root.fontFamily
                }
              }
            }
          }

          // Expandable Multi-Protocol Action Chooser Popover
          MultiProtocolChooser {
            visible: devCard.isChooserOpen
            Layout.fillWidth: true
            device: modelData
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
            fontFamily: root.fontFamily
            onLaunchSsh: function(ip, user) { root.sshRequested(ip, user) }
            onLaunchPing: function(ip) { root.pingRequested(ip) }
            onOpenWeb: function(url) { root.webRequested(url) }
            onCloseRequested: { root.activeChooserIndex = -1 }
          }
        }
      }
    }
  }
}
