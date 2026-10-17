import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui
import "components"

ColumnLayout {
  id: root

  property var site: null
  property var devices: []
  property var clients: []
  property string preferredTerminal: "xdg-terminal-exec"
  property string activeChooserNode: ""
  property var collapsedNodes: ({})
  property var collapsedClientNodes: ({})

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
  property color backup: "#F59E0B"
  property string fontFamily: Style.font.family

  signal sshRequested(string ip, string user)
  signal pingRequested(string ip)
  signal webRequested(string ip)

  spacing: Style.space(6)

  // --------------------------------------------------------------------------
  // Collapsible Tree Helper Functions (Separate Device & Client Toggles)
  // --------------------------------------------------------------------------
  function isDevCollapsed(key) {
    return !!root.collapsedNodes[key]
  }

  function isClientsCollapsed(key) {
    if (root.collapsedClientNodes && root.collapsedClientNodes["*"] === false) {
      return root.collapsedClientNodes[key] === true
    }
    if (root.collapsedClientNodes && root.collapsedClientNodes[key] === false) {
      return false
    }
    // By default, clients are collapsed
    return true
  }

  function isCollapsed(key) {
    return isDevCollapsed(key)
  }

  function toggleDevCollapse(key) {
    var next = {}
    var keys = Object.keys(root.collapsedNodes || {})
    for (var i = 0; i < keys.length; i++) {
      next[keys[i]] = root.collapsedNodes[keys[i]]
    }
    if (next[key]) {
      delete next[key]
    } else {
      next[key] = true
    }
    root.collapsedNodes = next
  }

  function toggleClientsCollapse(key) {
    var next = {}
    var keys = Object.keys(root.collapsedClientNodes || {})
    for (var i = 0; i < keys.length; i++) {
      next[keys[i]] = root.collapsedClientNodes[keys[i]]
    }
    if (isClientsCollapsed(key)) {
      next[key] = false // Expand
    } else {
      next[key] = true  // Collapse
    }
    root.collapsedClientNodes = next
  }

  function toggleCollapse(key) {
    toggleDevCollapse(key)
  }

  function expandAll() {
    root.collapsedNodes = ({})
    root.collapsedClientNodes = { "*": false }
  }

  function collapseAll() {
    var nextDev = { "gw": true }
    var flat = buildFlatTree()
    for (var i = 0; i < flat.length; i++) {
      if (flat[i].type === "device" && flat[i].key) {
        nextDev[flat[i].key] = true
      }
    }
    root.collapsedNodes = nextDev
    root.collapsedClientNodes = ({})
  }

  function hasAnyCollapsed() {
    if (Object.keys(root.collapsedNodes || {}).length > 0) return true
    if (!root.collapsedClientNodes || root.collapsedClientNodes["*"] !== false) return true
    return false
  }

  // --------------------------------------------------------------------------
  // Dynamic Hierarchy & Device/Client Association Helpers
  // --------------------------------------------------------------------------
  function normalizeMac(mac) {
    if (!mac) return ""
    return String(mac).toLowerCase().replace(/[:-]/g, "").trim()
  }

  function siteDevices() {
    var list = Array.isArray(root.devices) ? root.devices : []
    if (!root.site || !root.site.name) return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      if (!list[i].site || list[i].site === root.site.name) out.push(list[i])
    }
    return out.length > 0 ? out : list
  }

  function siteClients() {
    var list = Array.isArray(root.clients) ? root.clients : []
    if (!root.site || !root.site.name) return list
    var out = []
    for (var i = 0; i < list.length; i++) {
      if (!list[i].siteName || list[i].siteName === root.site.name) out.push(list[i])
    }
    return out.length > 0 ? out : list
  }

  function isGateway(d) {
    if (!d) return false
    var m = String(d.model || "").toLowerCase()
    var n = String(d.name || "").toLowerCase()
    return m.indexOf("ucg") >= 0 || m.indexOf("udm") >= 0 || m.indexOf("uxg") >= 0 || m.indexOf("gateway") >= 0 || n.indexOf("gateway") >= 0
  }

  function isSwitch(d) {
    if (!d) return false
    var m = String((d && d.model) || (d && d.device && d.device.model) || "").toLowerCase()
    var n = String((d && d.name) || (d && d.device && d.device.name) || "").toLowerCase()
    return m.indexOf("usw") >= 0 || m.indexOf("switch") >= 0 || n.indexOf("switch") >= 0
  }

  function isAccessPoint(d) {
    if (!d) return false
    if (isGateway(d) || isSwitch(d)) return false
    return true
  }

  function deviceTypePill(d) {
    if (isGateway(d)) return "GATEWAY"
    if (isSwitch(d)) return "SWITCH"
    return "AP"
  }

  function hasTrueTopology() {
    var list = siteDevices()
    for (var i = 0; i < list.length; i++) {
      if (list[i].parentName) return true
    }
    return false
  }

  function getGateway() {
    var list = siteDevices()
    for (var i = 0; i < list.length; i++) {
      if (isGateway(list[i])) return list[i]
    }
    for (var j = 0; j < list.length; j++) {
      if (!list[j].parentName) return list[j]
    }
    return root.site ? {
      name: root.site.gatewayModel || "UniFi Gateway",
      model: root.site.gatewayModel || "Gateway",
      ip: root.site.gatewayIp || "",
      online: root.site.status === "up"
    } : null
  }

  function getRootDevices() {
    var list = siteDevices()
    if (list.length === 0) {
      var gw = getGateway()
      return gw ? [gw] : []
    }
    var devNames = {}
    var devMacs = {}
    for (var i = 0; i < list.length; i++) {
      if (list[i].name) devNames[String(list[i].name).toLowerCase().trim()] = true
      if (list[i].mac) devMacs[normalizeMac(list[i].mac)] = true
      if (list[i].id) devMacs[String(list[i].id).toLowerCase()] = true
    }

    var roots = []
    for (var j = 0; j < list.length; j++) {
      var d = list[j]
      var pName = String(d.parentName || "").toLowerCase().trim()
      var pMac = normalizeMac(d.parentMac)
      if (isGateway(d) || !pName || (!devNames[pName] && (!pMac || !devMacs[pMac]))) {
        roots.push(d)
      }
    }
    if (roots.length === 0) {
      for (var k = 0; k < list.length; k++) {
        if (isGateway(list[k])) { roots.push(list[k]); break }
      }
      if (roots.length === 0 && list.length > 0) roots.push(list[0])
    }
    return roots
  }

  function getChildDevices(parentDev) {
    if (!parentDev) return []
    var list = siteDevices()
    var pName = String(parentDev.name || "").toLowerCase().trim()
    var pMac = normalizeMac(parentDev.mac)
    var pId = String(parentDev.id || "").toLowerCase()

    var children = []
    for (var i = 0; i < list.length; i++) {
      var d = list[i]
      if (d === parentDev) continue
      var dParentName = String(d.parentName || "").toLowerCase().trim()
      var dParentMac = normalizeMac(d.parentMac)
      var dParentId = String(d.parentDeviceId || "").toLowerCase()

      var matched = false
      if (pName && dParentName && dParentName === pName) matched = true
      else if (pMac && dParentMac && dParentMac === pMac) matched = true
      else if (pId && dParentId && dParentId === pId) matched = true

      if (matched) children.push(d)
    }

    children.sort(function(a, b) {
      var sa = isSwitch(a) ? 0 : 1
      var sb = isSwitch(b) ? 0 : 1
      if (sa !== sb) return sa - sb
      return (a.parentPort || 0) - (b.parentPort || 0)
    })
    return children
  }

  function getClientsForDevice(parentDev) {
    if (!parentDev) return []
    var allClients = siteClients()
    var pName = String(parentDev.name || "").toLowerCase().trim()
    var pMac = normalizeMac(parentDev.mac)
    var pId = String(parentDev.id || "").toLowerCase()

    var matched = []
    for (var i = 0; i < allClients.length; i++) {
      var c = allClients[i]
      var cUplinkId = String(c.uplinkDeviceId || "").toLowerCase()
      var cApName = String(c.apName || "").toLowerCase().trim()
      var cUpName = String(c.uplinkName || "").toLowerCase().trim()
      var cApMac = normalizeMac(c.apMac)
      var cUpMac = normalizeMac(c.uplinkMac)
      var cSwMac = normalizeMac(c.swMac)

      var isParent = false
      if (pId && cUplinkId && (cUplinkId === pId || cUplinkId === String(parentDev._id || "").toLowerCase())) {
        isParent = true
      } else if (pMac && ((cApMac && cApMac === pMac) || (cUpMac && cUpMac === pMac) || (cSwMac && cSwMac === pMac))) {
        isParent = true
      } else if (pName && ((cApName && cApName === pName) || (cUpName && cUpName === pName))) {
        isParent = true
      }

      if (isParent) matched.push(c)
    }

    matched.sort(function(a, b) {
      var wa = (a.isWired || a.type === "WIRED") ? 0 : 1
      var wb = (b.isWired || b.type === "WIRED") ? 0 : 1
      if (wa !== wb) return wa - wb
      return (a.uplinkPort || a.channel || 0) - (b.uplinkPort || b.channel || 0)
    })
    return matched
  }

  function getUnassignedClients() {
    var allClients = siteClients()
    var devList = siteDevices()
    var unassigned = []
    for (var i = 0; i < allClients.length; i++) {
      var c = allClients[i]
      var matched = false
      for (var d = 0; d < devList.length; d++) {
        var clients = getClientsForDevice(devList[d])
        if (clients.indexOf(c) >= 0) {
          matched = true
          break
        }
      }
      if (!matched) unassigned.push(c)
    }
    return unassigned
  }

  function getTier1Children() {
    var roots = getRootDevices()
    var gw = roots.length > 0 ? roots[0] : getGateway()
    return getChildDevices(gw)
  }

  function getTier2Children(parentDev) {
    return getChildDevices(parentDev)
  }

  function portSpeedLabel(dev) {
    if (!dev || !dev.parentPort) return ""
    var port = "Port " + dev.parentPort
    if (dev.uplinkSpeed >= 10000) return port + " · 10G"
    if (dev.uplinkSpeed >= 2500) return port + " · 2.5G"
    if (dev.uplinkSpeed >= 1000) return port + " · 1G"
    return port
  }

  function apBandsLabel(dev) {
    if (!dev) return ""
    var cls = getClientsForDevice(dev)
    var bands = []
    for (var i = 0; i < cls.length; i++) {
      var b = cls[i].band
      if (b && b !== "Ethernet" && bands.indexOf(b) < 0) {
        bands.push(b)
      }
    }
    if (bands.length > 0) return bands.join(" · ")
    var m = String(dev.model || "").toLowerCase()
    if (m.indexOf("u7") >= 0) return "6 GHz · 5 GHz · 2.4 GHz"
    if (m.indexOf("u6") >= 0 || m.indexOf("nano") >= 0 || m.indexOf("hd") >= 0) return "5 GHz · 2.4 GHz"
    return "5 GHz · 2.4 GHz"
  }

  // --------------------------------------------------------------------------
  // Dynamic Flattened Tree Builder with Dual Collapse Controls
  // --------------------------------------------------------------------------
  function buildFlatTree() {
    var out = []
    var roots = getRootDevices()
    var visited = {}

    function traverse(dev, depth, isLastChild, branchPrefix) {
      if (!dev) return
      var devId = String(dev.id || dev.mac || dev.name || depth)
      if (visited[devId]) return
      visited[devId] = true

      var devKey = depth === 0 ? "gw" : ("dev_" + devId)
      var clientKey = "clients_" + devId

      var childDevs = getChildDevices(dev)
      var childClients = getClientsForDevice(dev)

      var devCollapsed = isDevCollapsed(devKey)
      var clientsCollapsed = isClientsCollapsed(clientKey)

      var devObj = Object.assign({}, dev, {
        type: "device",
        device: dev,
        id: dev.id,
        name: dev.name,
        model: dev.model,
        ip: dev.ip,
        online: dev.online,
        parentPort: dev.parentPort,
        uplinkSpeed: dev.uplinkSpeed,
        depth: depth,
        key: devKey,
        clientKey: clientKey,
        hasDownstream: childDevs.length > 0 || childClients.length > 0,
        hasChildDevs: childDevs.length > 0,
        hasClients: childClients.length > 0,
        downstreamCount: childDevs.length + childClients.length,
        childDevCount: childDevs.length,
        clientCount: childClients.length,
        isDevCollapsed: devCollapsed,
        isClientsCollapsed: clientsCollapsed,
        isCollapsed: devCollapsed,
        isLast: isLastChild,
        branchPrefix: branchPrefix
      })
      out.push(devObj)

      var nextPrefix = branchPrefix + (isLastChild ? "   " : "│  ")

      // 1. Traverse child UniFi devices IF child devices are not collapsed
      if (!devCollapsed) {
        for (var i = 0; i < childDevs.length; i++) {
          var isLastDev = (i === childDevs.length - 1) && (clientsCollapsed || childClients.length === 0)
          traverse(childDevs[i], depth + 1, isLastDev, nextPrefix)
        }
      }

      // 2. Traverse connected clients IF clients are not collapsed
      if (!clientsCollapsed) {
        for (var j = 0; j < childClients.length; j++) {
          var isLastClient = (j === childClients.length - 1)
          out.push(Object.assign({}, childClients[j], {
            type: "client",
            client: childClients[j],
            parentDevice: dev,
            depth: depth + 1,
            isLast: isLastClient,
            branchPrefix: nextPrefix
          }))
        }
      }
    }

    for (var r = 0; r < roots.length; r++) {
      traverse(roots[r], 0, r === roots.length - 1, "")
    }

    var unassigned = getUnassignedClients()
    for (var u = 0; u < unassigned.length; u++) {
      out.push(Object.assign({}, unassigned[u], {
        type: "client",
        client: unassigned[u],
        parentDevice: null,
        depth: 1,
        isLast: u === unassigned.length - 1,
        branchPrefix: ""
      }))
    }

    return out
  }

  // --------------------------------------------------------------------------
  // Header: Hierarchy Breadcrumbs & Global Expand / Collapse All
  // --------------------------------------------------------------------------
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.space(6)

    Text {
      textFormat: Text.PlainText;
      text: "Gateway ➔ Switch ➔ AP ➔ Clients"
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption - 2
      font.bold: true
      Layout.fillWidth: true
    }

    Rectangle {
      implicitHeight: Style.space(18)
      implicitWidth: toggleAllRow.implicitWidth + Style.space(10)
      radius: 3
      color: toggleAllMouse.containsMouse ? root.cardHover : root.card
      border.width: 1
      border.color: root.outline

      RowLayout {
        id: toggleAllRow
        anchors.centerIn: parent
        spacing: Style.space(3)
        Text {
          textFormat: Text.PlainText;
          text: root.hasAnyCollapsed() ? "▶" : "▼"
          color: root.accent
          font.family: root.fontFamily
          font.pixelSize: 8
        }
        Text {
          textFormat: Text.PlainText;
          text: root.hasAnyCollapsed() ? "Expand All" : "Collapse All"
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: 8
          font.bold: true
        }
      }

      MouseArea {
        id: toggleAllMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.hasAnyCollapsed()) {
            root.expandAll()
          } else {
            root.collapseAll()
          }
        }
      }

      PanelToolTip {
        visible: toggleAllMouse.containsMouse
        text: root.hasAnyCollapsed() ? "Expand all topology tree levels" : "Collapse all topology tree levels"
        fontFamily: root.fontFamily
      }
    }
  }

  // --------------------------------------------------------------------------
  // Dynamic Dynamic Tree: Repeater of Flattened Dynamic Tree Nodes
  // --------------------------------------------------------------------------
  Repeater {
    model: root.buildFlatTree()
    delegate: ColumnLayout {
      id: nodeDelegate
      required property var modelData
      required property int index

      Layout.fillWidth: true
      spacing: Style.space(2)

      // ======================================================================
      // CASE 1: ROOT GATEWAY NODE (depth === 0)
      // ======================================================================
      Rectangle {
        id: gwCard
        visible: modelData.type === "device" && modelData.depth === 0
        property var gw: modelData.device
        Layout.fillWidth: true
        implicitHeight: gwCol.implicitHeight + Style.space(14)
        radius: 4
        color: root.track
        border.width: 1
        border.color: root.accent

        ColumnLayout {
          id: gwCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(8)
          spacing: Style.space(4)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(6)

            Rectangle {
              width: Style.space(8)
              height: Style.space(8)
              radius: width / 2
              color: (gwCard.gw && gwCard.gw.online) ? root.healthy : root.urgent
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText;
              text: (gwCard.gw && gwCard.gw.name) ? gwCard.gw.name : "UniFi Gateway"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              elide: Text.ElideRight
              Layout.maximumWidth: Style.space(110)
              Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
              height: Style.space(16)
              width: gwPillText.implicitWidth + Style.space(8)
              radius: 2
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
              Text {
                textFormat: Text.PlainText;
                id: gwPillText
                anchors.centerIn: parent
                text: "GATEWAY"
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 8
                font.bold: true
              }
            }

            // Button 1: UniFi Devices Collapse / Expand Button
            Rectangle {
              id: gwCollapseBtn
              visible: true
              opacity: modelData.hasChildDevs ? 1.0 : 0.45
              height: Style.space(16)
              width: gwDevsRow.implicitWidth + Style.space(8)
              radius: 2
              color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.cardHover : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              border.width: 1
              border.color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.outline : root.accent

              RowLayout {
                id: gwDevsRow
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text {
                  textFormat: Text.PlainText;
                  text: "⚡"
                  color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
                Text {
                  textFormat: Text.PlainText;
                  text: (modelData.hasChildDevs ? (modelData.childDevCount + " Devs ") : "0 Devs ") + (modelData.isDevCollapsed ? "▶" : "▼")
                  color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 8
                  font.bold: true
                }
              }

              MouseArea {
                id: gwCollapseMouse
                anchors.fill: parent
                hoverEnabled: !!modelData.hasChildDevs
                cursorShape: modelData.hasChildDevs ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (modelData.hasChildDevs) root.toggleDevCollapse(modelData.key)
                }
              }

              PanelToolTip {
                visible: gwCollapseMouse.containsMouse
                text: !modelData.hasChildDevs ? "No downstream UniFi devices" : (modelData.isCollapsed ? ("Expand " + modelData.childDevCount + " downstream gateway devices") : ("Collapse " + modelData.childDevCount + " downstream gateway devices"))
                fontFamily: root.fontFamily
              }
            }

            // Button 2: Clients Collapse / Expand Button
            Rectangle {
              id: gwClientsCollapseBtn
              visible: true
              opacity: modelData.hasClients ? 1.0 : 0.45
              height: Style.space(16)
              width: gwClientsRow.implicitWidth + Style.space(8)
              radius: 2
              color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.cardHover : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              border.width: 1
              border.color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.outline : root.accent

              RowLayout {
                id: gwClientsRow
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text {
                  textFormat: Text.PlainText;
                  text: "👥"
                  color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
                Text {
                  textFormat: Text.PlainText;
                  id: gwClientsText
                  text: (modelData.hasClients ? (modelData.clientCount + " Clients ") : "0 Clients ") + (modelData.isClientsCollapsed ? "▶" : "▼")
                  color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 8
                  font.bold: true
                }
              }

              MouseArea {
                id: gwClientsCollapseMouse
                anchors.fill: parent
                hoverEnabled: !!modelData.hasClients
                cursorShape: modelData.hasClients ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (modelData.hasClients) root.toggleClientsCollapse(modelData.clientKey)
                }
              }

              PanelToolTip {
                visible: gwClientsCollapseMouse.containsMouse
                text: !modelData.hasClients ? "No clients directly connected to gateway" : (modelData.isClientsCollapsed ? ("Expand " + modelData.clientCount + " connected clients") : ("Collapse " + modelData.clientCount + " connected clients"))
                fontFamily: root.fontFamily
              }
            }

            // Downstream Devices Count Badge (hidden: count already shown on gwCollapseBtn)
            Rectangle {
              visible: false
              height: Style.space(15)
              width: gwDownstreamText.implicitWidth + Style.space(8)
              radius: 2
              color: root.card
              border.width: 1
              border.color: root.outline
              Text {
                textFormat: Text.PlainText;
                id: gwDownstreamText
                anchors.centerIn: parent
                text: modelData.childDevCount + " devices"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 8
              }
            }

            Item { Layout.fillWidth: true }

            // SSH Action Button
            Rectangle {
              visible: !!(gwCard.gw && gwCard.gw.ip)
              implicitHeight: Style.space(20)
              implicitWidth: gwSshRow.implicitWidth + Style.space(12)
              radius: 3
              color: gwSshMouse.containsMouse ? root.accent : root.track
              border.width: 1
              border.color: root.accent
              RowLayout {
                id: gwSshRow
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { textFormat: Text.PlainText; text: ""; color: gwSshMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                Text { textFormat: Text.PlainText; id: gwSshText; text: "SSH"; color: gwSshMouse.containsMouse ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
              }
              MouseArea {
                id: gwSshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: if (gwCard.gw && gwCard.gw.ip) root.sshRequested(gwCard.gw.ip, "root")
              }

              PanelToolTip {
                visible: gwSshMouse.containsMouse
                text: "Open SSH terminal to gateway (" + (gwCard.gw ? gwCard.gw.ip : "") + ")"
                fontFamily: root.fontFamily
              }
            }

            // Multi-Protocol Action Chooser Button
            Rectangle {
              id: gwChooserBtn
              visible: !!(gwCard.gw && gwCard.gw.ip)
              implicitHeight: Style.space(20)
              implicitWidth: gwChooserBtnRow.implicitWidth + Style.space(10)
              radius: 3
              color: (root.activeChooserNode === "gw") ? root.accent : (gwChooserMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: (root.activeChooserNode === "gw") ? root.accent : root.outline
              RowLayout {
                id: gwChooserBtnRow
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { textFormat: Text.PlainText; text: "⚡"; color: (root.activeChooserNode === "gw") ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 3 }
                Text { textFormat: Text.PlainText; text: "Actions"; color: (root.activeChooserNode === "gw") ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: Style.font.caption - 2; font.bold: true }
              }
              MouseArea {
                id: gwChooserMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.activeChooserNode = (root.activeChooserNode === "gw") ? "" : "gw" }
              }
              PanelToolTip {
                visible: gwChooserMouse.containsMouse
                text: "Open multi-protocol action chooser for gateway"
                fontFamily: root.fontFamily
              }
            }
          }

          Text {
            textFormat: Text.PlainText;
            text: (gwCard.gw ? gwCard.gw.model : "") + (gwCard.gw && gwCard.gw.ip ? " · IP: " + gwCard.gw.ip : "") + (root.site && root.site.isp ? " · ISP: " + root.site.isp : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 2
          }

          // Multi-Protocol Action Chooser Popover
          MultiProtocolChooser {
            visible: root.activeChooserNode === "gw"
            Layout.fillWidth: true
            device: gwCard.gw
            preferredTerminal: root.preferredTerminal
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            urgent: root.urgent
            healthy: root.healthy
            fontFamily: root.fontFamily
            onLaunchSsh: function(ip, user) { root.sshRequested(ip, user) }
            onLaunchPing: function(ip) { root.pingRequested(ip) }
            onOpenWeb: function(url) { root.webRequested(url) }
            onCloseRequested: { root.activeChooserNode = "" }
          }
        }
      }

      // ======================================================================
      // CASE 2: TIER 1 DIRECT CHILDREN (depth === 1)
      // ======================================================================
      Rectangle {
        id: t1Card
        property var dev: modelData.device
        visible: modelData.type === "device" && modelData.depth === 1
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(14)
        implicitHeight: t1Col.implicitHeight + Style.space(12)
        radius: 4
        color: root.card
        border.width: 1
        border.color: (t1Card.dev && root.isSwitch(t1Card.dev)) ? root.outline : Qt.rgba(root.dim.r, root.dim.g, root.dim.b, 0.2)

        ColumnLayout {
          id: t1Col
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(7)
          spacing: Style.space(3)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Text {
              textFormat: Text.PlainText;
              text: modelData.isLast ? "└─" : "├─"
              color: root.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Rectangle {
              width: Style.space(7)
              height: Style.space(7)
              radius: width / 2
              color: (t1Card.dev && t1Card.dev.online) ? root.healthy : root.urgent
            }

            Text {
              textFormat: Text.PlainText;
              text: (t1Card.dev && (t1Card.dev.name || t1Card.dev.model)) || "Device"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
              Layout.minimumWidth: Style.space(45)
              Layout.maximumWidth: Style.space(90)
            }

            // Port badge with parent port number and link speed
            Rectangle {
              visible: !!(t1Card.dev && t1Card.dev.parentPort)
              height: Style.space(14)
              width: t1PortText.implicitWidth + Style.space(8)
              radius: 2
              color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
              Text {
                textFormat: Text.PlainText;
                id: t1PortText
                anchors.centerIn: parent
                text: t1Card.dev ? root.portSpeedLabel(t1Card.dev) : ""
                color: root.healthy
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Device Type Pill
            Rectangle {
              height: Style.space(14)
              width: t1PillText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: t1PillText
                anchors.centerIn: parent
                text: t1Card.dev ? root.deviceTypePill(t1Card.dev) : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Radio Channel Band Badge (for APs)
            Rectangle {
              visible: !!(t1Card.dev && root.isAccessPoint(t1Card.dev))
              height: Style.space(14)
              width: t1BandsText.implicitWidth + Style.space(8)
              radius: 2
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.16)
              border.width: 1
              border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
              Text {
                textFormat: Text.PlainText;
                id: t1BandsText
                anchors.centerIn: parent
                text: t1Card.dev ? root.apBandsLabel(t1Card.dev) : ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Button 1: UniFi Devices Collapse / Expand Button
            Rectangle {
              id: t1CollapseBtn
              visible: true
              opacity: modelData.hasChildDevs ? 1.0 : 0.45
              height: Style.space(14)
              width: t1DevsRow.implicitWidth + Style.space(8)
              radius: 2
              color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.track : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              border.width: 1
              border.color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.outline : root.accent

              RowLayout {
                id: t1DevsRow
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText;
                  text: "⚡"
                  color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                }
                Text {
                  textFormat: Text.PlainText;
                  text: (modelData.hasChildDevs ? (modelData.childDevCount + " Devs ") : "0 Devs ") + (modelData.isDevCollapsed ? "▶" : "▼")
                  color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                  font.bold: true
                }
              }

              MouseArea {
                id: t1CollapseMouse
                anchors.fill: parent
                hoverEnabled: !!modelData.hasChildDevs
                cursorShape: modelData.hasChildDevs ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (modelData.hasChildDevs) root.toggleDevCollapse(modelData.key)
                }
              }

              PanelToolTip {
                visible: t1CollapseMouse.containsMouse
                text: !modelData.hasChildDevs ? "No downstream UniFi devices" : (modelData.isCollapsed ? ("Expand " + modelData.childDevCount + " downstream devices") : ("Collapse " + modelData.childDevCount + " downstream devices"))
                fontFamily: root.fontFamily
              }
            }

            // Button 2: Clients Collapse / Expand Button
            Rectangle {
              id: t1ClientsCollapseBtn
              visible: true
              opacity: modelData.hasClients ? 1.0 : 0.45
              height: Style.space(14)
              width: t1ClientsRow.implicitWidth + Style.space(8)
              radius: 2
              color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.track : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              border.width: 1
              border.color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.outline : root.accent

              RowLayout {
                id: t1ClientsRow
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText;
                  text: "👥"
                  color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                }
                Text {
                  textFormat: Text.PlainText;
                  id: t1ClientsText
                  text: (modelData.hasClients ? (modelData.clientCount + " Clients ") : "0 Clients ") + (modelData.isClientsCollapsed ? "▶" : "▼")
                  color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                  font.bold: true
                }
              }

              MouseArea {
                id: t1ClientsCollapseMouse
                anchors.fill: parent
                hoverEnabled: !!modelData.hasClients
                cursorShape: modelData.hasClients ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (modelData.hasClients) root.toggleClientsCollapse(modelData.clientKey)
                }
              }

              PanelToolTip {
                visible: t1ClientsCollapseMouse.containsMouse
                text: !modelData.hasClients ? "No clients connected to this device" : (modelData.isClientsCollapsed ? ("Expand " + modelData.clientCount + " connected clients") : ("Collapse " + modelData.clientCount + " connected clients"))
                fontFamily: root.fontFamily
              }
            }

            // Downstream Devices Count Badge (hidden: count already shown on t1CollapseBtn)
            Rectangle {
              visible: false
              height: Style.space(14)
              width: t1DownstreamText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: t1DownstreamText
                anchors.centerIn: parent
                text: (modelData.childDevCount || 0) + " devs"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
            }

            Item { Layout.fillWidth: true }

            // Action Button: SSH for switches, Ping for others
            Rectangle {
              visible: !!(t1Card.dev && t1Card.dev.ip)
              implicitHeight: Style.space(18)
              implicitWidth: t1ActionRow.implicitWidth + Style.space(10)
              radius: 3
              color: t1ActionMouse.containsMouse ? root.accent : root.track
              border.width: 1
              border.color: root.outline
              RowLayout {
                id: t1ActionRow
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText;
                  text: (t1Card.dev && root.isSwitch(t1Card.dev)) ? "" : ""
                  color: t1ActionMouse.containsMouse ? root.accentForeground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
                Text {
                  textFormat: Text.PlainText;
                  id: t1ActionText
                  text: (t1Card.dev && root.isSwitch(t1Card.dev)) ? "SSH" : "Ping"
                  color: t1ActionMouse.containsMouse ? root.accentForeground : root.dim
                  font.family: root.fontFamily
                  font.pixelSize: 8
                }
              }
              MouseArea {
                id: t1ActionMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (!t1Card.dev) return
                  if (root.isSwitch(t1Card.dev)) {
                    root.sshRequested(t1Card.dev.ip, "root")
                  } else {
                    root.pingRequested(t1Card.dev.ip)
                  }
                }
              }

              PanelToolTip {
                visible: t1ActionMouse.containsMouse
                text: root.isSwitch(modelData) ? ("Open SSH session to switch (" + modelData.ip + ")") : ("Ping device (" + modelData.ip + ")")
                fontFamily: root.fontFamily
              }
            }

            // Multi-Protocol Action Chooser Button
            Rectangle {
              id: t1ChooserBtn
              visible: !!(t1Card.dev && t1Card.dev.ip)
              implicitHeight: Style.space(18)
              implicitWidth: t1ChooserBtnRow.implicitWidth + Style.space(8)
              radius: 3
              color: ((t1Card.dev && root.activeChooserNode === ("t1_" + t1Card.dev.id)) || root.activeChooserNode === modelData.key) ? root.accent : (t1ChooserMouse.containsMouse ? root.cardHover : root.track)
              border.width: 1
              border.color: ((t1Card.dev && root.activeChooserNode === ("t1_" + t1Card.dev.id)) || root.activeChooserNode === modelData.key) ? root.accent : root.outline
              RowLayout {
                id: t1ChooserBtnRow
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text { textFormat: Text.PlainText; text: "⚡"; color: ((t1Card.dev && root.activeChooserNode === ("t1_" + t1Card.dev.id)) || root.activeChooserNode === modelData.key) ? root.accentForeground : root.accent; font.family: root.fontFamily; font.pixelSize: 8 }
              }
              MouseArea {
                id: t1ChooserMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var nid = "t1_" + (t1Card.dev ? t1Card.dev.id : "")
                  root.activeChooserNode = (root.activeChooserNode === nid || root.activeChooserNode === modelData.key) ? "" : nid
                }
              }
              PanelToolTip {
                visible: t1ChooserMouse.containsMouse
                text: "Open multi-protocol action chooser for " + (t1Card.dev ? (t1Card.dev.name || "device") : "device")
                fontFamily: root.fontFamily
              }
            }
          }

          Text {
            textFormat: Text.PlainText;
            text: (t1Card.dev && t1Card.dev.model ? t1Card.dev.model : "") + (t1Card.dev && t1Card.dev.ip ? " · IP: " + t1Card.dev.ip : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 3
          }

          // Multi-Protocol Action Chooser Popover
          MultiProtocolChooser {
            visible: ((t1Card.dev && root.activeChooserNode === ("t1_" + t1Card.dev.id)) || root.activeChooserNode === modelData.key)
            Layout.fillWidth: true
            device: t1Card.dev
            preferredTerminal: root.preferredTerminal
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            urgent: root.urgent
            healthy: root.healthy
            fontFamily: root.fontFamily
            onLaunchSsh: function(ip, user) { root.sshRequested(ip, user) }
            onLaunchPing: function(ip) { root.pingRequested(ip) }
            onOpenWeb: function(url) { root.webRequested(url) }
            onCloseRequested: { root.activeChooserNode = "" }
          }
        }
      }

      // ======================================================================
      // CASE 3: DYNAMIC DOWNSTREAM DEVICES (depth >= 2, arbitrary daisy-chaining)
      // ======================================================================
      Rectangle {
        id: t2Card
        property var dev: modelData.device
        visible: modelData.type === "device" && modelData.depth >= 2
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(14) * modelData.depth
        implicitHeight: t2Col.implicitHeight + Style.space(10)
        radius: 4
        color: root.card
        border.width: 1
        border.color: root.outline

        ColumnLayout {
          id: t2Col
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(6)
          spacing: Style.space(2)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Text {
              textFormat: Text.PlainText;
              text: modelData.isLast ? "└─" : "├─"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
            }

            Rectangle {
              width: Style.space(6)
              height: Style.space(6)
              radius: width / 2
              color: (t2Card.dev && t2Card.dev.online) ? root.healthy : root.urgent
            }

            Text {
              textFormat: Text.PlainText;
              text: (t2Card.dev && (t2Card.dev.name || t2Card.dev.model)) || "Device"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 1
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
              Layout.minimumWidth: Style.space(40)
              Layout.maximumWidth: Style.space(80)
            }

            // Port badge (uplink port number on parent switch/gateway)
            Rectangle {
              visible: !!(t2Card.dev && t2Card.dev.parentPort)
              height: Style.space(13)
              width: t2PortText.implicitWidth + Style.space(6)
              radius: 2
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              Text {
                textFormat: Text.PlainText;
                id: t2PortText
                anchors.centerIn: parent
                text: t2Card.dev ? root.portSpeedLabel(t2Card.dev) : ""
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Device Type Pill
            Rectangle {
              height: Style.space(13)
              width: t2PillText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: t2PillText
                anchors.centerIn: parent
                text: t2Card.dev ? root.deviceTypePill(t2Card.dev) : ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Radio Channel Band Badge (for APs)
            Rectangle {
              visible: !!(t2Card.dev && root.isAccessPoint(t2Card.dev))
              height: Style.space(13)
              width: t2BandsText.implicitWidth + Style.space(6)
              radius: 2
              color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
              Text {
                textFormat: Text.PlainText;
                id: t2BandsText
                anchors.centerIn: parent
                text: t2Card.dev ? root.apBandsLabel(t2Card.dev) : ""
                color: root.healthy
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Button 1: UniFi Devices Collapse / Expand Button
            Rectangle {
              id: t2CollapseBtn
              visible: true
              opacity: modelData.hasChildDevs ? 1.0 : 0.45
              height: Style.space(13)
              width: t2DevsRow.implicitWidth + Style.space(8)
              radius: 2
              color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.track : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              border.width: 1
              border.color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.outline : root.accent

              RowLayout {
                id: t2DevsRow
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText;
                  text: "⚡"
                  color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                }
                Text {
                  textFormat: Text.PlainText;
                  text: (modelData.hasChildDevs ? (modelData.childDevCount + " Devs ") : "0 Devs ") + (modelData.isDevCollapsed ? "▶" : "▼")
                  color: (!modelData.hasChildDevs || modelData.isDevCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                  font.bold: true
                }
              }

              MouseArea {
                id: t2CollapseMouse
                anchors.fill: parent
                hoverEnabled: !!modelData.hasChildDevs
                cursorShape: modelData.hasChildDevs ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (modelData.hasChildDevs) root.toggleDevCollapse(modelData.key)
                }
              }

              PanelToolTip {
                visible: t2CollapseMouse.containsMouse
                text: !modelData.hasChildDevs ? "No downstream UniFi devices" : (modelData.isCollapsed ? ("Expand " + modelData.childDevCount + " downstream devices") : ("Collapse " + modelData.childDevCount + " downstream devices"))
                fontFamily: root.fontFamily
              }
            }

            // Button 2: Connected Clients Collapse / Expand Button
            Rectangle {
              id: t2ClientsCollapseBtn
              visible: true
              opacity: modelData.hasClients ? 1.0 : 0.45
              height: Style.space(13)
              width: t2ClientsRow.implicitWidth + Style.space(8)
              radius: 2
              color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.track : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.15)
              border.width: 1
              border.color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.outline : root.accent

              RowLayout {
                id: t2ClientsRow
                anchors.centerIn: parent
                spacing: Style.space(2)
                Text {
                  textFormat: Text.PlainText;
                  text: "👥"
                  color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                }
                Text {
                  textFormat: Text.PlainText;
                  id: t2ClientsText
                  text: (modelData.hasClients ? (modelData.clientCount + " Clients ") : "0 Clients ") + (modelData.isClientsCollapsed ? "▶" : "▼")
                  color: (!modelData.hasClients || modelData.isClientsCollapsed) ? root.dim : root.accent
                  font.family: root.fontFamily
                  font.pixelSize: 7
                  font.bold: true
                }
              }

              MouseArea {
                id: t2ClientsCollapseMouse
                anchors.fill: parent
                hoverEnabled: !!modelData.hasClients
                cursorShape: modelData.hasClients ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                  if (modelData.hasClients) root.toggleClientsCollapse(modelData.clientKey)
                }
              }

              PanelToolTip {
                visible: t2ClientsCollapseMouse.containsMouse
                text: !modelData.hasClients ? "No clients connected to this device" : (modelData.isClientsCollapsed ? ("Expand " + modelData.clientCount + " connected clients") : ("Collapse " + modelData.clientCount + " connected clients"))
                fontFamily: root.fontFamily
              }
            }

            // Downstream Devices Count Badge (hidden: count already shown on t2CollapseBtn)
            Rectangle {
              visible: false
              height: Style.space(13)
              width: t2DevsCountText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: t2DevsCountText
                anchors.centerIn: parent
                text: (modelData.childDevCount || 0) + " devs"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
            }

            Item { Layout.fillWidth: true }

            // Ping Button
            Rectangle {
              visible: !!(t2Card.dev && t2Card.dev.ip)
              implicitHeight: Style.space(16)
              implicitWidth: t2PingText.implicitWidth + Style.space(8)
              radius: 2
              color: t2PingMouse.containsMouse ? root.cardHover : root.track
              Text {
                textFormat: Text.PlainText;
                id: t2PingText
                anchors.centerIn: parent
                text: "Ping"
                color: t2PingMouse.containsMouse ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: 8
              }
              MouseArea {
                id: t2PingMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (t2Card.dev && t2Card.dev.ip) root.pingRequested(t2Card.dev.ip)
                }
              }

              PanelToolTip {
                visible: t2PingMouse.containsMouse
                text: "Ping device (" + modelData.ip + ")"
                fontFamily: root.fontFamily
              }
            }

            // Action Chooser Button
            Rectangle {
              id: t2ChooserBtn
              visible: !!(t2Card.dev && t2Card.dev.ip)
              implicitHeight: Style.space(16)
              implicitWidth: t2ChooserText.implicitWidth + Style.space(8)
              radius: 2
              color: ((t2Card.dev && root.activeChooserNode === ("t2_" + (t2Card.dev.id || index))) || root.activeChooserNode === modelData.key || t2ChooserMouse.containsMouse) ? root.cardHover : root.track
              Text {
                textFormat: Text.PlainText;
                id: t2ChooserText
                anchors.centerIn: parent
                text: "⚡"
                color: ((t2Card.dev && root.activeChooserNode === ("t2_" + (t2Card.dev.id || index))) || root.activeChooserNode === modelData.key || t2ChooserMouse.containsMouse) ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: 8
              }
              MouseArea {
                id: t2ChooserMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  var nid = "t2_" + (t2Card.dev ? (t2Card.dev.id || index) : index)
                  root.activeChooserNode = (root.activeChooserNode === nid || root.activeChooserNode === modelData.key) ? "" : nid
                }
              }
              PanelToolTip {
                visible: t2ChooserMouse.containsMouse
                text: "Open multi-protocol action chooser for " + (t2Card.dev ? (t2Card.dev.name || "device") : "device")
                fontFamily: root.fontFamily
              }
            }
          }

          Text {
            textFormat: Text.PlainText;
            text: (t2Card.dev && t2Card.dev.model ? t2Card.dev.model : "") + (t2Card.dev && t2Card.dev.ip ? " · IP: " + t2Card.dev.ip : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 3
          }

          // Multi-Protocol Action Chooser Popover
          MultiProtocolChooser {
            visible: ((t2Card.dev && root.activeChooserNode === ("t2_" + (t2Card.dev.id || index))) || root.activeChooserNode === modelData.key)
            Layout.fillWidth: true
            device: t2Card.dev
            preferredTerminal: root.preferredTerminal
            foreground: root.foreground
            dim: root.dim
            accent: root.accent
            card: root.card
            cardHover: root.cardHover
            track: root.track
            outline: root.outline
            urgent: root.urgent
            healthy: root.healthy
            fontFamily: root.fontFamily
            onLaunchSsh: function(ip, user) { root.sshRequested(ip, user) }
            onLaunchPing: function(ip) { root.pingRequested(ip) }
            onOpenWeb: function(url) { root.webRequested(url) }
            onCloseRequested: { root.activeChooserNode = "" }
          }
        }
      }

      // ======================================================================
      // CASE 4: CONNECTED CLIENTS (Dynamic nesting directly under parent device)
      // ======================================================================
      Rectangle {
        id: clientCard
        property var cl: modelData.client
        visible: modelData.type === "client" && !!clientCard.cl
        Layout.fillWidth: true
        Layout.leftMargin: Style.space(14) * modelData.depth
        implicitHeight: clientInnerCol.implicitHeight + Style.space(8)
        radius: 3
        color: clientHoverMouse.containsMouse ? root.cardHover : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.03)
        border.width: 1
        border.color: clientHoverMouse.containsMouse ? root.accent : root.outline

        ColumnLayout {
          id: clientInnerCol
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.margins: Style.space(5)
          spacing: Style.space(2)

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(5)

            Text {
              textFormat: Text.PlainText;
              text: modelData.isLast ? "└─" : "├─"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
            }

            // Connection Medium Icon: WiFi vs Ethernet
            Text {
              textFormat: Text.PlainText;
              text: (clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED")) ? "󰈀" : ""
              color: (clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED")) ? root.healthy : root.accent
              font.family: root.fontFamily
              font.pixelSize: 8
            }

            // Client name / hostname
            Text {
              textFormat: Text.PlainText;
              text: (clientCard.cl && (clientCard.cl.name || clientCard.cl.hostname || clientCard.cl.ip)) || "Client"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption - 2
              font.bold: true
              elide: Text.ElideRight
              Layout.maximumWidth: Style.space(90)
            }

            // Channel Band Badge (for Wireless Clients)
            Rectangle {
              visible: !(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED"))
              height: Style.space(12)
              width: clientBandText.implicitWidth + Style.space(6)
              radius: 2
              color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.2)
              Text {
                textFormat: Text.PlainText;
                id: clientBandText
                anchors.centerIn: parent
                text: (clientCard.cl && clientCard.cl.band ? clientCard.cl.band : "WiFi") + (clientCard.cl && clientCard.cl.channel ? " · Ch " + clientCard.cl.channel : "")
                color: root.accent
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Port Number Badge (for Wired Clients)
            Rectangle {
              visible: !!(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED"))
              height: Style.space(12)
              width: wiredPortText.implicitWidth + Style.space(6)
              radius: 2
              color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
              Text {
                textFormat: Text.PlainText;
                id: wiredPortText
                anchors.centerIn: parent
                text: (clientCard.cl && clientCard.cl.uplinkPort) ? (clientCard.cl.uplinkPort + (clientCard.cl.uplinkSpeed ? (" · " + (clientCard.cl.uplinkSpeed >= 1000 ? (clientCard.cl.uplinkSpeed / 1000 + "G") : (clientCard.cl.uplinkSpeed + "M"))) : "")) : "Ethernet"
                color: root.healthy
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            // Wireless Protocol / Generation Badge
            Rectangle {
              visible: !(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED")) && !!(clientCard.cl && clientCard.cl.radioProto)
              height: Style.space(12)
              width: clientProtoText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: clientProtoText
                anchors.centerIn: parent
                text: (clientCard.cl && clientCard.cl.radioProto) || ""
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
            }

            // Wired Link Protocol Badge
            Rectangle {
              visible: !!(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED") && clientCard.cl.radioProto)
              height: Style.space(12)
              width: wiredProtoText.implicitWidth + Style.space(6)
              radius: 2
              color: root.track
              Text {
                textFormat: Text.PlainText;
                id: wiredProtoText
                anchors.centerIn: parent
                text: (clientCard.cl && clientCard.cl.radioProto) || "Wired"
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
            }

            // Wireless Signal Strength Badge (e.g. -46 dBm)
            Rectangle {
              visible: !(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED")) && !!(clientCard.cl && clientCard.cl.signal !== undefined && clientCard.cl.signal !== 0)
              height: Style.space(12)
              width: clientSignalText.implicitWidth + Style.space(6)
              radius: 2
              color: Qt.rgba(root.healthy.r, root.healthy.g, root.healthy.b, 0.15)
              Text {
                textFormat: Text.PlainText;
                id: clientSignalText
                anchors.centerIn: parent
                text: (clientCard.cl && clientCard.cl.signal ? clientCard.cl.signal : 0) + " dBm"
                color: root.healthy
                font.family: root.fontFamily
                font.pixelSize: 7
                font.bold: true
              }
            }

            Item { Layout.fillWidth: true }

            // Ping Button (Wireless)
            Rectangle {
              visible: !(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED")) && !!(clientCard.cl && clientCard.cl.ip)
              implicitHeight: Style.space(15)
              implicitWidth: clientPingText.implicitWidth + Style.space(8)
              radius: 2
              color: clientPingMouse.containsMouse ? root.accent : root.track
              Text {
                textFormat: Text.PlainText;
                id: clientPingText
                anchors.centerIn: parent
                text: "Ping"
                color: clientPingMouse.containsMouse ? root.accentForeground : root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
              MouseArea {
                id: clientPingMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (clientCard.cl && clientCard.cl.ip) root.pingRequested(clientCard.cl.ip)
                }
              }
              PanelToolTip {
                visible: clientPingMouse.containsMouse
                text: "Ping wireless client (" + (clientCard.cl ? clientCard.cl.ip : "") + ")"
                fontFamily: root.fontFamily
              }
            }

            // Ping Button (Wired)
            Rectangle {
              visible: !!(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED") && clientCard.cl.ip)
              implicitHeight: Style.space(15)
              implicitWidth: wiredPingText.implicitWidth + Style.space(8)
              radius: 2
              color: wiredPingMouse.containsMouse ? root.accent : root.track
              Text {
                textFormat: Text.PlainText;
                id: wiredPingText
                anchors.centerIn: parent
                text: "Ping"
                color: wiredPingMouse.containsMouse ? root.accentForeground : root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
              MouseArea {
                id: wiredPingMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (clientCard.cl && clientCard.cl.ip) root.pingRequested(clientCard.cl.ip)
                }
              }
              PanelToolTip {
                visible: wiredPingMouse.containsMouse
                text: "Ping wired client (" + (clientCard.cl ? clientCard.cl.ip : "") + ")"
                fontFamily: root.fontFamily
              }
            }

            // Copy IP Button (Wireless)
            Rectangle {
              visible: !(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED")) && !!(clientCard.cl && clientCard.cl.ip)
              implicitHeight: Style.space(15)
              implicitWidth: Style.space(15)
              radius: 2
              color: clientCopyMouse.containsMouse ? root.cardHover : root.track
              Text {
                textFormat: Text.PlainText;
                anchors.centerIn: parent
                text: ""
                color: clientCopyMouse.containsMouse ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
              MouseArea {
                id: clientCopyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (clientCard.cl && clientCard.cl.ip) Quickshell.execDetached(["wl-copy", clientCard.cl.ip])
                }
              }
              PanelToolTip {
                visible: clientCopyMouse.containsMouse
                text: "Copy " + (clientCard.cl ? clientCard.cl.ip : "") + " to clipboard"
                fontFamily: root.fontFamily
              }
            }

            // Copy IP Button (Wired)
            Rectangle {
              visible: !!(clientCard.cl && (clientCard.cl.isWired || clientCard.cl.type === "WIRED") && clientCard.cl.ip)
              implicitHeight: Style.space(15)
              implicitWidth: Style.space(15)
              radius: 2
              color: wiredCopyMouse.containsMouse ? root.cardHover : root.track
              Text {
                textFormat: Text.PlainText;
                anchors.centerIn: parent
                text: ""
                color: wiredCopyMouse.containsMouse ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: 7
              }
              MouseArea {
                id: wiredCopyMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (clientCard.cl && clientCard.cl.ip) Quickshell.execDetached(["wl-copy", clientCard.cl.ip])
                }
              }
              PanelToolTip {
                visible: wiredCopyMouse.containsMouse
                text: "Copy " + (clientCard.cl ? clientCard.cl.ip : "") + " to clipboard"
                fontFamily: root.fontFamily
              }
            }
          }

          // Sub-row: IP, MAC, Link / Uplink details
          Text {
            textFormat: Text.PlainText;
            text: (clientCard.cl && clientCard.cl.ip ? "IP: " + clientCard.cl.ip : "") + (clientCard.cl && clientCard.cl.mac ? " · " + clientCard.cl.mac : "") + (clientCard.cl && clientCard.cl.rxRate ? " · ↓ " + clientCard.cl.rxRate + "M  ↑ " + clientCard.cl.txRate + "M" : "")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption - 3
          }
        }

        MouseArea {
          id: clientHoverMouse
          anchors.fill: parent
          hoverEnabled: true
        }
      }
    }
  }
}
