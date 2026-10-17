import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

RowLayout {
  id: root

  property var model: []
  property string selected: ""
  property color foreground: (Color.foreground || "#D8DEE9")
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family
  property int pillHeight: Style.space(26)
  property int fontPixelSize: Style.font.caption - 1
  property int pillRadius: 4

  signal filterSelected(string option)

  spacing: Style.space(4)

  Repeater {
    model: root.model
    delegate: Rectangle {
      required property string modelData
      implicitHeight: root.pillHeight
      implicitWidth: filterItemText.implicitWidth + Style.space(12)
      radius: root.pillRadius
      color: root.selected === modelData ? root.accent : (filterMouse.containsMouse ? root.cardHover : root.track)
      border.width: 1
      border.color: root.selected === modelData ? root.accent : root.outline

      Text {
        id: filterItemText
        anchors.centerIn: parent
        textFormat: Text.PlainText;
        text: modelData
        color: root.selected === modelData ? root.accentForeground : root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.fontPixelSize
        font.bold: root.selected === modelData
      }

      MouseArea {
        id: filterMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.selected = modelData
          root.filterSelected(modelData)
        }
      }
    }
  }
}
