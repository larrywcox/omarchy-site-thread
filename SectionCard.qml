import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

BorderSurface {
  id: root

  property string title: ""
  property string subtitle: ""
  property color subtitleColor: (Color.dim || Qt.darker(titleColor, 1.35))
  property string iconText: ""
  property color titleColor: (Color.foreground || "#D8DEE9")
  property string badgeText: ""
  property color badgeColor: (Color.accent || "#89B4FA")
  property color badgeTextColor: badgeColor
  property Component headerAccessory: null
  property string fontFamily: Style.font.family
  property color cardColor: Qt.rgba(titleColor.r, titleColor.g, titleColor.b, 0.05)
  property color outlineColor: Qt.rgba(titleColor.r, titleColor.g, titleColor.b, 0.15)
  default property alias content: body.data

  Layout.fillWidth: true
  Layout.minimumWidth: 0
  width: parent ? parent.width : implicitWidth
  color: cardColor
  borderSpec: Border.flat(outlineColor, 1)
  padding: Style.space(8)
  radius: Style.cornerRadius
  implicitHeight: body.implicitHeight + contentTopInset + contentBottomInset
  clip: true

  ColumnLayout {
    id: body
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.bottom: root.Layout.fillHeight ? parent.bottom : undefined
    anchors.topMargin: root.contentTopInset
    anchors.rightMargin: root.contentRightInset
    anchors.bottomMargin: root.contentBottomInset
    anchors.leftMargin: root.contentLeftInset
    spacing: Style.space(6)

    RowLayout {
      visible: root.title !== "" || root.headerAccessory !== null || root.iconText !== "" || root.badgeText !== ""
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText;
        visible: root.iconText !== ""
        text: root.iconText
        color: root.titleColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      Text {
        textFormat: Text.PlainText;
        visible: root.title !== ""
        Layout.fillWidth: true
        text: root.title
        color: root.titleColor
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Rectangle {
        visible: root.badgeText !== ""
        radius: 3
        color: Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.15)
        border.color: Qt.rgba(root.badgeColor.r, root.badgeColor.g, root.badgeColor.b, 0.35)
        border.width: 1
        implicitHeight: Style.space(16)
        implicitWidth: badgeLabel.implicitWidth + Style.space(8)
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight

        Text {
          textFormat: Text.PlainText;
          id: badgeLabel
          anchors.centerIn: parent
          text: root.badgeText
          color: root.badgeTextColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
          font.bold: true
        }
      }

      Loader {
        sourceComponent: root.headerAccessory
        visible: !!root.headerAccessory
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
      }
    }

    Text {
      textFormat: Text.PlainText;
      visible: root.subtitle !== ""
      Layout.fillWidth: true
      text: root.subtitle
      color: root.subtitleColor
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption - 2
      wrapMode: Text.WordWrap
      elide: Text.ElideRight
    }
  }
}
