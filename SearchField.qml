import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property alias text: input.text
  property string placeholderText: "Search..."
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color accent: (Color.accent || "#89B4FA")
  property string fontFamily: Style.font.family

  signal cleared()

  Layout.fillWidth: true
  implicitHeight: Style.space(28)
  radius: 4
  color: track
  border.width: 1
  border.color: input.activeFocus ? accent : outline

  RowLayout {
    anchors.fill: parent
    anchors.margins: Style.space(6)
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText
      text: ""
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption - 1
    }

    TextInput {
      id: input
      Layout.fillWidth: true
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption - 1
      selectByMouse: true
      clip: true

      Text {
        textFormat: Text.PlainText
        visible: !parent.text
        text: root.placeholderText
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 1
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: Boolean(input.text)
      text: "✕"
      color: clearMouse.containsMouse ? root.foreground : root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption - 1

      MouseArea {
        id: clearMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          input.text = ""
          root.cleared()
        }
      }
    }
  }
}
