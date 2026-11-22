#!/bin/sh
# Omarchy Mission Control: installs the optional swipe helper (a small system
# service that passes three- and four-finger swipe movement to Mission Control,
# only while it is open, and only to the account that installs it). Asks for
# the password once (pkexec).
#
# It needs `libinput-tools` (official Arch package). If that package is not
# installed yet, this script installs it and leaves a marker so remove.sh takes
# exactly that one package out again. Nothing else is ever recorded.
here=$(cd "$(dirname "$0")" && pwd)
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-mission-control"
marker="$conf/helper-installed-libinput-tools"
uid=$(id -u)
case "$uid" in ''|*[!0-9]*|0) echo "Run this as your own user, not as root." >&2; exit 1 ;; esac
mkdir -p "$conf"

# Marker from versions before 1.0.4 (a list of package names): keep only the
# fact that libinput-tools was ours.
if [ -f "$conf/helper-packages" ]; then
  grep -qx 'libinput-tools' "$conf/helper-packages" && : > "$marker"
  rm -f "$conf/helper-packages"
fi

had_pkg=1
pacman -Q libinput-tools >/dev/null 2>&1 || had_pkg=0

pkexec sh -c "
  set -e
  pacman -S --needed --noconfirm libinput-tools
  install -m 755 '$here/swipe-helper.py' /usr/local/bin/omarchy-mission-control-swipe
  sed 's/@UID@/$uid/' '$here/omarchy-mission-control-swipe.service' > /etc/systemd/system/omarchy-mission-control-swipe.service
  chmod 644 /etc/systemd/system/omarchy-mission-control-swipe.service
  systemctl daemon-reload
  systemctl enable --now omarchy-mission-control-swipe.service
  systemctl restart omarchy-mission-control-swipe.service
" || exit 1

[ "$had_pkg" = 0 ] && : > "$marker"
exit 0
