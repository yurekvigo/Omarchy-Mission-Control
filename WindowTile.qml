import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import QtQuick
import qs.Commons

// One window in the overview: its live picture (or icon and title when no
// picture can be taken). Click to go to it; drag it onto a workspace card to
// move it there. Used both inside the cards and in the large view of the
// workspace you're on. Corners are rounded like the real windows (Hyprland's
// decoration:rounding), and pointing at a window shows an X that closes it.
Item {
  id: tile

  required property var ov          // the Overview root
  required property var info        // the window (an entry of ov.cards[i].windows)
  required property Item dragLayer  // the full-screen item drags are measured in
  property bool showTitle: false
  // Small windows inside a workspace card: one click shows that workspace in
  // the large view, a double click goes to the window.
  property bool inCard: false

  readonly property real titleHeight: showTitle ? Math.round(Style.font.body * 1.2) + Style.space(14) : 0
  readonly property bool beingDragged: ov.dragging !== null && ov.dragging.address === info.address

  // Large windows get the same corner size as on screen; the small ones in
  // the cards get it scaled down with them.
  readonly property real scale: info.size && info.size[0] > 0 ? frame.width / info.size[0] : 0.2
  readonly property real cornerRadius: showTitle ? ov.windowRounding : Math.max(1.5, ov.windowRounding * scale)
  readonly property bool pointed: mouse.containsMouse || closeMouse.containsMouse

  opacity: beingDragged ? 0.35 : 1
  // Lit while a dragged window would swap places with this one.
  readonly property bool swapHere: ov.dragging !== null && ov.hoverWindow === info.address

  Component.onCompleted: ov.registerTile(tile)
  Component.onDestruction: ov.unregisterTile(tile)

  ClippingRectangle {
    id: frame
    width: parent.width
    height: parent.height - tile.titleHeight
    radius: tile.cornerRadius
    color: ov.selectedBackground

    ScreencopyView {
      id: shot
      anchors.fill: parent
      captureSource: ov.opened ? tile.info.toplevel : null
      live: ov.opened
      // One fixed capture size per window (its real size, at most 1200 wide),
      // scaled to the tile: tied to the tile's size, a shrinking tile showed
      // the old, larger picture cut off on one side until a new one came.
      readonly property real capW: tile.info.size && tile.info.size[0] > 0 ? Math.min(1200, tile.info.size[0]) : 800
      readonly property real capH: tile.info.size && tile.info.size[0] > 0 ? capW * tile.info.size[1] / tile.info.size[0] : 500
      constraintSize: Qt.size(capW, capH)
    }

    Column {
      anchors.centerIn: parent
      width: parent.width - Style.space(8)
      spacing: Style.space(4)
      visible: !shot.hasContent
      Image {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(Style.space(64), frame.height * 0.5)
        height: width
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        source: tile.info.icon
        fillMode: Image.PreserveAspectFit
        asynchronous: true
      }
      Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: tile.info.title || tile.info.appName
        color: ov.foreground
        font.family: ov.fontFamily
        font.pixelSize: Style.font.bodySmall
        visible: frame.height > Style.space(50) && !tile.showTitle
      }
    }

    MouseArea {
      id: mouse
      anchors.fill: parent
      hoverEnabled: true
      preventStealing: true
      property point start: Qt.point(0, 0)
      property bool moved: false
      onPressed: function(m) { start = Qt.point(m.x, m.y); moved = false }
      onPositionChanged: function(m) {
        if (!pressed) return
        if (!ov.dragging && Math.abs(m.x - start.x) + Math.abs(m.y - start.y) > Style.space(8)) {
          ov.dragSize = Qt.size(frame.width, frame.height)
          ov.dragging = tile.info
          moved = true
        }
        if (ov.dragging) {
          var p = mapToItem(tile.dragLayer, m.x, m.y)
          ov.dragPoint = p
          var swapWith = ov.swapTargetAt(p.x, p.y)
          ov.setSwapPreview(swapWith)
          ov.hoverWindow = swapWith ? swapWith.address : ""
          ov.hoverCard = swapWith ? -2 : ov.cardAt(p.x, p.y)
        }
      }
      onReleased: function(m) {
        if (!ov.dragging) return
        var p = mapToItem(tile.dragLayer, m.x, m.y)
        var id = ov.cardAt(p.x, p.y)
        var w = ov.dragging
        var swapWith = ov.swapTargetAt(p.x, p.y)
        if (swapWith) ov.holdSwapPreview()
        else ov.swapPreview = null
        ov.dragging = null
        ov.hoverCard = -2
        ov.hoverWindow = ""
        if (swapWith) ov.swapWindows(w, swapWith)
        else if (id === -1) ov.moveWindow(w, ov.freeWorkspace)
        else if (id > 0) ov.moveWindow(w, id)
      }
      onClicked: {
        if (ov.dragging || moved) return
        if (tile.inCard) ov.viewWorkspace(tile.info.workspaceId)
        else ov.goToWindow(tile.info)
      }
      onDoubleClicked: if (tile.inCard) ov.goToWindow(tile.info)
    }
  }

  // Outline: the theme's accent while pointed at.
  Rectangle {
    width: frame.width
    height: frame.height
    radius: tile.cornerRadius
    color: "transparent"
    border.color: tile.pointed || tile.swapHere ? ov.selectedText : Qt.alpha(ov.foreground, 0.25)
    border.width: tile.swapHere ? Math.max(3, Style.space(4)) : Math.max(1, Style.space(tile.showTitle ? 2 : 1))
  }

  // X on the top-right corner while pointed at: closes the window (the app
  // may still ask first, e.g. about unsaved work). Same look as a workspace
  // card's X, sitting over the corner like the card's. Only on the large
  // windows: small windows inside a card have no X.
  Rectangle {
    readonly property real size: Style.space(26)
    visible: !tile.inCard && tile.pointed && !ov.dragging && frame.width > size * 2.5 && frame.height > size * 1.8
    x: frame.width - width * 2 / 3
    y: -height / 3
    z: 10
    width: size
    height: size
    radius: size / 2
    color: closeMouse.containsMouse ? ov.selectedText : ov.background
    border.width: Math.max(1, Style.space(1))
    border.color: Qt.alpha(ov.foreground, 0.5)
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "\u00d7"
      color: closeMouse.containsMouse ? ov.background : ov.foreground
      font.family: ov.fontFamily
      font.pixelSize: Math.round(parent.width * 0.7)
      font.bold: true
    }
    MouseArea {
      id: closeMouse
      anchors.fill: parent
      anchors.margins: -Style.space(4)
      hoverEnabled: true
      onClicked: ov.closeWindow(tile.info)
    }
  }

  // App name under the large windows, like the Mac.
  Text {
    visible: tile.showTitle
    anchors.horizontalCenter: parent.horizontalCenter
    y: frame.height + Style.space(8)
    width: Math.min(implicitWidth, parent.width)
    elide: Text.ElideRight
    textFormat: Text.PlainText
    text: tile.info.appName || tile.info.title
    color: ov.themeForeground
    style: Text.Raised
    styleColor: Qt.alpha(ov.themeBackground, 0.7)
    font.family: ov.fontFamily
    font.pixelSize: Math.round(Style.font.body * 1.2)
    font.bold: true
  }
}
