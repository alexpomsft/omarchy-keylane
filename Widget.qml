import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "alexpomsft.keylane"

  // "stopped" | "missing" | "no-vault" | "locked" | "unlocked"
  property string vaultState: "stopped"
  property int conflicts: 0
  readonly property int intervalSec: Math.max(1, Number(setting("refreshIntervalSec", 3)))
  readonly property bool showWhenStopped: setting("showWhenStopped", true) === true

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function apply(text) {
    try {
      var s = JSON.parse(String(text || "{}"))
      conflicts = Number(s.conflicts || 0)
      if (!s.running) vaultState = "stopped"
      else if (s.session === "unlocked") vaultState = "unlocked"
      else if (s.session === "no-vault" || s.vault_configured === false) vaultState = "no-vault"
      else vaultState = "locked"
    } catch (e) {
      vaultState = "stopped"
    }
  }

  function act(cmd) {
    if (!root.bar) return
    root.bar.run("keylane " + cmd)
    refreshSoon.restart()
  }

  visible: vaultState !== "missing" && (showWhenStopped || vaultState !== "stopped")
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  IpcHandler {
    target: "alexpomsft.keylane"
    function refresh(): void { root.broadcast("refresh") }
  }

  Process {
    id: statusProc
    command: ["keylane", "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
    onExited: function(exitCode) {
      // 127: keylane is not on PATH
      if (exitCode === 127) root.vaultState = "missing"
    }
  }

  Timer {
    interval: root.intervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer { id: refreshSoon; interval: 400; onTriggered: root.refresh() }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vaultState === "unlocked" ? "\uf09c" : "\uf023"
    active: root.vaultState === "unlocked" || root.conflicts > 0
    dimmed: root.vaultState === "stopped"
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    tooltipText: {
      var t = root.vaultState === "unlocked" ? "Keylane: unlocked"
            : root.vaultState === "locked" ? "Keylane: locked"
            : root.vaultState === "no-vault" ? "Keylane: no vault chosen"
            : "Keylane: not running"
      if (root.conflicts > 0) t += " · " + root.conflicts + " sync conflict(s)"
      return t + "\nClick: search · Middle: manager · Right: lock"
    }
    onPressed: function(b) {
      if (b === Qt.RightButton) root.act("lock")
      else if (b === Qt.MiddleButton) root.act("manager")
      else root.act("search")
    }
  }
}
