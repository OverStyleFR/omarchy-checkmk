import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "Model.js" as Model

// Panel tomv.checkmk : liste des problèmes CheckMK avec actions.
Panel {
  id: root
  moduleName: "tomv.checkmk"
  ipcTarget: "tomv.checkmk"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // État brut du script checkmk-status.
  property var checkState: ({ summary: { hostsDown: 0, servicesCritical: 0, servicesWarning: 0, servicesUnknown: 0, total: 0 }, worstState: "ok", problems: [] })
  property bool loading: false
  property string lastError: ""

  readonly property int refreshInterval: Math.max(5, Number(root.setting("refreshIntervalSec", 30)))
  readonly property string baseUrl: String(root.setting("baseUrl", "https://checkmk.example.com/monitoring"))
  readonly property string apiVersion: String(root.setting("apiVersion", "1.0"))
  readonly property bool showAcknowledged: root.setting("showAcknowledged", false) === true
  readonly property int maxItemsInPanel: Math.max(1, Number(root.setting("maxItemsInPanel", 50)))
  readonly property bool useHostAlerts: root.setting("useHostAlerts", true) !== false
  readonly property bool useServiceAlerts: root.setting("useServiceAlerts", true) !== false
  readonly property string acknowledgeComment: String(root.setting("acknowledgeComment", "Ack from Omarchy bar"))

  readonly property color barColor: Model.stateColor(root.checkState.worstState, root.bar)
  readonly property string barText: root.lastError !== "" ? "ERROR" : (root.checkState.summary.total > 0 ? "\uf071 " + root.checkState.summary.total : "\uf071")
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"

  // Keyboard cursor.
  property bool cursorActive: false
  property int selectedIndex: -1
  property string selectedKey: ""

  function pluginScript(name) {
    var url = String(Qt.resolvedUrl("scripts/" + name))
    return decodeURIComponent(url.replace(/^file:\/\//, ""))
  }

  function refresh() {
    if (statusProc.running) return
    root.loading = true
    statusProc.running = true
  }

  function problemAt(idx) {
    if (idx < 0 || idx >= root.checkState.problems.length) return null
    return root.checkState.problems[idx]
  }

  function indexForProblemKey(key) {
    for (var i = 0; i < root.checkState.problems.length; i++) {
      if (Model.problemKey(root.checkState.problems[i]) === key) return i
    }
    return -1
  }

  function currentProblem() {
    if (!root.cursorActive || root.selectedIndex < 0) return null
    return problemAt(root.selectedIndex)
  }

  function openUrl(url) {
    if (!url) return
    Quickshell.execDetached(["omarchy-launch-browser", url])
  }

  function openProblemUrl(p) {
    if (!p) return
    var url = Model.buildCheckmkUrl(root.baseUrl, p.host, p.service)
    openUrl(url)
  }

  function acknowledgeCurrent() {
    var p = currentProblem()
    if (!p) return
    var target = p.type === "host" ? p.host : (p.host + "|" + p.service)
    ackProc.command = ["bash", "-c", root.pluginScript("checkmk-status") +
      " --base-url " + Util.shellQuote(root.baseUrl) +
      " --api-version " + Util.shellQuote(root.apiVersion) +
      " --acknowledge " + Util.shellQuote(target) +
      " " + Util.shellQuote(root.acknowledgeComment)]
    ackProc.running = true
  }

  function recheckCurrent() {
    var p = currentProblem()
    if (!p) return
    if (p.type === "host") {
      recheckProc.command = ["bash", "-c", root.pluginScript("checkmk-status") +
        " --base-url " + Util.shellQuote(root.baseUrl) +
        " --api-version " + Util.shellQuote(root.apiVersion) +
        " --recheck-host " + Util.shellQuote(p.host)]
    } else {
      recheckProc.command = ["bash", "-c", root.pluginScript("checkmk-status") +
        " --base-url " + Util.shellQuote(root.baseUrl) +
        " --api-version " + Util.shellQuote(root.apiVersion) +
        " --recheck-service " + Util.shellQuote(p.host + "|" + p.service)]
    }
    recheckProc.running = true
  }

  function moveCursor(delta) {
    var count = root.checkState.problems.length
    if (count === 0) return
    if (!root.cursorActive) {
      root.cursorActive = true
      root.selectedIndex = 0
    } else {
      root.selectedIndex = Math.max(0, Math.min(count - 1, root.selectedIndex + delta))
    }
    root.selectedKey = Model.problemKey(problemAt(root.selectedIndex))
    listView.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  onOpenedChanged: {
    if (opened) {
      refresh()
      root.cursorActive = false
      root.selectedIndex = -1
      root.selectedKey = ""
    }
  }

  Timer {
    id: poll
    interval: root.refreshInterval * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: ["bash", "-c", root.pluginScript("checkmk-status") +
      " --base-url " + Util.shellQuote(root.baseUrl) +
      " --api-version " + Util.shellQuote(root.apiVersion) +
      (root.showAcknowledged ? " --show-acknowledged" : "") +
      " --max-items " + root.maxItemsInPanel +
      " --use-host-alerts " + root.useHostAlerts +
      " --use-service-alerts " + root.useServiceAlerts +
      " --problems"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var parsed = Model.parseProblems(text)
        if (parsed) {
          root.checkState = parsed
          root.lastError = ""
        } else {
          root.lastError = Model.shortError(text)
        }
        root.loading = false
      }
    }
    onExited: function(exitCode) {
      root.loading = false
      if (exitCode !== 0 && root.lastError === "") {
        root.lastError = "CheckMK query failed"
      }
    }
  }

  Process {
    id: ackProc
    stderr: StdioCollector { id: ackStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.shortError(String(ackStderr.text || "").trim())
      }
      root.refresh()
    }
  }

  Process {
    id: recheckProc
    stderr: StdioCollector { id: recheckStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.lastError = Model.shortError(String(recheckStderr.text || "").trim())
      }
    }
  }

  IpcHandler {
    target: "tomv.checkmk"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): void { root.refresh() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dy !== 0) root.moveCursor(dy)
        if (dx !== 0) {
          // Left/right reserved for future use.
        }
      }
      onActivateRequested: root.openProblemUrl(root.currentProblem())
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (t === "r" || t === "R") root.refresh()
        else if (t === "a" || t === "A") root.acknowledgeCurrent()
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(12)

        // ---------- Hero : icône · titre · compteurs ----------
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

          Text {
            id: heroIcon
            text: "\uf071"
            color: root.barColor
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(12)
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "CheckMK"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
              width: parent.width
            }

            Text {
              text: root.lastError !== "" ? root.lastError.toUpperCase()
                  : root.loading ? "LOADING…"
                  : root.checkState.summary.total === 0 ? "All systems OK"
                  : "DOWN " + root.checkState.summary.hostsDown +
                    " · CRIT " + root.checkState.summary.servicesCritical +
                    " · WARN " + root.checkState.summary.servicesWarning +
                    " · UNK " + root.checkState.summary.servicesUnknown
              color: root.lastError !== "" ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.0
              elide: Text.ElideRight
              width: parent.width
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        // ---------- Liste des problèmes ----------
        ListView {
          id: listView
          width: parent.width
          height: Math.min(contentHeight, Style.space(360))
          spacing: Style.space(2)
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          interactive: contentHeight > height
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          model: root.checkState.problems
          section.property: "state"
          section.criteria: ViewSection.FullString
          section.delegate: PanelSectionHeader {
            required property string section
            text: section.toUpperCase()
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          delegate: ProblemRow {
            width: ListView.view.width
            problem: modelData
            flatIndex: index
          }
        }

        Text {
          visible: root.checkState.problems.length === 0 && !root.loading && root.lastError === ""
          text: "No active problems"
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
        }

        // ---------- Légende raccourcis ----------
        Text {
          visible: root.checkState.problems.length > 0
          text: "r refresh · a acknowledge · Enter open · Esc close"
          color: Qt.darker(root.bar.foreground, 1.7)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
        }
      }
    }
  }

  component ProblemRow: CursorSurface {
    id: row
    property var problem: null
    property int flatIndex: 0

    readonly property bool rowSelected: root.cursorActive && root.selectedIndex === row.flatIndex
    readonly property string itemKey: Model.problemKey(row.problem)

    hasCursor: row.rowSelected
    foreground: root.bar.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill

    implicitHeight: rowContent.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.selectedIndex = row.flatIndex
        root.selectedKey = row.itemKey
      }
      onClicked: root.openProblemUrl(row.problem)
    }

    RowLayout {
      id: rowContent
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(8)

      Text {
        text: row.problem ? Model.typeIcon(row.problem.type) : ""
        color: row.problem ? Model.stateColor(row.problem.state, root.bar) : root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.icon
        Layout.alignment: Qt.AlignVCenter
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.space(6)

          Text {
            text: row.problem ? row.problem.host : ""
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            font.bold: true
            elide: Text.ElideRight
            Layout.maximumWidth: row.problem && row.problem.service ? parent.width * 0.45 : parent.width
          }

          Text {
            visible: row.problem && row.problem.service
            text: row.problem && row.problem.service ? row.problem.service : ""
            color: Qt.darker(root.bar.foreground, 1.3)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
        }

        Text {
          text: row.problem && row.problem.output ? row.problem.output : ""
          color: Qt.darker(root.bar.foreground, 1.5)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
          Layout.fillWidth: true
        }
      }

      Text {
        text: row.problem ? Model.formatDuration(row.problem.last_state_change) : ""
        color: Qt.darker(root.bar.foreground, 1.6)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        Layout.alignment: Qt.AlignVCenter
      }

      Row {
        spacing: Style.space(2)
        Layout.alignment: Qt.AlignVCenter

        PanelActionButton {
          iconText: "\uf00c"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          enabled: row.rowSelected
          tooltipText: "Acknowledge"
          onClicked: {
            root.cursorActive = true
            root.selectedIndex = row.flatIndex
            root.selectedKey = row.itemKey
            root.acknowledgeCurrent()
          }
        }

        PanelActionButton {
          iconText: "\uf021"
          foreground: root.bar.foreground
          hoverColor: root.bar.urgent
          fontFamily: root.bar.fontFamily
          enabled: row.rowSelected
          tooltipText: "Recheck (not supported by CheckMK REST API)"
          onClicked: {
            root.cursorActive = true
            root.selectedIndex = row.flatIndex
            root.selectedKey = row.itemKey
            root.recheckCurrent()
          }
        }

        PanelActionButton {
          iconText: "\uf08e"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          enabled: row.rowSelected
          tooltipText: "Open in CheckMK"
          onClicked: {
            root.cursorActive = true
            root.selectedIndex = row.flatIndex
            root.selectedKey = row.itemKey
            root.openProblemUrl(row.problem)
          }
        }
      }
    }
  }
}
