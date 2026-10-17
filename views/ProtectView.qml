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

  property var fleetData: ({})
  property var capabilities: root.fleetData && root.fleetData.capabilities ? root.fleetData.capabilities : null
  readonly property bool canStreamProtect: {
    if (!root.capabilities || !root.capabilities.protectStreams) return true
    return root.capabilities.protectStreams.allowed !== false
  }
  readonly property string protectWarning: {
    if (root.capabilities && root.capabilities.protectStreams && !root.canStreamProtect) {
      return root.capabilities.protectStreams.warning || root.capabilities.protectStreams.missingPermission || "Missing 'protect:stream' scope: Camera snapshots and live streams unavailable"
    }
    return "Missing 'protect:stream' scope: Camera snapshots and live streams require 'protect.read' or 'protect:stream' permission"
  }
  property bool cloudMode: false
  property string selectedCameraId: ""
  property string selectedCameraName: ""
  property string snapshotPath: ""

  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  property color urgent: (Color.urgent || "#FF4D5A")
  property string fontFamily: Style.font.family

  signal selectCameraRequested(string camId, string camName)
  signal cleanupPriorSnapshotRequested()
  function selectCamera(camId, camName) {
    selectCameraRequested(camId, camName)
  }

            spacing: Style.space(8)
            PanelSectionHeader { width: root.width; text: root.cloudMode ? "PROTECT ACROSS ALL SITES" : "PROTECT CAMERAS"; foreground: root.foreground; fontFamily: root.fontFamily }

            // Inline Protect Permission Warning Banner
            Rectangle {
              id: protectPermissionBanner
              visible: !root.canStreamProtect
              width: root.width
              implicitHeight: protPermRow.implicitHeight + Style.space(12)
              radius: 4
              color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.12)
              border.width: 1
              border.color: root.urgent

              RowLayout {
                id: protPermRow
                anchors.fill: parent
                anchors.margins: Style.space(6)
                spacing: Style.space(8)

                Text {
                  textFormat: Text.PlainText;
                  text: ""
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }

                Text {
                  textFormat: Text.PlainText;
                  Layout.fillWidth: true
                  text: root.protectWarning
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  wrapMode: Text.WordWrap
                }
              }
            }

            Rectangle {
              visible: root.selectedCameraId !== ""
              width: root.width
              height: Math.round(width * 9 / 16)
              radius: Style.cornerRadius
              color: Qt.rgba(0, 0, 0, 0.35)
              clip: true
              Image {
                anchors.fill: parent
                source: root.snapshotPath
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                onStatusChanged: {
                  if (status === Image.Ready) {
                    root.cleanupPriorSnapshotRequested()
                  }
                }
              }
              Text {
                textFormat: Text.PlainText;
                anchors.centerIn: parent;
                visible: root.snapshotPath === "";
                text: !root.canStreamProtect
                  ? "Missing 'protect:stream' permission for camera snapshots"
                  : (root.cloudMode ? "Open Site Manager for live video" : "Loading " + root.selectedCameraName);
                color: !root.canStreamProtect ? root.urgent : root.foreground;
                font.family: root.fontFamily;
                font.pixelSize: Style.font.body;
              }
              Rectangle {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Style.space(8)
                width: cameraLabel.implicitWidth + Style.space(12)
                height: cameraLabel.implicitHeight + Style.space(6)
                radius: height / 2
                color: Qt.rgba(0, 0, 0, 0.62)
                Text { textFormat: Text.PlainText; id: cameraLabel; anchors.centerIn: parent; text: root.selectedCameraName; color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
              }
            }

            Flickable {
              width: root.width
              implicitHeight: Style.space(48)
              contentWidth: cameraCardsRow.implicitWidth
              clip: true
              boundsBehavior: Flickable.StopAtBounds

              RowLayout {
                id: cameraCardsRow
                spacing: Style.space(6)
                Repeater {
                  model: root.fleetData.protect && root.fleetData.protect.cameras ? root.fleetData.protect.cameras : []
                  Rectangle {
                    required property var modelData
                    implicitWidth: Style.space(100)
                    implicitHeight: Style.space(44)
                    radius: Style.cornerRadius
                    color: String(modelData.id) === root.selectedCameraId ? Style.selectedFillFor(root.foreground, root.accent) : Style.normalFillFor(root.foreground, root.accent)
                    border.width: String(modelData.id) === root.selectedCameraId ? 1 : 0
                    border.color: root.accent
                    ColumnLayout {
                      anchors.centerIn: parent
                      spacing: 1
                      Text { textFormat: Text.PlainText; text: Model.safe(modelData.name, "Camera"); color: root.foreground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true; elide: Text.ElideRight; Layout.alignment: Qt.AlignHCenter }
                      Text { textFormat: Text.PlainText; text: modelData.online ? "ONLINE" : "OFFLINE"; color: modelData.online ? root.dim : root.urgent; font.family: root.fontFamily; font.pixelSize: 8; Layout.alignment: Qt.AlignHCenter }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selectCamera(modelData) }
                  }
                }
              }
            }
            Text { textFormat: Text.PlainText; visible: !root.fleetData.protect || !root.fleetData.protect.available; width: root.width; text: root.cloudMode ? "Site Manager did not report Protect devices for this account" : "UniFi Protect is unavailable for this connection"; horizontalAlignment: Text.AlignHCenter; color: root.dim; font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall }
          }
