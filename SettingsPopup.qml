import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Right-click settings card for the Vector Bar pill.
PopupCard {
  id: root

  property var settings: ({})
  // [width, height] from the live Hyprland client when Vector is visible.
  property var liveSize: null
  property color foreground: Commons.Color.foreground
  property color accent: Commons.Color.accent
  property string fontFamily: Style.font.family

  signal saveRequested(var patch)
  signal dockRequested()

  contentWidth: root.fittedContentWidth(Style.space(320))
  contentHeight: root.fittedContentHeight(body.implicitHeight)

  function settingInt(key, fallback) {
    var v = root.settings ? root.settings[key] : undefined
    var n = Number(v)
    return (v !== undefined && v !== null && !isNaN(n)) ? Math.round(n) : fallback
  }

  function settingBool(key, fallback) {
    var v = root.settings ? root.settings[key] : undefined
    return typeof v === "boolean" ? v : fallback
  }

  function settingStr(key, fallback) {
    var v = root.settings ? root.settings[key] : undefined
    return typeof v === "string" ? v : fallback
  }

  function syncFields() {
    commandField.text = root.settingStr("command", "")
    var live = root.liveSize
    var hasLive = live && live.length >= 2 && !isNaN(Number(live[0])) && !isNaN(Number(live[1]))
    widthField.field.value = hasLive ? Math.round(Number(live[0])) : root.settingInt("width", 385)
    heightField.field.value = hasLive ? Math.round(Number(live[1])) : root.settingInt("height", 640)
    topPadField.field.value = root.settingInt("topPadding", 32)
    rightPadField.field.value = root.settingInt("rightPadding", 6)
  }

  onOpenChanged: if (open) syncFields()

  Column {
    id: body
    width: parent.width
    spacing: Style.space(10)

    // Title row + Dock
    RowLayout {
      width: parent.width
      spacing: Style.space(8)

      Text {
        Layout.fillWidth: true
        textFormat: Text.PlainText
        text: "Vector Bar"
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }

      Button {
        text: "Dock"
        tooltipText: "Move Vector to the top-right anchor (uses paddings below)"
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        bordered: true
        onClicked: root.dockRequested()
      }
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      text: "Command or path (blank = auto-detect)"
      color: Qt.darker(root.foreground, 1.4)
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
    }

    TextField {
      id: commandField
      width: parent.width
      foreground: root.foreground
      accent: root.accent
      placeholderText: "Vector, ~/Applications/Vector.AppImage, …"
      onEditingFinished: root.saveRequested({ command: text.trim() })
      onAccepted: root.saveRequested({ command: text.trim() })
    }

    GridLayout {
      width: parent.width
      columns: 2
      columnSpacing: Style.space(10)
      rowSpacing: Style.space(8)

      NumberField {
        id: widthField
        Layout.fillWidth: true
        label: "Width"
        from: 385
        to: 1600
        stepSize: 10
        value: root.settingInt("width", 385)
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        fieldWidth: Style.space(130)
        onModified: function(v) { root.saveRequested({ width: v }) }
      }

      NumberField {
        id: heightField
        Layout.fillWidth: true
        label: "Height"
        from: 575
        to: 2400
        stepSize: 10
        value: root.settingInt("height", 640)
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        fieldWidth: Style.space(130)
        onModified: function(v) { root.saveRequested({ height: v }) }
      }

      NumberField {
        id: topPadField
        Layout.fillWidth: true
        label: "Top padding"
        from: 0
        to: 200
        stepSize: 2
        value: root.settingInt("topPadding", 32)
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        fieldWidth: Style.space(130)
        onModified: function(v) { root.saveRequested({ topPadding: v }) }
      }

      NumberField {
        id: rightPadField
        Layout.fillWidth: true
        label: "Right padding"
        from: 0
        to: 200
        stepSize: 2
        value: root.settingInt("rightPadding", 6)
        foreground: root.foreground
        accent: root.accent
        fontFamily: root.fontFamily
        fieldWidth: Style.space(130)
        onModified: function(v) { root.saveRequested({ rightPadding: v }) }
      }
    }

    Toggle {
      width: parent.width
      label: "Pin"
      description: "Stay on screen when switching workspaces."
      foreground: root.foreground
      accent: root.accent
      fontFamily: root.fontFamily
      checked: root.settingBool("pin", true)
      onClicked: root.saveRequested({ pin: !checked })
    }

    Text {
      width: parent.width
      textFormat: Text.PlainText
      wrapMode: Text.WordWrap
      text: "Tip: bind Escape in ~/.config/hypr/bindings.lua to hide Vector when it is focused (see README)."
      color: Qt.darker(root.foreground, 1.5)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }
}
