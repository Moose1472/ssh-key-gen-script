#!/usr/bin/env bash
read -rp "Key name: " name
dir="$HOME/.ssh/keys/$name"
key="$dir/${name}id_ed25519"

mkdir -p -m 700 "$dir"
ssh-keygen -t ed25519 -f "$key" -C "$USER@$(hostname)" -N ""

echo -e "\nPublic key (paste into ~/.ssh/authorized_keys on target machine):"
cat "${key}.pub"
