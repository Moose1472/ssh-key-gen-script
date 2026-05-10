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
ssh-copy-id -i "$key.pub" -p "$port" "$ruser@$rhost"
if [ $? -ne 0 ]; then
    echo -e "\nERROR: Could not reach $rhost on port $port. Is SSH running on the remote machine?"
    rm -rf "$dir"
    exit 1
fi

# --- Windows-specific fix ---
if [[ "${is_win,,}" == "y" ]]; then
    echo -e "\n--- Applying Windows SSH fix ---"
    PS_CMD='$c=Get-Content "C:\ProgramData\ssh\sshd_config"; $c=$c -replace "^Match Group administrators","#Match Group administrators" -replace "^(\s+AuthorizedKeysFile __PROGRAMDATA__\S*)","#`$1"; Set-Content "C:\ProgramData\ssh\sshd_config" $c; $d="$env:USERPROFILE\.ssh"; if(!(Test-Path $d)){New-Item -ItemType Directory -Force $d|Out-Null}; $f="$d\authorized_keys"; if(!(Test-Path $f)){New-Item -ItemType File -Force $f|Out-Null}'
    ENC=$(printf '%s' "$PS_CMD" | iconv -t UTF-16LE | base64 | tr -d '\n')
    ssh -p "$port" "$ruser@$rhost" "powershell -EncodedCommand $ENC && cmd /c start /b powershell -Command \"Start-Sleep 3; Restart-Service sshd\""
    echo "Waiting for SSH service to restart..."
    sleep 8
fi

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
