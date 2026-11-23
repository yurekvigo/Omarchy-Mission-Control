import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Commons as Commons
import qs.Ui

// Mission Control: a Mac-style overview of every workspace.
//
// `omarchy-shell io.github.yurekvigo.mission-control open|close|toggle|launch`. The plugin
// sets up its own shortcut (Super + D) and four-finger swipe up/down while it
// is switched on (see "shortcuts"). A row of cards, one
// per workspace from 1 to the highest in use, with live pictures of their
// windows where they sit on the screen; the windows of the workspace you are
// on are shown large below. One click on a card switches to that workspace
// and keeps the overview open; a double click also closes it. Drag a window
// onto another card (or "+") to move it, onto another window of the same
// workspace to swap them; drag a card by its number to reorder workspaces.
// The gear (bottom left) opens Settings. The model and the window pictures
// only exist while the overview is open.
Item {
  id: root

  property var shell: null
  property var manifest: null

  property bool opened: false
  // Hyprland's window corner size (decoration:rounding), read on opening.
  property real windowRounding: 6
  // Show cards up to at least this workspace (raised by "+" while open).
  property int shownUpTo: 0

  property color background: Commons.Color.menu.background
  // The theme's base colours, for the backdrop and the text drawn on it.
  readonly property color themeBackground: Commons.Color.background
  readonly property color themeForeground: Commons.Color.foreground
  property color foreground: Commons.Color.menu.text
  property color border: Commons.Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color selectedBackground: Commons.Color.menu.selectedBackground
  property color selectedText: Commons.Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily

  // ------------------------------------------------- app launcher entry
  // While the plugin is on, it keeps a "Mission Control" entry in the app
  // launcher (a .desktop file in ~/.local/share/applications, icon.svg from
  // this folder). When the plugin is unloaded it checks a few seconds later
  // whether it was switched off or removed (not just the bar restarting) and
  // then deletes the entry.
  readonly property string launcherFile: Quickshell.env("HOME") + "/.local/share/applications/omarchy-mission-control.desktop"
  readonly property string launcherIcon: String(Qt.resolvedUrl("icon.svg")).replace(/^file:\/\//, "")
  readonly property string launcherText: "[Desktop Entry]\n"
    + "Type=Application\n"
    + "Name=Mission Control\n"
    + "Comment=See every workspace and its windows; move and arrange them\n"
    + "Exec=omarchy-shell io.github.yurekvigo.mission-control launch\n"
    + "Icon=" + launcherIcon + "\n"
    + "Terminal=false\n"
    + "Categories=Utility;\n"
    + "Keywords=workspaces;overview;windows;expose;spaces;\n"
    + "X-Generated-By=io.github.yurekvigo.mission-control plugin (removed when the plugin is switched off)\n"
  // Written or deleted to match the Application Icon switch in Settings.
  function syncLauncher() {
    if (!settingsReady) return
    if (setting("launcherIcon", true))
      Quickshell.execDetached(["sh", "-c",
        'mkdir -p "${1%/*}" && { [ "$(cat "$1" 2>/dev/null)" = "$2" ] || { printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"; }; }',
        "sh", launcherFile, launcherText])
    else
      Quickshell.execDetached(["rm", "-f", launcherFile])
  }

  // ------------------------------------------------------------- settings
  // ~/.config/omarchy-mission-control/settings.json: launcherIcon, barWidget (both on
  // unless switched off in Settings) and how many times it was opened. The
  // bar widget reads the same file.
  readonly property string settingsDir: Quickshell.env("HOME") + "/.config/omarchy-mission-control"
  property var settings: ({})
  property bool settingsReady: false
  function setting(key, fallback) { return settings[key] === undefined ? fallback : settings[key] }
  function setSetting(key, value) {
    var s = JSON.parse(JSON.stringify(settings))
    s[key] = value
    settings = s
    settingsFile.setText(JSON.stringify(s, null, 2) + "\n")
    if (key === "launcherIcon") syncLauncher()
  }
  FileView {
    id: settingsFile
    path: root.settingsDir + "/settings.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try { root.settings = JSON.parse(text()) || {} } catch (e) { root.settings = {} }
      var first = !root.settingsReady
      root.settingsReady = true
      if (first) { root.syncLauncher(); root.applyShortcuts() }
    }
    onLoadFailed: {
      // No settings yet: everything on.
      var first = !root.settingsReady
      root.settings = {}
      root.settingsReady = true
      if (first) { root.syncLauncher(); root.applyShortcuts() }
    }
  }
  Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", settingsDir])

  // ------------------------------------------------------------ shortcuts
  // While the plugin is on, it registers its own keyboard shortcut and
  // four-finger swipe up/down with Hyprland (nothing is written to the
  // Hyprland config), blurs what is behind the overview and shows the theme
  // refresh's still picture without a fade. Hyprland forgets
  // these whenever its config is reloaded, so they are applied again after
  // every reload. settings.json: "shortcut" (default "SUPER + D"; "" for
  // none) and "gestures" (default true).
  readonly property string pluginId: "io.github.yurekvigo.mission-control"
  function applyShortcuts() {
    if (!settingsReady) return
    var key = String(setting("shortcut", "SUPER + D")).replace(/[^A-Za-z0-9 +_]/g, "")
    var cmd = 'if __omarchy_mc_bind then pcall(function() __omarchy_mc_bind:unbind() end); __omarchy_mc_bind = nil end; '
    if (key !== "")
      cmd += '__omarchy_mc_bind = hl.bind("' + key + '", function() hl.exec_cmd("omarchy-shell ' + pluginId + ' toggle") end); '
    if (setting("gestures", true))
      cmd += 'pcall(hl.gesture, { fingers = 4, direction = "up", action = "unset" }); '
           + 'pcall(hl.gesture, { fingers = 4, direction = "down", action = "unset" }); '
           + 'hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("omarchy-shell ' + pluginId + ' open") end }); '
           + 'hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("omarchy-shell ' + pluginId + ' close") end }); '
    cmd += 'hl.layer_rule({ match = { namespace = "^omarchy-mission-control$" }, blur = true, ignore_alpha = 0.3 }); '
    // The theme refresh's still picture must cover the screen at once: faded
    // in, the workspaces it visits behind it showed through for a moment.
    cmd += 'hl.layer_rule({ match = { namespace = "^omarchy-mission-control-freeze$" }, no_anim = true, animation = "none" })'
    hyprEval(cmd)
  }
  // Runs Lua in Hyprland. Clearing a swipe that isn't set makes Hyprland note
  // a "config error" even inside pcall, and it keeps the last eval's errors,
  // so a harmless eval follows to leave the error list clean.
  function hyprEval(cmd) {
    Quickshell.execDetached(["sh", "-c",
      'hyprctl eval "$1" >/dev/null 2>&1; hyprctl eval "return 1" >/dev/null 2>&1', "sh", cmd])
  }
  Connections {
    target: Hyprland
    function onRawEvent(event) { if (event.name === "configreloaded") shortcutsLater.restart() }
  }
  Timer { id: shortcutsLater; interval: 150; onTriggered: root.applyShortcuts() }

  // ---------------------------------------------------- smooth swipe helper
  // Optional system service (helper/ in this folder) that lets the row of
  // cards follow three- and four-finger swipes. Settings installs or removes
  // it; both ask for the password.
  property bool helperInstalled: false
  property bool helperBusy: false
  function plugPath(name) { return String(Qt.resolvedUrl(name)).replace(/^file:\/\//, "") }
  function checkHelper() { helperCheck.running = true }
  function connectHelper() { relay.connected = false; relay.connected = true }
  function setHelper(on) {
    if (helperBusy) return
    helperBusy = true
    helperRun.command = ["sh", plugPath(on ? "helper/install.sh" : "helper/remove.sh")]
    helperRun.running = true
  }
  Process {
    id: helperCheck
    command: ["systemctl", "is-enabled", "--quiet", "omarchy-mission-control-swipe.service"]
    onExited: function(code) { root.helperInstalled = code === 0 }
  }
  Process {
    id: helperRun
    onExited: function(code) { root.helperBusy = false; root.checkHelper(); if (root.opened) root.connectHelper() }
  }

  // ------------------------------------------------------------- commands
  function open() {
    Hyprland.refreshToplevels()
    Hyprland.refreshMonitors()
    shownUpTo = 0
    settingsPage = ""
    roundingProcess.running = true
    if (settingsReady) setSetting("opened", setting("opened", 0) + 1)
    checkHelper()
    connectHelper()
    opened = true
    sideSwipes("workspace")
  }
  function close() {
    swipeSwapped = false
    swipeMode = ""
    if (swipeWasSwapped) {
      // Back to exactly what the config says, whatever happened meanwhile.
      swipeWasSwapped = false
      Quickshell.execDetached(["hyprctl", "reload"])
    }
    dragging = null
    swapPreview = null
    hoverWindow = ""
    relay.connected = false
    opened = false
  }
  function toggle() { if (opened) close(); else open() }

  // Settings window: "" (closed), "menu", "about" or "confirm" (Remove).
  property string settingsPage: ""
  // The page last shown beside Settings, kept while that window slides away.
  property string lastDetail: "about"
  onSettingsPageChanged: if (settingsPage === "about" || settingsPage === "confirm") lastDetail = settingsPage
  // 0..1: how far each window has slid in.
  property real menuIn: settingsPage !== "" ? 1 : 0
  property real detailIn: settingsPage === "about" || settingsPage === "confirm" ? 1 : 0
  Behavior on menuIn { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
  Behavior on detailIn { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }

  // Remove Plugin: uninstall.sh (in this folder) runs outside the bar's
  // process, since removing the plugin restarts the bar.
  function removePlugin() {
    Quickshell.execDetached(["setsid", "-f", "sh", plugPath("uninstall.sh")])
    settingsPage = ""
    close()
  }

  // ------------------------------------------- fresh pictures after a theme change
  // Hyprland doesn't redraw windows on workspaces you aren't looking at, so
  // after a theme change their pictures in the cards keep the old colours
  // until you visit them. So when the theme has changed, the next time the
  // overview is open it visits each workspace with windows for a moment
  // (behind its own screen, keeping its view still) and comes back.
  //
  // Normally this happens right after the theme change, before you open the
  // overview: once the apps on screen have re-coloured, a still picture of
  // the screen is laid over everything (it holds the keyboard and the pointer
  // meanwhile), the workspaces are visited behind it, and the picture goes
  // away. If the overview is opened before that, or an animated wallpaper is
  // playing (a still picture would stop it), it does the visiting itself.
  property bool picturesStale: false
  onBackgroundChanged: themeChanged()
  onForegroundChanged: themeChanged()
  onSelectedTextChanged: themeChanged()
  function themeChanged() {
    picturesStale = true
    if (!opened) themeSettle.restart()
  }
  onOpenedChanged: if (opened && picturesStale) { themeSettle.stop(); sweepStart.restart() }
  Timer { id: themeSettle; interval: 1500; onTriggered: if (!root.opened && root.picturesStale) root.freezeAndRefresh() }

  // Numbered workspaces with windows, other than the one you're on.
  function busyWorkspaces() {
    var seen = {}, ids = []
    var tls = Hyprland.toplevels.values
    for (var i = 0; i < tls.length; i++) {
      var ws = tls[i].workspace
      if (!ws || ws.id <= 0 || ws.id === liveWorkspace || seen[ws.id]) continue
      seen[ws.id] = true
      ids.push(ws.id)
    }
    ids.sort(function(a, b) { return a - b })
    return ids
  }

  property bool frozen: false
  function freezeAndRefresh() {
    if (busyWorkspaces().length === 0) { picturesStale = false; return }
    if (wallpaperCheck.running || frozen) return
    wallpaperCheck.running = true   // then freezes, unless a video is playing
  }
  // A still picture over an animated wallpaper (Omarchy's OWE) makes the
  // video stop for a moment. While one plays, the pictures stay stale instead
  // and the overview refreshes them itself when it is next opened, behind its
  // own screen. Without OWE, or with a still wallpaper, it freezes as before.
  Process {
    id: wallpaperCheck
    command: ["owe", "status"]
    stdout: StdioCollector { id: wallpaperOut }
    onExited: function(code) {
      var playing = false
      if (code === 0) {
        try {
          var st = JSON.parse(String(wallpaperOut.text || "{}"))
          playing = st.loaded_kind === "video" && st.paused !== true
        } catch (e) {}
      }
      if (playing || root.opened || !root.picturesStale) return
      root.frozen = true        // captures a fresh still picture; shown once it's ready
      freezeGuard.restart()
    }
  }
  // Never leave the screen frozen, whatever happens: stop visiting, go back
  // to the workspace it started on, and only then let input through again.
  Timer {
    id: freezeGuard
    interval: 4000
    onTriggered: {
      if (!root.frozen) return
      sweepStep.stop()
      root.sweepList = []
      if (root.sweepBack > 0) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + root.sweepBack + '" })')
      sweepDone.restart()
    }
  }

  property var sweepList: []
  property int sweepBack: 0
  Timer { id: sweepStart; interval: 350; onTriggered: root.refreshPictures() }
  function refreshPictures() {
    if (!opened && !frozen) return
    picturesStale = false
    var ids = busyWorkspaces()
    if (ids.length === 0) { frozen = false; return }
    sweepBack = liveWorkspace
    pinnedWorkspace = liveWorkspace
    sweepList = ids
    sweepStep.restart()
  }
  Timer {
    id: sweepStep
    interval: 110
    repeat: true
    onTriggered: {
      var l = root.sweepList
      if (l.length === 0) {
        stop()
        Hyprland.dispatch('hl.dsp.focus({ workspace = "' + root.sweepBack + '" })')
        sweepDone.restart()
        return
      }
      root.sweepList = l.slice(1)
      Hyprland.dispatch('hl.dsp.focus({ workspace = "' + l[0] + '" })')
    }
  }
  Timer { id: sweepDone; interval: 200; onTriggered: { root.pinnedWorkspace = 0; root.frozen = false } }

  // The still picture of the screen used while visiting after a theme change.
  PanelWindow {
    id: freezeWindow
    screen: {
      var name = Hyprland.focusedMonitor ? String(Hyprland.focusedMonitor.name || "") : ""
      for (var i = 0; i < Quickshell.screens.length; i++) if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
      return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }
    visible: root.frozen && freezeShot.hasContent
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omarchy-mission-control-freeze"
    // It holds the keyboard and the pointer while it is up. The workspaces
    // behind it really change for a moment, so nothing typed or clicked may
    // reach them: input comes back only once you are on your own workspace
    // again and the picture is gone.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    onVisibleChanged: if (visible) root.refreshPictures()

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
      hoverEnabled: true
      onWheel: function(w) { w.accepted = true }
    }
    Item { anchors.fill: parent; focus: true; Keys.onPressed: function(e) { e.accepted = true } }

    ScreencopyView {
      id: freezeShot
      anchors.fill: parent
      captureSource: root.frozen ? freezeWindow.screen : null
      live: false
      paintCursor: false
    }
  }

  // Opened from the app launcher: Omarchy's launcher waits 2 s for a new app
  // window or a change of the focused window, and seeing neither (the
  // overview isn't a window) shows "Launching Mission Control" for up to
  // 15 s. So, hidden behind the overview, focus another window for a moment
  // and then the original one again: the launcher counts that as the app
  // having started and never shows the message. As a backup (no other window
  // to hop to), dismiss the message if it shows anyway.
  function launch() {
    open()
    launchHop.restart()
    launcherOsd.ticks = 0
    launcherOsdStart.restart()
  }
  Timer {
    id: launchHop
    interval: 250
    onTriggered: {
      var active = Hyprland.activeToplevel
      var activeAddr = active && active.address ? String(active.address) : ""
      var other = "", otherHere = ""
      var tls = Hyprland.toplevels.values
      for (var i = 0; i < tls.length; i++) {
        var t = tls[i]
        if (!t.address || String(t.address) === activeAddr || !t.workspace || t.workspace.id <= 0) continue
        if (t.workspace.id === root.liveWorkspace) { otherHere = String(t.address); break }
        if (!other) other = String(t.address)
      }
      var hop = otherHere || other
      if (!hop) return
      var back = activeAddr ? 'hl.dispatch(hl.dsp.focus({ window = "' + root.target(activeAddr) + '" }))'
                            : root.focusBackCmd()
      root.withWindowFocus('hl.dispatch(hl.dsp.focus({ window = "' + root.target(hop) + '" })); ' + back)
    }
  }
  Timer { id: launcherOsdStart; interval: 1500; onTriggered: launcherOsd.restart() }
  Timer {
    id: launcherOsd
    property int ticks: 0
    interval: 100
    repeat: true
    onTriggered: {
      Quickshell.execDetached(["omarchy-shell", "osd", "close"])
      if (++ticks >= 15) stop()
    }
  }

  ShellIpc {
    target: "io.github.yurekvigo.mission-control"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function launch(): void { root.launch() }
    function closeCard(id: int): void { root.closeWorkspace(id) }
    function addCard(): void { root.addWorkspaceCard() }
    // Open Mission Control with a Settings page showing (menu, about,
    // confirm); used by the bar button's right-click box.
    function showSettings(page: string): void {
      if (!root.opened) root.open()
      root.settingsPage = page === "" ? "menu" : page
    }
    // Same as flipping a Settings switch (launcherIcon, barWidget); used by
    // the bar button's right-click box, and for testing.
    function setFlag(key: string, on: string): void { root.setSetting(key, on === "true" || on === "on" || on === "1") }
    // Show a Settings page: menu, about, confirm, or "" to close it (testing).
    function settingsPage(page: string): void { root.settingsPage = page }
    // Spring tests: pull the row by dx as a swipe would, let go, a wheel
    // notch (-1 / 1), and the row's position (and its end).
    function pull(dx: real): void { cardFlick.stopSpring(); cardFlick.rawX = cardFlick.contentX; cardFlick.rubberTo(cardFlick.rawX + dx) }
    function letGo(): void { if (cardFlick.contentX < 0 || cardFlick.contentX > cardFlick.maxX) cardFlick.springBack() }
    function wheelNotch(dir: int): void { cardFlick.scrollOrNudge(dir * (overlay.cardWidth + overlay.gap)) }
    function rowX(): string { return Math.round(cardFlick.contentX) + " (ends 0.." + Math.round(cardFlick.maxX) + ")" }
    // Visit every workspace for a moment so all pictures are fresh (testing;
    // done by itself after a theme change).
    function refresh(): void { root.refreshPictures() }
    // What happens right after a theme change, without changing it (testing).
    function themeRefresh(): void { root.picturesStale = true; root.freezeAndRefresh() }
    // Same as one mouse-wheel notch outside the cards (testing): -1 or 1.
    function step(dir: int): void { root.stepWorkspace(dir) }
    // Throw the row like the end of a three-finger swipe does (testing).
    function fling(v: real): void { cardFlick.flick(v, 0) }
    // While dragging (see previewSwap), the window a drop at (x, y) would
    // swap with, or "none" (testing).
    function swapTargetAtPoint(x: real, y: real): string {
      var t = root.swapTargetAt(x, y)
      return t ? String(t.appName || t.address) : "none"
    }
    // Let go of the drag started with previewSwap, as a real drop does (testing).
    function dropPreview(): void {
      var sp = root.swapPreview
      if (!sp || !root.dragging) return
      root.holdSwapPreview()
      var w = root.dragging
      root.dragging = null
      root.hoverWindow = ""
      root.swapWindows(w, sp.b)
    }
    // Show the drag preview of `a` held over `b` (testing); "" "" ends it.
    function previewSwap(a: string, b: string): void {
      if (a === "") { root.dragging = null; root.swapPreview = null; root.hoverWindow = ""; return }
      var A = null, B = null
      a = a.replace(/^0x/, ""); b = b.replace(/^0x/, "")
      for (var i = 0; i < root.cards.length; i++)
        for (var j = 0; j < root.cards[i].windows.length; j++) {
          var w = root.cards[i].windows[j]
          var wa = String(w.address).replace(/^0x/, "")
          if (wa === a) A = w
          if (wa === b) B = w
        }
      root.dragSize = Qt.size(1, 1)
      root.dragging = A
      root.setSwapPreview(B)
      root.hoverWindow = B ? B.address : ""
    }
    // Swap two windows by address (same as dropping one on the other; testing).
    function swap(a: string, b: string): void { root.swapWindows({ address: a }, { address: b }) }
    // Same check as after a window leaves workspace `ws` (for testing).
    function tidy(ws: int): void { root.tidyAfterRemoval(ws) }
    // Same as one click on card `id`: show it in the large view (for testing).
    function viewCard(id: int): void { root.viewWorkspace(id) }
    // "connected" when the three-finger swipe relay is reachable (for testing).
    function relayState(): string { return root.relay.connected ? "connected" : "not connected" }
    function scroll(dir: int): void { root.scrollCards(dir) }
    // Which workspace a window dropped at (x, y) would go to (-1 = "+", -2 = none).
    function dropTarget(x: real, y: real): int { return root.cardAt(x, y) }
    // Same as dragging card `id` to land before card `before` (or the end).
    function moveCard(id: int, before: int): void {
      root.draggingCard = id
      var pitch = overlay.cardWidth + overlay.gap
      var p = cardRow.mapToItem(overlay, (before - 1) * pitch, 10)
      root.cardDrop(p)
    }
  }

  function target(address) {
    var a = String(address || "")
    return "address:" + (a.indexOf("0x") === 0 ? a : "0x" + a)
  }
  function goToWindow(w) {
    Hyprland.dispatch('hl.dsp.focus({ window = "' + target(w.address) + '" })')
    close()
  }
  function goToWorkspace(id) {
    Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
    close()
  }
  // "+": one more empty card, scrolled into view.
  function addWorkspaceCard() {
    shownUpTo = cards.length + 1
    cardFlick.toEndPending = true
  }

  // ---------------------------------------------------- reordering cards
  // Drag a card along the row and drop it between two others: its windows
  // become that workspace number and the ones in between shift over, so the
  // workspaces are renumbered in the new order. You stay on the same windows.
  property int draggingCard: 0       // workspace id of the card being dragged
  property int cardSlot: -1          // where it would land: 0 = before the first card

  function cardDragTo(id, p) {
    draggingCard = id
    dragPoint = p
    var r = cardRow.mapFromItem(overlay, p.x, p.y)
    var pitch = overlay.cardWidth + overlay.gap
    cardSlot = Math.max(0, Math.min(cards.length, Math.round(r.x / pitch)))
  }

  function cardDrop(p) {
    var id = draggingCard
    cardDragTo(id, p)
    var slot = cardSlot
    draggingCard = 0
    cardSlot = -1
    if (id <= 0) return
    var order = []
    for (var i = 0; i < cards.length; i++) order.push(cards[i])
    var from = id - 1
    var to = slot > from ? slot - 1 : slot
    if (to === from) return
    var moving = order.splice(from, 1)[0]
    order.splice(to, 0, moving)
    var cur = currentWorkspace
    var newCur = cur
    for (var n = 0; n < order.length; n++) {
      var c = order[n]
      var dest = n + 1
      if (c.id === cur) newCur = dest
      if (c.id === dest) continue
      for (var j = 0; j < c.windows.length; j++)
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + dest + '", follow = false, window = "' + target(c.windows[j].address) + '" })')
    }
    if (newCur !== cur) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + newCur + '" })')
    Hyprland.refreshToplevels()
  }

  // ------------------------------------------- three-finger swipe scrolls
  // Hyprland takes three-finger left/right swipes itself (switch workspace),
  // so the overview never sees them. While the pointer is over the row of
  // cards, the overview switches that swipe (with the relay, the four-finger
  // one too) off in Hyprland and swaps it back
  // when the pointer leaves; closing the overview reloads Hyprland's config so
  // the normal swipe is certainly back.
  //
  // With the swipe relay running (system service omarchy-mission-control-swipe, which
  // passes on three-finger swipe movement from the touchpad and nothing else),
  // the row follows the fingers like the two-finger scroll, with momentum.
  // Without it, Hyprland's left/right swipe moves the row in steps instead.
  property bool swipeSwapped: false
  property bool swipeWasSwapped: false
  property string swipeMode: ""      // "relay" or "step" while swapped

  // While the overview is open it owns the three- and four-finger left/right
  // swipes, whatever they normally do on this computer: over the large view
  // they switch workspace, over the row of cards they scroll it. Closing the
  // overview reloads Hyprland's config, which puts the computer's own swipes
  // back exactly as configured.
  readonly property string clearSideSwipes:
    'for _, f in ipairs({ 3, 4 }) do for _, d in ipairs({ "horizontal", "left", "right" }) do '
    + 'pcall(hl.gesture, { fingers = f, direction = d, action = "unset" }) end end'

  function sideSwipes(mode) {
    var cmd = clearSideSwipes
    if (mode === "workspace") {
      cmd += '; hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })'
           + '; hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })'
    } else if (swipeMode === "step") {
      for (var f = 3; f <= 4; f++)
        cmd += '; hl.gesture({ fingers = ' + f + ', direction = "left", action = function() hl.exec_cmd("omarchy-shell io.github.yurekvigo.mission-control scroll 1") end })'
             + '; hl.gesture({ fingers = ' + f + ', direction = "right", action = function() hl.exec_cmd("omarchy-shell io.github.yurekvigo.mission-control scroll -1") end })'
    }
    // (mode "cards" with the relay: no Hyprland gesture at all; the relay's
    // movement scrolls the row.)
    swipeWasSwapped = true
    hyprEval(cmd)
  }

  // Pointer over the row of cards (on) or not (off).
  function swipeScrolls(on) {
    if (on === swipeSwapped) return
    swipeSwapped = on
    if (on) {
      swipeMode = relay.connected ? "relay" : "step"
      sideSwipes("cards")
    } else {
      swipeMode = ""
      if (opened) sideSwipes("workspace")
    }
  }

  // How far the row moves per unit of finger movement, and the fling after.
  readonly property real relaySpeed: 1.0
  property double relayLast: 0
  property real relayVelocity: 0     // px/s of the row, smoothed

  property alias relay: relay
  Socket {
    id: relay
    path: "/run/omarchy-mission-control/swipe.sock"
    // Connected by hand (connectHelper), not with a binding: a failed attempt
    // (helper not installed) would break the binding for good.
    parser: SplitParser {
      onRead: function(line) { root.relayLine(line) }
    }
  }

  function relayLine(line) {
    if (!swipeSwapped || swipeMode !== "relay") return
    var p = String(line).split(" ")
    var now = Date.now()
    if (p[0] === "b") {
      scrollAnim.stop()
      cardFlick.stopSpring()
      cardFlick.cancelFlick()
      cardFlick.rawX = cardFlick.contentX
      relayVelocity = 0
      relayLast = now
    } else if (p[0] === "u") {
      var dx = -parseFloat(p[1]) * relaySpeed
      if (isNaN(dx)) return
      cardFlick.rubberTo(cardFlick.rawX + dx)
      var dt = Math.max(1, now - relayLast) / 1000
      relayVelocity = relayVelocity * 0.6 + (dx / dt) * 0.4
      relayLast = now
    } else if (p[0] === "e") {
      // Pulled past an end: spring back. Otherwise keep gliding, like
      // letting go of a two-finger scroll (into an end it overshoots a
      // little and springs back too: the row's rebound).
      if (cardFlick.contentX < 0 || cardFlick.contentX > cardFlick.maxX)
        cardFlick.springBack()
      else if (now - relayLast < 80 && Math.abs(relayVelocity) > 150)
        cardFlick.flick(-relayVelocity, 0)
      relayVelocity = 0
    }
  }

  // One swipe glides the row two cards (dir 1 = towards the right end).
  // Hyprland only says that a swipe happened and which way, not how fast, so
  // quick swipes in a row in the same direction speed up instead: 2, 4, 6,
  // then 8 cards a swipe. A pause of 1 s or a change of direction starts over
  // at two cards.
  property int swipeStep: 0
  property int swipeDir: 0
  property double lastSwipe: 0

  function scrollCards(dir) {
    var now = Date.now()
    swipeStep = (dir === swipeDir && now - lastSwipe < 1000) ? Math.min(8, swipeStep + 2) : 2
    swipeDir = dir
    lastSwipe = now
    var from = scrollAnim.running ? scrollAnim.to : cardFlick.contentX
    scrollAnim.stop()
    scrollAnim.from = cardFlick.contentX
    scrollAnim.to = Math.max(0, Math.min(cardFlick.maxX, from + dir * swipeStep * (overlay.cardWidth + overlay.gap)))
    scrollAnim.start()
  }
  NumberAnimation {
    id: scrollAnim
    target: cardFlick
    property: "contentX"
    duration: 200
    easing.type: Easing.OutCubic
  }

  Component.onDestruction: {
    // Hand Hyprland back its own shortcuts and swipes (a bar restart loads
    // the plugin again, which applies ours again).
    Quickshell.execDetached(["hyprctl", "reload"])
    // Remove the launcher entry if the plugin was switched off or removed
    // (a bar restart loads it again within the 5 s, so the entry stays).
    Quickshell.execDetached(["sh", "-c",
      'sleep 5; omarchy plugin list --json 2>/dev/null | tr -d " \\n" | grep -q \'"id":"io.github.yurekvigo.mission-control",[^}]*"enabled":true\' || rm -f "$1"',
      "sh", launcherFile])
  }

  function closeWindow(w) {
    if (!w) return
    Hyprland.dispatch('hl.dsp.window.close({ window = "' + target(w.address) + '" })')
    Hyprland.refreshToplevels()
    tidyAfterRemoval(w.workspaceId)
  }

  // ------------------------------------------------ two left side by side
  // Omarchy keeps each tiling split's direction (dwindle preserve_split), so
  // when one of three windows leaves, the other two can end up on top of each
  // other on a wide screen. After a window is closed or moved out of a
  // workspace from the overview, if exactly two tiled windows are left there
  // stacked, the overview flips their split so they sit side by side (it
  // focuses one of them, toggles the split and focuses back, in one step).
  // Closing windows outside the overview is left as Omarchy does it.
  property bool keyboardPaused: false
  Timer {
    id: tidyFlip
    property string cmd: ""
    interval: 60
    onTriggered: {
      // Focusing a window makes Hyprland move the mouse pointer onto it, so
      // note where the pointer is and put it back right after.
      Quickshell.execDetached(["sh", "-c",
        'p=$(hyprctl cursorpos) && hyprctl eval "$1" && '
        + 'hyprctl eval "hl.dispatch(hl.dsp.cursor.move({ x = ${p%%,*}, y = ${p##*, } }))"',
        "sh", cmd])
      tidyResume.restart()
    }
  }
  Timer {
    id: tidyResume
    interval: 250
    onTriggered: { root.keyboardPaused = false; root.pinnedWorkspace = 0; Hyprland.refreshToplevels() }
  }

  // Run Hyprland commands that need a window focused: let go of the keyboard
  // for a moment (Hyprland won't focus a window while the overview holds it),
  // run them, then take it back.
  function withWindowFocus(cmd) {
    if (pinnedWorkspace === 0) pinnedWorkspace = liveWorkspace
    tidyFlip.cmd = cmd
    keyboardPaused = true
    tidyFlip.restart()
  }
  // Back to the workspace the overview is on (it focuses that workspace's
  // last used window).
  function focusBackCmd() {
    return 'hl.dispatch(hl.dsp.focus({ workspace = "' + currentWorkspace + '" }))'
  }

  // ------------------------------------------- organizing a workspace
  // Drag a window onto another window of the same workspace (in its card or
  // in the large view) and they swap places. Hyprland swaps the focused
  // window with a target, so focus one, swap, and focus back.
  property var tiles: []             // every window picture on screen
  property string hoverWindow: ""    // address of the window a drop would swap with
  function registerTile(t) { var l = tiles.slice(); l.push(t); tiles = l }
  function unregisterTile(t) { tiles = tiles.filter(function(x) { return x !== t }) }

  // The window picture under (x, y) of the overlay, other than the dragged one.
  function windowAt(x, y) {
    var best = null, bestZ = -1
    for (var i = 0; i < tiles.length; i++) {
      var t = tiles[i]
      if (!t || !t.visible || !t.info || (dragging && t.info.address === dragging.address)) continue
      var p = t.mapFromItem(overlay, x, y)
      if (p.x < 0 || p.y < 0 || p.x > t.width || p.y > t.height - t.titleHeight) continue
      // Inside a card, only the part of the card you can see counts.
      if (t.inCard && cardAt(x, y) !== t.info.workspaceId) continue
      if (t.z >= bestZ) { best = t.info; bestZ = t.z }
    }
    return best
  }

  // Window that a drag at (x, y) would swap with (same workspace), or null.
  function swapTargetAt(x, y) {
    if (!dragging) return null
    // In the large view, go by the windows' original spots, which don't
    // move while the preview slides the pictures around (going by where the
    // pictures are made the preview flick back and forth).
    var g = bigArea.mapFromItem(overlay, x, y)
    if (g.x >= 0 && g.y >= 0 && g.x <= bigArea.width && g.y <= bigArea.height) {
      var slot = bigArea.slotAt(g.x, g.y)
      if (slot < 0) return null
      var hit = bigInfo[bigOrder[slot]]
      return hit && hit.workspaceId === dragging.workspaceId && hit.address !== dragging.address ? hit : null
    }
    var w = windowAt(x, y)
    if (w && w.workspaceId === dragging.workspaceId && w.address !== dragging.address) return w
    // Over the dragged window's own picture, which has moved into the
    // target's place for the preview: keep that preview.
    if (swapPreview && !swapPreview.held && overTile(dragging.address, x, y)) return swapPreview.b
    return null
  }
  function overTile(address, x, y) {
    for (var i = 0; i < tiles.length; i++) {
      var t = tiles[i]
      if (!t || !t.visible || !t.info || t.info.address !== address) continue
      var p = t.mapFromItem(overlay, x, y)
      if (p.x < 0 || p.y < 0 || p.x > t.width || p.y > t.height - t.titleHeight) continue
      if (t.inCard && cardAt(x, y) !== t.info.workspaceId) continue
      return true
    }
    return false
  }

  // ------------------------------------------------- swap preview
  // While a window is dragged over another of the same workspace, the two
  // trade places on screen before the drop (the other one moves out of the
  // way). After the drop the preview is held until Hyprland reports the real
  // swap, so nothing slides back and forth.
  property var swapPreview: null     // { a: dragged window, b: target, held: bool }
  function setSwapPreview(target) {
    if (!target) { if (swapPreview && !swapPreview.held) swapPreview = null; return }
    if (swapPreview && !swapPreview.held && swapPreview.b.address === target.address) return
    swapPreview = { a: dragging, b: target, held: false }
  }
  // The window whose place `address` takes in the preview.
  function previewAddr(address) {
    var sp = swapPreview
    if (!sp) return address
    if (address === sp.a.address) return sp.b.address
    if (address === sp.b.address) return sp.a.address
    return address
  }
  // Where a card's small window is drawn: its own place, or its partner's.
  function previewGeom(w) {
    var sp = swapPreview
    if (!sp || !w) return w
    if (w.address === sp.a.address) return sp.b
    if (w.address === sp.b.address) return sp.a
    return w
  }
  function holdSwapPreview() {
    if (!swapPreview) return
    swapPreview = { a: swapPreview.a, b: swapPreview.b, held: true }
    previewRelease.restart()
  }
  // Fallback if Hyprland never reports both (e.g. the swap was refused).
  Timer { id: previewRelease; interval: 2000; onTriggered: root.swapPreview = null }
  // Hyprland reports the two windows one at a time; once both have moved,
  // the real places take over (they now match the preview, so nothing moves).
  onCardsChanged: {
    var sp = swapPreview
    if (!sp || !sp.held) return
    // Done when each window sits exactly where the other one was (not on a
    // spot in between while they move).
    var aDone = false, bDone = false
    for (var i = 0; i < cards.length; i++)
      for (var j = 0; j < cards[i].windows.length; j++) {
        var w = cards[i].windows[j]
        if (w.address === sp.a.address) aDone = String(w.at) === String(sp.b.at)
        if (w.address === sp.b.address) bDone = String(w.at) === String(sp.a.at)
      }
    if (aDone && bDone) {
      previewRelease.stop()
      swapPreview = null
    }
  }

  function swapWindows(a, b) {
    withWindowFocus('hl.dispatch(hl.dsp.focus({ window = "' + target(a.address) + '" })); '
      + 'hl.dispatch(hl.dsp.window.swap({ target = "' + target(b.address) + '" })); ' + focusBackCmd())
  }

  function tidyAfterRemoval(ws) {
    if (ws > 0) { tidyTimer.ws = ws; tidyTimer.restart() }
  }
  Timer {
    id: tidyTimer
    property int ws: 0
    interval: 450   // let Hyprland re-tile first
    onTriggered: { tidyProcess.ws = ws; tidyProcess.running = true }
  }
  Process {
    id: tidyProcess
    property int ws: 0
    command: ["sh", "-c", "hyprctl -j clients; echo @@; hyprctl -j workspaces; echo @@; hyprctl -j activewindow"]
    stdout: StdioCollector { onStreamFinished: root.tidyCheck(tidyProcess.ws, this.text) }
  }
  function tidyCheck(ws, text) {
    var parts = String(text).split("@@")
    var clients, workspaces, active
    try {
      clients = JSON.parse(parts[0]); workspaces = JSON.parse(parts[1])
      active = parts[2] && parts[2].trim() ? JSON.parse(parts[2]) : {}
    } catch (e) { return }
    var wsInfo = null
    for (var i = 0; i < workspaces.length; i++) if (workspaces[i].id === ws) wsInfo = workspaces[i]
    if (!wsInfo || wsInfo.tiledLayout !== "dwindle") return
    var tiled = clients.filter(function(c) {
      return c.workspace && c.workspace.id === ws && c.mapped && !c.hidden && !c.floating && !c.fullscreen
    })
    if (tiled.length !== 2) return
    var a = tiled[0], b = tiled[1]
    var stacked = Math.abs(a.at[0] - b.at[0]) < 8 && Math.abs(a.size[0] - b.size[0]) < 8
    var wide = a.size[0] > a.size[1] + b.size[1]
    if (!stacked || !wide) return
    var back = active && active.address
      ? 'hl.dispatch(hl.dsp.focus({ window = "address:' + active.address + '" }))'
      : 'hl.dispatch(hl.dsp.focus({ workspace = "' + currentWorkspace + '" }))'
    withWindowFocus('hl.dispatch(hl.dsp.focus({ window = "address:' + a.address + '" })); '
      + 'hl.dispatch(hl.dsp.layout("togglesplit")); ' + back)
    Hyprland.refreshToplevels()
  }

  Process {
    id: roundingProcess
    command: ["hyprctl", "getoption", "-j", "decoration:rounding"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { var v = JSON.parse(this.text)["int"]; if (v !== undefined) root.windowRounding = v } catch (e) {}
      }
    }
  }

  function moveWindow(w, id) {
    if (!w || id === w.workspaceId) return
    Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + id + '", follow = false, window = "' + target(w.address) + '" })')
    Hyprland.refreshToplevels()
    tidyAfterRemoval(w.workspaceId)
  }

  // Close workspace card k, like removing a desktop on the Mac: its windows
  // join the workspace before it (card 1's join card 2, which becomes the new
  // 1), every later workspace shifts down by one so the card disappears, and
  // you stay on the same windows. Nothing is closed.
  function closeWorkspace(k) {
    if (cards.length <= 1) return
    var cur = currentWorkspace
    for (var i = 0; i < cards.length; i++) {
      var c = cards[i]
      if (c.id < k || (k === 1 && c.id === 1)) continue
      // Card k's windows go to k - 1; every later card moves down one. For
      // k = 1, card 1's windows stay put and card 2's join them on 1.
      var to = (c.id === k) ? k - 1 : c.id - 1
      for (var j = 0; j < c.windows.length; j++)
        Hyprland.dispatch('hl.dsp.window.move({ workspace = "' + to + '", follow = false, window = "' + target(c.windows[j].address) + '" })')
    }
    var newCur = cur > k ? cur - 1 : (cur === k ? Math.max(1, k - 1) : cur)
    if (newCur !== cur) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + newCur + '" })')
    if (shownUpTo > 0) shownUpTo = Math.max(0, shownUpTo - 1)
    Hyprland.refreshToplevels()
  }

  // ------------------------------------------------------------ the model
  readonly property var focusedMonitor: Hyprland.focusedMonitor
  readonly property int liveWorkspace: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1
  // While a swap or split flip briefly focuses another window, the overview
  // keeps showing the workspace it was on (no flash of another workspace).
  property int pinnedWorkspace: 0
  readonly property int currentWorkspace: pinnedWorkspace > 0 ? pinnedWorkspace : liveWorkspace
  // One click on a card really switches to that workspace (the bar and the
  // screen behind follow) and keeps the overview open; a double click also
  // closes it.
  readonly property int shownWorkspace: currentWorkspace
  // One workspace back (-1) or on (1), within the cards shown; quick steps
  // add up before Hyprland has caught up with the first.
  property int stepTarget: 0
  onCurrentWorkspaceChanged: if (currentWorkspace === stepTarget) stepTarget = 0
  Timer { id: stepReset; interval: 600; onTriggered: root.stepTarget = 0 }
  function stepWorkspace(dir) {
    var base = stepTarget > 0 ? stepTarget : currentWorkspace
    var to = Math.max(1, Math.min(cards.length, base + dir))
    if (to === base) return
    stepTarget = to
    stepReset.restart()
    viewWorkspace(to)
    cardFlick.showCard(to)
  }

  function viewWorkspace(id) {
    if (id !== currentWorkspace) Hyprland.dispatch('hl.dsp.focus({ workspace = "' + id + '" })')
  }

  // Logical size and position of each monitor, by id, to place windows.
  function monitorBox(id) {
    var mons = Hyprland.monitors.values
    for (var i = 0; i < mons.length; i++) {
      var o = mons[i].lastIpcObject || {}
      if (o.id === id) {
        var s = o.scale || 1
        var t = o.transform % 2 === 1
        return { x: o.x || 0, y: o.y || 0,
                 w: (t ? o.height : o.width) / s, h: (t ? o.width : o.height) / s }
      }
    }
    var fm = root.focusedMonitor ? (root.focusedMonitor.lastIpcObject || {}) : {}
    var fs = fm.scale || 1
    return { x: fm.x || 0, y: fm.y || 0, w: (fm.width || 1920) / fs, h: (fm.height || 1080) / fs }
  }

  readonly property var cards: {
    // Nothing is built or kept up to date while the overview is closed
    // (window titles change all the time).
    if (!root.opened) return []
    var byId = {}
    var tls = Hyprland.toplevels.values
    for (var i = 0; i < tls.length; i++) {
      var t = tls[i]
      var ws = t.workspace
      if (!ws || ws.id <= 0) continue          // special workspaces, the dock
      var o = t.lastIpcObject || {}
      if (o.mapped === false || o.hidden === true) continue
      if (!byId[ws.id]) byId[ws.id] = { id: ws.id, windows: [] }
      var entry = DesktopEntries.heuristicLookup(String(o["class"] || (t.wayland ? t.wayland.appId : "") || ""))
      byId[ws.id].windows.push({
        address: t.address,
        workspaceId: ws.id,
        toplevel: t.wayland,
        title: String(t.title || o.title || ""),
        icon: entry && entry.icon ? Quickshell.iconPath(entry.icon, true) : "",
        appName: entry ? String(entry.name || "") : String(o["class"] || "?"),
        at: o.at || null,
        size: o.size || null,
        monitor: o.monitor,
        floating: !!o.floating,
        focusHistory: o.focusHistoryID === undefined ? 999 : o.focusHistoryID
      })
    }
    // Every workspace from 1 up to the highest one in use (or the one you're
    // on), empty ones in between included.
    var highest = Math.max(1, root.currentWorkspace)
    for (var key in byId) highest = Math.max(highest, byId[key].id)
    highest = Math.max(highest, root.shownUpTo)
    var list = []
    for (var n = 1; n <= highest; n++) list.push(byId[n] || { id: n, windows: [] })
    for (var j = 0; j < list.length; j++) {
      // Floating and most recently used windows on top.
      list[j].windows.sort(function(a, b) {
        if (a.floating !== b.floating) return a.floating ? 1 : -1
        return b.focusHistory - a.focusHistory
      })
    }
    return list
  }

  // The "+" card: the workspace after the last card.
  readonly property int freeWorkspace: cards.length + 1

  // Windows of the workspace you're on, shown large under the cards.
  // In the order they sit on the screen (top to bottom, then left to right),
  // so the large view follows the real arrangement and a swap shows there.
  readonly property var currentWindows: {
    for (var i = 0; i < cards.length; i++) {
      if (cards[i].id !== shownWorkspace) continue
      var list = cards[i].windows.slice()
      list.sort(function(a, b) {
        var ay = a.at ? a.at[1] : 0, by = b.at ? b.at[1] : 0
        var ax = a.at ? a.at[0] : 0, bx = b.at ? b.at[0] : 0
        var row = Math.round(ay / 60) - Math.round(by / 60)
        return row !== 0 ? row : ax - bx
      })
      return list
    }
    return []
  }

  // The large view keeps one picture per window for as long as the window is
  // shown there (keyed by address), so after a swap the pictures slide to
  // their new places instead of being rebuilt and jumping.
  readonly property var bigOrder: currentWindows.map(function(w) { return w.address })
  readonly property var bigInfo: {
    var m = {}
    for (var i = 0; i < currentWindows.length; i++) m[currentWindows[i].address] = currentWindows[i]
    return m
  }
  property var bigKeys: []
  onBigOrderChanged: {
    var want = bigOrder
    var same = bigKeys.length === want.length && want.every(function(a) { return bigKeys.indexOf(a) >= 0 })
    if (same) return
    var keep = bigKeys.filter(function(a) { return want.indexOf(a) >= 0 })
    bigKeys = keep.concat(want.filter(function(a) { return keep.indexOf(a) < 0 }))
  }

  // ------------------------------------------------------------- dragging
  property var dragging: null        // the window being dragged
  property size dragSize: Qt.size(0, 0)  // size of the picture it was dragged from
  property point dragPoint: Qt.point(0, 0)
  property int hoverCard: -2         // workspace id under the pointer, -1 = "+"

  function cardAt(x, y) {
    var b = plusButton.mapFromItem(overlay, x, y)
    if (b.x >= 0 && b.y >= 0 && b.x <= plusButton.width && b.y <= plusButton.height) return -1
    // The large area at the bottom is the workspace you're on.
    var g = bigArea.mapFromItem(overlay, x, y)
    if (g.x >= 0 && g.y >= 0 && g.x <= bigArea.width && g.y <= bigArea.height) return shownWorkspace
    // Only cards in the visible part of the scrolling row count.
    var f = cardFlick.mapFromItem(overlay, x, y)
    if (f.x < 0 || f.y < 0 || f.x > cardFlick.width || f.y > cardFlick.height) return -2
    for (var i = 0; i < cardRow.children.length; i++) {
      var c = cardRow.children[i]
      if (c.workspaceId === undefined) continue
      var p = c.mapFromItem(overlay, x, y)
      if (p.x >= 0 && p.y >= 0 && p.x <= c.width && p.y <= c.height) return c.workspaceId
    }
    return -2
  }

  // ------------------------------------------------------------- the view
  OverlayWindow {
    id: panel
    shown: root.opened
    WlrLayershell.namespace: "omarchy-mission-control"
    shownKeyboardFocus: root.keyboardPaused ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    Item {
      id: overlay
      anchors.fill: parent

      // The desktop behind, blurred and tinted with the theme's own
      // background colour (light in a light theme, dark in a dark one), so
      // you can still tell which theme you are in.
      Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.themeBackground, 0.45)
      }
      // Clicks on empty space do nothing; close with Esc, the shortcut or
      // four fingers down.
      MouseArea {
        anchors.fill: parent
      }

      // Mouse wheel outside the row of cards: previous / next workspace, one
      // a notch (over the cards it scrolls them; see the row's WheelHandler).
      // Like the three/four-finger swipes, so it works for mouse users too.
      WheelHandler {
        acceptedDevices: PointerDevice.Mouse
        property real acc: 0
        onWheel: function(e) {
          acc += e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x
          while (Math.abs(acc) >= 120) {
            root.stepWorkspace(acc > 0 ? -1 : 1)
            acc -= acc > 0 ? 120 : -120
          }
        }
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape && root.settingsPage !== "") {
            root.settingsPage = root.settingsPage === "menu" ? "" : "menu"
            event.accepted = true
          } else if (event.key === Qt.Key_Escape
              || (event.key === Qt.Key_D && (event.modifiers & Qt.MetaModifier))) {
            root.close()
            event.accepted = true
          }
        }
      }

      readonly property real gap: Style.space(22)
      readonly property real edge: Style.space(28)   // margin at the screen's sides
      readonly property var mon: root.monitorBox(root.focusedMonitor && root.focusedMonitor.lastIpcObject
                                                 ? root.focusedMonitor.lastIpcObject.id : -1)
      readonly property real aspect: mon.h > 0 ? mon.h / mon.w : 0.666
      readonly property real labelHeight: Style.font.body * 1.4 + Style.space(24)
      // The row of workspaces along the top, like the Mac's Spaces bar.
      // Cards keep one size; when they don't all fit, the row scrolls.
      readonly property real cardWidth: Math.min(width * 0.15, height * 0.22 / aspect)
      readonly property real cardHeight: cardWidth * aspect

      // The row of cards, scrolled sideways with two fingers or the mouse
      // wheel when it is wider than the screen.
      Flickable {
        id: cardFlick
        // Not scrolled by dragging or by the touchpad's two-finger scroll
        // (by design); the mouse wheel, three/four-finger swipes and
        // dragging near the ends move it (WheelHandler, relay, Timer below).
        interactive: false
        readonly property real overhang: Style.space(14)   // room for the X above the cards
        // The row is centred in the space left of the "+" button.
        readonly property real space: plusButton.x - overlay.gap - overlay.edge
        width: Math.min(cardRow.width + overhang * 2, space)
        height: cardRow.height + overhang
        x: overlay.edge + (space - width) / 2
        y: Style.space(40) - overhang
        contentWidth: cardRow.width + overhang * 2
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        maximumFlickVelocity: 6000
        flickDeceleration: 2500
        // A glide into an end overshoots a little and springs back.
        boundsBehavior: Flickable.OvershootBounds
        rebound: Transition {
          NumberAnimation { properties: "x"; duration: 520; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
        }
        clip: true
        readonly property real maxX: Math.max(0, contentWidth - width)
        // Set by "+": scroll to the end once the new card has been laid out.
        property bool toEndPending: false
        onMaxXChanged: if (toEndPending) { contentX = maxX; toEndPending = false }

        function scrollBy(dx) { contentX = Math.max(0, Math.min(maxX, contentX + dx)) }

        // ------- spring at the ends
        // While swiping, the row can be pulled past an end, resisting more the
        // further it goes (at most about 400 px), and springs back on release.
        property real rawX: 0      // where the fingers would have put it
        function rubberTo(x) {
          rawX = x
          if (x < 0) contentX = -400 * (1 - Math.exp(x / 730))
          else if (x > maxX) contentX = maxX + 400 * (1 - Math.exp(-(x - maxX) / 730))
          else contentX = x
        }
        function springBack() {
          stopSpring()
          spring.to = Math.max(0, Math.min(maxX, contentX))
          spring.start()
        }
        function stopSpring() { spring.stop(); nudge.stop() }
        // A wheel notch (or step) at an end: a small push and spring back.
        function scrollOrNudge(dx) {
          if ((dx < 0 && contentX <= 0) || (dx > 0 && contentX >= maxX)) {
            if (nudge.running || spring.running) return
            nudgeOut.to = contentX + (dx < 0 ? -50 : 50)
            nudgeBack.to = dx < 0 ? 0 : maxX
            nudge.start()
          } else {
            stopSpring()
            scrollBy(dx)
          }
        }
        SpringAnimation {
          id: spring
          target: cardFlick
          property: "contentX"
          spring: 3.2
          damping: 0.22
          epsilon: 0.5
        }
        SequentialAnimation {
          id: nudge
          NumberAnimation { id: nudgeOut; target: cardFlick; property: "contentX"; duration: 90; easing.type: Easing.OutQuad }
          SpringAnimation { id: nudgeBack; target: cardFlick; property: "contentX"; spring: 3.2; damping: 0.22; epsilon: 0.5 }
        }
        // Bring the workspace you're on into view when the overview opens.
        function showCurrent() { showCard(root.currentWorkspace) }
        // Scroll so card `id` is in view (centred when it was off to a side).
        function showCard(id) {
          var left = overhang + (id - 1) * (overlay.cardWidth + overlay.gap)
          if (left >= contentX && left + overlay.cardWidth <= contentX + width) return
          // Worked out from the number of cards: right after opening the row
          // hasn't been laid out yet, so maxX can still be stale.
          var n = root.cards.length
          var full = overhang * 2 + n * overlay.cardWidth + Math.max(0, n - 1) * overlay.gap
          contentX = Math.max(0, Math.min(Math.max(0, full - width), left - (width - overlay.cardWidth) / 2))
        }
        Connections {
          target: root
          function onOpenedChanged() { if (root.opened) Qt.callLater(cardFlick.showCurrent) }
        }

        // Pointer over the row: three-finger swipes scroll it (see swipeScrolls).
        HoverHandler {
          onHoveredChanged: root.swipeScrolls(hovered && root.opened)
        }

        WheelHandler {
          // Mouse wheel only (one card a notch): the touchpad's two-finger
          // scroll doesn't move the row (by design); three
          // and four fingers do (see sideSwipes).
          acceptedDevices: PointerDevice.Mouse
          onWheel: function(e) {
            var a = Math.abs(e.angleDelta.x) > Math.abs(e.angleDelta.y) ? e.angleDelta.x : e.angleDelta.y
            cardFlick.scrollOrNudge(-a / 120 * (overlay.cardWidth + overlay.gap))
          }
        }

        // While a window is dragged near either end of the row, keep scrolling.
        Timer {
          interval: 16
          repeat: true
          running: (root.dragging !== null || root.draggingCard > 0) && edge !== 0
          readonly property real band: Style.space(70)
          readonly property real localX: root.dragPoint.x - cardFlick.x
          readonly property bool inRow: root.dragPoint.y >= cardFlick.y && root.dragPoint.y <= cardFlick.y + cardFlick.height
          readonly property int edge: !inRow ? 0 : (localX < band ? -1 : (localX > cardFlick.width - band ? 1 : 0))
          onTriggered: cardFlick.scrollBy(edge * Style.space(24))
        }

      // Where a dragged card will land: an accent bar between two cards.
      Rectangle {
        visible: root.draggingCard > 0 && root.cardSlot >= 0
        width: Style.space(5)
        height: overlay.cardHeight
        radius: width / 2
        z: 20
        color: root.selectedText
        x: cardRow.x + root.cardSlot * (overlay.cardWidth + overlay.gap) - overlay.gap / 2 - width / 2
        y: cardRow.y
      }

      Row {
        id: cardRow
        x: cardFlick.overhang
        y: cardFlick.overhang
        spacing: overlay.gap

        Repeater {
          // A count, not the list itself: the cards (and their window
          // pictures) stay as they are when a window changes, instead of
          // being rebuilt and flickering.
          model: root.cards.length

          delegate: Item {
            id: card
            required property int index
            readonly property var cardData: root.cards[index] || ({ id: index + 1, windows: [] })
            readonly property int workspaceId: index + 1
            readonly property bool current: workspaceId === root.currentWorkspace
            readonly property bool viewed: workspaceId === root.shownWorkspace
            // Window pictures keyed by address, kept while the window is here.
            readonly property var winOrder: cardData.windows.map(function(w) { return w.address })
            readonly property var winMap: {
              var m = {}
              for (var i = 0; i < cardData.windows.length; i++) m[cardData.windows[i].address] = cardData.windows[i]
              return m
            }
            property var winKeys: []
            onWinOrderChanged: {
              var want = winOrder
              var same = winKeys.length === want.length && want.every(function(a) { return winKeys.indexOf(a) >= 0 })
              if (same) return
              var keep = winKeys.filter(function(a) { return want.indexOf(a) >= 0 })
              winKeys = keep.concat(want.filter(function(a) { return keep.indexOf(a) < 0 }))
            }
            readonly property bool dropHere: root.dragging !== null && root.hoverCard === workspaceId
                                             && root.dragging.workspaceId !== workspaceId
            readonly property var box: root.monitorBox(cardData.windows.length > 0
                                                        ? cardData.windows[0].monitor : -1)
            readonly property real k: screenArea.width / Math.max(1, box.w)

            width: overlay.cardWidth
            height: overlay.cardHeight + overlay.labelHeight
            opacity: root.draggingCard === workspaceId ? 0.35 : 1

            BorderSurface {
              id: surface
              width: parent.width
              height: overlay.cardHeight
              radius: root.cornerRadius
              color: card.dropHere ? root.selectedBackground : root.background
              borderSpec: root.borderSpec
              padding: 0
              clip: true

              MouseArea {
                anchors.fill: parent
                preventStealing: true
                property point start: Qt.point(0, 0)
                property bool moved: false
                onPressed: function(m) { start = Qt.point(m.x, m.y); moved = false }
                onPositionChanged: function(m) {
                  if (!pressed) return
                  if (Math.abs(m.x - start.x) + Math.abs(m.y - start.y) > Style.space(8)) moved = true
                  if (moved) root.cardDragTo(card.workspaceId, mapToItem(overlay, m.x, m.y))
                }
                onReleased: function(m) { if (moved) root.cardDrop(mapToItem(overlay, m.x, m.y)) }
                onClicked: if (!moved) root.viewWorkspace(card.workspaceId)
                onDoubleClicked: root.goToWorkspace(card.workspaceId)
              }

              Item {
                id: screenArea
                anchors.fill: parent
                anchors.topMargin: surface.contentTopInset
                anchors.rightMargin: surface.contentRightInset
                anchors.bottomMargin: surface.contentBottomInset
                anchors.leftMargin: surface.contentLeftInset
                clip: true

                Repeater {
                  model: card.winKeys

                  // Windows keep their place on the screen, scaled down;
                  // without a known place they sit in a simple grid.
                  delegate: WindowTile {
                    id: small
                    required property string modelData   // the window's address
                    readonly property var real: card.winMap[modelData]
                    readonly property var w: root.previewGeom(real)
                    readonly property int index: Math.max(0, card.winOrder.indexOf(root.previewAddr(modelData)))
                    readonly property bool placed: !!w && !!w.at && !!w.size
                    readonly property var mb: root.monitorBox(w ? w.monitor : -1)
                    readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(card.cardData.windows.length)))
                    ov: root
                    info: real || ({ address: modelData, workspaceId: -1, toplevel: null, title: "", icon: "", appName: "" })
                    visible: !!real
                    dragLayer: overlay
                    inCard: true
                    // Centre and size animate (see below), so a resize grows
                    // or shrinks evenly from the middle.
                    property real ww: placed ? w.size[0] * card.k : screenArea.width / cols
                    property real hh: placed ? w.size[1] * card.k : screenArea.height / cols
                    property real cx: (placed ? (w.at[0] - mb.x) * card.k : (index % cols) * screenArea.width / cols) + ww0 / 2
                    property real cy: (placed ? (w.at[1] - mb.y) * card.k : Math.floor(index / cols) * screenArea.height / cols) + hh0 / 2
                    readonly property real ww0: placed ? w.size[0] * card.k : screenArea.width / cols
                    readonly property real hh0: placed ? w.size[1] * card.k : screenArea.height / cols
                    x: cx - ww / 2
                    y: cy - hh / 2
                    width: ww
                    height: hh
                    z: index
                    // Slide to a new place too, but not when first shown.
                    property bool settled: false
                    Component.onCompleted: Qt.callLater(function() { small.settled = true })
                    Behavior on cx { enabled: small.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on cy { enabled: small.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on ww { enabled: small.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on hh { enabled: small.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                  }
                }
              }
            }

            HoverHandler { id: cardHover }

            // Close (X) in the card's top-right corner while pointed at.
            Rectangle {
              visible: (cardHover.hovered || closeMouse.containsMouse) && root.cards.length > 1 && !root.dragging
              x: parent.width - width * 2 / 3
              y: -height / 3
              z: 50
              width: Style.space(26)
              height: width
              radius: width / 2
              color: closeMouse.containsMouse ? root.selectedText : root.background
              border.width: Math.max(1, Style.space(1))
              border.color: Qt.alpha(root.foreground, 0.5)
              Text {
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: "\u00d7"
                color: closeMouse.containsMouse ? root.background : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Math.round(parent.width * 0.7)
                font.bold: true
              }
              MouseArea {
                id: closeMouse
                anchors.fill: parent
                anchors.margins: -Style.space(4)
                hoverEnabled: true
                onClicked: root.closeWorkspace(card.workspaceId)
              }
            }

            // The workspace shown in the large view: accent outline.
            Rectangle {
              width: parent.width
              height: overlay.cardHeight
              radius: root.cornerRadius
              color: "transparent"
              border.width: Math.max(2, Style.space(3))
              border.color: root.selectedText
              visible: card.viewed
              z: 5
            }

            // Workspace number on a small pill in the theme's menu colours.
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter
              y: overlay.cardHeight + Style.space(8)
              width: Math.max(height, label.implicitWidth + Style.space(16))
              height: label.implicitHeight + Style.space(6)
              radius: height / 2
              color: card.current ? root.selectedText : root.background
              Text {
                id: label
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: String(card.workspaceId)
                color: card.current ? root.background : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Math.round(Style.font.body * 1.4)
                font.bold: true
              }
            }

            // The strip under the card, number included, is the card's handle:
            // drag it to move the whole card (reorder workspaces); click it to
            // go there. Small windows inside the card drag on their own.
            MouseArea {
              x: 0
              y: overlay.cardHeight
              width: parent.width
              height: overlay.labelHeight
              cursorShape: moved ? Qt.ClosedHandCursor : Qt.OpenHandCursor
              preventStealing: true
              property point start: Qt.point(0, 0)
              property bool moved: false
              onPressed: function(m) { start = Qt.point(m.x, m.y); moved = false }
              onPositionChanged: function(m) {
                if (!pressed) return
                if (Math.abs(m.x - start.x) + Math.abs(m.y - start.y) > Style.space(8)) moved = true
                if (moved) root.cardDragTo(card.workspaceId, mapToItem(overlay, m.x, m.y))
              }
              onReleased: function(m) { if (moved) root.cardDrop(mapToItem(overlay, m.x, m.y)) }
              onClicked: if (!moved) root.viewWorkspace(card.workspaceId)
                onDoubleClicked: root.goToWorkspace(card.workspaceId)
            }
          }
        }

      }
      }

      // "+" button, fixed at the right edge of the screen (it doesn't scroll):
      // click it to add an empty workspace card (the overview stays open, like
      // the Mac), or drop a window on it to give the window a new workspace.
      Rectangle {
        id: plusButton
        readonly property bool dropHere: root.dragging !== null && root.hoverCard === -1
        width: Style.space(41)
        height: width
        x: overlay.width - width - overlay.edge
        y: cardFlick.y + cardFlick.overhang + (overlay.cardHeight - height) / 2
        radius: root.cornerRadius > 0 ? root.cornerRadius : width / 4
        color: dropHere || plusMouse.containsMouse ? root.selectedText : root.background
        border.width: Math.max(1, Style.space(2))
        border.color: Qt.alpha(root.foreground, 0.4)

        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "+"
          color: plusButton.dropHere || plusMouse.containsMouse ? root.background : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.round(parent.height * 0.6)
        }
        MouseArea {
          id: plusMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.addWorkspaceCard()
        }
      }

      // The windows of the workspace you're on, spread out large below the
      // row of workspaces (Mac-style), each with its app's name under it.
      Item {
        id: bigArea
        x: parent.width * 0.04
        y: cardFlick.y + cardFlick.height + Style.space(18)
        width: parent.width * 0.92
        height: parent.height - y - Style.space(44)

        readonly property int n: root.currentWindows.length
        readonly property int cols: Math.max(1, Math.ceil(Math.sqrt(n * width / Math.max(1, height) / 1.6)))
        readonly property int rows: Math.max(1, Math.ceil(n / cols))
        readonly property real cellW: width / cols
        readonly property real cellH: height / rows
        readonly property real pad: Style.space(10)
        // Windows in a row sit next to each other with this gap, the row
        // centred as a group (they are not spread over equal cells).
        readonly property real gap: Style.space(28)
        readonly property real titleH: Math.round(Style.font.body * 1.2) + Style.space(14)

        // Size of the picture of window `address`: as large as its cell allows.
        function frameSize(address) {
          var info = root.bigInfo[address]
          var aspect = info && info.size && info.size[0] > 0 ? info.size[1] / info.size[0] : overlay.aspect
          var w = Math.max(1, Math.min(cellW - pad * 2, (cellH - pad * 2 - titleH) / aspect))
          return { w: w, h: w * aspect }
        }
        // Where spot i of the real order is: left edge, width, centre.
        function slotRect(i) {
          var row = Math.floor(i / cols)
          var first = row * cols
          var last = Math.min(n, first + cols) - 1
          var total = 0, before = 0
          for (var j = first; j <= last; j++) {
            var w = frameSize(root.bigOrder[j]).w
            if (j < i) before += w + gap
            total += w + (j > first ? gap : 0)
          }
          var mine = frameSize(root.bigOrder[i]).w
          var x = (width - total) / 2 + before
          return { x: x, w: mine, cx: x + mine / 2, cy: row * cellH + cellH / 2 }
        }
        // The spot of the large view at (x, y), by the real order, or -1.
        function slotAt(x, y) {
          var row = Math.floor(y / cellH)
          if (row < 0 || row >= rows) return -1
          var first = row * cols
          var last = Math.min(n, first + cols) - 1
          for (var i = first; i <= last; i++) {
            var r = slotRect(i)
            if (x >= r.x - gap / 2 && x <= r.x + r.w + gap / 2) return i
          }
          return -1
        }
        // Lit while a window from another workspace is dragged over it:
        // dropping it here brings it to the workspace you're on.
        readonly property bool dropHere: root.dragging !== null
          && root.dragging.workspaceId !== root.shownWorkspace
          && root.dragPoint.x >= x && root.dragPoint.x <= x + width
          && root.dragPoint.y >= y && root.dragPoint.y <= y + height

        Rectangle {
          anchors.fill: parent
          anchors.margins: -Style.space(10)
          visible: bigArea.dropHere
          radius: root.cornerRadius > 0 ? root.cornerRadius * 2 : Style.space(12)
          color: Qt.alpha(root.selectedText, 0.08)
          border.width: Math.max(2, Style.space(3))
          border.color: root.selectedText
        }

        Text {
          anchors.centerIn: parent
          visible: bigArea.n === 0
          textFormat: Text.PlainText
          text: "No windows on this workspace"
          color: root.themeForeground
          opacity: 0.8
          font.family: root.fontFamily
          font.pixelSize: Math.round(Style.font.body * 1.4)
        }

        Repeater {
          model: root.bigKeys

          delegate: WindowTile {
            id: big
            required property string modelData   // the window's address
            readonly property var winInfo: root.bigInfo[modelData]
            readonly property int index: Math.max(0, root.bigOrder.indexOf(root.previewAddr(modelData)))
            // Its own size, at the spot it takes (its partner's during a
            // swap preview).
            readonly property var frame: bigArea.frameSize(modelData)
            readonly property var slot: bigArea.slotRect(index)

            ov: root
            info: winInfo || ({ address: modelData, workspaceId: -1, toplevel: null, title: "", icon: "", appName: "" })
            visible: !!winInfo
            dragLayer: overlay
            showTitle: true
            // Slide to a new place (after a swap), but not when first shown.
            // The centre and the size are what animate, so a window that
            // changes size grows or shrinks evenly from its middle.
            property bool settled: false
            Component.onCompleted: Qt.callLater(function() { big.settled = true })
            property real cx: slot.cx
            property real cy: slot.cy
            property real ww: frame.w
            property real hh: frame.h + titleHeight
            Behavior on cx { enabled: big.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on cy { enabled: big.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on ww { enabled: big.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            Behavior on hh { enabled: big.settled; NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
            width: ww
            height: hh
            x: cx - ww / 2
            y: cy - hh / 2
          }
        }
      }

      // ---------------------------------------------------- gear + Settings
      // Just the gear symbol (no button behind it), accent coloured while
      // pointed at or while Settings is open.
      Item {
        id: gear
        width: Style.space(19)
        height: width
        x: overlay.edge
        y: overlay.height - height - overlay.edge
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "\uf013"
          color: gearMouse.containsMouse || root.settingsPage !== "" ? root.selectedText : root.themeForeground
          style: Text.Raised
          styleColor: Qt.alpha(root.themeBackground, 0.7)
          font.family: root.fontFamily
          font.pixelSize: parent.width
        }
        MouseArea {
          id: gearMouse
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.settingsPage = root.settingsPage === "" ? "menu" : ""
        }
      }

      // Clicks beside the Settings window close it (not the overview).
      MouseArea {
        anchors.fill: parent
        visible: root.settingsPage !== ""
        z: 90
        onClicked: root.settingsPage = ""
        onWheel: function(w) { w.accepted = true }
      }

      // Settings in the bottom left, just above the gear; About and Remove
      // open beside it on the right, lined up along the bottom.
      SettingsPanel {
        id: settingsPanel
        ov: root
        mode: "menu"
        // Rises from the bottom-left corner while fading in.
        visible: root.menuIn > 0
        opacity: root.menuIn
        z: 95
        x: overlay.edge
        y: gear.y - height - Style.space(12) + (1 - root.menuIn) * Style.space(60)
      }
      SettingsPanel {
        id: detailPanel
        ov: root
        mode: "detail"
        // Slides out to the right from behind Settings while fading in.
        visible: root.detailIn > 0
        opacity: root.detailIn
        z: 94
        x: settingsPanel.x + settingsPanel.width + Style.space(14) - (1 - root.detailIn) * Style.space(80)
        y: settingsPanel.y + settingsPanel.height - height
      }

      // The card being dragged follows the pointer.
      Rectangle {
        visible: root.draggingCard > 0
        width: overlay.cardWidth * 0.8
        height: overlay.cardHeight * 0.8
        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
        z: 100
        radius: root.cornerRadius
        color: Qt.alpha(root.background, 0.85)
        border.width: Math.max(1, Style.space(2))
        border.color: root.selectedText
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: String(root.draggingCard)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Math.round(parent.height * 0.4)
          font.bold: true
        }
      }

      // The window being dragged follows the pointer: no bigger than the
      // picture it was picked up from (80% of a small one, at most 160 x 100)
      // and see-through, so the spot it would land on stays visible.
      Rectangle {
        visible: root.dragging !== null
        readonly property real k: Math.min(1, Style.space(160) / Math.max(1, root.dragSize.width),
                                           Style.space(100) / Math.max(1, root.dragSize.height))
        width: Math.max(Style.space(24), root.dragSize.width * Math.min(0.8, k))
        height: Math.max(Style.space(16), root.dragSize.height * Math.min(0.8, k))
        opacity: 0.7
        x: root.dragPoint.x - width / 2
        y: root.dragPoint.y - height / 2
        z: 100
        radius: Math.max(2, root.cornerRadius / 2)
        color: root.selectedBackground
        border.width: Math.max(1, Style.space(2))
        border.color: root.selectedText
        clip: true
        ScreencopyView {
          anchors.fill: parent
          anchors.margins: parent.border.width
          captureSource: root.dragging ? root.dragging.toplevel : null
          live: true
        }
      }
    }
  }
}
