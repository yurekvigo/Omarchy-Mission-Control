import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Mission Control's bar button: a small drawing of the overview (a row of
// workspace cards over three windows) in the bar's colour. Left click: open
// or close Mission Control. Right click: a box with its settings (the same
// switches as in Settings, Open Mission Control, and About, which opens
// Mission Control on that page; Remove Plugin is only in Settings). Hidden
// when Settings > Bar Widget is off (the settings live
// in ~/.config/omarchy-mission-control/settings.json, shared with the overview; the box
// changes them through the overview, so both stay in step).
BarWidget {
  id: root
  moduleName: "io.github.yurekvigo.mission-control"

  property bool shown: true
  property bool launcherIcon: true
  property bool boxOpen: false
  // The box calls this when it closes itself (a click elsewhere, or Mission
  // Control taking the screen). Without it the box set its own `open` and
  // lost its link to boxOpen, so right clicks stopped opening it.
  function close() { boxOpen = false }
  readonly property color boxForeground: Commons.Color.popups.text
  readonly property string boxFont: root.bar ? root.bar.fontFamily : Style.font.family
  function ipc(args) { Quickshell.execDetached(["omarchy-shell", "io.github.yurekvigo.mission-control"].concat(args)) }

  FileView {
    path: Quickshell.env("HOME") + "/.config/omarchy-mission-control/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        var s = JSON.parse(text())
        root.shown = s.barWidget !== false
        root.launcherIcon = s.launcherIcon !== false
      } catch (e) { root.shown = true; root.launcherIcon = true }
    }
    onLoadFailed: { root.shown = true; root.launcherIcon = true }
  }

  visible: shown
  implicitWidth: shown ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    visible: root.shown
    bar: root.bar
    tooltipText: "Mission Control"
    iconComponent: Component {
      Item {
        id: glyph
        implicitWidth: Style.bar.iconSize
        implicitHeight: Style.bar.iconSize
        width: implicitWidth
        height: implicitHeight
        readonly property color ink: root.bar ? root.bar.barForeground : Commons.Color.foreground
        readonly property real u: width / 16
        // Three workspace cards (the first filled) over three windows.
        Rectangle { x: 0; y: 1 * glyph.u; width: 4.4 * glyph.u; height: 3 * glyph.u; radius: 0.8 * glyph.u; color: glyph.ink }
        Repeater {
          model: 2
          Rectangle {
            required property int index
            x: (5.8 + index * 5.1) * glyph.u; y: 1 * glyph.u; width: 4.4 * glyph.u; height: 3 * glyph.u; radius: 0.8 * glyph.u
            color: "transparent"; border.color: glyph.ink; border.width: Math.max(1, 0.9 * glyph.u)
          }
        }
        Rectangle { x: 0; y: 6 * glyph.u; width: 7.4 * glyph.u; height: 4.4 * glyph.u; radius: 0.9 * glyph.u; color: glyph.ink }
        Rectangle { x: 8.6 * glyph.u; y: 6 * glyph.u; width: 7.4 * glyph.u; height: 4.4 * glyph.u; radius: 0.9 * glyph.u; color: glyph.ink }
        Rectangle { x: 4.3 * glyph.u; y: 11.4 * glyph.u; width: 7.4 * glyph.u; height: 4.2 * glyph.u; radius: 0.9 * glyph.u; color: glyph.ink }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) {
        root.boxOpen = !root.boxOpen
      } else {
        root.boxOpen = false
        root.ipc(["toggle"])
      }
    }
  }

  // ------------------------------------------------- right-click box
  // `omarchy-shell io.github.yurekvigo.mission-control.bar box` opens or closes it (same as a
  // right click; for a keyboard shortcut or a test).
  ShellIpc {
    target: "io.github.yurekvigo.mission-control.bar"
    function box(): void { root.boxOpen = !root.boxOpen }
  }

  PopupCard {
    id: box
    anchorItem: root
    owner: root
    bar: root.bar
    open: root.boxOpen && root.shown
    contentWidth: box.fittedContentWidth(Style.space(250))
    contentHeight: box.fittedContentHeight(boxColumn.implicitHeight)

    Column {
      id: boxColumn
      anchors.fill: parent
      spacing: Style.space(2)

      Text {
        textFormat: Text.PlainText
        text: "MISSION CONTROL"
        bottomPadding: Style.space(6)
        color: Qt.alpha(root.boxForeground, 0.55)
        font.family: root.boxFont
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: Style.space(1.5)
      }

      ActionRow { glyph: "\uf2d0"; label: "Open Mission Control"; onPick: { root.boxOpen = false; root.ipc(["open"]) } }

      Rectangle { width: boxColumn.width; height: 1; color: Qt.alpha(root.boxForeground, 0.12) }

      SwitchRow {
        label: "Application Icon"
        on: root.launcherIcon
        onFlip: root.ipc(["setFlag", "launcherIcon", root.launcherIcon ? "false" : "true"])
      }
      SwitchRow {
        label: "Bar Widget"
        on: root.shown
        onFlip: { root.boxOpen = false; root.ipc(["setFlag", "barWidget", root.shown ? "false" : "true"]) }
      }

      Rectangle { width: boxColumn.width; height: 1; color: Qt.alpha(root.boxForeground, 0.12) }

      ActionRow { glyph: "\uf05a"; label: "About\u2026"; onPick: { root.boxOpen = false; root.ipc(["showSettings", "about"]) } }
    }
  }

  component SwitchRow: Item {
    id: sw
    property string label: ""
    property bool on: true
    signal flip()
    width: parent ? parent.width : Style.space(250)
    implicitHeight: Style.space(34)
    height: implicitHeight
    Text {
      x: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: sw.label
      color: Commons.Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    ToggleSwitch {
      anchors.right: parent.right
      anchors.rightMargin: Style.space(4)
      anchors.verticalCenter: parent.verticalCenter
      checked: sw.on
      onToggled: sw.flip()
    }
  }

  component ActionRow: Item {
    id: act
    property string glyph: ""
    property string label: ""
    property bool danger: false
    signal pick()
    width: parent ? parent.width : Style.space(250)
    implicitHeight: Style.space(30)
    height: implicitHeight
    readonly property color ink: danger ? Commons.Color.urgent : Commons.Color.popups.text
    Rectangle {
      anchors.fill: parent
      radius: Style.space(6)
      visible: actMouse.containsMouse
      color: Qt.alpha(Commons.Color.accent, 0.16)
    }
    Text {
      id: actGlyph
      x: Style.space(8)
      width: Style.space(18)
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignHCenter
      textFormat: Text.PlainText
      text: act.glyph
      color: act.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.body
    }
    Text {
      anchors.left: actGlyph.right
      anchors.leftMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: act.label
      color: act.ink
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }
    MouseArea {
      id: actMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: act.pick()
    }
  }
}
