import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

ColumnLayout {
  id: root

  property var settings: ({})
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color accent: (Color.accent || "#89B4FA")
  function contrastTextFor(c) {
    if (!c) return "#ffffff"
    var lum = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
    return lum > 0.55 ? "#0f141c" : "#ffffff"
  }
  readonly property color accentForeground: contrastTextFor(accent)
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color urgent: (Color.urgent || "#FF4D5A")
  property color healthy: "#10B981"
  property string fontFamily: Style.font.family

  signal settingChanged(string key, var value)
  signal clearHistoryRequested()
  signal testNotifyRequested()
  signal closeSettingsRequested()
  signal runDiagnosticsRequested()

  property var diagnostics: null
  property string lastErrorText: ""
  property bool diagnosticsRunning: false
  property int diagAgeSec: 0

  Timer {
    id: diagAgeTimer
    interval: 1000
    repeat: true
    running: true
    onTriggered: {
      if (root.diagnostics && root.diagnostics.timestamp) {
        root.diagAgeSec = Math.max(0, Math.floor(Date.now() / 1000) - root.diagnostics.timestamp)
      } else {
        root.diagAgeSec = 0
      }
    }
  }

  Timer {
    id: diagAutoRefreshTimer
    interval: 60000
    repeat: true
    running: root.visible
    onTriggered: root.runDiagnosticsRequested()
  }

  spacing: Style.space(12)

  // Top header in settings view
  SectionCard {
    title: "SITETHREAD PREFERENCES"
    subtitle: "Customize top bar telemetry, refresh intervals, and terminal shortcuts"
    iconText: ""
    titleColor: root.foreground
    fontFamily: root.fontFamily

    ColumnLayout {
      Layout.fillWidth: true
      Layout.topMargin: Style.space(4)
      spacing: Style.space(12)

      // 1. Bar Badge Mode Selector
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "BAR BADGE MODE"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Select what is displayed on the top bar badge next to the UniFi logo"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { id: "alerts", label: "Alerts Count" },
              { id: "clients", label: "Fleet Clients" },
              { id: "sites", label: "Sites Ratio" },
              { id: "updates", label: "Updates" },
              { id: "off", label: "Off" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.badgeMode || "alerts") === modelData.id
              implicitHeight: Style.space(24)
              implicitWidth: badgePillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (badgeMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: badgePillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? root.accentForeground : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: badgeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("badgeMode", modelData.id)
              }
            }
          }
        }
      }

      // 2. Multi-Dot Site Bar Status
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "MULTI-DOT SITE STATUS IN TOP BAR"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Display individual site status indicator dots beside the UniFi bar icon"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { val: true, label: "Enabled" },
              { val: false, label: "Disabled" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.enableMultiDot !== undefined ? root.settings.enableMultiDot : true) === modelData.val
              implicitHeight: Style.space(24)
              implicitWidth: mDotText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (mDotMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: mDotText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? root.accentForeground : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: mDotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("enableMultiDot", modelData.val)
              }
            }
          }
        }
      }

      // 3. Auto-Rotate 3D Globe
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "AUTO-ROTATE 3D VECTOR GLOBE"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Continuously rotate fleet globe when the Overview dashboard is opened"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { val: true, label: "Auto-Rotate" },
              { val: false, label: "Manual Drag Only" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.autoRotate !== undefined ? root.settings.autoRotate : false) === modelData.val
              implicitHeight: Style.space(24)
              implicitWidth: autoRotPillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (autoRotMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: autoRotPillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? root.accentForeground : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: autoRotMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("autoRotate", modelData.val)
              }
            }
          }
        }
      }

      // 4. Polling Refresh Interval
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText;
          text: "ADAPTIVE DUAL-RATE POLLING"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Active rate (while popup panel or Analytics window is open)"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { sec: 10, label: "10s" },
              { sec: 15, label: "15s (default)" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.activeRefreshSeconds || 15) === modelData.sec
              implicitHeight: Style.space(24)
              implicitWidth: activePillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (activeMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: activePillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? root.accentForeground : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: activeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("activeRefreshSeconds", modelData.sec)
              }
            }
          }
        }

        Text {
          textFormat: Text.PlainText;
          text: "Idle rate (while closed in background)"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { sec: 60, label: "1m" },
              { sec: 120, label: "2m (default)" },
              { sec: 180, label: "3m" },
              { sec: 300, label: "5m" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.idleRefreshSeconds || 120) === modelData.sec
              implicitHeight: Style.space(24)
              implicitWidth: idlePillText.implicitWidth + Style.space(14)
              radius: 4
              color: isSelected ? root.accent : (idleMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: idlePillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? root.accentForeground : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: idleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("idleRefreshSeconds", modelData.sec)
              }
            }
          }
        }
      }

      // 5. Preferred Terminal for SSH
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "PREFERRED TERMINAL (SSH & DIAGNOSTICS)"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Terminal emulator used when launching 1-click SSH and ping consoles"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(6)

          Repeater {
            model: [
              { cmd: "xdg-terminal-exec", label: "Default" },
              { cmd: "ghostty", label: "Ghostty" },
              { cmd: "kitty", label: "Kitty" },
              { cmd: "foot", label: "Foot" },
              { cmd: "alacritty", label: "Alacritty" }
            ]
            delegate: Rectangle {
              required property var modelData
              readonly property bool isSelected: (root.settings.terminalCommand || "xdg-terminal-exec") === modelData.cmd
              implicitHeight: Style.space(24)
              implicitWidth: termPillText.implicitWidth + Style.space(12)
              radius: 4
              color: isSelected ? root.accent : (termMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.accent : root.outline

              Text {
                textFormat: Text.PlainText;
                id: termPillText
                anchors.centerIn: parent
                text: modelData.label
                color: isSelected ? root.accentForeground : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: isSelected
              }

              MouseArea {
                id: termMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.settingChanged("terminalCommand", modelData.cmd)
              }
            }
          }
        }
      }

      // 6. Linux Desktop & Native Notifications
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText;
          text: "LINUX DESKTOP & NOTIFICATIONS"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Text {
          textFormat: Text.PlainText;
          text: "Send native desktop notifications via notify-send on site outages and WAN failover"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 2
        }

        RowLayout {
          spacing: Style.space(8)

          // Toggle Button
          Rectangle {
            id: notifyToggleBtn
            readonly property bool isEnabled: root.settings ? (root.settings.enableNotifications !== false) : true
            implicitHeight: Style.space(24)
            implicitWidth: notifyToggleText.implicitWidth + Style.space(16)
            radius: 4
            color: notifyToggleBtn.isEnabled ? Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.22) : root.track
            border.width: 1
            border.color: notifyToggleBtn.isEnabled ? root.healthy : root.outline

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text {
                textFormat: Text.PlainText;
                text: notifyToggleBtn.isEnabled ? "" : ""
                color: notifyToggleBtn.isEnabled ? root.healthy : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
              Text {
                textFormat: Text.PlainText;
                id: notifyToggleText
                text: notifyToggleBtn.isEnabled ? "Notifications: Enabled" : "Notifications: Disabled"
                color: notifyToggleBtn.isEnabled ? root.healthy : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
            }

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.settingChanged("enableNotifications", !notifyToggleBtn.isEnabled)
            }
          }

          // Test Notification Button
          Rectangle {
            implicitHeight: Style.space(24)
            implicitWidth: testNotifyText.implicitWidth + Style.space(14)
            radius: 4
            color: testNotifyMouse.containsMouse ? root.cardHover : root.track
            border.width: 1
            border.color: root.accent

            RowLayout {
              anchors.centerIn: parent
              spacing: Style.space(5)
              Text {
                textFormat: Text.PlainText;
                text: ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
              Text {
                textFormat: Text.PlainText;
                id: testNotifyText
                text: "Send Test Notification"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
              }
            }

            MouseArea {
              id: testNotifyMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.testNotifyRequested()
            }
          }
        }
      }

      // 7. System Health & Diagnostics
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(4)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            textFormat: Text.PlainText;
            text: "SYSTEM HEALTH & DIAGNOSTICS"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }

          Item { Layout.fillWidth: true }

          // Staleness badge if age > 120s
          Rectangle {
            visible: !!(root.diagnostics && root.diagAgeSec > 120)
            implicitHeight: Style.space(16)
            implicitWidth: staleBadgeText.implicitWidth + Style.space(8)
            radius: 3
            color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2)
            border.width: 1
            border.color: root.urgent

            Text {
              id: staleBadgeText
              anchors.centerIn: parent
              textFormat: Text.PlainText;
              text: "STALE (> 2m)"
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: 8
              font.bold: true
            }
          }

          // Freshness relative age text
          Text {
            textFormat: Text.PlainText;
            text: {
              if (!root.diagnostics) return ""
              if (root.diagAgeSec < 15) return "Checked: Just now"
              if (root.diagAgeSec < 60) return "Checked: " + root.diagAgeSec + "s ago"
              var mins = Math.floor(root.diagAgeSec / 60)
              return "Checked: " + mins + "m ago"
            }
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
          }
        }

        Rectangle {
          Layout.fillWidth: true
          implicitHeight: diagCol.implicitHeight + Style.space(16)
          radius: 4
          color: root.track
          border.width: 1
          border.color: (root.diagnostics && !root.diagnostics.apiReachable) ? root.urgent : root.outline

          ColumnLayout {
            id: diagCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Style.space(8)
            spacing: Style.space(6)

            // API Reachability & Self-Test Row
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(8)
                height: Style.space(8)
                radius: 4
                color: (root.diagnostics && root.diagnostics.apiReachable) ? root.healthy : ((root.diagnostics && root.diagnostics.mode === "disconnected") ? root.dim : root.urgent)
              }

              Text {
                textFormat: Text.PlainText;
                text: {
                  if (!root.diagnostics) return "API Status: Checking..."
                  if (root.diagnostics.mode === "demo") return "API Status: Demo Mode (Simulated)"
                  if (root.diagnostics.apiReachable) return "API Status: Reachable (" + root.diagnostics.apiLatencyMs + "ms)"
                  return "API Status: Offline / Error" + (root.diagnostics.apiStatusCode ? " (HTTP " + root.diagnostics.apiStatusCode + ")" : "")
                }
                color: (root.diagnostics && root.diagnostics.apiReachable) ? root.foreground : root.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
                font.bold: true
                Layout.fillWidth: true
              }

              // Self-Test Button
              Rectangle {
                implicitHeight: Style.space(22)
                implicitWidth: diagBtnText.implicitWidth + Style.space(14)
                radius: 3
                color: diagBtnMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent
                border.width: 1
                border.color: root.accent

                RowLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(4)
                  Text { textFormat: Text.PlainText; text: root.diagnosticsRunning ? "" : ""; color: root.accentForeground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2 }
                  Text { textFormat: Text.PlainText; id: diagBtnText; text: root.diagnosticsRunning ? "Testing..." : "Self-Test"; color: root.accentForeground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
                }

                MouseArea {
                  id: diagBtnMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.runDiagnosticsRequested()
                }
              }
            }

            // Cache & Local Storage Health
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText;
                text: "Cache Health:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
              Text {
                textFormat: Text.PlainText;
                text: {
                  if (!root.diagnostics) return "Inspecting cache..."
                  var s = root.diagnostics.cachedSites + " site(s) cached"
                  if (root.diagnostics.cachedSites > 0) s += " (latest: " + root.diagnostics.cacheAgeSec + "s ago)"
                  s += root.diagnostics.cacheWritable ? " · Writable" : " · Read-only"
                  return s
                }
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                Layout.fillWidth: true
              }
            }

            // Scope & Probe Disclaimer
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(5)
              Text {
                textFormat: Text.PlainText;
                text: ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
              Text {
                textFormat: Text.PlainText;
                text: (root.diagnostics && root.diagnostics.scope) ? root.diagnostics.scope : "Point-in-time endpoint probe. Does not verify role permissions or live telemetry streaming."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 8
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
              }
            }

            // Scopes & Capabilities Checklist
            ColumnLayout {
              visible: !!(root.diagnostics && root.diagnostics.capabilities)
              Layout.fillWidth: true
              spacing: Style.space(4)

              Text {
                textFormat: Text.PlainText;
                text: "API PERMISSIONS & SCOPES"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
              }

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(6)

                // Scope 1: devices:write
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: Style.space(22)
                  radius: 3
                  color: root.track
                  border.width: 1
                  border.color: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.powerCycle && !root.diagnostics.capabilities.powerCycle.allowed) ? root.urgent : root.outline

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.powerCycle && !root.diagnostics.capabilities.powerCycle.allowed) ? "" : ""
                      color: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.powerCycle && !root.diagnostics.capabilities.powerCycle.allowed) ? root.urgent : root.healthy
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "devices:write (PoE)"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: 8
                    }
                  }
                }

                // Scope 2: firmware:upgrade
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: Style.space(22)
                  radius: 3
                  color: root.track
                  border.width: 1
                  border.color: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.firmwareUpgrade && !root.diagnostics.capabilities.firmwareUpgrade.allowed) ? root.urgent : root.outline

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.firmwareUpgrade && !root.diagnostics.capabilities.firmwareUpgrade.allowed) ? "" : ""
                      color: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.firmwareUpgrade && !root.diagnostics.capabilities.firmwareUpgrade.allowed) ? root.urgent : root.healthy
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "firmware:upgrade"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: 8
                    }
                  }
                }

                // Scope 3: protect:stream
                Rectangle {
                  Layout.fillWidth: true
                  implicitHeight: Style.space(22)
                  radius: 3
                  color: root.track
                  border.width: 1
                  border.color: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.protectStreams && !root.diagnostics.capabilities.protectStreams.allowed) ? root.urgent : root.outline

                  RowLayout {
                    anchors.centerIn: parent
                    spacing: Style.space(4)
                    Text {
                      textFormat: Text.PlainText;
                      text: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.protectStreams && !root.diagnostics.capabilities.protectStreams.allowed) ? "" : ""
                      color: (root.diagnostics && root.diagnostics.capabilities && root.diagnostics.capabilities.protectStreams && !root.diagnostics.capabilities.protectStreams.allowed) ? root.urgent : root.healthy
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                    }
                    Text {
                      textFormat: Text.PlainText;
                      text: "protect:stream"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: 8
                    }
                  }
                }
              }
            }

            // Error Display (if any error occurred)
            Rectangle {
              visible: !!(root.lastErrorText || (root.diagnostics && root.diagnostics.apiError))
              Layout.fillWidth: true
              radius: 3
              color: Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.12)
              border.width: 1
              border.color: root.urgent
              implicitHeight: errBannerCol.implicitHeight + Style.space(8)

              ColumnLayout {
                id: errBannerCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Style.space(6)
                spacing: Style.space(2)

                Text {
                  textFormat: Text.PlainText;
                  text: "Last Error / Diagnostics Failure:"
                  color: root.urgent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: root.lastErrorText || (root.diagnostics ? root.diagnostics.apiError : "")
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                  wrapMode: Text.WordWrap
                  Layout.fillWidth: true
                }
              }
            }

            // Recent Operations & Action Outcomes
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)

              Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.outline
              }

              Text {
                textFormat: Text.PlainText;
                text: "RECENT OPERATIONS & ACTION OUTCOMES"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
              }

              Repeater {
                model: (root.diagnostics && root.diagnostics.operations && root.diagnostics.operations.length > 0) ? root.diagnostics.operations : []
                delegate: Rectangle {
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: opCol.implicitHeight + Style.space(8)
                  radius: 3
                  color: root.card
                  border.width: 1
                  border.color: {
                    if (modelData.status === "completed") return root.healthy
                    if (modelData.status === "failed") return root.urgent
                    return root.accent
                  }

                  ColumnLayout {
                    id: opCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Style.space(6)
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Rectangle {
                        implicitHeight: Style.space(16)
                        implicitWidth: opStatusText.implicitWidth + Style.space(8)
                        radius: 2
                        color: {
                          if (modelData.status === "completed") return Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.2)
                          if (modelData.status === "failed") return Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.2)
                          return Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
                        }

                        Text {
                          id: opStatusText
                          anchors.centerIn: parent
                          textFormat: Text.PlainText;
                          text: {
                            if (modelData.status === "completed") return "COMPLETED"
                            if (modelData.status === "failed") return "FAILED"
                            if (modelData.status === "accepted") return "REQUEST ACCEPTED"
                            if (modelData.status === "in_progress") return "IN PROGRESS"
                            return String(modelData.status || "UNKNOWN").toUpperCase()
                          }
                          color: {
                            if (modelData.status === "completed") return root.healthy
                            if (modelData.status === "failed") return root.urgent
                            return root.accent
                          }
                          font.family: root.fontFamily
                          font.pixelSize: 8
                          font.bold: true
                        }
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.title || modelData.target
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption - 1
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText;
                        text: modelData.relativeTime || modelData.timeText || ""
                        color: root.dim
                        font.family: root.fontFamily
                        font.pixelSize: 8
                      }
                    }

                    Text {
                      textFormat: Text.PlainText;
                      text: modelData.message || ""
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption - 2
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                    }

                    Text {
                      visible: !!modelData.error
                      textFormat: Text.PlainText;
                      text: "Error detail: " + modelData.error
                      color: root.urgent
                      font.family: root.fontFamily
                      font.pixelSize: 8
                      wrapMode: Text.WordWrap
                      Layout.fillWidth: true
                    }
                  }
                }
              }

              Text {
                visible: !(root.diagnostics && root.diagnostics.operations && root.diagnostics.operations.length > 0)
                textFormat: Text.PlainText;
                text: "No recent operations recorded. Action outcomes will appear here."
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
            }
          }
        }
      }

      // 8. Action Controls: Clear History & Back
      RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.space(8)
        spacing: Style.space(10)

        Rectangle {
          implicitHeight: Style.space(28)
          implicitWidth: clearBtnText.implicitWidth + Style.space(16)
          radius: 4
          color: clearMouse.containsMouse ? Qt.rgba(root.urgent.r, root.urgent.g, root.urgent.b, 0.25) : root.track
          border.width: 1
          border.color: root.urgent

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(5)
            Text { textFormat: Text.PlainText; text: ""; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; id: clearBtnText; text: "Clear Alert History"; color: root.urgent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
          }

          MouseArea {
            id: clearMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.clearHistoryRequested()
          }
        }

        Item { Layout.fillWidth: true }

        Rectangle {
          implicitHeight: Style.space(28)
          implicitWidth: backBtnText.implicitWidth + Style.space(18)
          radius: 4
          color: backMouse.containsMouse ? Qt.lighter(root.accent, 1.1) : root.accent

          RowLayout {
            anchors.centerIn: parent
            spacing: Style.space(5)
            Text { textFormat: Text.PlainText; text: ""; color: root.accentForeground; font.family: root.fontFamily; font.pixelSize: Style.font.caption }
            Text { textFormat: Text.PlainText; id: backBtnText; text: "Back to Dashboard"; color: root.accentForeground; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 1; font.bold: true }
          }

          MouseArea {
            id: backMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.closeSettingsRequested()
          }
        }
      }
    }
  }
}
