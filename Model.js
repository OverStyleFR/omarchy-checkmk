// Helpers for tomv.checkmk (parsing, sorting, formatting, URL building).

function parseProblems(raw) {
  var text = String(raw || "")
  if (!text) return null
  try {
    var parsed = JSON.parse(text)
    if (!parsed || typeof parsed !== "object") return null
    if (!parsed.summary) parsed.summary = { hostsDown: 0, servicesCritical: 0, servicesWarning: 0, servicesUnknown: 0, total: 0 }
    if (!parsed.problems) parsed.problems = []
    if (!parsed.worstState) parsed.worstState = "ok"
    return parsed
  } catch (e) {
    return null
  }
}

function severityRank(state) {
  var s = String(state || "").toLowerCase()
  if (s === "critical" || s === "down") return 4
  if (s === "unreachable") return 3
  if (s === "unknown") return 2
  if (s === "warning") return 1
  return 0
}

function stateColor(state, bar) {
  if (!bar) return "#888888"
  var s = String(state || "").toLowerCase()
  if (s === "critical" || s === "down") return bar.urgent
  if (s === "unreachable") return "#c084fc"
  if (s === "unknown") return "#a78bfa"
  if (s === "warning") return "#fbbf24"
  if (s === "ok") return "#4ade80"
  return Qt.darker(bar.foreground, 1.5)
}

function stateIcon(state) {
  var s = String(state || "").toLowerCase()
  if (s === "critical" || s === "down") return "\uf071" // fa-exclamation-triangle
  if (s === "unreachable" || s === "unknown") return "\uf059" // fa-question-circle
  if (s === "warning") return "\uf06a" // fa-exclamation-circle
  return "\uf058" // fa-check-circle
}

function typeIcon(type) {
  var t = String(type || "").toLowerCase()
  if (t === "host") return "\uf233" // fa-server
  return "\uf013" // fa-cog
}

function formatDuration(isoOrEpoch) {
  if (!isoOrEpoch || isoOrEpoch === "") return ""
  var thenMs = 0
  var n = Number(isoOrEpoch)
  if (isFinite(n) && n > 1000000000) {
    // Unix epoch seconds from Livestatus.
    thenMs = n * 1000
  } else {
    thenMs = Date.parse(String(isoOrEpoch))
  }
  if (!isFinite(thenMs) || thenMs <= 0) return ""
  var diff = Math.max(0, Math.floor((Date.now() - thenMs) / 1000))
  var d = Math.floor(diff / 86400)
  diff -= d * 86400
  var h = Math.floor(diff / 3600)
  diff -= h * 3600
  var m = Math.floor(diff / 60)
  var s = diff - m * 60
  if (d > 0) return d + "d " + h + "h"
  if (h > 0) return h + "h " + m + "m"
  if (m > 0) return m + "m " + s + "s"
  return s + "s"
}

function buildCheckmkUrl(baseUrl, host, service) {
  var base = String(baseUrl || "").replace(/\/$/, "")
  if (!base) return ""
  var url = base + "/check_mk/index.py?start_url="
  var path = "view.py?view_name="
  if (service !== undefined && service !== null && service !== "") {
    path += "service&host=" + encodeURIComponent(host) + "&service=" + encodeURIComponent(service)
  } else {
    path += "host_status&host=" + encodeURIComponent(host)
  }
  return url + encodeURIComponent(path)
}

function shortError(text) {
  var t = String(text || "").trim()
  if (t.length === 0) return "Failed"
  try {
    var parsed = JSON.parse(t)
    if (parsed && parsed.error) return String(parsed.error)
    if (parsed && parsed.title && parsed.detail) return String(parsed.detail)
  } catch (e) {}
  var lines = t.split("\n")
  var last = lines[lines.length - 1].trim()
  if (last.length > 80) last = last.substring(0, 77) + "…"
  return last
}

function groupProblems(problems) {
  var list = Array.isArray(problems) ? problems : []
  var groups = []
  var currentSeverity = null
  var currentList = []
  for (var i = 0; i < list.length; i++) {
    var p = list[i]
    var sev = severityRank(p.state)
    if (sev !== currentSeverity) {
      if (currentList.length > 0) {
        groups.push({ severity: currentSeverity, severityName: currentList[0].state, items: currentList })
      }
      currentSeverity = sev
      currentList = []
    }
    currentList.push(p)
  }
  if (currentList.length > 0) {
    groups.push({ severity: currentSeverity, severityName: currentList[0].state, items: currentList })
  }
  return groups
}

function flattenWithHeaders(problems) {
  var groups = groupProblems(problems)
  var out = []
  var flatIndex = 0
  for (var g = 0; g < groups.length; g++) {
    var group = groups[g]
    out.push({ kind: "header", state: group.severityName, count: group.items.length })
    for (var i = 0; i < group.items.length; i++) {
      out.push({ kind: "problem", problem: group.items[i], flatIndex: flatIndex })
      flatIndex++
    }
  }
  return out
}

function problemKey(p) {
  if (!p) return ""
  if (p.type === "host") return "host:" + (p.host || "")
  return "service:" + (p.host || "") + "|" + (p.service || "")
}

if (typeof module !== "undefined") {
  module.exports = {
    parseProblems: parseProblems,
    severityRank: severityRank,
    stateColor: stateColor,
    stateIcon: stateIcon,
    typeIcon: typeIcon,
    formatDuration: formatDuration,
    buildCheckmkUrl: buildCheckmkUrl,
    shortError: shortError,
    groupProblems: groupProblems,
    flattenWithHeaders: flattenWithHeaders,
    problemKey: problemKey
  }
}
