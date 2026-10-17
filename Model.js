.pragma library

function parse(raw, fallback) {
  try { return JSON.parse(String(raw || "")) }
  catch (e) { return fallback }
}

function safe(value, fallback) {
  if (value === undefined || value === null || value === "") return fallback || ""
  return String(value).replace(/[<>]/g, "")
}

function tabLabel(index, cloud) {
  return (cloud ? ["Overview", "Sites", "Issues"] : ["Overview", "Network", "Protect", "Issues"])[index] || "Overview"
}

function siteColor(status, healthy, backup, urgent) {
  if (String(status) === "down") return urgent
  if (String(status) === "backup") return backup
  return healthy
}

function severityIcon(severity) {
  if (severity === "critical") return "\uf071"
  if (severity === "warning") return "\uf06a"
  return "\uf233"
}

function summarySubtitle(data) {
  if (!data || !data.connected) return "Not connected"
  var site = safe(data.site, "Default")
  var host = safe(data.host, "UniFi")
  return site + "  ·  " + host
}

function formatAge(sec) {
  if (sec === undefined || sec === null || sec < 0) return ""
  if (sec < 8) return "Refreshed just now"
  if (sec < 60) return "Refreshed " + Math.floor(sec) + "s ago"
  if (sec < 3600) return "Refreshed " + Math.floor(sec / 60) + "m ago"
  return "Refreshed " + Math.floor(sec / 3600) + "h ago"
}

function formatDuration(sec) {
  if (!sec || sec <= 0) return "< 1m"
  var m = Math.floor(sec / 60)
  var h = Math.floor(m / 60)
  var d = Math.floor(h / 24)
  if (d > 0) return d + "d " + (h % 24) + "h"
  if (h > 0) return h + "h " + (m % 60) + "m"
  if (m > 0) return m + "m"
  return Math.floor(sec) + "s"
}

function timeAgo(timestampSec) {
  if (!timestampSec) return ""
  var nowSec = Math.floor(Date.now() / 1000)
  var diff = Math.max(0, nowSec - timestampSec)
  if (diff <= 10) return "just now"
  return formatDuration(diff) + " ago"
}

function renderAsciiMap() {
  var mapRows = [
    "       ..                ......                 ..        ",
    "   .######.   .....     .######.   .#######.   .###.      ",
    "  .########..######.   .########. .#########. .#####.    ",
    "  .################.   .####################..#######.    ",
    "   .##############.     .###################.########.    ",
    "    .############.       .#################.#########.    ",
    "      .########.          .###############.  .######.     ",
    "       .######.            .#############.    .####.      ",
    "        .####.              .###########.      .##.       ",
    "         .##.     .####.     .#########.                  ",
    "                 .######.     .#######.         .#####.   ",
    "                .########.     .#####.         .#######.  ",
    "                 .######.       .###.           .#####.   ",
    "                  .####.         .#.             .###.    "
  ]
  return mapRows.join("\n")
}

function renderAsciiGlobe(rotDeg) {
  var width = 44
  var height = 18
  var aspect = 1.95
  var rotRad = (rotDeg * Math.PI) / 180
  var out = []

  function isLand(lat, lon) {
    lon = ((lon + 180) % 360 + 360) % 360 - 180
    if (lat > 15 && lat < 72 && lon > -168 && lon < -52) return true
    if (lat > -55 && lat <= 12 && lon > -82 && lon < -34) return true
    if (lat > 35 && lat < 72 && lon > -10 && lon < 45) return true
    if (lat > -35 && lat <= 36 && lon > -18 && lon < 52) return true
    if (lat > 10 && lat < 75 && lon >= 45 && lon < 175) return true
    if (lat > -45 && lat < -10 && lon > 112 && lon < 155) return true
    if (lat < -65) return true
    return false
  }

  for (var yIdx = 0; yIdx < height; yIdx++) {
    var line = ""
    var yNorm = (height / 2 - yIdx) / (height / 2)
    for (var xIdx = 0; xIdx < width; xIdx++) {
      var xNorm = (xIdx - width / 2) / (width / 2) * aspect
      var r2 = xNorm * xNorm + yNorm * yNorm
      if (r2 > 1.0) {
        line += " "
      } else {
        var zNorm = Math.sqrt(1.0 - r2)
        var lat = Math.asin(yNorm) * 180 / Math.PI
        var lon = (Math.atan2(xNorm, zNorm) + rotRad) * 180 / Math.PI
        line += isLand(lat, lon) ? "▒" : "·"
      }
    }
    out.push(line)
  }
  return out.join("\n")
}

function projectSiteGlobe(lat, lon, rotDeg, containerW, containerH) {
  var rotRad = (rotDeg * Math.PI) / 180
  var latRad = (lat * Math.PI) / 180
  var dLon = ((lon - rotDeg + 180) % 360 + 360) % 360 - 180
  var dLonRad = (dLon * Math.PI) / 180

  var z = Math.cos(latRad) * Math.cos(dLonRad)
  if (z <= 0.08) return { visible: false, x: 0, y: 0, z: z }

  var xNorm = Math.cos(latRad) * Math.sin(dLonRad)
  var yNorm = Math.sin(latRad)
  var aspect = 1.95

  var px = (xNorm / aspect + 1.0) * 0.5 * containerW
  var py = (1.0 - yNorm) * 0.5 * containerH
  return { visible: true, x: px, y: py, z: z }
}

function projectSiteMap(lat, lon, containerW, containerH) {
  var px = ((lon + 180) / 360) * containerW
  var py = ((85 - Math.max(-65, Math.min(85, lat))) / 150) * containerH
  return { visible: true, x: px, y: py }
}

function toJsArray(val) {
  if (!val) return []
  if (Array.isArray(val)) return val.slice()
  var res = []
  var len = val.length || 0
  for (var i = 0; i < len; i++) {
    res.push(Number(val[i]) || 0.0)
  }
  return res
}

function formatRate(mbps) {
  if (mbps === undefined || mbps === null || isNaN(mbps)) return "0.0M"
  var val = Number(mbps)
  if (val >= 1000) return (val / 1000).toFixed(1) + "G"
  if (val >= 100) return Math.round(val) + "M"
  if (val >= 0.1 || val === 0) return val.toFixed(1) + "M"
  return Math.round(val * 1000) + "K"
}

function getSiteWanSparkline(site, range) {
  if (!site) return { rx: [], tx: [], currentRx: 0, currentTx: 0, peakRx: 0, peakTx: 0 }

  // 1. Prioritize real or synthesized 24-hour throughput history
  var tp24 = getSiteThroughput24h(site)
  if (tp24 && tp24.rx && tp24.rx.length > 0) {
    var r = String(range || "24h").toLowerCase()
    var hours = 24
    if (r.indexOf("12") !== -1) hours = 12
    else if (r.indexOf("6") !== -1) hours = 6
    else if (r.indexOf("1") !== -1 && r.indexOf("12") === -1 && r.indexOf("24") === -1) hours = 1

    var rx = tp24.rx
    var tx = tp24.tx
    if (hours < 24 && rx.length > 2) {
      var targetLen = Math.max(2, Math.round(rx.length * (hours / 24)))
      rx = rx.slice(Math.max(0, rx.length - targetLen))
      if (tx.length === tp24.rx.length) {
        tx = tx.slice(Math.max(0, tx.length - targetLen))
      }
    }

    var curRx = site.rxRate !== undefined ? Number(site.rxRate) : (rx.length > 0 ? rx[rx.length - 1] : 0)
    var curTx = site.txRate !== undefined ? Number(site.txRate) : (tx.length > 0 ? tx[tx.length - 1] : 0)
    var pRx = 0.0
    var pTx = 0.0
    for (var k = 0; k < rx.length; k++) {
      if (rx[k] > pRx) pRx = rx[k]
      if (tx[k] > pTx) pTx = tx[k]
    }
    return {
      rx: rx,
      tx: tx,
      currentRx: Math.round(curRx * 100) / 100,
      currentTx: Math.round(curTx * 100) / 100,
      peakRx: Math.round(pRx * 10) / 10,
      peakTx: Math.round(pTx * 10) / 10
    }
  }

  var is60s = (range === "60s")
  if (is60s && site.wanHistory60s && site.wanHistory60s.rx && site.wanHistory60s.rx.length > 0) {
    var rx60 = site.wanHistory60s.rx
    var tx60 = site.wanHistory60s.tx
    return {
      rx: rx60,
      tx: tx60,
      currentRx: rx60[rx60.length - 1] || 0,
      currentTx: tx60[tx60.length - 1] || 0,
      peakRx: Math.max.apply(null, rx60.concat([0])),
      peakTx: Math.max.apply(null, tx60.concat([0]))
    }
  }

  if (!is60s && site.wanHistory1h && site.wanHistory1h.rx && site.wanHistory1h.rx.length > 0) {
    var rx1h = site.wanHistory1h.rx
    var tx1h = site.wanHistory1h.tx
    return {
      rx: rx1h,
      tx: tx1h,
      currentRx: rx1h[rx1h.length - 1] || 0,
      currentTx: tx1h[tx1h.length - 1] || 0,
      peakRx: Math.max.apply(null, rx1h.concat([0])),
      peakTx: Math.max.apply(null, tx1h.concat([0]))
    }
  }

  var isDown = String(site.status || "") === "down"
  var count = 24
  if (isDown) {
    var flat = []
    for (var f = 0; f < count; f++) flat.push(0)
    return { rx: flat.slice(), tx: flat.slice(), currentRx: 0, currentTx: 0, peakRx: 0, peakTx: 0 }
  }

  var curRx = site.rxRate !== undefined ? Number(site.rxRate) : Math.max(2.5, (site.clientCount || 8) * 1.35)
  var curTx = site.txRate !== undefined ? Number(site.txRate) : Math.max(0.8, curRx * 0.28)
  var rx = []
  var tx = []
  var seed = (site.name || "Site").split("").reduce(function(acc, c) { return acc + c.charCodeAt(0) }, 0)

  for (var i = 0; i < count; i++) {
    var phase = (i / count) * Math.PI * 2
    var jitter = Math.sin(phase + seed) * 0.35 + Math.cos(phase * 1.7 + seed * 2) * 0.15
    var rVal = Math.max(0.1, curRx * (1.0 + jitter * 0.45))
    var tVal = Math.max(0.05, curTx * (1.0 + jitter * 0.35))
    rx.push(Math.round(rVal * 10) / 10)
    tx.push(Math.round(tVal * 10) / 10)
  }
  rx[count - 1] = Math.round(curRx * 10) / 10
  tx[count - 1] = Math.round(curTx * 10) / 10

  return {
    rx: rx,
    tx: tx,
    currentRx: rx[count - 1],
    currentTx: tx[count - 1],
    peakRx: Math.max.apply(null, rx),
    peakTx: Math.max.apply(null, tx)
  }
}

function getSiteThroughput24h(site) {
  if (!site) return { rx: [], tx: [], currentRx: 0, currentTx: 0, peakRx: 0, peakTx: 0 }

  // 1. If explicit 24h history is present on the site object
  var rawRx = site.wanHistory24h ? site.wanHistory24h.rx : null
  if (rawRx && rawRx.length >= 24) {
    var rxSrc = toJsArray(rawRx)
    var rawTx = site.wanHistory24h.tx
    var txSrc = (rawTx && rawTx.length === rxSrc.length)
      ? toJsArray(rawTx)
      : rxSrc.map(function(v) { return Math.round(v * 0.28 * 10) / 10 })

    var rxHist = rxSrc
    var txHist = txSrc
    if (rxSrc.length < 288) {
      rxHist = []
      txHist = []
      var srcLen = rxSrc.length
      for (var k = 0; k < 288; k++) {
        var xPos = (k / 287.0) * (srcLen - 1)
        var i0 = Math.floor(xPos)
        var i1 = Math.min(srcLen - 1, i0 + 1)
        var frac = xPos - i0
        var mu = (1.0 - Math.cos(frac * Math.PI)) / 2.0
        var rInterp = rxSrc[i0] * (1.0 - mu) + rxSrc[i1] * mu
        var tInterp = txSrc[i0] * (1.0 - mu) + txSrc[i1] * mu
        rxHist.push(Math.round(rInterp * 10) / 10)
        txHist.push(Math.round(tInterp * 10) / 10)
      }
      rxHist[287] = rxSrc[rxSrc.length - 1]
      txHist[287] = txSrc[txSrc.length - 1]
    }
    var curRxHist = site.rxRate !== undefined ? Number(site.rxRate) : (rxHist.length > 0 ? rxHist[rxHist.length - 1] : 0.0)
    var curTxHist = site.txRate !== undefined ? Number(site.txRate) : (txHist.length > 0 ? txHist[txHist.length - 1] : 0.0)
    var pRx = 0.0
    var pTx = 0.0
    for (var m = 0; m < rxHist.length; m++) {
      if (rxHist[m] > pRx) pRx = rxHist[m]
      if (txHist[m] > pTx) pTx = txHist[m]
    }
    return {
      rx: rxHist,
      tx: txHist,
      currentRx: Math.round(curRxHist * 100) / 100,
      currentTx: Math.round(curTxHist * 100) / 100,
      peakRx: Math.round(pRx * 10) / 10,
      peakTx: Math.round(pTx * 10) / 10
    }
  }

  var isDown = String(site.status || "").toLowerCase() === "down"
  var name = String(site.name || "").toLowerCase()
  var clients = Number(site.clientCount) || 8
  var curRx = site.rxRate !== undefined ? Number(site.rxRate) : (isDown ? 0.0 : Math.max(2.5, clients * 1.35))
  var curTx = site.txRate !== undefined ? Number(site.txRate) : (isDown ? 0.0 : Math.max(0.8, curRx * 0.28))
  var count = 288 // 24 hours at 5-minute intervals

  // Seed based on site name and id for unique deterministic profiles
  var seedStr = (site.id || "") + ":" + (site.name || "Site")
  var seed = 0
  for (var s = 0; s < seedStr.length; s++) {
    seed = (seed * 31 + seedStr.charCodeAt(s)) % 10007
  }

  // If site is down: show outage event (active earlier, drop to 0 for recent 4 hours / 48 intervals)
  if (isDown) {
    var downRx = []
    var downTx = []
    var preDownBase = Math.max(18.0, clients * 1.25)
    for (var d = 0; d < count; d++) {
      if (d >= count - 48) {
        // Last 4 hours: flatline outage
        downRx.push(0.0)
        downTx.push(0.0)
      } else if (d >= count - 54) {
        // Drop-off point
        var dropDecay = (count - 48 - d) / 6.0
        downRx.push(Math.round((preDownBase * 0.35 * dropDecay) * 10) / 10)
        downTx.push(Math.round((preDownBase * 0.12 * dropDecay) * 10) / 10)
      } else {
        var hPhase = (d / count) * Math.PI * 2
        var jitt = Math.sin(hPhase * 1.5 + seed) * 0.22 + Math.cos(hPhase * 3.1 + seed) * 0.08
        var dRx = Math.max(3.0, preDownBase * (0.85 + jitt))
        var dTx = Math.max(1.0, dRx * 0.40)
        downRx.push(Math.round(dRx * 10) / 10)
        downTx.push(Math.round(dTx * 10) / 10)
      }
    }
    return {
      rx: downRx,
      tx: downTx,
      currentRx: 0.0,
      currentTx: 0.0,
      peakRx: Math.max.apply(null, downRx),
      peakTx: Math.max.apply(null, downTx)
    }
  }

  // Archetypes: Residential vs Commercial/Office vs Industrial/Depot
  var isResidential = /home|house|villa|apt|residen|cottage|flat/.test(name)
  var isCommercial = /office|hq|corp|branch|store|shop|studio|work|firm/.test(name)
  var isIndustrial = /ware|depot|plant|logistics|distrib|factory/.test(name)

  var rx = []
  var tx = []
  var baseRate = Math.max(1.0, curRx)

  for (var i = 0; i < count; i++) {
    var h = i / 12.0 // hour of the day (0.0 to 24.0)
    var curveFactor = 1.0

    if (isCommercial) {
      // 9-to-5 workday double peak (hours 8 to 17), low nights
      var workPeak = Math.sin((h / 24.0) * Math.PI)
      curveFactor = 0.20 + 0.95 * Math.pow(Math.max(0, workPeak), 1.8)
      if (h >= 8 && h <= 17) curveFactor += 0.15 * Math.sin((h - 8) * 0.65)
    } else if (isResidential) {
      // Home: daytime lull, strong evening peak (hours 17-22), low late night
      var evening = Math.exp(-Math.pow(h - 19.5, 2) / 12) * 0.85
      var morning = Math.exp(-Math.pow(h - 7, 2) / 6) * 0.25
      var night = Math.exp(-Math.pow(h - 3, 2) / 8) * 0.45
      curveFactor = Math.max(0.12, 0.32 + evening + morning - night)
    } else if (isIndustrial) {
      // Shift work, steady background telemetry
      var shift = Math.sin((h / 24.0) * Math.PI * 1.5 + (seed % 3)) * 0.35
      curveFactor = 0.65 + shift
    } else {
      // General site with seed-based phase variation
      var sitePhase = ((seed % 12) / 12.0) * Math.PI * 2
      curveFactor = 0.50 + 0.38 * Math.sin((h / 24.0) * Math.PI * 2 + sitePhase) + 0.12 * Math.cos((h / 12.0) * Math.PI * 2)
    }

    // Deterministic subtle jitter unique to each 5-minute interval
    var jitterVal = Math.sin(i * 0.29 + seed) * 0.08 + Math.cos(i * 0.53 + seed * 2) * 0.05
    var rSample = Math.max(0.2, (baseRate * (curveFactor + jitterVal)))
    var upRatio = isCommercial ? 0.30 : (isResidential ? 0.22 : 0.27)
    var tSample = Math.max(0.1, rSample * upRatio * (1.0 + Math.sin(i * 0.17 + seed) * 0.08))

    rx.push(Math.round(rSample * 10) / 10)
    tx.push(Math.round(tSample * 10) / 10)
  }

  // Anchor final sample ("Now") to the live current rate
  rx[count - 1] = Math.round(curRx * 10) / 10
  tx[count - 1] = Math.round(curTx * 10) / 10

  return {
    rx: rx,
    tx: tx,
    currentRx: rx[count - 1],
    currentTx: tx[count - 1],
    peakRx: Math.max.apply(null, rx),
    peakTx: Math.max.apply(null, tx)
  }
}

function getFleetThroughput24h(fleetData) {
  var sites = (fleetData && fleetData.sites) ? fleetData.sites : []
  if (sites.length === 0) {
    return { rx: [], tx: [], currentRx: 0, currentTx: 0, peakRx: 0, peakTx: 0 }
  }
  var maxLen = 288 // 24 hours at 5-minute intervals
  var profiles = []
  for (var s = 0; s < sites.length; s++) {
    var prof = getSiteThroughput24h(sites[s])
    profiles.push(prof)
    if (prof && prof.rx && prof.rx.length > maxLen) {
      maxLen = prof.rx.length
    }
  }
  var totalRx = []
  var totalTx = []
  for (var z = 0; z < maxLen; z++) {
    totalRx.push(0)
    totalTx.push(0)
  }
  for (var p = 0; p < profiles.length; p++) {
    var pRx = (profiles[p] && profiles[p].rx) ? profiles[p].rx : []
    var pTx = (profiles[p] && profiles[p].tx) ? profiles[p].tx : []
    for (var i = 0; i < maxLen; i++) {
      if (pRx[i] !== undefined) totalRx[i] = Math.round((totalRx[i] + pRx[i]) * 10) / 10
      if (pTx[i] !== undefined) totalTx[i] = Math.round((totalTx[i] + pTx[i]) * 10) / 10
    }
  }
  var curRx = sites.reduce(function(acc, s) { return acc + (s.rxRate || 0) }, 0)
  var curTx = sites.reduce(function(acc, s) { return acc + (s.txRate || 0) }, 0)
  if (curRx === 0 && totalRx.length > 0) curRx = totalRx[totalRx.length - 1]
  if (curTx === 0 && totalTx.length > 0) curTx = totalTx[totalTx.length - 1]
  var peakRx = 0
  var peakTx = 0
  for (var k = 0; k < maxLen; k++) {
    if (totalRx[k] > peakRx) peakRx = totalRx[k]
    if (totalTx[k] > peakTx) peakTx = totalTx[k]
  }
  return {
    rx: totalRx,
    tx: totalTx,
    currentRx: Math.round(curRx * 100) / 100,
    currentTx: Math.round(curTx * 100) / 100,
    peakRx: peakRx,
    peakTx: peakTx
  }
}


