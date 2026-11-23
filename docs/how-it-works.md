# How it works

Notes for anyone reading or changing the code.

## Files

| File | What it is |
|---|---|
| `manifest.json` | Plugin ID, name, version, and its two kinds: `service` and `bar-widget` |
| `Overview.qml` | The service: the model, every action, and the full-screen view |
| `WindowTile.qml` | One window picture (used in the cards and in the large view) |
| `SettingsPanel.qml` | The Settings window and its About and Remove pages |
| `BarWidget.qml` | The bar button and its right-click box |
| `icon.svg` | The launcher icon |
| `uninstall.sh` | What Settings → Remove Plugin runs |
| `helper/` | The optional swipe helper: service unit, script, installer, remover |

## The model

`Hyprland.toplevels` (Quickshell) is turned into `cards`: one entry per
workspace from 1 to the highest in use, each with its windows and their
position and size from Hyprland. `cards` is empty while Mission Control is
closed, so nothing is built or updated in the background.

Window pictures are `ScreencopyView`s of each toplevel, captured at one fixed
size and scaled. Cards and the large view keep one picture per window, keyed
by its address, so a change slides pictures to their new places instead of
rebuilding them.

## Talking to Hyprland

- **Actions** (focus, move, close, swap, toggle split) go through
  `Hyprland.dispatch` or `hyprctl eval` with Hyprland's Lua API (`hl.dsp…`).
- **Swap and split-flip need a focused window.** Hyprland won't focus a window
  while a layer holds the keyboard, so the overview lets go of the keyboard
  for a moment, runs the commands, puts the mouse pointer back where it was,
  and takes the keyboard back. Its view is pinned to the workspace it was on
  meanwhile.
- **Shortcut and swipes** are registered at run time with `hyprctl eval`
  (`hl.bind`, `hl.gesture`). Hyprland forgets them when its config reloads, so
  the plugin listens for the `configreloaded` event and applies them again.
- **Side swipes while open.** On opening, every three/four-finger
  horizontal/left/right gesture is cleared and set to "workspace"; over the
  row of cards they are cleared so the helper's movement scrolls the row (or
  set to step commands without the helper). Hyprland cannot report which
  gestures are configured, so closing runs `hyprctl reload` to put the user's
  own back.

## The swipe helper

`helper/swipe-helper.py` runs as root from a locked-down systemd unit. It
listens on `/run/omarchy-mission-control/swipe.sock`. While a client is
connected it runs `libinput debug-events`, keeps `GESTURE_SWIPE_*` lines with
three or more fingers, and writes `b <fingers>`, `u <dx> <dy>` and `e` lines.
When the last client disconnects it stops libinput. It checks each
connection's account (`SO_PEERCRED`) and accepts only `ALLOWED_UID`, which
`install.sh` writes into the unit.

The overview connects on every open (not with a property binding: a failed
attempt would break the binding for good).

## Settings

`~/.config/omarchy-mission-control/settings.json`, read by the overview and
the bar button: `launcherIcon`, `barWidget`, `shortcut`, `gestures`, `opened`.

The launcher entry is a `.desktop` file the plugin writes to
`~/.local/share/applications` and deletes when the plugin is switched off.
Its command is `launch`, which also keeps Omarchy's "Launching…" message from
appearing (the launcher waits for a new window, and the overview isn't one).

## Commands

`omarchy-shell <plugin-id> <command>`:

| Command | Does |
|---|---|
| `open`, `close`, `toggle`, `launch` | Open and close |
| `showSettings <menu\|about\|confirm>` | Open with a Settings page showing |
| `setFlag <launcherIcon\|barWidget> <true\|false>` | Flip a setting |
| `scroll <1\|-1>` | Step the row (used by the swipes without the helper) |

The rest (`step`, `swap`, `moveCard`, `closeCard`, `addCard`, `viewCard`,
`pull`, `letGo`, `wheelNotch`, `rowX`, `fling`, `refresh`, `themeRefresh`,
`previewSwap`, `dropPreview`, `swapTargetAtPoint`, `dropTarget`, `tidy`,
`relayState`, `settingsPage`) exist for testing each feature without a mouse
or touchpad. `omarchy-shell <plugin-id>.bar box` opens the bar button's box.

## Testing a change

```bash
omarchy plugin validate .
omarchy restart shell
qs log -p /usr/share/omarchy/shell -t 200 | grep -i mission
```

`rescanPlugins` alone keeps the old code running; restart the shell.

## The theme refresh

Windows on other workspaces don't redraw while hidden. After a theme change,
with the overview closed, the plugin shows a one-frame screenshot of the output
on an Overlay layer that holds the keyboard exclusively and swallows pointer
input, focuses each busy workspace for a moment behind it, focuses the
original workspace again, and only then removes the layer. A guard does the
same hand-back after four seconds if anything stalls. The layer is shown
without a fade (a layer rule with `no_anim`, set with the other rules after
every reload), so the visited workspaces never show through.

Before freezing, the plugin asks Omarchy's wallpaper engine (`owe status`).
If a video wallpaper is playing (`loaded_kind` is `video` and it isn't
paused), the still picture would visibly stop it, so the plugin doesn't
freeze: the pictures stay marked stale and the overview visits the
workspaces itself the next time it is opened. Without `owe`, or with a still
wallpaper, it freezes as described.

The overview's backdrop blurs only the wallpaper (`xray = true` in its layer
rule), never windows, so a workspace visited behind it can't show through and
no still picture is needed while it is open.
