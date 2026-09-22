import QtQuick
import Quickshell
import qs.Ui
import qs.Commons

// Bar entry point for tomv.checkmk.
// Shows an alert glyph + total problem count, coloured by worst state.
// Left click toggles the panel, right click forces a refresh.
BarWidget {
  id: root
  moduleName: "tomv.checkmk"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: panelLoader.item ? panelLoader.item.barText : "\uf071"
    foreground: panelLoader.item ? panelLoader.item.barColor : root.bar.foreground
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        if (panelLoader.item) panelLoader.item.refresh()
      } else {
        root.toggle()
      }
    }
  }
}
