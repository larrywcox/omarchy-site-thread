import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "../Model.js" as Model

Item {
  id: root

  property var site: null
  property var throughputData: null
  property string range: "24h"
  property bool compact: false
  property bool showControls: !compact
  property bool showRates: true
  property bool interactive: true
  signal rangeSelected(string range)

  property color downloadColor: (Color.accent || "#89B4FA")
  property color uploadColor: (Color.healthy || "#10B981")
  property color foreground: (Color.foreground || "#D8DEE9")
  property color dim: (Color.dim || Qt.darker(foreground, 1.35))
  property color track: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.15)
  property color outline: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.18)
  property color card: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.05)
  property color cardHover: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.09)
  property string fontFamily: Style.font.family

  property var rxData: []
  property var txData: []
  property real currentRx: 0.0
  property real currentTx: 0.0
  property real peakRx: 0.0
  property real peakTx: 0.0
  property int hoverIndex: -1
  property real hoverMouseX: 0
  property real hoverMouseY: 0

  implicitWidth: compact ? Style.space(120) : Style.space(320)
  implicitHeight: compact ? Style.space(26) : Style.space(100)

  function getThroughputDate(idx) {
    var totalLen = (root.rxData && root.rxData.length > 0) ? root.rxData.length : 24
    if (idx < 0 || idx >= totalLen) return ""
    var intervalMins = (totalLen > 24 || totalLen === 12 || (root.range && String(root.range).indexOf("60s") === -1)) ? 5 : 60
    var minsAgo = (totalLen - 1 - idx) * intervalMins
    var nowMs = Date.now()
    if (intervalMins === 5) {
      nowMs = Math.floor(nowMs / (5 * 60 * 1000)) * (5 * 60 * 1000)
    }
    var target = new Date(nowMs - minsAgo * 60 * 1000)
    var days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    var months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    return days[target.getDay()] + ", " + months[target.getMonth()] + " " + target.getDate() + ", " + target.getFullYear()
  }

  function getThroughputTime(idx) {
    var totalLen = (root.rxData && root.rxData.length > 0) ? root.rxData.length : 24
    if (idx < 0 || idx >= totalLen) return ""
    var intervalMins = (totalLen > 24 || totalLen === 12 || (root.range && String(root.range).indexOf("60s") === -1)) ? 5 : 60
    var minsAgo = (totalLen - 1 - idx) * intervalMins
    var nowMs = Date.now()
    if (intervalMins === 5) {
      nowMs = Math.floor(nowMs / (5 * 60 * 1000)) * (5 * 60 * 1000)
    }
    var target = new Date(nowMs - minsAgo * 60 * 1000)
    var h = target.getHours()
    var m = target.getMinutes()
    var ampm = h >= 12 ? "PM" : "AM"
    var h12 = h % 12
    if (h12 === 0) h12 = 12
    var hPad = (h12 < 10 ? "0" : "") + h12
    var mPad = (m < 10 ? "0" : "") + m
    var hours = Math.floor(minsAgo / 60)
    var remMins = minsAgo % 60
    var rel = minsAgo === 0 ? "Now" : (minsAgo < 60 ? (minsAgo + "m ago") : (remMins === 0 ? (hours + "h ago") : (hours + "h " + remMins + "m ago")))
    return hPad + ":" + mPad + " " + ampm + " (" + rel + ")"
  }

  function refreshSparkline() {
    var res = null
    if (root.throughputData) {
      var rx = root.throughputData.rx || []
      var tx = root.throughputData.tx || []
      if (rx.length === 0) {
        if (root.throughputData.sites) {
          res = Model.getFleetThroughput24h(root.throughputData)
        } else {
          var baseRx = root.throughputData.rxRate || 45.0
          var baseTx = root.throughputData.txRate || 12.0
          res = Model.getSiteThroughput24h({ rxRate: baseRx, txRate: baseTx })
        }
      } else {
        var rNorm = String(root.range || "24h").toLowerCase()
        var hours = 24
        if (rNorm.indexOf("12") !== -1) hours = 12
        else if (rNorm.indexOf("6") !== -1) hours = 6
        else if (rNorm.indexOf("1") !== -1 && rNorm.indexOf("12") === -1 && rNorm.indexOf("24") === -1) hours = 1

        var rxUse = rx
        var txUse = tx
        if (hours < 24 && rx.length > 2) {
          var targetLen = Math.max(2, Math.round(rx.length * (hours / 24)))
          rxUse = rx.slice(Math.max(0, rx.length - targetLen))
          if (tx.length === rx.length) {
            txUse = tx.slice(Math.max(0, tx.length - targetLen))
          }
        }

        var curRx = root.throughputData.currentRx !== undefined ? root.throughputData.currentRx : (root.throughputData.rxRate || (rxUse.length > 0 ? rxUse[rxUse.length - 1] : 0))
        var curTx = root.throughputData.currentTx !== undefined ? root.throughputData.currentTx : (root.throughputData.txRate || (txUse.length > 0 ? txUse[txUse.length - 1] : 0))
        var pRx = 0.0
        var pTx = 0.0
        for (var k = 0; k < rxUse.length; k++) {
          if (rxUse[k] > pRx) pRx = rxUse[k]
          if (txUse[k] > pTx) pTx = txUse[k]
        }
        res = {
          rx: rxUse,
          tx: txUse,
          currentRx: Math.round(curRx * 100) / 100,
          currentTx: Math.round(curTx * 100) / 100,
          peakRx: Math.round(pRx * 10) / 10,
          peakTx: Math.round(pTx * 10) / 10
        }
      }
    } else if (root.site) {
      res = Model.getSiteWanSparkline(root.site, root.range)
    }

    if (res) {
      root.rxData = res.rx || []
      root.txData = res.tx || []
      root.currentRx = res.currentRx || 0.0
      root.currentTx = res.currentTx || 0.0
      root.peakRx = res.peakRx || 0.0
      root.peakTx = res.peakTx || 0.0
      sparkCanvas.requestPaint()
    }
  }

  onSiteChanged: refreshSparkline()
  onThroughputDataChanged: refreshSparkline()
  onRangeChanged: refreshSparkline()

  Component.onCompleted: refreshSparkline()

  // Real-time jitter tick kept inactive since sparklines show genuine 24h historical telemetry
  Timer {
    id: rollingTick
    interval: 1000
    running: false
    repeat: true
  }

  ColumnLayout {
    anchors.fill: parent
    spacing: root.compact ? 1 : Style.space(2)

    // Header strip for non-compact mode
    ColumnLayout {
      visible: !root.compact
      Layout.fillWidth: true
      spacing: 1

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.space(6)

        Text {
          textFormat: Text.PlainText;
          text: {
            var r = String(root.range || "24h").toLowerCase()
            if (r.indexOf("12") !== -1) return "12-HOUR WAN THROUGHPUT"
            if (r.indexOf("6") !== -1) return "6-HOUR WAN THROUGHPUT"
            if (r.indexOf("1") !== -1 && r.indexOf("12") === -1 && r.indexOf("24") === -1) return "1-HOUR WAN THROUGHPUT"
            return "24-HOUR WAN THROUGHPUT"
          }
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption - 1
          font.bold: true
        }

        Item { Layout.fillWidth: true }

        // Rate badges
        RowLayout {
          spacing: Style.space(6)
          Text {
            textFormat: Text.PlainText;
            text: "↓ " + Model.formatRate(root.currentRx) + "bps"
            color: root.downloadColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }
          Text {
            textFormat: Text.PlainText;
            text: "↑ " + Model.formatRate(root.currentTx) + "bps"
            color: root.uploadColor
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 1
            font.bold: true
          }
        }

        // Range Selector (24h · 12h · 6h · 1h)
        RowLayout {
          visible: root.showControls
          spacing: Style.space(2)

          Repeater {
            model: ["24h", "12h", "6h", "1h"]
            delegate: Rectangle {
              required property string modelData
              readonly property bool isSelected: {
                var cur = String(root.range || "24h").toLowerCase()
                if (modelData === "24h") return cur.indexOf("24") !== -1
                if (modelData === "12h") return cur.indexOf("12") !== -1
                if (modelData === "6h") return cur.indexOf("6") !== -1
                if (modelData === "1h") return cur.indexOf("1") !== -1 && cur.indexOf("12") === -1 && cur.indexOf("24") === -1
                return false
              }
              implicitWidth: rangeOptText.implicitWidth + Style.space(8)
              implicitHeight: Style.space(18)
              radius: 3
              color: isSelected ? root.downloadColor : (rangeMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: isSelected ? root.downloadColor : root.outline

              Text {
                textFormat: Text.PlainText;
                id: rangeOptText
                anchors.centerIn: parent
                text: modelData
                color: isSelected ? "#ffffff" : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: isSelected
              }

              MouseArea {
                id: rangeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var fullRange = (modelData === "24h") ? "24 hours" : ((modelData === "12h") ? "12 hours" : ((modelData === "6h") ? "6 hours" : "1 hour"))
                  root.range = fullRange
                  root.rangeSelected(fullRange)
                }
              }

              PanelToolTip {
                visible: rangeMouse.containsMouse
                text: modelData === "24h" ? "24 hours" : (modelData === "12h" ? "12 hours" : (modelData === "6h" ? "6 hours" : "1 hour"))
                fontFamily: root.fontFamily
              }
            }
          }

          Item {
            visible: false
            Text {
              id: rangeText
              text: root.range || "24h"
            }
          }
        }
      }

      Text {
        textFormat: Text.PlainText;
        text: "5m intervals · Peak: " + root.peakRx.toFixed(1) + " Mbps DL / " + root.peakTx.toFixed(1) + " Mbps UL"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption - 2
      }
    }

    // Compact Mode Rate Label & Range Tag
    RowLayout {
      visible: root.compact && root.showRates
      Layout.fillWidth: true
      spacing: Style.space(4)

      Text {
        textFormat: Text.PlainText;
        text: "↓" + Model.formatRate(root.currentRx) + " ↑" + Model.formatRate(root.currentTx)
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: 8
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Rectangle {
        visible: root.interactive
        implicitWidth: compactRangeText.implicitWidth + 6
        implicitHeight: 12
        radius: 2
        color: root.track
        border.width: 0.5
        border.color: root.outline

        Text {
          textFormat: Text.PlainText;
          id: compactRangeText
          anchors.centerIn: parent
          text: root.range || "24h"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: 7
          font.bold: true
        }
      }
    }

    // Sparkline Canvas
    Item {
      Layout.fillWidth: true
      Layout.fillHeight: true

      Canvas {
        id: sparkCanvas
        anchors.fill: parent
        renderTarget: Canvas.Image

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
          var ctx = getContext("2d")
          if (!ctx) return
          ctx.reset()

          var w = width
          var h = height
          if (w <= 10 || h <= 8) return

          var rx = root.rxData || []
          var tx = root.txData || []
          if (rx.length < 2) return

          if (!root.compact) {
            var leftPad = 32
            var botPad = 14
            var topPad = 6
            var chartW = w - leftPad - 10
            var chartH = Math.max(16, h - botPad - topPad)

            var maxVal = Math.max(40, Math.ceil(root.peakRx / 20) * 20)
            if (maxVal < 60 && maxVal > 40) maxVal = 60
            if (maxVal > 80 && maxVal < 100) maxVal = 100

            // Grid lines & Y-axis labels
            ctx.strokeStyle = root.outline
            ctx.fillStyle = root.dim
            ctx.font = "8px " + root.fontFamily
            ctx.lineWidth = 0.5
            var stepVal = maxVal / 4
            for (var g = 0; g <= 4; g++) {
              var gy = topPad + (chartH / 4) * g
              ctx.beginPath()
              ctx.moveTo(leftPad, gy)
              ctx.lineTo(w - 10, gy)
              ctx.stroke()
              var lblVal = Math.round(maxVal - g * stepVal)
              ctx.fillText(lblVal + "M", 2, gy + 3)
            }

            // X-axis time labels (24 hours matching Overview tab)
            var rNorm = String(root.range || "24h").toLowerCase()
            var timeLabels = (rNorm.indexOf("12") !== -1)
              ? ["12h ago", "9h", "6h", "3h", "Now"]
              : ((rNorm.indexOf("6") !== -1)
                ? ["6h ago", "4.5h", "3h", "1.5h", "Now"]
                : ((rNorm.indexOf("1") !== -1 && rNorm.indexOf("12") === -1 && rNorm.indexOf("24") === -1)
                  ? ["1h ago", "45m", "30m", "15m", "Now"]
                  : ["24h ago", "18h", "12h", "6h", "Now"]))
            for (var t = 0; t < timeLabels.length; t++) {
              var txPos = leftPad + (chartW / 4) * t
              ctx.fillText(timeLabels[t], txPos - (t === 4 ? 18 : 10), h - 2)
            }

            // Draw Download Curve
            ctx.beginPath()
            var step = chartW / (rx.length - 1)
            for (var i = 0; i < rx.length; i++) {
              var px = leftPad + i * step
              var py = topPad + chartH - (rx[i] / maxVal) * chartH
              if (i === 0) ctx.moveTo(px, py)
              else ctx.lineTo(px, py)
            }
            ctx.strokeStyle = root.downloadColor
            ctx.lineWidth = 2.0
            ctx.stroke()

            // Download gradient fill
            var grad = ctx.createLinearGradient(0, topPad, 0, topPad + chartH)
            grad.addColorStop(0, Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, 0.35))
            grad.addColorStop(1, Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, 0.02))
            ctx.lineTo(leftPad + chartW, topPad + chartH)
            ctx.lineTo(leftPad, topPad + chartH)
            ctx.closePath()
            ctx.fillStyle = grad
            ctx.fill()

            // Draw Upload Curve
            if (tx.length === rx.length) {
              ctx.beginPath()
              for (var j = 0; j < tx.length; j++) {
                var txX = leftPad + j * step
                var txY = topPad + chartH - (tx[j] / maxVal) * chartH
                if (j === 0) ctx.moveTo(txX, txY)
                else ctx.lineTo(txX, txY)
              }
              ctx.strokeStyle = root.uploadColor
              ctx.lineWidth = 1.5
              ctx.stroke()
            }

            // Vertical scrub line and highlight dots on hover
            if (root.hoverIndex >= 0 && root.hoverIndex < rx.length) {
              var hx = leftPad + root.hoverIndex * step
              var hrxY = topPad + chartH - (rx[root.hoverIndex] / maxVal) * chartH
              var htxY = topPad + chartH - (tx[root.hoverIndex] / maxVal) * chartH

              ctx.save()
              ctx.beginPath()
              ctx.strokeStyle = Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.7)
              ctx.lineWidth = 1.0
              ctx.setLineDash([3, 3])
              ctx.moveTo(hx, topPad)
              ctx.lineTo(hx, topPad + chartH)
              ctx.stroke()
              ctx.restore()

              // Download halo and dot
              ctx.beginPath()
              ctx.arc(hx, hrxY, 6, 0, 2 * Math.PI)
              ctx.fillStyle = Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, 0.35)
              ctx.fill()
              ctx.beginPath()
              ctx.arc(hx, hrxY, 3.5, 0, 2 * Math.PI)
              ctx.fillStyle = root.downloadColor
              ctx.fill()

              // Upload halo and dot
              if (tx.length > root.hoverIndex) {
                ctx.beginPath()
                ctx.arc(hx, htxY, 5, 0, 2 * Math.PI)
                ctx.fillStyle = Qt.rgba(root.uploadColor.r, root.uploadColor.g, root.uploadColor.b, 0.35)
                ctx.fill()
                ctx.beginPath()
                ctx.arc(hx, htxY, 3, 0, 2 * Math.PI)
                ctx.fillStyle = root.uploadColor
                ctx.fill()
              }
            }
          } else {
            // Compact Mode
            var maxV = Math.max(1.0, root.peakRx * 1.15)
            if (maxV <= 0) maxV = 1.0

            var padTop = 2
            var padBottom = 2
            var drawH = Math.max(4, h - padTop - padBottom)
            var stepX = w / (rx.length - 1)

            // 1. Download Gradient Fill & Stroke
            ctx.beginPath()
            for (var k = 0; k < rx.length; k++) {
              var x = k * stepX
              var y = padTop + drawH - (rx[k] / maxV) * drawH
              if (k === 0) ctx.moveTo(x, y)
              else ctx.lineTo(x, y)
            }

            ctx.save()
            ctx.strokeStyle = root.downloadColor
            ctx.lineWidth = 1.2
            ctx.stroke()
            ctx.restore()

            var cGrad = ctx.createLinearGradient(0, padTop, 0, padTop + drawH)
            cGrad.addColorStop(0, Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, 0.20))
            cGrad.addColorStop(1, Qt.rgba(root.downloadColor.r, root.downloadColor.g, root.downloadColor.b, 0.01))
            ctx.lineTo(w, padTop + drawH)
            ctx.lineTo(0, padTop + drawH)
            ctx.closePath()
            ctx.fillStyle = cGrad
            ctx.fill()

            // 2. Upload Stroke
            if (tx.length === rx.length) {
              ctx.beginPath()
              for (var l = 0; l < tx.length; l++) {
                var txCompactX = l * stepX
                var txCompactY = padTop + drawH - (tx[l] / maxV) * drawH
                if (l === 0) ctx.moveTo(txCompactX, txCompactY)
                else ctx.lineTo(txCompactX, txCompactY)
              }
              ctx.strokeStyle = root.uploadColor
              ctx.lineWidth = 1.0
              ctx.stroke()
            }

            if (root.hoverIndex >= 0 && root.hoverIndex < rx.length) {
              var compactHx = root.hoverIndex * stepX
              var compactHy = padTop + drawH - (rx[root.hoverIndex] / maxV) * drawH
              ctx.save()
              ctx.strokeStyle = Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.6)
              ctx.lineWidth = 1
              ctx.setLineDash([2, 2])
              ctx.beginPath()
              ctx.moveTo(compactHx, padTop)
              ctx.lineTo(compactHx, padTop + drawH)
              ctx.stroke()
              ctx.restore()

              ctx.beginPath()
              ctx.arc(compactHx, compactHy, 2.5, 0, Math.PI * 2)
              ctx.fillStyle = root.downloadColor
              ctx.fill()
            }

            ctx.fillStyle = root.dim
            ctx.font = "7px " + root.fontFamily
            ctx.fillText("24h ago", 2, h - 2)
            ctx.fillText("Now", w - 16, h - 2)
          }
        }
      }

      MouseArea {
        id: canvasMouseArea
        anchors.fill: parent
        hoverEnabled: root.interactive
        cursorShape: root.interactive ? Qt.CrossCursor : Qt.ArrowCursor

        onPositionChanged: function(mouse) {
          if (root.interactive && root.rxData.length > 1) {
            var leftPad = root.compact ? 0 : 32
            var rightPad = root.compact ? 0 : 10
            var chartW = sparkCanvas.width - leftPad - rightPad
            if (chartW <= 0) return
            var maxIdx = root.rxData.length - 1
            var clampedX = Math.max(leftPad, Math.min(sparkCanvas.width - rightPad, mouse.x))
            var ratio = (clampedX - leftPad) / chartW
            var idx = Math.max(0, Math.min(maxIdx, Math.round(ratio * maxIdx)))
            root.hoverIndex = idx
            root.hoverMouseX = mouse.x
            root.hoverMouseY = mouse.y
            sparkCanvas.requestPaint()
          }
        }

        onExited: {
          root.hoverIndex = -1
          sparkCanvas.requestPaint()
        }

        // Floating Info Card Tooltip in non-compact mode (matches OverviewTab)
        Rectangle {
          id: infoCard
          visible: !root.compact && root.hoverIndex >= 0
          enabled: false
          z: 100
          width: cardLayout.implicitWidth + Style.space(16)
          height: cardLayout.implicitHeight + Style.space(14)
          radius: 6
          color: (Color.popups && Color.popups.background) ? Color.popups.background : (Color.background || "#161b2a")
          border.width: 1
          border.color: root.downloadColor

          x: {
            var targetX = root.hoverMouseX + 16
            if (targetX + width > sparkCanvas.width - 8) {
              targetX = root.hoverMouseX - width - 16
            }
            return Math.max(8, Math.min(sparkCanvas.width - width - 8, targetX))
          }
          y: {
            var targetY = root.hoverMouseY - height / 2
            return Math.max(4, Math.min(sparkCanvas.height - height - 4, targetY))
          }

          ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: Style.space(6)
            spacing: Style.space(3)

            RowLayout {
              spacing: Style.space(6)
              Text {
                textFormat: Text.PlainText;
                text: ""
                color: root.downloadColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 1
              }
              ColumnLayout {
                spacing: 1
                Text {
                  textFormat: Text.PlainText;
                  text: root.getThroughputDate(root.hoverIndex)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 1
                  font.bold: true
                }
                Text {
                  textFormat: Text.PlainText;
                  text: root.getThroughputTime(root.hoverIndex)
                  color: root.dim
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption - 2
                }
              }
            }

            Rectangle {
              Layout.fillWidth: true
              height: 1
              color: root.outline
            }

            RowLayout {
              spacing: Style.space(6)
              Rectangle {
                width: 6
                height: 6
                radius: 3
                color: root.downloadColor
              }
              Text {
                textFormat: Text.PlainText;
                text: "Download:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
              Text {
                textFormat: Text.PlainText;
                text: (root.rxData[root.hoverIndex] !== undefined ? root.rxData[root.hoverIndex].toFixed(1) : "0.0") + " Mbps"
                color: root.downloadColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                Layout.alignment: Qt.AlignRight
              }
            }

            RowLayout {
              spacing: Style.space(6)
              Rectangle {
                width: 6
                height: 6
                radius: 3
                color: root.uploadColor
              }
              Text {
                textFormat: Text.PlainText;
                text: "Upload:"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
              }
              Text {
                textFormat: Text.PlainText;
                text: (root.txData[root.hoverIndex] !== undefined ? root.txData[root.hoverIndex].toFixed(1) : "0.0") + " Mbps"
                color: root.uploadColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption - 2
                font.bold: true
                Layout.alignment: Qt.AlignRight
              }
            }
          }
        }

        // PanelToolTip only for compact mode
        PanelToolTip {
          visible: root.compact && canvasMouseArea.containsMouse
          fontFamily: root.fontFamily
          text: {
            if (root.hoverIndex >= 0 && root.hoverIndex < root.rxData.length) {
              return root.getThroughputTime(root.hoverIndex) + ": ↓ " + Model.formatRate(root.rxData[root.hoverIndex]) + "bps · ↑ " + Model.formatRate(root.txData[root.hoverIndex]) + "bps"
            }
            return "24h WAN (5m intervals): ↓ " + Model.formatRate(root.currentRx) + "bps · ↑ " + Model.formatRate(root.currentTx) + "bps" + (root.peakRx > 0 ? (" · Peak: " + Model.formatRate(root.peakRx) + "bps") : "")
          }
        }
      }
    }
  }
}
