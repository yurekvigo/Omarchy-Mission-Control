#!/bin/sh
# Omarchy Mission Control: removes the swipe helper and the packages that
# install.sh added for it. Asks for the password once (pkexec).
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy-mission-control"
pkgs=""
if [ -f "$conf/helper-packages" ]; then
  for p in $(cat "$conf/helper-packages"); do
    case "$p" in *[!A-Za-z0-9@._+-]*) continue ;; esac
    pacman -Q "$p" >/dev/null 2>&1 && pkgs="$pkgs $p"
  done
fi
[ -e /etc/systemd/system/omarchy-mission-control-swipe.service ] || [ -e /usr/local/bin/omarchy-mission-control-swipe ] || [ -n "$pkgs" ] || exit 0
pkexec sh -c "
  systemctl disable --now omarchy-mission-control-swipe.service 2>/dev/null
  rm -f /etc/systemd/system/omarchy-mission-control-swipe.service /usr/local/bin/omarchy-mission-control-swipe
  systemctl daemon-reload
  ${pkgs:+pacman -Rns --noconfirm$pkgs}
" || exit 1
rm -f "$conf/helper-packages"
