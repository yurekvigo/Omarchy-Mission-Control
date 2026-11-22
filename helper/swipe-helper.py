#!/usr/bin/python3 -I
"""Swipe helper for Omarchy Mission Control.

Hyprland keeps three- and four-finger swipe movement to itself, so Mission
Control can't make its row of workspace cards follow the fingers. While
Mission Control is open (connected to the socket), this runs `libinput
debug-events` (as root, from the omarchy-mission-control-swipe system service),
keeps only swipe events with three or more fingers and passes on nothing else:
lines "b <fingers>", "u <dx> <dy>" and "e" on the socket
/run/omarchy-mission-control/swipe.sock. Only the account that installed the
helper (ALLOWED_UID, set in the service unit by install.sh) may connect; every
other local account is turned away. Key presses are never relayed (libinput
hides key codes by default, and every line that isn't a swipe is dropped). It
reads no input at all while Mission Control is closed.
"""
import os
import re
import selectors
import socket
import struct
import subprocess
import sys

SOCK_DIR = "/run/omarchy-mission-control"
SOCK_PATH = SOCK_DIR + "/swipe.sock"
MIN_FINGERS = 3


def allowed_uid():
    """The one account that may listen, or None (then nobody may)."""
    try:
        uid = int(os.environ.get("ALLOWED_UID", ""))
    except ValueError:
        return None
    return uid if uid > 0 else None


def peer_uid(conn):
    """The account on the other end of a Unix socket connection."""
    creds = conn.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, struct.calcsize("3i"))
    return struct.unpack("3i", creds)[1]

# " event8   GESTURE_SWIPE_UPDATE         +0.049s\t3 -5.27/ 0.29 (-5.27/ 0.29 unaccelerated)"
# " event8   GESTURE_SWIPE_UPDATE      2  +0.056s\t3 -71.58/13.67 (...)"  (repeats are counted)
SWIPE = re.compile(
    r"\bGESTURE_SWIPE_(BEGIN|UPDATE|END)\s+(?:\d+\s+)?\+?[\d.]+s\s+(\d+)"
    r"(?:\s+(-?[\d.]+)\s*/\s*(-?[\d.]+))?")


def main():
    os.makedirs(SOCK_DIR, exist_ok=True)
    try:
        os.unlink(SOCK_PATH)
    except FileNotFoundError:
        pass
    server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    server.bind(SOCK_PATH)
    os.chmod(SOCK_PATH, 0o666)
    server.listen(8)
    server.setblocking(False)

    sel = selectors.DefaultSelector()
    sel.register(server, selectors.EVENT_READ, "accept")
    clients = []
    owner = allowed_uid()
    state = {"proc": None, "fd": None, "pending": b"", "active": False}

    # libinput only runs while someone is listening (Mission Control is open),
    # so nothing reads the input devices the rest of the time.
    def start():
        # stdbuf: libinput would otherwise hold its lines back and write them
        # in large batches when its output goes to a pipe.
        proc = subprocess.Popen(["stdbuf", "-oL", "libinput", "debug-events"], stdout=subprocess.PIPE,
                                stderr=subprocess.DEVNULL, bufsize=0)
        os.set_blocking(proc.stdout.fileno(), False)
        sel.register(proc.stdout, selectors.EVENT_READ, "libinput")
        state.update(proc=proc, fd=proc.stdout.fileno(), pending=b"", active=False)

    def stop():
        proc = state["proc"]
        if proc is None:
            return
        try:
            sel.unregister(proc.stdout)
        except (KeyError, ValueError):
            pass
        proc.terminate()
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        proc.stdout.close()
        state.update(proc=None, fd=None, pending=b"", active=False)

    def drop(c):
        if c in clients:
            clients.remove(c)
        try:
            sel.unregister(c)
        except (KeyError, ValueError):
            pass
        c.close()
        if not clients:
            stop()

    def send(msg):
        data = (msg + "\n").encode()
        for c in clients[:]:
            try:
                c.sendall(data)
            except OSError:
                drop(c)

    while True:
        for key, _ in sel.select():
            if key.data == "accept":
                try:
                    conn, _ = server.accept()
                except OSError:
                    continue
                # Only the installing account gets swipe movement.
                try:
                    ok = owner is not None and peer_uid(conn) == owner
                except OSError:
                    ok = False
                if not ok:
                    conn.close()
                    continue
                conn.settimeout(0.2)
                clients.append(conn)
                sel.register(conn, selectors.EVENT_READ, "client")
                if state["proc"] is None:
                    start()
                continue
            if key.data == "client":
                # Clients never send anything: readable means it hung up.
                try:
                    gone = not key.fileobj.recv(64)
                except OSError:
                    gone = True
                if gone:
                    drop(key.fileobj)
                continue
            if state["proc"] is None or key.fileobj is not state["proc"].stdout:
                continue
            # Read everything waiting, then handle every complete line.
            try:
                chunk = os.read(state["fd"], 65536)
            except BlockingIOError:
                continue
            if not chunk:
                return 1  # libinput stopped: let systemd restart us
            *lines, state["pending"] = (state["pending"] + chunk).split(b"\n")
            for raw in lines:
                if b"GESTURE_SWIPE_" not in raw:
                    continue
                m = SWIPE.search(raw.decode(errors="replace"))
                if not m:
                    continue
                kind, fingers = m.group(1), int(m.group(2))
                if kind == "BEGIN":
                    state["active"] = fingers >= MIN_FINGERS
                    if state["active"]:
                        send(f"b {fingers}")
                elif kind == "UPDATE" and state["active"] and m.group(3) is not None:
                    send(f"u {float(m.group(3)):.3f} {float(m.group(4)):.3f}")
                elif kind == "END" and state["active"]:
                    state["active"] = False
                    send("e")

if __name__ == "__main__":
    sys.exit(main())
