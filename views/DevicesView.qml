import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import ".."
import "../components"

Item {
  id: root
  implicitHeight: devInventory.implicitHeight
  implicitWidth: parent ? parent.width : 300

  property var devices: []
  property string currentFilter: "all"
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

  DeviceInventoryView {
    id: devInventory
    anchors.fill: parent
    devices: root.devices
    currentFilter: root.currentFilter
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
    onSshRequested: function(ip, user) { root.sshRequested(ip, user) }
    onPingRequested: function(ip) { root.pingRequested(ip) }
    onWebRequested: function(ip) {
      if (ip) Quickshell.execDetached(["xdg-open", "https://" + ip])
      root.webRequested(ip)
    }
  }
}
