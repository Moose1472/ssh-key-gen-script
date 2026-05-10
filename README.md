# Scripts

Personal collection of scripts and tools. Hosted publicly so they can be pulled and run from any machine with an internet connection.

---

## Table of Contents

- [SSH Key Generator](#ssh-key-generator)
  - [Run It](#run-it)
  - [What It Does](#what-it-does)
  - [Where Keys Are Stored](#where-keys-are-stored)
  - [Adding Your Key to a Remote Machine](#adding-your-key-to-a-remote-machine)

---

## SSH Key Generator

Generates an `ed25519` SSH key pair, automatically named and organized by whatever name you provide. No passphrase — keys are ready to use immediately.

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

### What It Does

1. Asks you for a key name (e.g. `LarsonBOSS`)
2. Creates the directory automatically if it doesn't exist
3. Generates a private key and a public key
4. Prints the public key so you can copy it to your target machine

---

### Where Keys Are Stored

| OS | Path |
|---|---|
| Windows | `C:\Users\[you]\.ssh\keys\[name]\[name]id_ed25519` |
| Linux | `/home/[you]/.ssh/keys/[name]/[name]id_ed25519` |
| macOS | `/Users/[you]/.ssh/keys/[name]/[name]id_ed25519` |

**Example** — if your username is `grayl` and you named the key `LarsonBOSS`:
```
C:\Users\grayl\.ssh\keys\LarsonBOSS\LarsonBOSSid_ed25519
C:\Users\grayl\.ssh\keys\LarsonBOSS\LarsonBOSSid_ed25519.pub
```

---

### Adding Your Key to a Remote Machine

After running the script, your public key is printed on screen. To allow passwordless SSH into a remote machine, copy that public key line and add it to the remote machine's authorized keys file.

**On the remote machine, run:**
```bash
echo "paste-your-public-key-here" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Or use `ssh-copy-id` if available:**
```bash
ssh-copy-id -i ~/.ssh/keys/[name]/[name]id_ed25519.pub user@remote-ip
```

Once added, you can SSH in without a password:
```bash
ssh -i ~/.ssh/keys/[name]/[name]id_ed25519 user@remote-ip
```
