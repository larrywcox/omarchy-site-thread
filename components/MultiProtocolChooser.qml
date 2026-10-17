import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "../Model.js" as Model

BorderSurface {
  id: root

  property var device: null
  property var consoleObj: null
  property bool isOpen: false
  property string preferredTerminal: "xdg-terminal-exec"

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
  property color backup: "#F59E0B"
  property string fontFamily: Style.font.family

  signal actionTriggered(string protocolId, string label, string target)
  signal launchSsh(string ip, string user)
  signal launchPing(string ip)
  signal openWeb(string url)
  signal copyIp(string ip)
  signal openDirectConnect(var consoleObj)
  signal closeRequested()

  property string feedbackNotice: ""

  Timer {
    id: feedbackTimer
    interval: 2200
    repeat: false
    onTriggered: root.feedbackNotice = ""
  }

  function deviceName() {
    if (!root.device) return "UniFi Device"
    return root.device.name || root.device.model || "UniFi Device"
  }

  function deviceIp() {
    if (!root.device) return ""
    return root.device.ip || root.device.ipAddress || root.device.lanIp || root.device.gatewayIp || ""
  }

  function deviceMac() {
    if (!root.device) return ""
    return root.device.mac || root.device.id || ""
  }

  function isGatewayDevice() {
    if (!root.device) return false
    var m = String(root.device.model || "").toLowerCase()
    var n = String(root.device.name || "").toLowerCase()
    return m.indexOf("ucg") >= 0 || m.indexOf("udm") >= 0 || m.indexOf("uxg") >= 0 || m.indexOf("gateway") >= 0 || n.indexOf("gateway") >= 0
  }

  function isSwitchDevice() {
    if (!root.device) return false
    var m = String(root.device.model || "").toLowerCase()
    return m.indexOf("usw") >= 0 || m.indexOf("switch") >= 0
  }

  function getProtocols() {
    var d = root.device
    if (!d) return []
    var ip = deviceIp()
    var mac = deviceMac()
    var isGw = isGatewayDevice()
    var isSw = isSwitchDevice()
    var cObj = root.consoleObj

    var list = []

    // 1. SSH Protocol
    if (ip) {
      list.push({
        id: "ssh",
        name: "SSH Terminal Shell",
        protocol: "SSH",
        badge: "PORT 22",
        detail: "root@" + ip,
        icon: "",
        badgeColor: root.accent,
        badgeBg: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.18),
        tooltip: "Launch terminal SSH session to root@" + ip
      })
    }

    // 2. ICMP Ping Protocol
    if (ip) {
      list.push({
        id: "ping",
        name: "ICMP Ping Latency",
        protocol: "ICMP",
        badge: "ECHO",
        detail: "Continuous round-trip ping test",
        icon: "",
        badgeColor: root.healthy,
        badgeBg: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.18),
        tooltip: "Send continuous ICMP ping packets to " + ip
      })
    }

    // 3. Web Management Console (HTTPS)
    if (ip) {
      list.push({
        id: "web",
        name: "Web Management UI",
        protocol: "HTTPS",
        badge: "PORT 443",
        detail: "https://" + ip,
        icon: "",
        badgeColor: root.backup,
        badgeBg: Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18),
        tooltip: "Open local device web management interface in browser"
      })
    }

    // 4. Direct LAN IP & MAC
    if (ip) {
      list.push({
        id: "direct_ip",
        name: "Direct Interface IP",
        protocol: "IPv4",
        badge: "DIRECT",
        detail: ip + (mac ? (" · " + mac) : ""),
        icon: "󰈀",
        badgeColor: "#10B981",
        badgeBg: Qt.rgba(0.06, 0.72, 0.51, 0.18),
        tooltip: "Copy direct IP address (" + ip + ") to clipboard"
      })
    }

    // 5. UniFi OS / Cloud Console / Direct Connect
    if (isGw || cObj || Boolean(d.hostId) || Boolean(d.site)) {
      var directDomain = cObj ? (cObj.directConnectDomain || "") : ""
      var hasDirect = Boolean(cObj && (cObj.directConnectUrl || directDomain))
      list.push({
        id: "unifi_os",
        name: hasDirect ? "UniFi OS Direct P2P" : "UniFi OS Console",
        protocol: hasDirect ? "P2P" : "Cloud",
        badge: hasDirect ? "P2P CONNECT" : "UNIFI OS",
        detail: hasDirect ? ("Direct tunnel: " + directDomain) : "UniFi OS application hub & Site Manager",
        icon: "",
        badgeColor: "#CBA6F7",
        badgeBg: Qt.rgba(0.8, 0.65, 0.97, 0.18),
        tooltip: hasDirect ? "Direct P2P encrypted connect to UniFi OS console" : "Open UniFi OS applications hub"
      })
    }

    return list
  }

  function executeProtocol(proto) {
    if (!proto || !proto.id) return
    var ip = deviceIp()

    if (proto.id === "ssh") {
      root.launchSsh(ip, "root")
      root.actionTriggered("ssh", proto.name, ip)
      root.feedbackNotice = "Launched SSH to " + ip
      feedbackTimer.restart()
    } else if (proto.id === "ping") {
      root.launchPing(ip)
      root.actionTriggered("ping", proto.name, ip)
      root.feedbackNotice = "Started ping to " + ip
      feedbackTimer.restart()
    } else if (proto.id === "web") {
      var webUrl = "https://" + ip
      Quickshell.execDetached(["xdg-open", webUrl])
      root.openWeb(webUrl)
      root.actionTriggered("web", proto.name, webUrl)
      root.feedbackNotice = "Opened " + webUrl
      feedbackTimer.restart()
    } else if (proto.id === "direct_ip") {
      Quickshell.execDetached(["wl-copy", ip])
      root.copyIp(ip)
      root.actionTriggered("direct_ip", proto.name, ip)
      root.feedbackNotice = "Copied " + ip + " to clipboard!"
      feedbackTimer.restart()
    } else if (proto.id === "unifi_os") {
      var cObj = root.consoleObj
      var target = ""
      if (cObj && cObj.directConnectUrl) target = cObj.directConnectUrl
      else if (cObj && cObj.directConnectDomain) target = "https://" + cObj.directConnectDomain
      else if (root.device && root.device.hostId) target = "https://unifi.ui.com/consoles/" + root.device.hostId
      else target = "https://unifi.ui.com"
      Quickshell.execDetached(["xdg-open", target])
      if (cObj) root.openDirectConnect(cObj)
      root.actionTriggered("unifi_os", proto.name, target)
      root.feedbackNotice = "Connected to UniFi OS"
      feedbackTimer.restart()
    }
  }

  color: root.card
  radius: Style.cornerRadius
  borderSpec: Border.flat(root.accent, 1)
  implicitHeight: chooserCol.implicitHeight + Style.space(16)
  height: implicitHeight

  ColumnLayout {
    id: chooserCol
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: Style.space(8)
    spacing: Style.space(6)

    // Header strip
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: width / 2
        color: (root.device && root.device.online !== false) ? root.healthy : root.urgent
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(4)
          Text {
            textFormat: Text.PlainText;
            text: root.deviceName()
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
            elide: Text.ElideRight
            Layout.maximumWidth: Style.space(180)
          }
          Text {
            textFormat: Text.PlainText;
            visible: !!(root.device && root.device.model && root.device.name !== root.device.model)
            text: "(" + (root.device ? root.device.model : "") + ")"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: 8
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        Text {
          textFormat: Text.PlainText;
          text: root.feedbackNotice !== "" ? root.feedbackNotice : "MULTI-PROTOCOL ACTION CHOOSER"
          color: root.feedbackNotice !== "" ? root.healthy : root.accent
          font.family: root.fontFamily
          font.pixelSize: 8
          font.bold: true
        }
      }

      // Close button
      Rectangle {
        implicitWidth: Style.space(18)
        implicitHeight: Style.space(18)
        radius: 3
        color: closeMouse.containsMouse ? root.cardHover : root.track
        border.width: 1
        border.color: closeMouse.containsMouse ? root.urgent : root.outline
        Layout.alignment: Qt.AlignVCenter

        Text {
          textFormat: Text.PlainText;
          anchors.centerIn: parent
          text: "✕"
          color: closeMouse.containsMouse ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 3
          font.bold: true
        }

        MouseArea {
          id: closeMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.closeRequested()
        }

        PanelToolTip {
          visible: closeMouse.containsMouse
          text: "Dismiss action chooser"
          fontFamily: root.fontFamily
        }
      }
    }

    // Protocol list
    Repeater {
      model: root.getProtocols()
      delegate: Rectangle {
        required property var modelData
        required property int index

        Layout.fillWidth: true
        implicitHeight: protoRow.implicitHeight + Style.space(8)
        radius: 3
        color: protoMouse.containsMouse ? root.cardHover : root.track
        border.width: 1
        border.color: protoMouse.containsMouse ? modelData.badgeColor : root.outline

        MouseArea {
          id: protoMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.executeProtocol(modelData)
        }

        RowLayout {
          id: protoRow
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.margins: Style.space(6)
          spacing: Style.space(6)

          // Protocol Badge tag
          Rectangle {
            implicitWidth: protoTagText.implicitWidth + Style.space(8)
            implicitHeight: Style.space(16)
            radius: 2
            color: modelData.badgeBg
            border.width: 1
            border.color: modelData.badgeColor
            Layout.alignment: Qt.AlignVCenter

            Text {
              textFormat: Text.PlainText;
              id: protoTagText
              anchors.centerIn: parent
              text: modelData.badge
              color: modelData.badgeColor
              font.family: root.fontFamily
              font.pixelSize: 7
              font.bold: true
            }
          }

          // Protocol icon & name
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            Layout.alignment: Qt.AlignVCenter

            Text {
              textFormat: Text.PlainText;
              text: modelData.name
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }

            Text {
              textFormat: Text.PlainText;
              text: modelData.detail
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: 8
              elide: Text.ElideRight
            }
          }

          // Action trigger button
          Rectangle {
            implicitWidth: triggerRow.implicitWidth + Style.space(10)
            implicitHeight: Style.space(18)
            radius: 3
            color: protoMouse.containsMouse ? modelData.badgeColor : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.08)
            border.width: 1
            border.color: modelData.badgeColor
            Layout.alignment: Qt.AlignVCenter

            RowLayout {
              id: triggerRow
              anchors.centerIn: parent
              spacing: Style.space(3)

              Text {
                textFormat: Text.PlainText;
                text: modelData.icon
                color: protoMouse.containsMouse ? "#ffffff" : modelData.badgeColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 3
              }

              Text {
                textFormat: Text.PlainText;
                text: modelData.protocol
                color: protoMouse.containsMouse ? "#ffffff" : modelData.badgeColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 3
                font.bold: true
              }
            }
          }
        }

        PanelToolTip {
          visible: protoMouse.containsMouse
          text: modelData.tooltip
          fontFamily: root.fontFamily
        }
      }
    }
  }
}
