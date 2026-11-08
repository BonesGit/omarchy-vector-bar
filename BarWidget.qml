import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Shared.js" as Shared

// Vector chat popover toggle. Left-click toggles the window; right-click
// opens settings. bin/vector-toggle owns show/hide/dock and settings.json;
// this widget launches it and edits plugin settings via --apply.

BarWidget {
  id: root
  // moduleName is injected by the bar. Binding it here makes the
  // property read-only and injectProps() throws before settings land.

  readonly property string tooltip: "Vector Bar"
  property bool settingsOpen: false

  // Plugin-owned settings (not Omarchy shell.json). Defaults until FileView
  // loads ~/.config/io.github.bonesgit.omarchy-vector-bar/settings.json.
  property var pluginSettings: ({
    command: "",
    width: 385,
    height: 640,
    topPadding: 32,
    rightPadding: 6,
    pin: true
  })

  onSettingsOpenChanged: {
    if (settingsOpen) Shared.claimSettings(root)
    else Shared.releaseSettings(root)
  }

  // Plugin root on disk. Qt.resolvedUrl is qs:// or file://; strip to a
  // real path so the kernel can exec the helper.
  readonly property string pluginDir: decodeURIComponent(
    String(Qt.resolvedUrl("."))
      .replace(/^file:\/\//, "")
      .replace(/^qs:\/\/\//, "/")
  ).replace(/\/$/, "")

  readonly property string toggleCmd: root.pluginDir + "/bin/vector-toggle"

  readonly property string settingsPath: Quickshell.env("HOME")
    + "/.config/io.github.bonesgit.omarchy-vector-bar/settings.json"

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.pluginSettings = root.normalizedSettings(text())
    onLoadFailed: root.pluginSettings = root.normalizedSettings("")
    onFileChanged: reload()
  }

  function normalizedSettings(raw) {
    var d = {}
    if (raw && String(raw).trim() !== "") {
      try { d = JSON.parse(raw) } catch (e) { d = {} }
    }
    if (!d || typeof d !== "object") d = {}
    function asInt(v, fallback) {
      var n = Number(v)
      return (v !== undefined && v !== null && !isNaN(n)) ? Math.round(n) : fallback
    }
    return {
      command: typeof d.command === "string" ? d.command : "",
      width: asInt(d.width, 385),
      height: asInt(d.height, 640),
      topPadding: asInt(d.topPadding, 32),
      rightPadding: asInt(d.rightPadding, 6),
      pin: typeof d.pin === "boolean" ? d.pin : true
    }
  }

  // Color mark while a Vector Hyprland client exists (running, including
  // parked on special:vector-bar); greyscale when the process/window is gone.
  readonly property bool appRunning: {
    var list = Hyprland.toplevels.values
    var n = list.length
    for (var i = 0; i < n; i++) {
      var ipc = list[i].lastIpcObject
      if (ipc && ipc["class"] === "Vector") return true
    }
    return false
  }

  // Last Hyprland size seen for any Vector client (including parked). Kept so
  // a quit (window destroyed) can still persist a manual resize.
  property var lastKnownSize: null

  readonly property var vectorClientSize: {
    var list = Hyprland.toplevels.values
    var n = list.length
    for (var i = 0; i < n; i++) {
      var ipc = list[i].lastIpcObject
      if (!ipc || ipc["class"] !== "Vector") continue
      var sz = ipc["size"]
      if (sz && sz.length >= 2) return [Number(sz[0]), Number(sz[1])]
    }
    return null
  }

  onVectorClientSizeChanged: {
    if (vectorClientSize && vectorClientSize.length >= 2)
      lastKnownSize = [Math.round(vectorClientSize[0]), Math.round(vectorClientSize[1])]
  }

  onAppRunningChanged: {
    // Quit path: hide already remembered; this catches resize-then-quit.
    if (!appRunning && lastKnownSize && lastKnownSize.length >= 2)
      root.runToggle([
        "--remember",
        "--width", String(lastKnownSize[0]),
        "--height", String(lastKnownSize[1])
      ])
  }

  function close() {
    root.settingsOpen = false
  }

  function runToggle(args) {
    var argv = [root.toggleCmd]
    if (args && args.length) {
      for (var i = 0; i < args.length; i++) argv.push(args[i])
    }
    Quickshell.execDetached(argv)
  }

  function toggle() {
    root.runToggle([])
  }

  function dock() {
    root.runToggle(["--dock"])
  }

  function settingInt(entry, key, fallback) {
    var n = Number(entry[key])
    return (entry[key] !== undefined && entry[key] !== null && !isNaN(n)) ? Math.round(n) : fallback
  }

  // Live Vector size from Hyprland (null when absent / parked). Used so the
  // settings card reflects a manual resize before the next hide snapshot.
  readonly property var vectorLiveSize: {
    var list = Hyprland.toplevels.values
    var n = list.length
    for (var i = 0; i < n; i++) {
      var ipc = list[i].lastIpcObject
      if (!ipc || ipc["class"] !== "Vector") continue
      var ws = ipc["workspace"]
      var name = ws && typeof ws === "object" ? ws["name"] : ws
      if (name === "special:vector-bar") return null
      var sz = ipc["size"]
      if (sz && sz.length >= 2) return [Number(sz[0]), Number(sz[1])]
    }
    return null
  }

  function applyLive(entry, resize) {
    // Pass values on the argv so apply does not race the settings.json write.
    // Only forward width/height when the patch changed size — otherwise a
    // pin/padding apply would stomp a manual resize.
    var argv = [
      "--apply",
      "--pin", (entry.pin === false) ? "0" : "1",
      "--command", entry.command || "",
      "--top-padding", String(root.settingInt(entry, "topPadding", 32)),
      "--right-padding", String(root.settingInt(entry, "rightPadding", 6))
    ]
    if (resize) {
      argv.push(
        "--width", String(root.settingInt(entry, "width", 385)),
        "--height", String(root.settingInt(entry, "height", 640))
      )
    }
    root.runToggle(argv)
  }

  function saveSettings(patch) {
    var entry = root.normalizedSettings(JSON.stringify(root.pluginSettings || {}))
    for (var k in patch) entry[k] = patch[k]
    root.pluginSettings = entry
    root.applyLive(entry, ("width" in patch) || ("height" in patch))
  }

  IpcHandler {
    target: "io.github.bonesgit.omarchy-vector-bar"
    function toggle(): void { root.toggle() }
    function dock(): void { root.dock() }
    // Called by vector-esc before hide/forward so Escape closes settings first.
    // (Method cannot be named "escape" — illegal for IpcHandler.)
    function closeSettings(): string {
      return Shared.closeSettings() ? "closed" : "none"
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    labelVisible: false
    hasVisualContent: true
    tooltipText: root.tooltip
    fixedWidth: root.vertical ? -1 : Style.bar.iconSlot
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1

    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) return
      if (buttonCode === Qt.RightButton) {
        root.settingsOpen = !root.settingsOpen
        return
      }
      if (root.settingsOpen) root.settingsOpen = false
      root.toggle()
    }

    Item {
      anchors.fill: parent

      Image {
        id: vecIcon
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        // Bright gradient sits high; nudge down to match optical-glyph icons.
        anchors.verticalCenterOffset: 3
        width: 16
        height: 16
        source: Qt.resolvedUrl(
          root.appRunning ? "assets/vector-mark.svg" : "assets/vector-mark-off.svg")
        fillMode: Image.PreserveAspectFit
        smooth: false
        mipmap: false
      }
      Text {
        anchors.centerIn: parent
        visible: vecIcon.status !== Image.Ready
        textFormat: Text.PlainText
        text: "V"
        font.pointSize: Math.round(Style.bar.iconSlot * 0.5)
        font.bold: true
        color: "white"
      }
    }
  }

  SettingsPopup {
    id: settingsPopup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.settingsOpen
    settings: root.pluginSettings
    liveSize: root.vectorLiveSize
    foreground: root.bar ? root.bar.barForeground : Commons.Color.foreground
    accent: Commons.Color.accent
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
    onSaveRequested: function(patch) { root.saveSettings(patch) }
    onDockRequested: root.dock()
  }
}
