import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import ".."
import "../components"
import "../Model.js" as Model

Column {
  id: root

  property var issuesList: []
  property int activeIssuesCount: 0
  property string issueFilter: "all"

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color accentForeground: "#ffffff"
  property color urgent: (Color.urgent || "#FF4D5A")
  property color urgentForeground: "#ffffff"
  property color backup: "#f59e0b"
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property string fontFamily: Style.font.family

  signal clearHistoryRequested()
  function clearHistory() {
    clearHistoryRequested()
  }

  function contrastTextFor(c) {
    if (!c) return "#ffffff"
    var lum = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
    return lum > 0.55 ? "#11111b" : "#ffffff"
  }

            spacing: Style.space(8)

            // Header & Filter bar
            RowLayout {
              width: root.width
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText;
                text: "FLEET ISSUES"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                Layout.fillWidth: true
              }

              // Filter buttons & Clear button
              RowLayout {
                spacing: Style.space(3)
                Layout.alignment: Qt.AlignRight

                Rectangle {
                  implicitWidth: allFilterText.implicitWidth + Style.space(8)
                  implicitHeight: Style.space(20)
                  radius: 3
                  color: root.issueFilter === "all" ? root.accent : root.track
                  Text { textFormat: Text.PlainText; id: allFilterText; anchors.centerIn: parent; text: "All (" + root.issuesList.length + ")"; color: root.issueFilter === "all" ? root.accentForeground : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: root.issueFilter === "all" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.issueFilter = "all" }
                }

                Rectangle {
                  implicitWidth: actFilterText.implicitWidth + Style.space(8)
                  implicitHeight: Style.space(20)
                  radius: 3
                  color: root.issueFilter === "active" ? root.urgent : root.track
                  Text { textFormat: Text.PlainText; id: actFilterText; anchors.centerIn: parent; text: "Active (" + root.activeIssuesCount + ")"; color: root.issueFilter === "active" ? root.urgentForeground : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: root.issueFilter === "active" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.issueFilter = "active" }
                }

                Rectangle {
                  implicitWidth: resFilterText.implicitWidth + Style.space(8)
                  implicitHeight: Style.space(20)
                  radius: 3
                  color: root.issueFilter === "resolved" ? root.dim : root.track
                  Text { textFormat: Text.PlainText; id: resFilterText; anchors.centerIn: parent; text: "Resolved"; color: root.issueFilter === "resolved" ? root.contrastTextFor(root.dim) : root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: root.issueFilter === "resolved" }
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.issueFilter = "resolved" }
                }

                Rectangle {
                  implicitWidth: clearHistoryBtnText.implicitWidth + Style.space(8)
                  implicitHeight: Style.space(20)
                  radius: 3
                  color: clearHistoryMouse.containsMouse ? root.cardHover : root.track
                  border.width: 1
                  border.color: root.outline
                  Text { textFormat: Text.PlainText; id: clearHistoryBtnText; anchors.centerIn: parent; text: "Clear"; color: clearHistoryMouse.containsMouse ? root.foreground : root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                  MouseArea {
                    id: clearHistoryMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      root.clearHistory()
                    }
                  }
                }
              }
            }

            // Issue list items (Active on top, Resolved greyed out below)
            Repeater {
              model: {
                var list = root.issuesList || []
                if (root.issueFilter === "active") return list.filter(function(i) { return i.active === true })
                if (root.issueFilter === "resolved") return list.filter(function(i) { return i.active !== true })
                return list
              }

              BorderSurface {
                required property var modelData
                readonly property bool isResolved: modelData.active !== true
                width: root.width
                implicitHeight: issueRow.implicitHeight + Style.space(12)
                color: root.card
                radius: Style.cornerRadius
                opacity: isResolved ? 0.62 : 1.0
                borderSpec: Border.flat(isResolved ? root.outline : (modelData.severity === "critical" ? root.urgent : root.backup), 1)

                RowLayout {
                  id: issueRow
                  anchors.fill: parent
                  anchors.margins: Style.space(8)
                  spacing: Style.space(8)

                  // Status Icon (Warning vs Checkmark)
                  Text {
                    textFormat: Text.PlainText;
                    text: isResolved ? "✓" : "\uf071"
                    color: isResolved ? root.dim : (modelData.severity === "critical" ? root.urgent : root.backup)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    Layout.alignment: Qt.AlignVCenter
                  }

                  ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1

                    Text {
                      textFormat: Text.PlainText;
                      text: Model.safe(modelData.title)
                      color: isResolved ? root.dim : root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: !isResolved
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: isResolved
                        ? (Model.safe(modelData.site) + (modelData.resolvedAt ? (" · Resolved " + Model.timeAgo(modelData.resolvedAt)) : "") + (modelData.durationSeconds ? (" · Downtime: " + Model.formatDuration(modelData.durationSeconds)) : ""))
                        : (Model.safe(modelData.site) + (modelData.durationSeconds ? (" · Down for " + Model.formatDuration(modelData.durationSeconds)) : ""))
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      elide: Text.ElideRight
                      Layout.fillWidth: true
                    }
                  }

                  // Status Pill (Active Alert vs Greyed-out Resolved)
                  Rectangle {
                    id: issueBadge
                    radius: 3
                    implicitHeight: Style.space(16)
                    implicitWidth: issueBadgeText.implicitWidth + Style.space(8)
                    color: isResolved ? root.track : (modelData.severity === "critical" ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.18) : Qt.rgba(root.backup.r, root.backup.g, root.backup.b, 0.18))
                    border.width: 1
                    border.color: isResolved ? root.outline : (modelData.severity === "critical" ? root.urgent : root.backup)
                    Layout.alignment: Qt.AlignVCenter
                    Text {
                      textFormat: Text.PlainText;
                      id: issueBadgeText
                      anchors.centerIn: parent
                      text: isResolved ? "RESOLVED" : "ACTIVE"
                      color: isResolved ? root.dim : (modelData.severity === "critical" ? root.urgent : root.backup)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      font.bold: true
                    }
                  }
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              visible: (root.issuesList || []).length === 0
              width: parent.width
              text: "No issues reported across your UniFi fleet. All systems operational."
              horizontalAlignment: Text.AlignHCenter
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
