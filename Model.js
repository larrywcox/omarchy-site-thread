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
  return (cloud ? ["Overview", "Sites"] : ["Overview", "Network", "Protect"])[index] || "Overview"
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
