import QtQuick
import Quickshell.Io
import "GlobeModel.js" as GlobeModel

Item {
  id: root

  property var countries: []
  property var sites: []
  property var connections: []
  property var sdwan: null
  property var selectedSite: null

  property real centreLatitude: -25
  property real centreLongitude: 120
  property real globeScale: 1.0
  property real minimumScale: 0.5
  property real maximumScale: 160.0
  property real longitudeSensitivity: 0.65
  property real latitudeSensitivity: 0.55
  property bool autoRotate: false
  property bool animateTraffic: true
  property real flowProgress: 0.0

  property color backgroundColor: "transparent"
  property color sphereColor: "#0f1520"
  property color landColor: "#1e293b"
  property color gridColor: "#334155"
  property color outlineColor: "#38bdf8"
  property color textColor: "#f3f4f5"
  property color healthy: "#10b981"
  property color backup: "#f59e0b"
  property color urgent: "#ff4d5a"
  property string fontFamily: "monospace"

  property var hoveredEvent: null
  property real hoverX: 0
  property real hoverY: 0
  property var preparedCountries: []
  property var preparedGrid: []
  property var preparedEvents: []
  property var preparedConnections: []
  property var hitEvents: []
  property var visibleSites: []

  signal siteActivated(var site)
  signal interactionStarted()

  NumberAnimation {
    id: flowAnimation
    target: root
    property: "flowProgress"
    from: 0.0
    to: 1.0
    duration: 2500
    loops: Animation.Infinite
    running: root.animateTraffic && root.visible && Boolean(root.preparedConnections && root.preparedConnections.length > 0)
  }

  onFlowProgressChanged: {
    if (root.visible && root.preparedConnections && root.preparedConnections.length > 0) {
      globeCanvas.requestPaint()
    }
  }

  function radius() {
    return Math.min(width, height) * 0.44 * globeScale
  }

  function zoomIn() {
    interactionStarted()
    globeScale = GlobeModel.clamp(globeScale * 1.35, minimumScale, maximumScale)
  }

  function zoomOut() {
    interactionStarted()
    globeScale = GlobeModel.clamp(globeScale / 1.35, minimumScale, maximumScale)
  }

  function resetZoom() {
    interactionStarted()
    globeScale = 1.0
  }

  function withAlpha(color, alpha) {
    if (typeof color === "string" && /^#[0-9a-fA-F]{6}$/.test(color)) {
      var value = parseInt(color.slice(1), 16)
      return Qt.rgba(
        ((value >> 16) & 255) / 255,
        ((value >> 8) & 255) / 255,
        (value & 255) / 255,
        alpha)
    }
    return Qt.rgba(color.r, color.g, color.b, alpha)
  }

  function focusCoordinate(latitude, longitude) {
    var nextLatitude = Number(latitude)
    var nextLongitude = Number(longitude)
    if (!isFinite(nextLatitude) || !isFinite(nextLongitude)) return
    centreLatitude = GlobeModel.clamp(nextLatitude, -78, 78)
    centreLongitude = GlobeModel.wrapLongitude(nextLongitude)
  }

  function focusSite(site) {
    if (!site) return
    var lat = Number(site.lat !== undefined ? site.lat : 0)
    var lng = Number(site.lng !== undefined ? site.lng : 0)
    focusCoordinate(lat, lng)
  }

  function prepareCoordinates(coordinates, latitudeFirst) {
    var output = []
    if (!Array.isArray(coordinates)) return output
    for (var i = 0; i < coordinates.length; i++) {
      var latitude = Number(coordinates[i][latitudeFirst ? 0 : 1])
      var longitude = Number(coordinates[i][latitudeFirst ? 1 : 0])
      if (!isFinite(latitude) || !isFinite(longitude)
          || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue
      latitude *= Math.PI / 180
      longitude *= Math.PI / 180
      var cosLatitude = Math.cos(latitude)
      output.push(
        cosLatitude * Math.cos(longitude),
        cosLatitude * Math.sin(longitude),
        Math.sin(latitude))
    }
    return output
  }

  function prepareCountryGeometry() {
    var output = []
    var rows = Array.isArray(countries) ? countries : []
    for (var i = 0; i < rows.length; i++) {
      var feature = rows[i]
      if (!feature || !feature.geometry) continue
      var geometry = feature.geometry
      var polygons = geometry.type === "Polygon" ? [geometry.coordinates] : geometry.coordinates
      if (!Array.isArray(polygons)) continue
      for (var p = 0; p < polygons.length; p++) {
        var ring = polygons[p] && polygons[p][0]
        var prepared = prepareCoordinates(ring, false)
        if (prepared.length >= 9) output.push({ world: prepared, projected: new Array(prepared.length) })
      }
    }
    return output
  }

  function prepareGridGeometry() {
    var output = []
    for (var latitude = -60; latitude <= 60; latitude += 30) {
      var parallel = []
      for (var longitude = -180; longitude <= 180; longitude += 3)
        parallel.push([latitude, longitude])
      output.push(prepareCoordinates(parallel, true))
    }
    for (var meridian = -150; meridian <= 180; meridian += 30) {
      var line = []
      for (var lat = -90; lat <= 90; lat += 3) line.push([lat, meridian])
      output.push(prepareCoordinates(line, true))
    }
    return output
  }

  function prepareConnectionGeometry() {
    var output = []
    var rawConns = Array.isArray(connections) && connections.length > 0
      ? connections
      : (sdwan && Array.isArray(sdwan.connections) ? sdwan.connections : [])
    if (!rawConns || rawConns.length === 0) return output

    var siteList = Array.isArray(sites) ? sites : []
    for (var i = 0; i < rawConns.length; i++) {
      var conn = rawConns[i]
      if (!conn) continue
      var siteA = GlobeModel.findSite(siteList, conn.siteA) || GlobeModel.findSite(siteList, conn.siteIdA) || GlobeModel.findSite(siteList, conn.hostIdA)
      var siteB = GlobeModel.findSite(siteList, conn.siteB) || GlobeModel.findSite(siteList, conn.siteIdB) || GlobeModel.findSite(siteList, conn.hostIdB)
      if (!siteA || !siteB) continue
      var latA = Number(siteA.lat)
      var lngA = Number(siteA.lng)
      var latB = Number(siteB.lat)
      var lngB = Number(siteB.lng)
      if (!isFinite(latA) || !isFinite(lngA) || !isFinite(latB) || !isFinite(lngB)) continue

      var vA = GlobeModel.latLngToVector(latA, lngA)
      var vB = GlobeModel.latLngToVector(latB, lngB)
      var theta = GlobeModel.angularDistance(vA, vB)
      if (theta < 0.001) continue

      var altitude = Math.min(0.14, Math.max(0.06, Math.sin(theta / 2) * 0.12 + 0.03))
      var steps = Math.max(20, Math.min(60, Math.round(theta * 24)))
      var waypoints = GlobeModel.generateArcWaypoints(vA, vB, altitude, steps)
      var ping = conn.ping !== undefined ? conn.ping : 0
      var isConnected = conn.connected !== false
      var color = GlobeModel.latencyColor(ping, isConnected, healthy, backup, urgent)

      output.push({
        connection: conn,
        siteA: siteA,
        siteB: siteB,
        vA: vA,
        vB: vB,
        theta: theta,
        altitude: altitude,
        waypoints: waypoints,
        color: color,
        ping: ping,
        connected: isConnected
      })
    }
    return output
  }

  function prepareSiteGeometry() {
    var output = []
    var rows = Array.isArray(sites) ? sites : []
    var rawConns = Array.isArray(connections) && connections.length > 0
      ? connections
      : (sdwan && Array.isArray(sdwan.connections) ? sdwan.connections : [])

    for (var i = 0; i < rows.length; i++) {
      var site = rows[i]
      var latitude = Number(site && (site.lat !== undefined ? site.lat : 0))
      var longitude = Number(site && (site.lng !== undefined ? site.lng : 0))
      if (!isFinite(latitude) || !isFinite(longitude)
          || latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) continue
      latitude *= Math.PI / 180
      longitude *= Math.PI / 180
      var cosLatitude = Math.cos(latitude)

      var sdwanInfo = ""
      if (rawConns && rawConns.length > 0) {
        for (var c = 0; c < rawConns.length; c++) {
          var conn = rawConns[c]
          var matchA = (site.name && String(site.name).toLowerCase() === String(conn.siteA).toLowerCase()) || (site.id && String(site.id).toLowerCase() === String(conn.siteA).toLowerCase()) || (conn.siteIdA && String(site.id).toLowerCase() === String(conn.siteIdA).toLowerCase()) || (conn.hostIdA && String(site.hostId || "").toLowerCase() === String(conn.hostIdA).toLowerCase())
          var matchB = (site.name && String(site.name).toLowerCase() === String(conn.siteB).toLowerCase()) || (site.id && String(site.id).toLowerCase() === String(conn.siteB).toLowerCase()) || (conn.siteIdB && String(site.id).toLowerCase() === String(conn.siteIdB).toLowerCase()) || (conn.hostIdB && String(site.hostId || "").toLowerCase() === String(conn.hostIdB).toLowerCase())
          if (matchA) {
            sdwanInfo = " SD-WAN ⇄ " + conn.siteB + " (" + (conn.ping !== undefined ? conn.ping + "ms" : "mesh") + ")"
            break
          } else if (matchB) {
            sdwanInfo = " SD-WAN ⇄ " + conn.siteA + " (" + (conn.ping !== undefined ? conn.ping + "ms" : "mesh") + ")"
            break
          }
        }
      }

      output.push({
        event: {
          id: site.id || String(i),
          title: site.name || "Site",
          status: site.status || "up",
          statusText: site.statusText || "",
          gatewayModel: site.gatewayModel || "",
          clientCount: site.clientCount || 0,
          deviceCount: site.deviceCount || 0,
          isp: site.isp || "",
          sdwanInfo: sdwanInfo,
          site: site
        },
        worldX: cosLatitude * Math.cos(longitude),
        worldY: cosLatitude * Math.sin(longitude),
        worldZ: Math.sin(latitude),
        visible: false,
        screenX: 0,
        screenY: 0,
        depth: -1,
        radius: 4.5
      })
    }
    return output
  }

  function paintCurve(ctx, coordinates, centreX, centreY, globeRadius,
                      sinLatitude, cosLatitude, sinLongitude, cosLongitude) {
    var drawing = false
    ctx.beginPath()
    for (var i = 0; i < coordinates.length; i += 3) {
      var horizontal = coordinates[i] * cosLongitude + coordinates[i + 1] * sinLongitude
      var xProjection = coordinates[i + 1] * cosLongitude - coordinates[i] * sinLongitude
      var yProjection = cosLatitude * coordinates[i + 2] - sinLatitude * horizontal
      var depth = sinLatitude * coordinates[i + 2] + cosLatitude * horizontal
      if (depth < 0) {
        drawing = false
        continue
      }
      var x = centreX + xProjection * globeRadius
      var y = centreY - yProjection * globeRadius
      if (!drawing) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
      drawing = true
    }
    ctx.stroke()
  }

  function paintGrid(ctx, centreX, centreY, globeRadius) {
    ctx.strokeStyle = withAlpha(gridColor, 0.22)
    ctx.lineWidth = Math.min(1.2, Math.max(0.6, globeRadius / 500))
    var latitude = centreLatitude * Math.PI / 180
    var longitude = centreLongitude * Math.PI / 180
    var sinLatitude = Math.sin(latitude)
    var cosLatitude = Math.cos(latitude)
    var sinLongitude = Math.sin(longitude)
    var cosLongitude = Math.cos(longitude)
    for (var i = 0; i < preparedGrid.length; i++)
      paintCurve(ctx, preparedGrid[i], centreX, centreY, globeRadius,
        sinLatitude, cosLatitude, sinLongitude, cosLongitude)
  }

  function paintCountries(ctx, centreX, centreY, globeRadius) {
    var latitude = centreLatitude * Math.PI / 180
    var longitude = centreLongitude * Math.PI / 180
    var sinLatitude = Math.sin(latitude)
    var cosLatitude = Math.cos(latitude)
    var sinLongitude = Math.sin(longitude)
    var cosLongitude = Math.cos(longitude)
    ctx.fillStyle = withAlpha(landColor, 0.92)
    ctx.strokeStyle = withAlpha(outlineColor, 0.38)
    ctx.lineWidth = 0.75

    for (var ringIndex = 0; ringIndex < preparedCountries.length; ringIndex++) {
      var geometry = preparedCountries[ringIndex]
      var ring = geometry.world
      var projected = geometry.projected
      var points = Math.floor(ring.length / 3)
      var hiddenIndex = -1
      for (var pointIndex = 0; pointIndex < points; pointIndex++) {
        var offset = pointIndex * 3
        var horizontal = ring[offset] * cosLongitude + ring[offset + 1] * sinLongitude
        projected[offset] = ring[offset + 1] * cosLongitude - ring[offset] * sinLongitude
        projected[offset + 1] = cosLatitude * ring[offset + 2] - sinLatitude * horizontal
        projected[offset + 2] = sinLatitude * ring[offset + 2] + cosLatitude * horizontal
        if (projected[offset + 2] < 0 && hiddenIndex < 0) hiddenIndex = pointIndex
      }

      if (hiddenIndex < 0) {
        ctx.beginPath()
        for (var visibleIndex = 0; visibleIndex < points; visibleIndex++) {
          var visibleOffset = visibleIndex * 3
          var screenX = centreX + projected[visibleOffset] * globeRadius
          var screenY = centreY - projected[visibleOffset + 1] * globeRadius
          if (visibleIndex === 0) ctx.moveTo(screenX, screenY)
          else ctx.lineTo(screenX, screenY)
        }
        ctx.closePath()
        ctx.fill()
        ctx.stroke()
        continue
      }

      var previousOffset = hiddenIndex * 3
      var previousX = projected[previousOffset]
      var previousY = projected[previousOffset + 1]
      var previousDepth = projected[previousOffset + 2]
      var drawing = false
      var startAngle = 0
      for (var step = 1; step <= points; step++) {
        var currentIndex = (hiddenIndex + step) % points
        var currentOffset = currentIndex * 3
        var currentX = projected[currentOffset]
        var currentY = projected[currentOffset + 1]
        var currentDepth = projected[currentOffset + 2]
        var previousVisible = previousDepth >= 0
        var currentVisible = currentDepth >= 0

        if (!previousVisible && currentVisible) {
          var enteringRatio = previousDepth / (previousDepth - currentDepth)
          var enteringX = previousX + (currentX - previousX) * enteringRatio
          var enteringY = previousY + (currentY - previousY) * enteringRatio
          var enteringLength = Math.sqrt(enteringX * enteringX + enteringY * enteringY) || 1
          enteringX /= enteringLength
          enteringY /= enteringLength
          startAngle = Math.atan2(-enteringY, enteringX)
          ctx.beginPath()
          ctx.moveTo(centreX + enteringX * globeRadius, centreY - enteringY * globeRadius)
          ctx.lineTo(centreX + currentX * globeRadius, centreY - currentY * globeRadius)
          drawing = true
        } else if (previousVisible && currentVisible && drawing) {
          ctx.lineTo(centreX + currentX * globeRadius, centreY - currentY * globeRadius)
        } else if (previousVisible && !currentVisible && drawing) {
          var leavingRatio = previousDepth / (previousDepth - currentDepth)
          var leavingX = previousX + (currentX - previousX) * leavingRatio
          var leavingY = previousY + (currentY - previousY) * leavingRatio
          var leavingLength = Math.sqrt(leavingX * leavingX + leavingY * leavingY) || 1
          leavingX /= leavingLength
          leavingY /= leavingLength
          var endAngle = Math.atan2(-leavingY, leavingX)
          var clockwiseArc = (startAngle - endAngle + Math.PI * 2) % (Math.PI * 2)
          ctx.lineTo(centreX + leavingX * globeRadius, centreY - leavingY * globeRadius)
          ctx.stroke()
          ctx.arc(centreX, centreY, globeRadius, endAngle, startAngle, clockwiseArc > Math.PI)
          ctx.closePath()
          ctx.fill()
          drawing = false
        }
        previousX = currentX
        previousY = currentY
        previousDepth = currentDepth
      }
    }
  }

  function paintMarker(ctx, row, isSelected) {
    var event = row.event
    var markerRadius = isSelected ? row.radius + 2.5 : row.radius
    var color = event.status === "down" ? urgent : (event.status === "backup" ? backup : healthy)

    // Outer pulsing beacon halo
    ctx.beginPath()
    ctx.arc(row.screenX, row.screenY, markerRadius + 4, 0, Math.PI * 2)
    ctx.strokeStyle = withAlpha(color, 0.45)
    ctx.lineWidth = 1.3
    ctx.stroke()

    // Inner bright core
    ctx.beginPath()
    ctx.arc(row.screenX, row.screenY, markerRadius, 0, Math.PI * 2)
    ctx.fillStyle = withAlpha(color, 0.95)
    ctx.fill()
    ctx.strokeStyle = "#ffffff"
    ctx.lineWidth = 1.0
    ctx.stroke()

    if (isSelected) {
      ctx.beginPath()
      ctx.arc(row.screenX, row.screenY, markerRadius + 7, 0, Math.PI * 2)
      ctx.strokeStyle = withAlpha(color, 0.8)
      ctx.lineWidth = 1.5
      ctx.stroke()
    }
  }

  function updateVisibleSitesFromRows(rows) {
    var nextSites = []
    for (var i = 0; i < rows.length; i++) {
      if (rows[i] && rows[i].event && rows[i].event.site) {
        nextSites.push(rows[i].event.site)
      }
    }
    var changed = false
    if (!root.visibleSites || root.visibleSites.length !== nextSites.length) {
      changed = true
    } else {
      for (var k = 0; k < nextSites.length; k++) {
        if (!root.visibleSites[k] || root.visibleSites[k].id !== nextSites[k].id) {
          changed = true
          break
        }
      }
    }
    if (changed) {
      root.visibleSites = nextSites
    }
  }

  function updateVisibleSites() {
    if (!preparedEvents || preparedEvents.length === 0) {
      if (root.visibleSites && root.visibleSites.length !== 0) root.visibleSites = []
      return
    }
    var latitude = centreLatitude * Math.PI / 180
    var longitude = centreLongitude * Math.PI / 180
    var sinLatitude = Math.sin(latitude)
    var cosLatitude = Math.cos(latitude)
    var sinLongitude = Math.sin(longitude)
    var cosLongitude = Math.cos(longitude)
    var globeRadius = radius()
    var w = (globeCanvas && globeCanvas.width > 0) ? globeCanvas.width : width
    var h = (globeCanvas && globeCanvas.height > 0) ? globeCanvas.height : height
    var visibleRows = []

    for (var i = 0; i < preparedEvents.length; i++) {
      var row = preparedEvents[i]
      var horizontal = row.worldX * cosLongitude + row.worldY * sinLongitude
      var xProjection = row.worldY * cosLongitude - row.worldX * sinLongitude
      var yProjection = cosLatitude * row.worldZ - sinLatitude * horizontal
      var depth = sinLatitude * row.worldZ + cosLatitude * horizontal
      var screenX = w / 2 + xProjection * globeRadius
      var screenY = h / 2 - yProjection * globeRadius
      var margin = row.radius + 10
      var isVisible = depth >= 0
      if (w > 0 && h > 0) {
        isVisible = isVisible
          && screenX >= -margin && screenX <= w + margin
          && screenY >= -margin && screenY <= h + margin
      }
      if (isVisible) {
        visibleRows.push(row)
      }
    }
    updateVisibleSitesFromRows(visibleRows)
  }

  function paintEvents(ctx) {
    var latitude = centreLatitude * Math.PI / 180
    var longitude = centreLongitude * Math.PI / 180
    var sinLatitude = Math.sin(latitude)
    var cosLatitude = Math.cos(latitude)
    var sinLongitude = Math.sin(longitude)
    var cosLongitude = Math.cos(longitude)
    var globeRadius = radius()
    var visibleRows = []
    var selectedRow = null

    for (var i = 0; i < preparedEvents.length; i++) {
      var row = preparedEvents[i]
      var horizontal = row.worldX * cosLongitude + row.worldY * sinLongitude
      var xProjection = row.worldY * cosLongitude - row.worldX * sinLongitude
      var yProjection = cosLatitude * row.worldZ - sinLatitude * horizontal
      var depth = sinLatitude * row.worldZ + cosLatitude * horizontal
      row.screenX = globeCanvas.width / 2 + xProjection * globeRadius
      row.screenY = globeCanvas.height / 2 - yProjection * globeRadius
      row.depth = depth
      var margin = row.radius + 10
      row.visible = depth >= 0
        && row.screenX >= -margin && row.screenX <= globeCanvas.width + margin
        && row.screenY >= -margin && row.screenY <= globeCanvas.height + margin
      if (!row.visible) continue
      visibleRows.push(row)
      if (selectedSite && row.event.id === selectedSite.id) {
        selectedRow = row
      } else {
        paintMarker(ctx, row, false)
      }
    }
    if (selectedRow) paintMarker(ctx, selectedRow, true)
    hitEvents = visibleRows
    updateVisibleSitesFromRows(visibleRows)
  }

  function drawTrafficPulse(ctx, item, t, centreX, centreY, globeRadius,
                            sinLatitude, cosLatitude, sinLongitude, cosLongitude, direction) {
    if (t < 0.02 || t > 0.98) return
    var pt = GlobeModel.interpolateArc(item.vA, item.vB, item.theta, t, item.altitude)
    var horiz = pt.x * cosLongitude + pt.y * sinLongitude
    var xProj = pt.y * cosLongitude - pt.x * sinLongitude
    var yProj = cosLatitude * pt.z - sinLatitude * horiz
    var depth = sinLatitude * pt.z + cosLatitude * horiz
    if (depth <= 0) return

    var sx = centreX + xProj * globeRadius
    var sy = centreY - yProj * globeRadius
    var depthAlpha = Math.min(1.0, depth * 4.0)

    var tailT = t - direction * 0.035
    if (tailT > 0 && tailT < 1) {
      var tailPt = GlobeModel.interpolateArc(item.vA, item.vB, item.theta, tailT, item.altitude)
      var tailHoriz = tailPt.x * cosLongitude + tailPt.y * sinLongitude
      var tailXProj = tailPt.y * cosLongitude - tailPt.x * sinLongitude
      var tailYProj = cosLatitude * tailPt.z - sinLatitude * tailHoriz
      var tailDepth = sinLatitude * tailPt.z + cosLatitude * tailHoriz
      if (tailDepth > 0) {
        var tailSx = centreX + tailXProj * globeRadius
        var tailSy = centreY - tailYProj * globeRadius
        ctx.beginPath()
        ctx.moveTo(tailSx, tailSy)
        ctx.lineTo(sx, sy)
        ctx.strokeStyle = withAlpha(item.color, 0.65 * depthAlpha)
        ctx.lineWidth = 1.8
        ctx.stroke()
      }
    }

    ctx.beginPath()
    ctx.arc(sx, sy, 3.2, 0, Math.PI * 2)
    ctx.fillStyle = withAlpha(item.color, 0.50 * depthAlpha)
    ctx.fill()

    ctx.beginPath()
    ctx.arc(sx, sy, 1.5, 0, Math.PI * 2)
    ctx.fillStyle = withAlpha("#ffffff", 0.95 * depthAlpha)
    ctx.fill()
  }

  function paintConnections(ctx, centreX, centreY, globeRadius) {
    if (!preparedConnections || preparedConnections.length === 0) return

    var latitude = centreLatitude * Math.PI / 180
    var longitude = centreLongitude * Math.PI / 180
    var sinLatitude = Math.sin(latitude)
    var cosLatitude = Math.cos(latitude)
    var sinLongitude = Math.sin(longitude)
    var cosLongitude = Math.cos(longitude)

    for (var c = 0; c < preparedConnections.length; c++) {
      var item = preparedConnections[c]
      var waypoints = item.waypoints
      var projected = []

      for (var w = 0; w < waypoints.length; w++) {
        var wp = waypoints[w]
        var horiz = wp.x * cosLongitude + wp.y * sinLongitude
        var xProj = wp.y * cosLongitude - wp.x * sinLongitude
        var yProj = cosLatitude * wp.z - sinLatitude * horiz
        var depth = sinLatitude * wp.z + cosLatitude * horiz
        projected.push({
          screenX: centreX + xProj * globeRadius,
          screenY: centreY - yProj * globeRadius,
          depth: depth,
          t: wp.t
        })
      }

      var isDashed = !item.connected

      function strokeArcPass(lineWidth, strokeAlpha) {
        ctx.save()
        ctx.beginPath()
        ctx.lineWidth = lineWidth
        ctx.strokeStyle = withAlpha(item.color, strokeAlpha)
        if (isDashed) {
          ctx.setLineDash([4, 4])
        } else {
          ctx.setLineDash([])
        }
        var drawing = false
        for (var i = 0; i < projected.length; i++) {
          var pt = projected[i]
          if (pt.depth >= 0) {
            if (!drawing) {
              if (i > 0) {
                var prev = projected[i - 1]
                var ratio = prev.depth / (prev.depth - pt.depth)
                var hx = prev.screenX + (pt.screenX - prev.screenX) * ratio
                var hy = prev.screenY + (pt.screenY - prev.screenY) * ratio
                ctx.moveTo(hx, hy)
                ctx.lineTo(pt.screenX, pt.screenY)
              } else {
                ctx.moveTo(pt.screenX, pt.screenY)
              }
              drawing = true
            } else {
              ctx.lineTo(pt.screenX, pt.screenY)
            }
          } else {
            if (drawing) {
              var prev = projected[i - 1]
              var ratio = prev.depth / (prev.depth - pt.depth)
              var hx = prev.screenX + (pt.screenX - prev.screenX) * ratio
              var hy = prev.screenY + (pt.screenY - prev.screenY) * ratio
              ctx.lineTo(hx, hy)
              drawing = false
            }
          }
        }
        ctx.stroke()
        ctx.restore()
      }

      // 1. Soft glowing aura along the arc
      strokeArcPass(3.4, 0.22)
      // 2. Focused core line
      strokeArcPass(1.4, 0.88)

      // 3. Simulated packet traffic pulses
      if (item.connected && animateTraffic) {
        for (var p = 0; p < 3; p++) {
          var pulseT = (root.flowProgress + p / 3.0) % 1.0
          drawTrafficPulse(ctx, item, pulseT, centreX, centreY, globeRadius,
                           sinLatitude, cosLatitude, sinLongitude, cosLongitude, 1)
        }
        var revT = (1.0 - (root.flowProgress + 0.5) % 1.0)
        drawTrafficPulse(ctx, item, revT, centreX, centreY, globeRadius,
                         sinLatitude, cosLatitude, sinLongitude, cosLongitude, -1)
      }
    }
  }

  function paintGlobe(ctx) {
    var centreX = globeCanvas.width / 2
    var centreY = globeCanvas.height / 2
    var globeRadius = radius()
    if (!isFinite(globeRadius) || globeRadius <= 0) return
    ctx.reset()

    if (backgroundColor !== "transparent") {
      ctx.fillStyle = backgroundColor
      ctx.fillRect(0, 0, globeCanvas.width, globeCanvas.height)
    }

    // Sphere shading radial gradient
    var sphere = ctx.createRadialGradient(
      centreX - globeRadius * 0.28, centreY - globeRadius * 0.32, globeRadius * 0.04,
      centreX, centreY, globeRadius)
    sphere.addColorStop(0, withAlpha(Qt.lighter(sphereColor, 1.6), 1))
    sphere.addColorStop(0.62, sphereColor)
    sphere.addColorStop(1, Qt.darker(sphereColor, 1.7))
    ctx.beginPath()
    ctx.arc(centreX, centreY, globeRadius, 0, Math.PI * 2)
    ctx.fillStyle = sphere
    ctx.fill()

    ctx.save()
    ctx.beginPath()
    ctx.arc(centreX, centreY, globeRadius - 0.5, 0, Math.PI * 2)
    ctx.clip()
    paintGrid(ctx, centreX, centreY, globeRadius)
    paintCountries(ctx, centreX, centreY, globeRadius)
    ctx.restore()

    paintConnections(ctx, centreX, centreY, globeRadius)
    paintEvents(ctx)

    // Globe horizon outline
    ctx.beginPath()
    ctx.arc(centreX, centreY, globeRadius, 0, Math.PI * 2)
    ctx.strokeStyle = withAlpha(outlineColor, 0.45)
    ctx.lineWidth = 1.1
    ctx.stroke()
  }

  function eventUnderPointer(x, y) {
    var nearest = null
    var nearestDistance = 256
    for (var i = 0; i < hitEvents.length; i++) {
      var row = hitEvents[i]
      var deltaX = row.screenX - x
      var deltaY = row.screenY - y
      var distance = deltaX * deltaX + deltaY * deltaY
      if (distance > nearestDistance) continue
      nearest = row.event
      nearestDistance = distance
    }
    return nearest
  }

  function activateAt(x, y) {
    var event = eventUnderPointer(x, y)
    if (event) {
      siteActivated(event.site)
    }
  }

  onCountriesChanged: {
    preparedCountries = prepareCountryGeometry()
    globeCanvas.requestPaint()
  }

  onConnectionsChanged: {
    preparedConnections = prepareConnectionGeometry()
    preparedEvents = prepareSiteGeometry()
    globeCanvas.requestPaint()
  }

  onSdwanChanged: {
    preparedConnections = prepareConnectionGeometry()
    preparedEvents = prepareSiteGeometry()
    globeCanvas.requestPaint()
  }

  onSitesChanged: {
    hitEvents = []
    hoveredEvent = null
    preparedConnections = prepareConnectionGeometry()
    preparedEvents = prepareSiteGeometry()
    if (sites && sites.length > 0 && centreLatitude === -25 && centreLongitude === 120) {
      focusSite(sites[0])
    }
    updateVisibleSites()
    globeCanvas.requestPaint()
  }

  onSelectedSiteChanged: globeCanvas.requestPaint()
  onCentreLatitudeChanged: { updateVisibleSites(); globeCanvas.requestPaint() }
  onCentreLongitudeChanged: { updateVisibleSites(); globeCanvas.requestPaint() }
  onGlobeScaleChanged: { updateVisibleSites(); globeCanvas.requestPaint() }
  onWidthChanged: { updateVisibleSites(); globeCanvas.requestPaint() }
  onHeightChanged: { updateVisibleSites(); globeCanvas.requestPaint() }

  FileView {
    id: countriesFile
    path: Qt.resolvedUrl("assets/countries.json").toString().replace(/^file:\/\//, "")
    watchChanges: false
    printErrors: false
    onLoaded: {
      try {
        var collection = JSON.parse(text())
        root.countries = Array.isArray(collection.features) ? collection.features : []
      } catch (error) {
        root.countries = []
      }
    }
  }

  Timer {
    interval: 50
    running: root.autoRotate && !pointer.pressed
    repeat: true
    onTriggered: root.centreLongitude = GlobeModel.wrapLongitude(root.centreLongitude + 0.35)
  }

  Canvas {
    id: globeCanvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative
    onPaint: {
      var ctx = getContext("2d")
      if (ctx) root.paintGlobe(ctx)
    }
  }

  Component.onCompleted: {
    preparedGrid = prepareGridGeometry()
    preparedCountries = prepareCountryGeometry()
    preparedConnections = prepareConnectionGeometry()
    preparedEvents = prepareSiteGeometry()
    updateVisibleSites()
    globeCanvas.requestPaint()
  }

  MouseArea {
    id: pointer
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton
    cursorShape: pressed
      ? Qt.ClosedHandCursor
      : (root.hoveredEvent ? Qt.PointingHandCursor : Qt.OpenHandCursor)

    property real lastX: 0
    property real lastY: 0
    property real totalMovement: 0

    onPressed: function(mouse) {
      root.interactionStarted()
      lastX = mouse.x
      lastY = mouse.y
      totalMovement = 0
      root.hoveredEvent = null
    }

    onPositionChanged: function(mouse) {
      root.hoverX = mouse.x
      root.hoverY = mouse.y
      if (!(pressedButtons & Qt.LeftButton)) {
        root.hoveredEvent = root.eventUnderPointer(mouse.x, mouse.y)
        return
      }
      var deltaX = mouse.x - lastX
      var deltaY = mouse.y - lastY
      root.centreLongitude = GlobeModel.wrapLongitude(
        root.centreLongitude - deltaX * root.longitudeSensitivity / root.globeScale)
      root.centreLatitude = GlobeModel.clamp(
        root.centreLatitude + deltaY * root.latitudeSensitivity / root.globeScale, -78, 78)
      totalMovement += Math.abs(deltaX) + Math.abs(deltaY)
      lastX = mouse.x
      lastY = mouse.y
    }

    onReleased: function(mouse) {
      if (totalMovement < 7) {
        root.activateAt(mouse.x, mouse.y)
        root.hoveredEvent = root.eventUnderPointer(mouse.x, mouse.y)
      }
    }

    onExited: if (!(pressedButtons & Qt.LeftButton)) root.hoveredEvent = null

    onWheel: function(wheel) {
      root.interactionStarted()
      root.globeScale = GlobeModel.clamp(
        root.globeScale * Math.exp(wheel.angleDelta.y / 540),
        root.minimumScale, root.maximumScale)
      wheel.accepted = true
    }

    onDoubleClicked: function(mouse) {
      root.zoomIn()
    }
  }

  // Interactive Hover Tooltip
  Rectangle {
    visible: !!root.hoveredEvent && !pointer.pressed
    x: Math.min(root.width - width - 8, Math.max(8, root.hoverX + 14))
    y: Math.min(root.height - height - 8, Math.max(8, root.hoverY + 14))
    width: Math.min(300, tooltipCol.implicitWidth + 20)
    height: tooltipCol.implicitHeight + 14
    color: Qt.rgba(0.06, 0.08, 0.12, 0.95)
    border.color: root.withAlpha(root.outlineColor, 0.55)
    border.width: 1
    radius: 4

    Column {
      id: tooltipCol
      anchors.centerIn: parent
      spacing: 2

      Text {
        textFormat: Text.PlainText
        text: root.hoveredEvent ? root.hoveredEvent.title : ""
        color: root.textColor
        font.family: root.fontFamily
        font.pixelSize: 11
        font.bold: true
      }

      Text {
        textFormat: Text.PlainText
        text: root.hoveredEvent
          ? (root.hoveredEvent.gatewayModel ? root.hoveredEvent.gatewayModel + " · " : "") + root.hoveredEvent.clientCount + " clients · " + (root.hoveredEvent.status === "up" ? "ONLINE" : root.hoveredEvent.status.toUpperCase())
          : ""
        color: root.hoveredEvent && root.hoveredEvent.status === "down" ? root.urgent : (root.hoveredEvent && root.hoveredEvent.status === "backup" ? root.backup : root.healthy)
        font.family: root.fontFamily
        font.pixelSize: 10
      }

      Text {
        textFormat: Text.PlainText
        visible: Boolean(root.hoveredEvent && root.hoveredEvent.sdwanInfo)
        text: (root.hoveredEvent && root.hoveredEvent.sdwanInfo) ? root.hoveredEvent.sdwanInfo : ""
        color: root.healthy
        font.family: root.fontFamily
        font.pixelSize: 10
      }
    }
  }
}
