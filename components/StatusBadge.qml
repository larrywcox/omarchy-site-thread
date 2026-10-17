import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string text: ""
  property color badgeColor: (Color.accent || "#89B4FA")
  property color textColor: badgeColor
  property int badgeRadius: 3
  property int fontPixelSize: Style.font.caption - 2
  property bool bold: true
  property string fontFamily: Style.font.family
  property int horizontalPadding: Style.space(8)
  property int verticalPadding: Style.space(2)

  radius: root.badgeRadius
  implicitHeight: badgeLabel.implicitHeight + root.verticalPadding * 2
  implicitWidth: badgeLabel.implicitWidth + root.horizontalPadding * 2
  color: Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.18)
  border.width: 1
  border.color: root.badgeColor

  Text {
    id: badgeLabel
    anchors.centerIn: parent
    textFormat: Text.PlainText;
    text: root.text
    color: root.textColor
    font.family: root.fontFamily
    font.pixelSize: root.fontPixelSize
    font.bold: root.bold
  }
}
