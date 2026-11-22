#!/bin/sh
# Omarchy Mission Control: installs the optional swipe helper (a small system
# service that passes three- and four-finger swipe movement to Mission Control,
# only while it is open). Asks for the password once (pkexec).
#
# It needs `libinput-tools` (official Arch package). If this script installs
# it, that is noted so remove.sh can take it out again.
here=$(cd "$(dirname "$0")" && pwd)
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-mission-control"
mkdir -p "$conf"
if ! pacman -Q libinput-tools >/dev/null 2>&1; then
  before=$(pacman -Qq | sort)
  need_pkg=1
fi
pkexec sh -c "
  set -e
  pacman -S --needed --noconfirm libinput-tools
  install -m 755 '$here/swipe-helper.py' /usr/local/bin/omarchy-mission-control-swipe
  install -m 644 '$here/omarchy-mission-control-swipe.service' /etc/systemd/system/omarchy-mission-control-swipe.service
  systemctl daemon-reload
  systemctl enable --now omarchy-mission-control-swipe.service
  systemctl restart omarchy-mission-control-swipe.service
" || exit 1
if [ -n "$need_pkg" ]; then
  # Every package that came with it (libinput-tools and what it pulled in).
  after=$(pacman -Qq | sort)
  printf '%s\n' "$before" > "$conf/.pk-before"
  printf '%s\n' "$after" | comm -13 "$conf/.pk-before" - > "$conf/helper-packages"
  rm -f "$conf/.pk-before"
fi
