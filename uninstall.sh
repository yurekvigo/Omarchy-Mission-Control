#!/bin/sh
# Omarchy Mission Control: Settings > Remove Plugin runs this, outside the
# bar's process (the bar restarts while the plugin is removed).
#
# It removes the plugin and everything it set up: the app launcher entry, the
# swipe helper if it was installed (asks for the password), its settings, and
# the plugin itself; then Hyprland reloads its config, which drops the
# plugin's shortcut and swipes.
#
# If ~/.config/omarchy-mission-control/remove-hook exists, that script runs
# instead (for setups that manage the plugin some other way).
ID="io.github.yurekvigo.mission-control"
here=$(cd "$(dirname "$0")" && pwd)
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-mission-control"
say() { notify-send -a "Mission Control" "$1" "$2" 2>/dev/null || true; }

if [ -f "$conf/remove-hook" ]; then
  if sh "$conf/remove-hook"; then say "Mission Control removed" "Everything it set up is gone."
  else say "Mission Control: removal didn't finish" "The remove hook reported a problem."; fi
  exit
fi

sh "$here/helper/remove.sh" || say "Mission Control" "The swipe helper is still installed (password pop-up cancelled?)."
rm -f "$HOME/.local/share/applications/omarchy-mission-control.desktop"
rm -rf "$conf"
omarchy plugin remove "$ID" --yes
hyprctl reload >/dev/null 2>&1
say "Mission Control removed" "The plugin and everything it set up are gone."
