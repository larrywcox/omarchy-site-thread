var radians = Math.PI / 180
var degrees = 180 / Math.PI

function clamp(value, minimum, maximum) {
  return Math.max(minimum, Math.min(maximum, value))
}

function wrapLongitude(value) {
  var wrapped = (Number(value) + 180) % 360
  if (wrapped < 0) wrapped += 360
  return wrapped - 180
}

function project(latitude, longitude, centreLatitude, centreLongitude) {
  var phi = Number(latitude) * radians
  var lambda = wrapLongitude(Number(longitude) - Number(centreLongitude)) * radians
  var phi0 = Number(centreLatitude) * radians
  var cosPhi = Math.cos(phi)
  var sinPhi = Math.sin(phi)
  var cosPhi0 = Math.cos(phi0)
  var sinPhi0 = Math.sin(phi0)

  return {
    x: cosPhi * Math.sin(lambda),
    y: cosPhi0 * sinPhi - sinPhi0 * cosPhi * Math.cos(lambda),
    z: sinPhi0 * sinPhi + cosPhi0 * cosPhi * Math.cos(lambda)
  }
}

function unproject(x, y, centreLatitude, centreLongitude) {
  var rho2 = x * x + y * y
  if (rho2 > 1) return null

  var z = Math.sqrt(Math.max(0, 1 - rho2))
  var phi0 = Number(centreLatitude) * radians
  var cosPhi0 = Math.cos(phi0)
  var sinPhi0 = Math.sin(phi0)
  var latitude = Math.asin(y * cosPhi0 + z * sinPhi0)
  var longitude = Number(centreLongitude) * radians
    + Math.atan2(x, z * cosPhi0 - y * sinPhi0)

  return {
    latitude: latitude * degrees,
    longitude: wrapLongitude(longitude * degrees)
  }
}

function latLngToVector(latitude, longitude) {
  var phi = Number(latitude) * radians
  var lambda = Number(longitude) * radians
  var cosPhi = Math.cos(phi)
  return {
    x: cosPhi * Math.cos(lambda),
    y: cosPhi * Math.sin(lambda),
    z: Math.sin(phi)
  }
}

function angularDistance(v1, v2) {
  var dot = clamp(v1.x * v2.x + v1.y * v2.y + v1.z * v2.z, -1, 1)
  return Math.acos(dot)
}

function interpolateArc(v1, v2, theta, t, altitude) {
  var sinTheta = Math.sin(theta)
  var vx, vy, vz
  if (sinTheta < 1e-5) {
    vx = (1 - t) * v1.x + t * v2.x
    vy = (1 - t) * v1.y + t * v2.y
    vz = (1 - t) * v1.z + t * v2.z
    var len = Math.sqrt(vx * vx + vy * vy + vz * vz) || 1
    vx /= len
    vy /= len
    vz /= len
  } else {
    var w1 = Math.sin((1 - t) * theta) / sinTheta
    var w2 = Math.sin(t * theta) / sinTheta
    vx = w1 * v1.x + w2 * v2.x
    vy = w1 * v1.y + w2 * v2.y
    vz = w1 * v1.z + w2 * v2.z
  }
  var h = 1.0 + (altitude || 0) * Math.sin(Math.PI * t)
  return {
    x: vx * h,
    y: vy * h,
    z: vz * h
  }
}

function generateArcWaypoints(v1, v2, altitude, steps) {
  var theta = angularDistance(v1, v2)
  var numSteps = steps || Math.max(16, Math.min(60, Math.round(theta * 24)))
  var waypoints = []
  for (var i = 0; i <= numSteps; i++) {
    var t = i / numSteps
    var pt = interpolateArc(v1, v2, theta, t, altitude)
    pt.t = t
    waypoints.push(pt)
  }
  return waypoints
}

function latencyColor(ping, connected, healthyColor, backupColor, urgentColor) {
  if (connected === false) return urgentColor
  var p = Number(ping)
  if (!isFinite(p) || p <= 0) return healthyColor
  if (p < 35) return healthyColor
  if (p <= 80) return backupColor
  return urgentColor
}

function findSite(sites, identifier) {
  if (!sites || !identifier) return null
  if (typeof identifier === "object" && identifier.lat !== undefined && identifier.lng !== undefined) {
    return identifier
  }
  var key = String(identifier).trim().toLowerCase()
  for (var i = 0; i < sites.length; i++) {
    var s = sites[i]
    if (!s) continue
    if (s.id && String(s.id).trim().toLowerCase() === key) return s
    if (s.hostId && String(s.hostId).trim().toLowerCase() === key) return s
    if (s.name && String(s.name).trim().toLowerCase() === key) return s
  }
  return null
}

