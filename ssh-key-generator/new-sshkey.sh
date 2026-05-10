#!/usr/bin/env bash
read -rp "Key name: " name
read -rp "Remote machine IP or hostname: " rhost
read -rp "Username on remote machine: " ruser
read -rp "SSH port (press Enter for 22): " port
port=${port:-22}
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
