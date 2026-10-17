import QtQuick
import QtQuick.Layouts
import qs.Commons

Rectangle {
  id: root

  property string label: ""
  property string value: ""
  property string subvalue: ""
  property string iconText: ""
  property color valColor: (Color.foreground || "#D8DEE9")
  property color subColor: (Color.dim || Qt.darker(valColor, 1.35))
  property color trackColor: Qt.rgba(valColor.r, valColor.g, valColor.b, 0.08)
  property string fontFamily: Style.font.family
  property bool isHighlighted: false

  Layout.fillWidth: true
  Layout.preferredWidth: 1
  Layout.minimumWidth: 0
  implicitHeight: Style.space(46)
  radius: 4
  color: isHighlighted ? Qt.rgba(valColor.r, valColor.g, valColor.b, 0.15) : trackColor
  border.width: isHighlighted ? 1 : 0
  border.color: valColor
  clip: true

  Behavior on color { ColorAnimation { duration: 120 } }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(2)
    spacing: 0

    Text {
      textFormat: Text.PlainText;
      visible: root.label !== "" && root.subvalue !== ""
      text: root.label
      color: (Color.dim || "#888888")
      font.family: root.fontFamily
      font.pixelSize: 7
      font.bold: true
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: Style.space(3)

      Text {
        textFormat: Text.PlainText;
        visible: root.iconText !== ""
        text: root.iconText
        color: root.valColor
        font.family: root.fontFamily
        font.pixelSize: 9
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText;
        text: root.value
        color: root.valColor
        font.family: root.fontFamily
        font.pixelSize: 13
        font.bold: true
        elide: Text.ElideRight
        Layout.alignment: Qt.AlignVCenter
      }
    }

    Text {
      textFormat: Text.PlainText;
      text: root.subvalue !== "" ? root.subvalue : root.label
      color: root.subvalue !== "" ? root.subColor : (Color.dim || "#888888")
      font.family: root.fontFamily
      font.pixelSize: 8
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }
}
