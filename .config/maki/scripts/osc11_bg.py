#!/usr/bin/env python3
"""Print "light" or "dark" from the terminal background color (OSC 11).

Called by maki's init.lua at startup. jobstart children are setsid'd, so
there is no controlling terminal and stdin is /dev/null: find maki's pty
by walking /proc/<ancestor>/fd/0.

Exit 1 with a reason on stderr when the background cannot be determined.
"""
import os
import re
import select
import sys
import termios
import tty


def open_tty():
    try:
        return os.open("/dev/tty", os.O_RDWR)
    except OSError:
        pass
    pid = os.getppid()
    for _ in range(5):
        try:
            target = os.readlink(f"/proc/{pid}/fd/0")
        except OSError:
            break
        if target.startswith("/dev/pts/") or target.startswith("/dev/tty"):
            return os.open(target, os.O_RDWR)
        try:
            with open(f"/proc/{pid}/stat") as f:
                pid = int(f.read().split(") ", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            break
    raise OSError("no tty in ancestor chain")


def query_osc11(fd, timeout=0.3):
    old = termios.tcgetattr(fd)
    try:
        tty.setraw(fd)
        os.write(fd, b"\x1b]11;?\x1b\\")
        data = b""
        steps = int(timeout / 0.02)
        while steps > 0:
            r, _, _ = select.select([fd], [], [], 0.02)
            if not r:
                steps -= 1
                continue
            chunk = os.read(fd, 256)
            if not chunk:
                break
            data += chunk
            if b"\x1b\\" in data or b"\x07" in data:
                break
        return data
    finally:
        termios.tcsetattr(fd, termios.TCSAFLUSH, old)


fd = open_tty()
try:
    lflag = termios.tcgetattr(fd)[3]
    if not (lflag & termios.ICANON) and not (lflag & termios.ECHO):
        # A live TUI already owns this tty in raw mode (e.g. /reload):
        # querying would race its input loop, so skip and keep the theme.
        print("skip")
        sys.exit(0)
    resp = query_osc11(fd)
finally:
    os.close(fd)

m = re.search(rb"\x1b\]11;rgb:([0-9a-fA-F]+)/([0-9a-fA-F]+)/([0-9a-fA-F]+)", resp)
if not m:
    sys.stderr.write("no OSC 11 response: %r\n" % resp)
    sys.exit(1)
r, g, b = (int(v, 16) / 65535.0 for v in m.groups())
luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
print("light" if luminance > 0.5 else "dark")
