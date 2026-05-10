#!/usr/bin/env bash
read -rp "Key name: " name
read -rp "Remote machine IP or hostname: " rhost
read -rp "Username on remote machine: " ruser
read -rp "SSH port (press Enter for 22): " port
port=${port:-22}
read -rp "Is the remote machine Windows? (y/N): " is_win
read -rp "SSH config nickname (press Enter to use key name): " nick
nick=${nick:-$name}

# --- Generate key pair ---
dir="$HOME/.ssh/keys/$name"
key="$dir/${name}id_ed25519"
mkdir -p -m 700 "$dir"

echo -e "\n--- Generating key pair ---"
ssh-keygen -t ed25519 -f "$key" -C "$USER@$(hostname)" -N ""

# --- Push public key to remote machine ---
echo -e "\n--- Pushing public key (enter remote password when prompted) ---"

case "$is_win" in
    [Yy]*)
        # Windows: SCP the key, then use PowerShell to install it
        scp -P "$port" "$key.pub" "$ruser@$rhost:temp_key.pub"
        if [ $? -ne 0 ]; then
            echo -e "\nERROR: Could not reach $rhost on port $port. Is SSH running on the remote machine?"
            rm -rf "$dir"
            exit 1
        fi

        # Write key to both standard and admin locations — no restart needed
        PS_CMD='
$tempKey   = "$env:USERPROFILE\temp_key.pub"
$sshDir    = "$env:USERPROFILE\.ssh"
$authKeys  = "$sshDir\authorized_keys"
$adminKeys = "C:\ProgramData\ssh\administrators_authorized_keys"

New-Item -Force -ItemType Directory $sshDir | Out-Null
if (!(Test-Path $authKeys))  { New-Item -Force -ItemType File $authKeys  | Out-Null }
if (!(Test-Path $adminKeys)) { New-Item -Force -ItemType File $adminKeys | Out-Null }

Get-Content $tempKey | Add-Content $authKeys
Get-Content $tempKey | Add-Content $adminKeys

$acl = New-Object System.Security.AccessControl.FileSecurity
$acl.SetAccessRuleProtection($true, $false)
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("Administrators","FullControl","Allow")))
$acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule("SYSTEM","FullControl","Allow")))
Set-Acl $adminKeys $acl

$c = Get-Content "C:\ProgramData\ssh\sshd_config"
$c = $c -replace "^Match Group administrators","#Match Group administrators" -replace "^(\s+AuthorizedKeysFile __PROGRAMDATA__\S*)","#`$1"
Set-Content "C:\ProgramData\ssh\sshd_config" $c

Remove-Item $tempKey
'
        ENC=$(printf '%s' "$PS_CMD" | iconv -t UTF-16LE | base64 | tr -d '\n')
        echo "Installing key and applying Windows SSH fix..."
        ssh -p "$port" "$ruser@$rhost" "powershell -EncodedCommand $ENC"
        ;;
    *)
        # Linux/macOS: standard ssh-copy-id
        ssh-copy-id -i "$key.pub" -p "$port" "$ruser@$rhost"
        if [ $? -ne 0 ]; then
            echo -e "\nERROR: Could not reach $rhost on port $port. Is SSH running on the remote machine?"
            rm -rf "$dir"
            exit 1
        fi
        ;;
esac

# --- Add SSH config entry ---
echo -e "\n--- Adding SSH config entry ---"
config="$HOME/.ssh/config"
touch "$config" && chmod 600 "$config"
printf "\nHost %s\n    HostName %s\n    User %s\n    Port %s\n    IdentityFile %s\n" \
    "$nick" "$rhost" "$ruser" "$port" "$key" >> "$config"
echo "Entry added for '$nick'."

# --- Test connection ---
echo -e "\n--- Testing connection ---"
ssh "$nick" "echo 'Connection successful!'"

echo -e "\nDone! Connect anytime with: ssh $nick"
