# Changelog

## 1.0.6

- An animated wallpaper no longer stops for a moment after a theme change.
  While a video wallpaper is playing (Omarchy's `owe`), the workspace
  pictures are not refreshed behind a still picture of the screen; the
  overview refreshes them itself the next time it is opened. With a still
  wallpaper, or without `owe`, nothing changes.
- The overview's backdrop now blurs only the wallpaper (Hyprland's x-ray
  blur), not the windows behind it. When the overview refreshes the pictures
  itself, the workspace being visited no longer shows through for a moment,
  and an animated wallpaper keeps playing behind it.

## 1.0.5

- No more flicker after a theme change: the still picture laid over the
  screen while the workspace pictures are refreshed now appears at once
  instead of fading in, so the workspaces visited behind it no longer show
  through for a moment.

## 1.0.4

Security fixes from the marketplace review:

- The theme refresh now holds the keyboard and the pointer while it visits
  other workspaces behind its still picture, so nothing typed or clicked in
  that moment can reach another application.
- The swipe helper's installer no longer compares package lists. It records
  only whether it installed `libinput-tools`, and removal passes only that one
  package name to pacman.
- The swipe helper accepts connections only from the account that installed
  it.

## 1.0.3

- The large windows are bigger and sit next to each other as a centred
  group, instead of being spread over equal slices of the screen.

## 1.0.2

- The background is tinted with the theme's own colour instead of black, so
  you can tell a light theme from a dark one; the text on it uses the theme's
  text colour.

## 1.0.1

- Setting up the shortcut and swipes no longer leaves a "config error" entry
  in Hyprland when a swipe it clears wasn't set.

## 1.0.0

First release.

- Row of workspace cards with live window pictures, and a large view of the
  current workspace.
- Click to switch, double-click to switch and close.
- Drag windows between workspaces, onto **+**, or onto each other to swap,
  with a live preview.
- Drag cards to reorder workspaces; remove a workspace with its **x**.
- Mouse wheel and three/four-finger swipes: scroll the cards or switch
  workspace, with a spring at both ends of the row.
- Optional swipe helper so the row follows your fingers.
- Follows the theme, including after a theme change.
- Settings: app launcher icon, bar button, smooth swipes, About, Remove.
- Bar button with a right-click box.
