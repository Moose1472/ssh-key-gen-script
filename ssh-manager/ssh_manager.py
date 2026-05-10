#!/usr/bin/env python3
"""
jump — Personal SSH connection manager
Usage: python ssh_manager.py [command] [args]
       python ssh_manager.py          (interactive menu)
"""

import os
import sys
import json
import subprocess
import socket
import argparse
import shutil
from pathlib import Path
from datetime import datetime

CONFIG_DIR = Path.home() / ".ssh_manager"
DEVICES_FILE = CONFIG_DIR / "devices.json"
APP_NAME = "jump"
VERSION = "1.0.0"

# ── ANSI colors (works on Windows 10+ with VT processing enabled) ──────────
if sys.platform == "win32":
    os.system("")  # enable VT100 on Windows console

R = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
MAGENTA = "\033[95m"
CYAN = "\033[96m"
WHITE = "\033[97m"

def c(color, text):
    return f"{color}{text}{R}"

# ── Storage ─────────────────────────────────────────────────────────────────
def load_devices():
    if DEVICES_FILE.exists():
        with open(DEVICES_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    return {}

def save_devices(devices):
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    with open(DEVICES_FILE, "w", encoding="utf-8") as f:
        json.dump(devices, f, indent=2)

# ── Formatting helpers ───────────────────────────────────────────────────────
def banner():
    print(f"""
{BOLD}{CYAN}  ╔══════════════════════════════╗
  ║  ✈  jump  —  ssh manager   ║
  ╚══════════════════════════════╝{R}  {DIM}v{VERSION}{R}
""")

def divider(label=""):
    width = 54
    if label:
        pad = (width - len(label) - 2) // 2
        print(f"{DIM}{'─' * pad} {label} {'─' * (width - pad - len(label) - 2)}{R}")
    else:
        print(f"{DIM}{'─' * width}{R}")

def ok(msg):   print(f"  {GREEN}✓{R}  {msg}")
def warn(msg): print(f"  {YELLOW}⚠{R}  {msg}")
def err(msg):  print(f"  {RED}✗{R}  {msg}")
def info(msg): print(f"  {CYAN}→{R}  {msg}")

def prompt(label, default=None, secret=False):
    hint = f" [{DIM}{default}{R}]" if default else ""
    try:
        if secret:
            import getpass
            val = getpass.getpass(f"  {BOLD}{label}{hint}: ")
        else:
            val = input(f"  {BOLD}{label}{hint}: ").strip()
        return val if val else default
    except (KeyboardInterrupt, EOFError):
        print()
        return default

def device_tag(d):
    tag = f"{d.get('user', '')}@{d['host']}"
    if d.get('port', 22) != 22:
        tag += f":{d['port']}"
    return tag

# ── Device table ─────────────────────────────────────────────────────────────
def print_table(devices):
    if not devices:
        warn("No devices saved yet. Run  add  to add one.")
        return

    col_name  = max(len("NAME"),  max(len(n) for n in devices))
    col_host  = max(len("HOST/IP"), max(len(d['host']) for d in devices.values()))
    col_user  = max(len("USER"),  max(len(d.get('user','')) for d in devices.values()))
    col_port  = 5
    col_group = max(len("GROUP"), max(len(d.get('group','—')) for d in devices.values()))

    hdr = (f"  {BOLD}{CYAN}{'NAME':<{col_name}}{R}  "
           f"{BOLD}{'HOST/IP':<{col_host}}{R}  "
           f"{BOLD}{'USER':<{col_user}}{R}  "
           f"{BOLD}{'PORT':<{col_port}}{R}  "
           f"{BOLD}{'GROUP':<{col_group}}{R}  "
           f"{BOLD}NOTES{R}")
    print(hdr)
    divider()

    for name, d in sorted(devices.items()):
        online_sym = ""
        port   = d.get('port', 22)
        group  = d.get('group', '—')
        notes  = d.get('notes', '')
        user   = d.get('user', '')
        host_str = c(YELLOW, f"{d['host']:<{col_host}}")
        port_str = c(DIM, str(port))
        print(f"  {c(BOLD+GREEN, f'{name:<{col_name}}')}  "
              f"{host_str}  "
              f"{user:<{col_user}}  "
              f"{port_str:<{col_port + len(DIM) + len(R)}}  "
              f"{group:<{col_group}}  "
              f"{c(DIM, notes)}")
    divider()
    print(f"  {DIM}{len(devices)} device(s){R}\n")

# ── Commands ─────────────────────────────────────────────────────────────────
def cmd_list(devices, _args=None):
    banner()
    divider("saved devices")
    print_table(devices)

def cmd_add(devices, args=None):
    print(f"\n{BOLD}  Add a new device{R}\n")
    # Name
    name = None
    while not name:
        name = prompt("Alias (short name)", "").strip()
        if not name:
            err("Alias cannot be empty.")
        elif name in devices:
            err(f"'{name}' already exists. Use  edit  to update it.")
            name = None

    host    = prompt("Hostname or IP")
    user    = prompt("SSH username", os.environ.get("USERNAME") or os.environ.get("USER") or "")
    port    = prompt("Port", "22")
    key     = prompt("Identity file (path to .pem/.key, leave blank for default)", "")
    group   = prompt("Group / tag", "")
    notes   = prompt("Notes", "")

    try:
        port = int(port)
    except (ValueError, TypeError):
        port = 22

    device = {
        "host":    host,
        "user":    user,
        "port":    port,
        "added":   datetime.now().isoformat(timespec="seconds"),
    }
    if key:    device["identity"] = key
    if group:  device["group"]    = group
    if notes:  device["notes"]    = notes

    devices[name] = device
    save_devices(devices)
    ok(f"Saved  {c(BOLD, name)}  →  {device_tag(device)}\n")

def cmd_connect(devices, args):
    name = args.name if hasattr(args, 'name') else args
    if name not in devices:
        err(f"Unknown device '{name}'. Run  list  to see saved devices.")
        return
    d = devices[name]
    _connect(name, d)

def _connect(name, d):
    host  = d["host"]
    user  = d.get("user", "")
    port  = d.get("port", 22)
    key   = d.get("identity", "")

    cmd = ["ssh"]
    if port != 22:
        cmd += ["-p", str(port)]
    if key:
        cmd += ["-i", key]
    if user:
        cmd.append(f"{user}@{host}")
    else:
        cmd.append(host)

    info(f"Connecting to {c(BOLD, name)}  ({' '.join(cmd)})\n")

    # Update last_used
    devices_live = load_devices()
    if name in devices_live:
        devices_live[name]["last_used"] = datetime.now().isoformat(timespec="seconds")
        save_devices(devices_live)

    try:
        subprocess.run(cmd)
    except FileNotFoundError:
        err("'ssh' not found. Make sure OpenSSH is installed and in your PATH.")
    except KeyboardInterrupt:
        print()
        info("Session ended.")

def cmd_remove(devices, args):
    name = args.name if hasattr(args, 'name') else args
    if name not in devices:
        err(f"No device named '{name}'.")
        return
    confirm = prompt(f"Delete '{name}'? (yes/no)", "no")
    if confirm.lower() in ("y", "yes"):
        del devices[name]
        save_devices(devices)
        ok(f"Removed '{name}'.")
    else:
        info("Cancelled.")

def cmd_edit(devices, args):
    name = args.name if hasattr(args, 'name') else args
    if name not in devices:
        err(f"No device named '{name}'.")
        return
    d = devices[name]
    print(f"\n{BOLD}  Editing '{name}'  {DIM}(press Enter to keep current value){R}\n")
    d["host"]  = prompt("Hostname or IP",    d.get("host", "")) or d["host"]
    d["user"]  = prompt("Username",          d.get("user", "")) or d.get("user", "")
    d["port"]  = int(prompt("Port",          str(d.get("port", 22))) or 22)
    d["identity"] = prompt("Identity file",  d.get("identity", ""))
    d["group"]    = prompt("Group",          d.get("group", ""))
    d["notes"]    = prompt("Notes",          d.get("notes", ""))
    # strip empty optional fields
    for k in ("identity", "group", "notes"):
        if not d.get(k):
            d.pop(k, None)
    devices[name] = d
    save_devices(devices)
    ok(f"Updated '{name}'.\n")

def cmd_ping(devices, args):
    name = args.name if hasattr(args, 'name') else args
    if name not in devices:
        err(f"No device named '{name}'.")
        return
    d = devices[name]
    host = d["host"]
    port = d.get("port", 22)
    info(f"Checking {host}:{port} …")
    try:
        with socket.create_connection((host, port), timeout=5):
            ok(f"{host}:{port} is {c(GREEN, 'reachable')} (SSH port open)\n")
    except (socket.timeout, ConnectionRefusedError, OSError) as e:
        err(f"{host}:{port} is {c(RED, 'unreachable')} — {e}\n")

def cmd_copy_id(devices, args):
    name = args.name if hasattr(args, 'name') else args
    if name not in devices:
        err(f"No device named '{name}'.")
        return
    d = devices[name]
    pub_key = prompt("Path to public key", str(Path.home() / ".ssh" / "id_rsa.pub"))
    cmd = ["ssh-copy-id"]
    port = d.get("port", 22)
    if port != 22:
        cmd += ["-p", str(port)]
    if d.get("identity"):
        cmd += ["-i", d["identity"]]
    user = d.get("user", "")
    host = d["host"]
    cmd.append(f"{user}@{host}" if user else host)
    info(f"Running: {' '.join(cmd)}")
    try:
        subprocess.run(cmd)
    except FileNotFoundError:
        err("'ssh-copy-id' not found. On Windows, copy the key manually.")

def cmd_export(devices, args=None):
    out = Path(prompt("Export to file", "jump_devices.json"))
    with open(out, "w", encoding="utf-8") as f:
        json.dump(devices, f, indent=2)
    ok(f"Exported {len(devices)} device(s) to {out}\n")

def cmd_import(devices, args=None):
    src = Path(prompt("Import from file", "jump_devices.json"))
    if not src.exists():
        err(f"File not found: {src}")
        return
    with open(src, "r", encoding="utf-8") as f:
        incoming = json.load(f)
    merged = 0
    for name, d in incoming.items():
        if name in devices:
            overwrite = prompt(f"'{name}' exists — overwrite? (yes/no)", "no")
            if overwrite.lower() not in ("y", "yes"):
                continue
        devices[name] = d
        merged += 1
    save_devices(devices)
    ok(f"Imported {merged} device(s).\n")

# ── Interactive menu ──────────────────────────────────────────────────────────
def interactive_menu():
    devices = load_devices()
    banner()
    while True:
        divider("saved devices")
        print_table(devices)
        divider("actions")
        actions = [
            ("c", "connect",     "SSH into a device"),
            ("a", "add",         "Add new device"),
            ("e", "edit",        "Edit a device"),
            ("r", "remove",      "Remove a device"),
            ("p", "ping",        "Ping (check reachability)"),
            ("k", "copy-id",     "Copy SSH key to device"),
            ("x", "export",      "Export devices to JSON"),
            ("i", "import",      "Import devices from JSON"),
            ("q", "quit",        "Exit"),
        ]
        for key, name, desc in actions:
            print(f"  {c(BOLD+CYAN, f'[{key}]')}  {c(BOLD, name):<10}  {c(DIM, desc)}")
        print()

        try:
            choice = input(f"  {BOLD}>{R} ").strip().lower()
        except (KeyboardInterrupt, EOFError):
            print()
            break

        print()

        if choice in ("q", "quit", "exit"):
            info("Bye!\n")
            break

        elif choice in ("c", "connect"):
            if not devices:
                warn("No devices. Add one first.")
                continue
            names = sorted(devices)
            for i, n in enumerate(names, 1):
                print(f"  {c(CYAN, str(i)+'.')} {n}  {c(DIM, device_tag(devices[n]))}")
            print()
            sel = prompt("Device name or number")
            if not sel:
                continue
            if sel.isdigit():
                idx = int(sel) - 1
                if 0 <= idx < len(names):
                    sel = names[idx]
                else:
                    err("Invalid number.")
                    continue
            if sel in devices:
                _connect(sel, devices[sel])
                devices = load_devices()  # refresh after session
            else:
                err(f"No device '{sel}'.")

        elif choice in ("a", "add"):
            cmd_add(devices)

        elif choice in ("e", "edit"):
            name = prompt("Device name to edit")
            if name:
                cmd_edit(devices, name)
                devices = load_devices()

        elif choice in ("r", "remove"):
            name = prompt("Device name to remove")
            if name:
                cmd_remove(devices, name)
                devices = load_devices()

        elif choice in ("p", "ping"):
            name = prompt("Device name to ping")
            if name:
                cmd_ping(devices, name)

        elif choice in ("k", "copy-id"):
            name = prompt("Device name")
            if name:
                cmd_copy_id(devices, name)

        elif choice in ("x", "export"):
            cmd_export(devices)

        elif choice in ("i", "import"):
            cmd_import(devices)
            devices = load_devices()

        else:
            warn(f"Unknown command '{choice}'.")

# ── CLI entry point ───────────────────────────────────────────────────────────
def main():
    parser = argparse.ArgumentParser(
        prog=APP_NAME,
        description="jump — personal SSH connection manager",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
commands:
  list                     list all saved devices
  add                      add a new device (interactive)
  connect <name>           SSH into a device
  remove  <name>           delete a saved device
  edit    <name>           edit a device's settings
  ping    <name>           check if SSH port is reachable
  copy-id <name>           copy your public key to a device
  export                   export devices to JSON
  import                   import devices from JSON

  (no command)             launch interactive menu
        """,
    )
    parser.add_argument("--version", action="version", version=f"{APP_NAME} {VERSION}")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("list")
    sub.add_parser("add")

    for cmd in ("connect", "remove", "edit", "ping", "copy-id"):
        p = sub.add_parser(cmd)
        p.add_argument("name")

    sub.add_parser("export")
    sub.add_parser("import")

    args = parser.parse_args()
    devices = load_devices()

    if args.command is None:
        interactive_menu()
    elif args.command == "list":
        cmd_list(devices)
    elif args.command == "add":
        cmd_add(devices)
    elif args.command == "connect":
        cmd_connect(devices, args)
    elif args.command == "remove":
        cmd_remove(devices, args)
    elif args.command == "edit":
        cmd_edit(devices, args)
    elif args.command == "ping":
        cmd_ping(devices, args)
    elif args.command == "copy-id":
        cmd_copy_id(devices, args)
    elif args.command == "export":
        cmd_export(devices)
    elif args.command == "import":
        cmd_import(devices)


if __name__ == "__main__":
    main()
