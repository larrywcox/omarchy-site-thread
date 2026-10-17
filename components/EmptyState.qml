import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string iconText: ""
  property color iconColor: "#10b981"
  property string title: ""
  property string subtitle: ""
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family
  property int iconPixelSize: Style.font.body
  property int titlePixelSize: Style.font.caption
  property int subtitlePixelSize: Style.font.caption - 1
  property bool showBorder: true

  Layout.fillWidth: true
  implicitHeight: emptyCol.implicitHeight + Style.space(24)
  radius: 6
  color: root.card
  border.width: root.showBorder ? 1 : 0
  border.color: root.outline

  ColumnLayout {
    id: emptyCol
    anchors.centerIn: parent
    spacing: Style.space(6)

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.space(8)

      Text {
        visible: root.iconText !== ""
        textFormat: Text.PlainText;
        text: root.iconText
        color: root.iconColor
        font.family: root.fontFamily
        font.pixelSize: root.iconPixelSize
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        visible: root.title !== ""
        textFormat: Text.PlainText;
        text: root.title
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.titlePixelSize
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
      }
    }

    Text {
      visible: root.subtitle !== ""
      textFormat: Text.PlainText;
      text: root.subtitle
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: root.subtitlePixelSize
      Layout.alignment: Qt.AlignHCenter
      wrapMode: Text.WordWrap
    }
  }
}
