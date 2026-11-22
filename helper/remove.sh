#!/bin/sh
# Omarchy Mission Control: removes the swipe helper. If install.sh installed
# `libinput-tools` for it (marker file), that one package is removed too, with
# the dependencies nothing else needs. No other package name is ever passed to
# pacman. Asks for the password once (pkexec).
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-mission-control"
marker="$conf/helper-installed-libinput-tools"

# Marker from versions before 1.0.4.
if [ -f "$conf/helper-packages" ]; then
  grep -qx 'libinput-tools' "$conf/helper-packages" && : > "$marker"
  rm -f "$conf/helper-packages"
fi

drop_pkg=0
[ -f "$marker" ] && pacman -Q libinput-tools >/dev/null 2>&1 && drop_pkg=1
[ -e /etc/systemd/system/omarchy-mission-control-swipe.service ] || [ -e /usr/local/bin/omarchy-mission-control-swipe ] || [ "$drop_pkg" = 1 ] || { rm -f "$marker"; exit 0; }

if [ "$drop_pkg" = 1 ]; then pkg_cmd='pacman -Rns --noconfirm libinput-tools || true'; else pkg_cmd=':'; fi
pkexec sh -c "
  systemctl disable --now omarchy-mission-control-swipe.service 2>/dev/null
  rm -f /etc/systemd/system/omarchy-mission-control-swipe.service /usr/local/bin/omarchy-mission-control-swipe
  systemctl daemon-reload
  $pkg_cmd
" || exit 1
rm -f "$marker"
