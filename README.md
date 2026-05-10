# Scripts

Personal collection of scripts and tools. Hosted publicly so they can be pulled and run from any machine with an internet connection.

---

## Table of Contents

- [SSH Key Generator](#ssh-key-generator)
  - [Run It](#run-it)
  - [What It Asks](#what-it-asks)
  - [What It Does](#what-it-does)
  - [Where Keys Are Stored](#where-keys-are-stored)
  - [Connecting After Setup](#connecting-after-setup)
- [Windows SSH Prep](#windows-ssh-prep)

---

## SSH Key Generator

Fully automated SSH key setup. Generates a key pair, pushes it to the remote machine, adds an SSH config entry, and tests the connection — all in one run. After setup, connecting is as simple as `ssh NickName`.

### Run It

**Windows — PowerShell:**
```powershell
irm https://graysden.com/ssh-key-gen.ps1 | iex
```

**Linux / macOS — Bash:**
```bash
bash <(curl -sS https://graysden.com/ssh-key-gen.sh)
```

> No files need to be downloaded manually. As long as the machine has internet, the command above is all you need.

---

### What It Asks

| Prompt | Example | Notes |
|---|---|---|
| Key name | `HomeServer` | Names the key files and folder |
| Remote IP or hostname | `192.168.1.100` | The machine you want to connect to |
| Username on remote machine | `john` | Your username on that machine |
| SSH port | `22` | Press Enter to use the default (22) |
| Is the remote machine Windows? | `y` / `N` | Applies an automatic fix for Windows SSH key auth |
| SSH config nickname | `home` | What you'll type to connect — press Enter to use the key name |

---

### What It Does

1. Generates a passwordless `ed25519` key pair
2. Pushes the public key to the remote machine *(you'll enter the remote password once — never again)*
3. If the remote machine is Windows, automatically installs the key in the correct locations and fixes the SSH config — no restart required
4. Adds an entry to your SSH config
5. Tests the connection to confirm everything works

---

### Where Keys Are Stored

| OS | Path |
|---|---|
| Windows | `C:\Users\[you]\.ssh\keys\[name]\[name]id_ed25519` |
| Linux | `/home/[you]/.ssh/keys/[name]/[name]id_ed25519` |
| macOS | `/Users/[you]/.ssh/keys/[name]/[name]id_ed25519` |

**Example** — username `john`, key named `HomeServer`:
```
C:\Users\john\.ssh\keys\HomeServer\HomeServerid_ed25519
C:\Users\john\.ssh\keys\HomeServer\HomeServerid_ed25519.pub
```

---

### Connecting After Setup

Once the script finishes, connect to the machine anytime with just:

```bash
ssh NickName
```

No IP address, no username, no key path — the SSH config handles all of it automatically.

---

## Windows SSH Prep

If you need to manually prepare a Windows machine to accept SSH keys before running the key generator, run this on the Windows machine:

```powershell
irm https://graysden.com/win-ssh-prep.ps1 | iex
```

> This is optional — the key generator handles it automatically when you answer `y` to the Windows prompt.
