import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string message: ""
  property string toastType: "info"
  property color foreground: (Color.foreground || "#D8DEE9")
  property color accent: (Color.accent || "#89B4FA")
  property color healthy: "#10B981"
  property color urgent: (Color.urgent || "#FF4D5A")
  property string fontFamily: Style.font.family

  Layout.fillWidth: true
  visible: root.message !== ""
  height: root.message !== "" ? Style.space(30) : 0
  radius: 6
  color: root.toastType === "error" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.22) : (root.toastType === "success" ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.22) : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.22))
  border.width: 1
  border.color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)

  RowLayout {
    anchors.centerIn: parent
    spacing: Style.space(8)

    Text {
      textFormat: Text.PlainText
      text: root.toastType === "error" ? "" : (root.toastType === "success" ? "" : "")
      color: root.toastType === "error" ? root.urgent : (root.toastType === "success" ? root.healthy : root.accent)
      font.family: root.fontFamily
      font.pixelSize: 11
    }

    Text {
      id: toastText
      textFormat: Text.PlainText
      text: root.message
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption - 1
      font.bold: true
    }
  }
}
