import Quickshell
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Mission Control's Settings window (gear button, bottom left of the
// overview): Application Icon and Bar Widget switches, About, and Remove
// Plugin with a confirmation step. `ov` is the Overview root; its
// `settingsPage` says which page shows ("menu", "about", "confirm").
BorderSurface {
  id: panel

  required property var ov
  // "menu": the Settings window itself; "detail": the window beside it that
  // shows About or the Remove confirmation.
  property string mode: "menu"

  readonly property color fg: ov.foreground
  readonly property color dim: Qt.alpha(ov.foreground, 0.6)
  readonly property color accent: ov.selectedText
  readonly property color danger: Commons.Color.urgent
  readonly property string font: ov.fontFamily
  readonly property real rowH: Style.space(58)

  width: mode === "menu" ? Style.space(380) : Style.space(460)
  height: pageColumn.implicitHeight + Style.space(40)
  radius: Math.max(ov.cornerRadius, Style.space(6))
  color: ov.background
  borderSpec: ov.borderSpec
  padding: Style.space(20)

  // Clicks inside stay inside (the area around closes the window).
  MouseArea { anchors.fill: parent; onWheel: function(w) { w.accepted = true } }

  Column {
    id: pageColumn
    x: Style.space(20)
    y: Style.space(20)
    width: panel.width - Style.space(40)
    spacing: Style.space(4)

    // ------------------------------------------------------------- menu
    Column {
      width: parent.width
      visible: panel.mode === "menu"
      spacing: Style.space(4)

      Row {
        spacing: Style.space(12)
        bottomPadding: Style.space(10)
        MiniIcon { size: Style.space(40); animated: false }
        Column {
          anchors.verticalCenter: parent.verticalCenter
          Text { text: "Mission Control"; color: panel.fg; font.family: panel.font; font.pixelSize: Style.font.heading; font.bold: true; textFormat: Text.PlainText }
          Text { text: "Settings"; color: panel.dim; font.family: panel.font; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
        }
      }

      SettingRow {
        title: "Application Icon"
        subtitle: "Show Mission Control in the app launcher"
        ToggleSwitch {
          anchors.verticalCenter: parent.verticalCenter
          checked: panel.ov.setting("launcherIcon", true)
          onToggled: panel.ov.setSetting("launcherIcon", !checked)
        }
      }
      SettingRow {
        title: "Bar Widget"
        subtitle: "Show the Mission Control button on the bar"
        ToggleSwitch {
          anchors.verticalCenter: parent.verticalCenter
          checked: panel.ov.setting("barWidget", true)
          onToggled: panel.ov.setSetting("barWidget", !checked)
        }
      }
      SettingRow {
        title: "Smooth Swipes"
        subtitle: panel.ov.helperBusy ? "Working\u2026 (asks for your password)"
                : panel.ov.helperInstalled ? "Helper installed: cards follow your fingers"
                : "Install the swipe helper (asks for your password)"
        ToggleSwitch {
          anchors.verticalCenter: parent.verticalCenter
          checked: panel.ov.helperInstalled
          busy: panel.ov.helperBusy
          onToggled: panel.ov.setHelper(!checked)
        }
      }
      SettingRow {
        title: "About"
        subtitle: "Who made this, and a few numbers"
        clickable: true
        onClicked: ov.settingsPage = "about"
        Text { anchors.verticalCenter: parent.verticalCenter; text: "›"; color: panel.dim; font.pixelSize: Style.font.heading * 1.4; textFormat: Text.PlainText }
      }
      SettingRow {
        title: "Remove Plugin"
        titleColor: panel.danger
        subtitle: "Take Mission Control off this computer"
        clickable: true
        onClicked: ov.settingsPage = "confirm"
        Text { anchors.verticalCenter: parent.verticalCenter; text: "›"; color: panel.danger; font.pixelSize: Style.font.heading * 1.4; textFormat: Text.PlainText }
      }
    }

    // ------------------------------------------------------- confirm
    Column {
      width: parent.width
      visible: panel.mode === "detail" && ov.lastDetail === "confirm"
      spacing: Style.space(14)

      Text { text: "Remove Mission Control?"; color: panel.fg; font.family: panel.font; font.pixelSize: Style.font.heading; font.bold: true; textFormat: Text.PlainText }
      Text {
        width: parent.width
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: panel.dim
        font.family: panel.font
        font.pixelSize: Style.font.body
        lineHeight: 1.25
        text: "This removes Mission Control and everything it set up: the overview, its shortcut and swipes, the app icon, the bar button and, if installed, the swipe helper (that part asks for your password). This can't be undone from here."
      }
      Row {
        anchors.right: parent.right
        spacing: Style.space(10)
        PanelButton { label: "Cancel"; onClicked: ov.settingsPage = "menu" }
        PanelButton { label: "Remove"; fill: panel.danger; labelColor: "#ffffff"; onClicked: ov.removePlugin() }
      }
    }

    // --------------------------------------------------------- about
    Column {
      width: parent.width
      visible: panel.mode === "detail" && ov.lastDetail === "about"
      spacing: Style.space(6)

      MiniIcon {
        anchors.horizontalCenter: parent.horizontalCenter
        size: Style.space(108)
        animated: ov.settingsPage === "about"
      }
      Item { width: 1; height: Style.space(6) }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Mission Control"; color: panel.fg; font.family: panel.font; font.pixelSize: Style.font.heading * 1.5; font.bold: true; textFormat: Text.PlainText }
      Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Version " + (ov.manifest && ov.manifest.version ? ov.manifest.version : "1.0.0") + "  ·  for Omarchy"; color: panel.dim; font.family: panel.font; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
      Text { anchors.horizontalCenter: parent.horizontalCenter; topPadding: Style.space(6); text: "Every workspace at a glance. Drag, swap, glide."; color: panel.fg; font.family: panel.font; font.pixelSize: Style.font.subtitle; font.italic: true; textFormat: Text.PlainText }

      Rectangle { width: parent.width; height: 1; color: Qt.alpha(panel.fg, 0.15); anchors.horizontalCenter: parent.horizontalCenter }

      Column {
        width: parent.width
        spacing: Style.space(4)
        topPadding: Style.space(6)
        CreditLine { who: "Yurek"; what: "Idea, design and every \"not quite, try again\"" }
        CreditLine { who: "Claude"; what: "Code, by Anthropic's AI, one change at a time" }
      }
      Text {
        width: parent.width
        topPadding: Style.space(8)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        textFormat: Text.PlainText
        color: panel.dim
        font.family: panel.font
        font.pixelSize: Style.font.bodySmall
        lineHeight: 1.25
        text: "Built together on 22 November 2026, in one long Sunday and more than fifty rounds of \"almost\": a spring that stretches to 400 px, windows that step aside before you drop them, and a theme change you never see."
      }
      Text {
        width: parent.width
        topPadding: Style.space(6)
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        color: panel.accent
        font.family: panel.font
        font.pixelSize: Style.font.body
        font.bold: true
        readonly property int windowCount: {
          var n = 0
          for (var i = 0; i < ov.cards.length; i++) n += ov.cards[i].windows.length
          return n
        }
        readonly property int busy: ov.cards.filter(function(c) { return c.windows.length > 0 }).length
        text: "Right now: " + busy + (busy === 1 ? " workspace" : " workspaces") + " in use · "
              + windowCount + (windowCount === 1 ? " window" : " windows") + " · opened "
              + ov.setting("opened", 0) + (ov.setting("opened", 0) === 1 ? " time" : " times")
      }
      Item { width: 1; height: Style.space(6) }
      PanelButton { anchors.horizontalCenter: parent.horizontalCenter; label: "Back"; onClicked: ov.settingsPage = "menu" }
    }
  }

  // ------------------------------------------------------- pieces
  component SettingRow: Item {
    id: row
    property string title: ""
    property string subtitle: ""
    property color titleColor: Commons.Color.menu.text
    property bool clickable: false
    signal clicked()
    default property alias trailing: trailingBox.data
    width: parent ? parent.width : Style.space(400)
    height: Style.space(58)

    Rectangle {
      anchors.fill: parent
      radius: Math.max(Style.cornerRadius, Style.space(4))
      color: row.clickable && rowMouse.containsMouse ? Commons.Color.menu.selectedBackground : "transparent"
    }
    Column {
      anchors.left: parent.left
      anchors.leftMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)
      Text { text: row.title; color: row.titleColor; font.family: Style.font.menuFamily; font.pixelSize: Style.font.subtitle; font.bold: true; textFormat: Text.PlainText }
      Text { text: row.subtitle; color: Qt.alpha(Commons.Color.menu.text, 0.6); font.family: Style.font.menuFamily; font.pixelSize: Style.font.bodySmall; textFormat: Text.PlainText }
    }
    Item {
      id: trailingBox
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: parent.height
    }
    MouseArea {
      id: rowMouse
      anchors.fill: parent
      enabled: row.clickable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: row.clicked()
    }
  }

  component PanelButton: Rectangle {
    id: btn
    property string label: ""
    property color fill: Commons.Color.menu.selectedBackground
    property color labelColor: Commons.Color.menu.text
    signal clicked()
    width: Math.max(Style.space(92), btnText.implicitWidth + Style.space(28))
    height: Style.space(36)
    radius: Math.max(Style.cornerRadius, Style.space(4))
    color: btnMouse.containsMouse ? Qt.lighter(fill, 1.15) : fill
    border.width: Math.max(1, Style.space(1))
    border.color: Qt.alpha(Commons.Color.menu.text, 0.25)
    Text { id: btnText; anchors.centerIn: parent; text: btn.label; color: btn.labelColor; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body; font.bold: true; textFormat: Text.PlainText }
    MouseArea { id: btnMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: btn.clicked() }
  }

  component CreditLine: Row {
    property string who: ""
    property string what: ""
    spacing: Style.space(10)
    anchors.horizontalCenter: parent.horizontalCenter
    Text { text: parent.who; width: Style.space(70); horizontalAlignment: Text.AlignRight; color: Commons.Color.menu.selectedText; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body; font.bold: true; textFormat: Text.PlainText }
    Text { text: parent.what; color: Commons.Color.menu.text; font.family: Style.font.menuFamily; font.pixelSize: Style.font.body; textFormat: Text.PlainText }
  }

  // The app icon drawn live: a row of workspace cards (the current one in
  // Omarchy green) above three windows. Animated on the About page: the
  // green card walks along the row and the two top windows swap places.
  component MiniIcon: Item {
    id: icon
    property real size: Style.space(40)
    property bool animated: false
    property int current: 0
    property bool swapped: false
    width: size
    height: size
    readonly property real u: size / 512

    Timer { running: icon.animated; interval: 900; repeat: true; onTriggered: { icon.current = (icon.current + 1) % 4; if (icon.current === 0) icon.swapped = !icon.swapped } }

    Rectangle { x: 16 * icon.u; y: 16 * icon.u; width: 480 * icon.u; height: width; radius: 96 * icon.u; color: "#16161e"; border.color: "#2a2b3d"; border.width: Math.max(1, 6 * icon.u) }
    Repeater {
      model: 4
      Rectangle {
        required property int index
        x: (76 + index * 90) * icon.u; y: 88 * icon.u; width: 76 * icon.u; height: 50 * icon.u; radius: 8 * icon.u
        color: index === icon.current ? "#a6d16b" : "transparent"
        border.width: index === icon.current ? 0 : Math.max(1, 8 * icon.u)
        border.color: index === 3 ? "#565f89" : "#c0caf5"
        Behavior on color { ColorAnimation { duration: 250 } }
      }
    }
    Repeater {
      model: [{ x: 76, y: 196, w: 168, h: 120, bar: "#7aa2f7" }, { x: 268, y: 196, w: 168, h: 120, bar: "#7aa2f7" }, { x: 172, y: 336, w: 168, h: 104, bar: "#a6d16b" }]
      Item {
        required property var modelData
        required property int index
        readonly property real gx: index < 2 && icon.swapped ? (index === 0 ? 268 : 76) : modelData.x
        x: gx * icon.u; y: modelData.y * icon.u; width: modelData.w * icon.u; height: modelData.h * icon.u
        Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.3 } }
        Rectangle { anchors.fill: parent; radius: 12 * icon.u; color: "#c0caf5" }
        Rectangle { width: parent.width; height: 22 * icon.u; radius: 10 * icon.u; color: modelData.bar }
      }
    }
  }
}
