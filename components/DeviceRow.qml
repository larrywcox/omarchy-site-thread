import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root
  property var modelData: ({})
  readonly property var devData: root.modelData || ({})
  property int index: 0
  property string category: ""
  property bool isChooserOpen: false

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
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

  Layout.fillWidth: true
  implicitHeight: devInnerCol.implicitHeight + Style.space(16)
  radius: 4
  color: root.isChooserOpen ? root.cardHover : (devCardMouse.containsMouse ? root.cardHover : root.card)
  border.width: 1
  border.color: root.isChooserOpen ? root.accent : (devCardMouse.containsMouse ? root.accent : root.outline)

  MouseArea {
    id: devCardMouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.isChooserOpen = !root.isChooserOpen
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
        color: root.devData.online ? root.healthy : root.urgent
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText;
        text: root.devData.name || root.devData.model || "UniFi Device"
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
        visible: !!(root.devData.model && root.devData.name !== root.devData.model)
        text: "· " + (root.devData.model || "")
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
        visible: !!root.devData.site
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
          text: root.devData.site || ""
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
        text: "IP: " + (root.devData.ip || "DHCP") + (root.devData.id ? " · MAC: " + root.devData.id : "")
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

        // SSH Button
        Rectangle {
          visible: !!root.devData.ip && (root.category === "gateways" || root.category === "switches")
          implicitHeight: Style.space(20)
          implicitWidth: sshBtnRow.implicitWidth + Style.space(12)
          radius: 3
          color: devSshMouse.containsMouse ? root.accent : root.track
          border.width: 1
          border.color: devSshMouse.containsMouse ? root.accent : root.outline

          RowLayout {
            id: sshBtnRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              textFormat: Text.PlainText;
              text: ""
              color: devSshMouse.containsMouse ? "#ffffff" : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 3
            }

            Text {
              textFormat: Text.PlainText;
              text: "SSH"
              color: devSshMouse.containsMouse ? "#ffffff" : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
            }
          }

          MouseArea {
            id: devSshMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.sshRequested(root.devData.ip, "root")
          }

          PanelToolTip {
            visible: devSshMouse.containsMouse
            text: "Open SSH terminal to " + (root.devData.name || root.devData.ip)
            fontFamily: root.fontFamily
          }
        }

        // Ping Button
        Rectangle {
          visible: !!root.devData.ip
          implicitHeight: Style.space(20)
          implicitWidth: pingBtnRow.implicitWidth + Style.space(12)
          radius: 3
          color: devPingMouse.containsMouse ? root.accent : root.track
          border.width: 1
          border.color: devPingMouse.containsMouse ? root.accent : root.outline

          RowLayout {
            id: pingBtnRow
            anchors.centerIn: parent
            spacing: Style.space(4)

            Text {
              textFormat: Text.PlainText;
              text: ""
              color: devPingMouse.containsMouse ? "#ffffff" : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 3
            }

            Text {
              textFormat: Text.PlainText;
              text: "Ping"
              color: devPingMouse.containsMouse ? "#ffffff" : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
            }
          }

          MouseArea {
            id: devPingMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pingRequested(root.devData.ip)
          }

          PanelToolTip {
            visible: devPingMouse.containsMouse
            text: "Ping " + root.devData.ip + " in floating terminal"
            fontFamily: root.fontFamily
          }
        }

        // Web GUI Button
        Rectangle {
          visible: !!root.devData.ip && root.category === "gateways"
          implicitHeight: Style.space(20)
          implicitWidth: Style.space(24)
          radius: 3
          color: devWebMouse.containsMouse ? root.accent : root.track
          border.width: 1
          border.color: devWebMouse.containsMouse ? root.accent : root.outline

          Text {
            textFormat: Text.PlainText;
            anchors.centerIn: parent
            text: ""
            color: devWebMouse.containsMouse ? "#ffffff" : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
          }

          MouseArea {
            id: devWebMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.webRequested(root.devData.ip)
          }

          PanelToolTip {
            visible: devWebMouse.containsMouse
            text: "Open Web UI (https://" + root.devData.ip + ")"
            fontFamily: root.fontFamily
          }
        }

        // Multi-Protocol Action Chooser Button
        Rectangle {
          id: actionChooserBtn
          implicitHeight: Style.space(20)
          implicitWidth: actionChooserBtnRow.implicitWidth + Style.space(12)
          radius: 3
          color: root.isChooserOpen ? root.accent : (chooserMouse.containsMouse ? root.cardHover : root.track)
          border.width: 1
          border.color: root.isChooserOpen ? root.accent : root.outline

          RowLayout {
            id: actionChooserBtnRow
            anchors.centerIn: parent
            spacing: Style.space(3)
            Text {
              textFormat: Text.PlainText;
              text: "⚡"
              color: root.isChooserOpen ? "#ffffff" : root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 3
            }
            Text {
              textFormat: Text.PlainText;
              id: actionChooserText
              text: "Actions"
              color: root.isChooserOpen ? "#ffffff" : root.accent
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
            onClicked: root.isChooserOpen = !root.isChooserOpen
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
      visible: root.isChooserOpen
      Layout.fillWidth: true
      device: root.devData
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
      onCloseRequested: { root.isChooserOpen = false }
    }
  }
}

