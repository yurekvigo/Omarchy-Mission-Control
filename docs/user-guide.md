# User guide

Everything Omarchy Mission Control does, and how to do it.

## Opening and closing

| To | Do this |
|---|---|
| Open | Swipe **up** with four fingers, press **Super + D**, click the bar button, or start "Mission Control" from the app launcher |
| Close | Swipe **down** with four fingers, press **Esc**, or press **Super + D** again |

Clicking empty space does not close it, so a missed click never throws you out.

## What you see

- **The row of cards** along the top: one card for every workspace from 1 up
  to the highest one in use, empty ones included. Each card shows live
  pictures of its windows, placed as they are on the real screen. The number
  under the card you are on is highlighted.
- **The large view** below: the windows of the workspace you are on, in the
  order they sit on the screen, each with its app name.
- **+** at the right edge adds a workspace.
- **The gear** at the bottom left opens Settings.

## Moving between workspaces

| To | Do this |
|---|---|
| Switch and stay in Mission Control | Click a card once |
| Switch and close Mission Control | Double-click a card |
| Go to a window | Click it in the large view, or double-click it in a card |
| Next / previous workspace | Mouse wheel, or a three/four-finger swipe left or right, anywhere outside the row of cards |

## Moving and arranging windows

| To | Do this |
|---|---|
| Move a window to another workspace | Drag it (from the large view or from inside a card) onto another card |
| Put a window on a new workspace | Drag it onto **+** |
| Bring a window to the workspace you are on | Drag it from a card down into the large view |
| Swap two windows | Drag one onto another window of the same workspace. The other one slides out of the way before you let go |
| Close a window | Point at it in the large view and click its **x** |

When a window leaves a workspace and two tiled windows are left stacked on
top of each other, Mission Control turns them side by side.

## Managing workspaces

| To | Do this |
|---|---|
| Add an empty workspace | Click **+**. It stays only if you put a window on it |
| Reorder workspaces | Drag a card by the number under it (or by an empty part of the card). Workspaces are renumbered in the new order |
| Remove a workspace | Point at its card and click the **x**. Its windows join the workspace before it; nothing is closed |

## Scrolling the row of cards

Cards keep their size. When there are more than fit on the screen, scroll the
row while the pointer is over it:

- **Mouse wheel:** one card per notch.
- **Three- or four-finger swipe** left or right. With
  [Smooth Swipes](#smooth-swipes) the row follows your fingers and keeps
  gliding; without it, each swipe moves the row two cards, and quick swipes in
  a row move further.
- **Dragging** a window or a card near either end scrolls the row by itself.

The row stretches like a spring at both ends and bounces back.

## Settings

Click the gear at the bottom left.

| Setting | What it does |
|---|---|
| **Application Icon** | Shows or hides "Mission Control" in the app launcher |
| **Bar Widget** | Shows or hides the Mission Control button on the bar |
| **Smooth Swipes** | Installs or removes the optional swipe helper (see below). Asks for your password |
| **About** | Version, credits, and a few live numbers |
| **Remove Plugin** | Removes the plugin and everything it set up, after you confirm |

Right-clicking the bar button opens a small box with Open Mission Control,
the Application Icon and Bar Widget switches, and About.

### Changing the shortcut or the swipes

The keyboard shortcut and the four-finger up/down swipes are set in
`~/.config/omarchy-mission-control/settings.json`:

```json
{
  "shortcut": "SUPER + D",
  "gestures": true
}
```

- `"shortcut"`: any Hyprland key combination, or `""` for none.
- `"gestures"`: `false` leaves the four-finger up/down swipes alone.

Run `omarchy restart shell` after editing the file.

To use a key or gesture of your own, bind it to one of these commands
(replace the ID with the one in the plugin's `manifest.json`):

```bash
omarchy-shell io.github.yurekvigo.mission-control toggle
```

`open` and `close` work the same way.

## Smooth swipes

Hyprland keeps three- and four-finger swipe movement to itself, so a plugin
only learns that a swipe happened, not how far the fingers moved. With
**Settings → Smooth Swipes** switched on, a small system service passes that
movement on, and the row of cards follows your fingers.

What it installs and does:

- The package `libinput-tools` (an official Arch package), if you don't have
  it, plus a service called `omarchy-mission-control-swipe`.
- It reads the touchpad **only while Mission Control is open**.
- It keeps only swipes made with three or more fingers and passes on three
  things: a swipe started, it moved this far, it ended. Key presses are never
  read out or passed on.
- Only the account that installed it can connect. Other accounts on the same
  computer are turned away, so on a shared computer each person who wants
  smooth swipes would need to be the one who installs it.
- systemd locks it down: no access to your home folder, a read-only system,
  no extra privileges.

Switching Smooth Swipes off removes the service, and removes `libinput-tools`
too if Mission Control installed it. No other package is ever touched.

## Themes

Mission Control uses your theme's menu colours and follows theme changes.
Windows on workspaces you are not looking at don't redraw by themselves, so
shortly after a theme change Mission Control quickly visits each workspace
behind a still picture of your screen. The screen holds still for under a
second, and the keyboard and mouse are held for that moment so nothing you
type or click can land on another workspace. The cards then show the new
colours.

## Taking a screenshot of Mission Control

Press your normal screenshot key (**Print** on Omarchy) while it is open. If
your key doesn't respond there, run this in a terminal, then open Mission
Control within five seconds:

```bash
sleep 5; omarchy capture screenshot fullscreen save
```

## Removing it

**Settings → Remove Plugin → Remove.** This removes the plugin, the launcher
entry, its settings and, if installed, the swipe helper (that part asks for
your password). Hyprland then reloads its config, which drops the plugin's
shortcut and swipes.

## Troubleshooting

| Problem | What to do |
|---|---|
| Super + D or the four-finger swipe does nothing | Another binding may be using it. Change `"shortcut"` in the settings file, or run `omarchy restart shell` |
| A three/four-finger swipe stopped switching workspaces | Run `hyprctl reload`. Mission Control borrows those swipes while it is open and gives them back when it closes |
| Swipes over the cards move in steps | That is the behaviour without the helper. Switch on **Settings → Smooth Swipes** |
| A card shows old theme colours | Click the card once; visiting the workspace redraws its windows |
| A window shows an icon, not a picture | Its picture couldn't be captured yet. It appears once the window has drawn |
| The gear looks like an empty box | Install a Nerd Font (Omarchy ships one) |
