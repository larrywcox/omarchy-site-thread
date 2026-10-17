import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."
import "../Model.js" as Model

BorderSurface {
  id: siteCardSurface
  required property var modelData
  readonly property var rowData: (siteCardSurface.modelData && typeof siteCardSurface.modelData === "object") ? siteCardSurface.modelData : ({})
  property bool cloudMode: false
  property var siteConsole: null
  property bool isChooserOpen: false
  property string timeRange: "24 hours"

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property color backup: "#f59e0b"
  property string fontFamily: Style.font.family

  signal siteClicked(var site)
  signal launchSshRequested(string ip, string user)
  signal launchPingRequested(string ip)
  signal directConnectRequested(var consoleObj)

  implicitHeight: siteCardCol.implicitHeight + Style.space(18)
  height: implicitHeight
  color: siteCardMouse.containsMouse ? siteCardSurface.cardHover : siteCardSurface.card
  radius: Style.cornerRadius
  borderSpec: Border.flat(siteCardMouse.containsMouse ? siteCardSurface.accent : siteCardSurface.outline, 1)

  MouseArea {
    id: siteCardMouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: siteCardSurface.cloudMode
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: siteCardSurface.siteClicked(siteCardSurface.rowData)
  }

  ColumnLayout {
    id: siteCardCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(8)
    spacing: Style.space(4)

    // Row 1: Status Dot + Site Name + Gateway Badge + Status Pill
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: siteCardSurface.cloudMode
          ? Model.siteColor(siteCardSurface.rowData.status, siteCardSurface.healthy, siteCardSurface.backup, siteCardSurface.urgent)
          : (siteCardSurface.rowData.online ? siteCardSurface.healthy : siteCardSurface.urgent)
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText;
        text: Model.safe(siteCardSurface.rowData.name, "UniFi Site")
        color: siteCardSurface.foreground
        font.family: siteCardSurface.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      Rectangle {
        visible: siteCardSurface.cloudMode && siteCardSurface.rowData.gatewayModel !== undefined && siteCardSurface.rowData.gatewayModel !== ""
        radius: 3
        implicitHeight: Style.space(16)
        implicitWidth: gwBadgeText.implicitWidth + Style.space(8)
        color: siteCardSurface.track
        border.width: 1
        border.color: siteCardSurface.outline
        Layout.alignment: Qt.AlignVCenter
        Text {
          textFormat: Text.PlainText;
          id: gwBadgeText
          anchors.centerIn: parent
          text: Model.safe(siteCardSurface.rowData.gatewayModel)
          color: siteCardSurface.foreground
          font.family: siteCardSurface.fontFamily
          font.pixelSize: Style.font.caption - 2
        }
      }

      Rectangle {
        radius: 3
        implicitHeight: Style.space(16)
        implicitWidth: siteStatusLabel.implicitWidth + Style.space(8)
        color: siteCardSurface.cloudMode
          ? (siteCardSurface.rowData.status === "down" ? Qt.rgba(siteCardSurface.urgent.r, siteCardSurface.urgent.g, siteCardSurface.urgent.b, 0.18) : (siteCardSurface.rowData.status === "backup" ? Qt.rgba(siteCardSurface.backup.r, siteCardSurface.backup.g, siteCardSurface.backup.b, 0.18) : Qt.rgba(siteCardSurface.healthy.r, siteCardSurface.healthy.g, siteCardSurface.healthy.b, 0.18)))
          : (siteCardSurface.rowData.online ? siteCardSurface.track : Qt.rgba(siteCardSurface.urgent.r, siteCardSurface.urgent.g, siteCardSurface.urgent.b, 0.18))
        border.width: 1
        border.color: siteCardSurface.cloudMode
          ? Model.siteColor(siteCardSurface.rowData.status, siteCardSurface.healthy, siteCardSurface.backup, siteCardSurface.urgent)
          : (siteCardSurface.rowData.online ? siteCardSurface.outline : siteCardSurface.urgent)
        Layout.alignment: Qt.AlignVCenter
        Text {
          textFormat: Text.PlainText;
          id: siteStatusLabel
          anchors.centerIn: parent
          text: siteCardSurface.cloudMode
            ? String(siteCardSurface.rowData.statusText || "Online").toUpperCase()
            : (siteCardSurface.rowData.online ? "ONLINE" : "OFFLINE")
          color: siteCardSurface.cloudMode
            ? Model.siteColor(siteCardSurface.rowData.status, siteCardSurface.healthy, siteCardSurface.backup, siteCardSurface.urgent)
            : (siteCardSurface.rowData.online ? siteCardSurface.dim : siteCardSurface.urgent)
          font.family: siteCardSurface.fontFamily
          font.pixelSize: Style.font.caption - 2
          font.bold: true
        }
      }
    }

    // Row 2: Telemetry Details + Action Buttons (Direct, SSH, Ping)
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText;
        text: siteCardSurface.cloudMode
          ? (String(siteCardSurface.rowData.deviceCount || 0) + " dev · " + String(siteCardSurface.rowData.clientCount || 0) + " cli ( " + (siteCardSurface.rowData.wifiClients || 0) + " / \uf0e8 " + (siteCardSurface.rowData.wiredClients || 0) + ")" + (siteCardSurface.rowData.isp ? " · " + Model.safe(siteCardSurface.rowData.isp) : "") + " · WAN " + (Number(siteCardSurface.rowData.wanUptime || 100) >= 99.95 ? "100" : Number(siteCardSurface.rowData.wanUptime || 100).toFixed(1)) + "%")
          : (Model.safe(siteCardSurface.rowData.model, "") + (siteCardSurface.rowData.ip ? " · " + Model.safe(siteCardSurface.rowData.ip) : ""))
        color: siteCardSurface.dim
        font.family: siteCardSurface.fontFamily
        font.pixelSize: Style.font.caption - 2
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }

      // Action buttons cluster
      RowLayout {
        spacing: Style.space(4)
        Layout.alignment: Qt.AlignVCenter

        // Direct Connect Launch button
        Rectangle {
          property var sc: siteCardSurface.siteConsole
          visible: siteCardSurface.cloudMode && sc !== null && Boolean(sc.directConnectUrl || sc.directConnectDomain)
          implicitWidth: Style.space(20)
          implicitHeight: Style.space(20)
          radius: 3
          color: directSiteMouse.containsMouse ? siteCardSurface.accent : Qt.rgba(siteCardSurface.accent.r, siteCardSurface.accent.g, siteCardSurface.accent.b, 0.18)
          border.width: 1
          border.color: siteCardSurface.accent
          Text {
            textFormat: Text.PlainText;
            anchors.centerIn: parent
            text: ""
            color: directSiteMouse.containsMouse ? siteCardSurface.accentForeground : siteCardSurface.accent
            font.family: siteCardSurface.fontFamily
            font.pixelSize: Style.font.caption - 2
          }
          MouseArea {
            id: directSiteMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var target = sc ? (sc.directConnectUrl || ("https://" + sc.directConnectDomain)) : ""
              if (target) Quickshell.execDetached(["xdg-open", target])
              siteCardSurface.directConnectRequested(sc)
            }
          }

          PanelToolTip {
            visible: directSiteMouse.containsMouse
            text: "Direct P2P connect to UniFi OS console"
            fontFamily: siteCardSurface.fontFamily
          }
        }

        // SSH to Gateway Action Button
        Rectangle {
          visible: siteCardSurface.cloudMode && siteCardSurface.rowData.gatewayIp !== undefined && siteCardSurface.rowData.gatewayIp !== ""
          implicitWidth: sshBtnText.implicitWidth + Style.space(14)
          implicitHeight: Style.space(20)
          radius: 3
          color: sshMouse.containsMouse ? siteCardSurface.accent : siteCardSurface.track
          border.width: 1
          border.color: sshMouse.containsMouse ? siteCardSurface.accent : siteCardSurface.outline
          Text {
            textFormat: Text.PlainText;
            id: sshBtnText
            anchors.centerIn: parent
            text: "SSH"
            color: sshMouse.containsMouse ? siteCardSurface.accentForeground : siteCardSurface.accent
            font.family: siteCardSurface.fontFamily
            font.pixelSize: Style.font.caption - 2
            font.bold: true
          }
          MouseArea {
            id: sshMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: siteCardSurface.launchSshRequested(siteCardSurface.rowData.gatewayIp, "root")
          }

          PanelToolTip {
            visible: sshMouse.containsMouse
            text: "Open SSH terminal to gateway (" + siteCardSurface.modelData.gatewayIp + ")"
            fontFamily: siteCardSurface.fontFamily
          }
        }

        // Ping Gateway Action Button
        Rectangle {
          visible: siteCardSurface.cloudMode && siteCardSurface.rowData.gatewayIp !== undefined && siteCardSurface.rowData.gatewayIp !== ""
          implicitWidth: pingBtnText.implicitWidth + Style.space(14)
          implicitHeight: Style.space(20)
          radius: 3
          color: pingMouse.containsMouse ? siteCardSurface.cardHover : siteCardSurface.track
          border.width: 1
          border.color: pingMouse.containsMouse ? siteCardSurface.accent : siteCardSurface.outline
          Text {
            textFormat: Text.PlainText;
            id: pingBtnText
            anchors.centerIn: parent
            text: "Ping"
            color: pingMouse.containsMouse ? siteCardSurface.foreground : siteCardSurface.dim
            font.family: siteCardSurface.fontFamily
            font.pixelSize: Style.font.caption - 2
            font.bold: true
          }
          MouseArea {
            id: pingMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: siteCardSurface.launchPingRequested(siteCardSurface.rowData.gatewayIp)
          }

          PanelToolTip {
            visible: pingMouse.containsMouse
            text: "Ping gateway (" + siteCardSurface.modelData.gatewayIp + ")"
            fontFamily: siteCardSurface.fontFamily
          }
        }

        // Multi-Protocol Action Chooser Button
        Rectangle {
          id: actionChooserBtn
          visible: siteCardSurface.cloudMode && siteCardSurface.rowData.gatewayIp !== undefined && siteCardSurface.rowData.gatewayIp !== ""
          implicitWidth: Style.space(22)
          implicitHeight: Style.space(20)
          radius: 3
          color: siteCardSurface.isChooserOpen ? siteCardSurface.accent : (siteChooserMouse.containsMouse ? siteCardSurface.cardHover : siteCardSurface.track)
          border.width: 1
          border.color: siteCardSurface.isChooserOpen ? siteCardSurface.accent : siteCardSurface.outline

          Text {
            textFormat: Text.PlainText;
            anchors.centerIn: parent
            text: "⚡"
            color: siteCardSurface.isChooserOpen ? siteCardSurface.accentForeground : siteCardSurface.accent
            font.family: siteCardSurface.fontFamily
            font.pixelSize: Style.font.caption - 2
          }

          MouseArea {
            id: siteChooserMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              siteCardSurface.isChooserOpen = !siteCardSurface.isChooserOpen
            }
          }

          PanelToolTip {
            visible: siteChooserMouse.containsMouse
            text: "Open multi-protocol action chooser for " + (siteCardSurface.rowData.name || "gateway")
            fontFamily: siteCardSurface.fontFamily
          }
        }
      }
    }

    // Expandable Multi-Protocol Action Chooser
    MultiProtocolChooser {
      visible: siteCardSurface.isChooserOpen
      Layout.fillWidth: true
      device: ({
        name: (siteCardSurface.rowData.name || "Site") + " Gateway",
        model: siteCardSurface.rowData.gatewayModel || "Gateway",
        ip: siteCardSurface.rowData.gatewayIp,
        hostId: siteCardSurface.rowData.hostId,
        site: siteCardSurface.rowData.name,
        online: siteCardSurface.rowData.status !== "down"
      })
      consoleObj: siteCardSurface.siteConsole
      foreground: siteCardSurface.foreground
      dim: siteCardSurface.dim
      accent: siteCardSurface.accent
      card: siteCardSurface.card
      cardHover: siteCardSurface.cardHover
      track: siteCardSurface.track
      outline: siteCardSurface.outline
      urgent: siteCardSurface.urgent
      healthy: siteCardSurface.healthy
      fontFamily: siteCardSurface.fontFamily
      onLaunchSsh: function(ip, user) { siteCardSurface.launchSshRequested(ip, user) }
      onLaunchPing: function(ip) { siteCardSurface.launchPingRequested(ip) }
      onOpenDirectConnect: function(c) { siteCardSurface.directConnectRequested(c) }
      onCloseRequested: { siteCardSurface.isChooserOpen = false }
    }

    // Row 3: 24-Hour WAN Sparkline (matching Overview tab, filtered for this site)
    WanSparkline {
      id: siteWanSparkline
      visible: siteCardSurface.cloudMode && siteCardSurface.rowData.status !== undefined
      site: siteCardSurface.rowData
      throughputData: siteCardSurface.rowData ? Model.getSiteThroughput24h(siteCardSurface.rowData) : null
      compact: false
      interactive: true
      range: siteCardSurface.timeRange // range: "24h"
      onRangeSelected: function(r) { siteCardSurface.timeRange = r }
      downloadColor: siteCardSurface.accent
      uploadColor: siteCardSurface.healthy
      foreground: siteCardSurface.foreground
      dim: siteCardSurface.dim
      outline: siteCardSurface.outline
      fontFamily: siteCardSurface.fontFamily
      Layout.fillWidth: true
      Layout.topMargin: Style.space(4)
      implicitHeight: Style.space(100)
    }
  }
}
