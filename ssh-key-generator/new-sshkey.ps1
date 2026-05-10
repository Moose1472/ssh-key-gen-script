$name  = Read-Host "Key name"
$rhost = Read-Host "Remote machine IP or hostname"
$ruser = Read-Host "Username on remote machine"
$port  = Read-Host "SSH port (press Enter for 22)"
if (-not $port) { $port = "22" }
$nick  = Read-Host "SSH config nickname (press Enter to use key name)"
if (-not $nick) { $nick = $name }

# --- Generate key pair ---
$dir     = Join-Path $HOME ".ssh/keys/$name"
$key     = Join-Path $dir "${name}id_ed25519"
$comment = "$([System.Environment]::UserName)@$(hostname)"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Write-Host "`n--- Generating key pair ---"
if ($env:OS -eq 'Windows_NT') {
    cmd /c "ssh-keygen -t ed25519 -f `"$key`" -C `"$comment`" -N `"`""
} else {
    ssh-keygen -t ed25519 -f "$key" -C "$comment" -N ""
}

# --- Push public key to remote machine ---
Write-Host "`n--- Pushing public key (enter remote password when prompted) ---"
$pubkey = (Get-Content "$key.pub").Trim()
ssh -p $port "${ruser}@${rhost}" "mkdir -p ~/.ssh && echo `"$pubkey`" >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"

# --- Add SSH config entry ---
Write-Host "`n--- Adding SSH config entry ---"
$configPath = Join-Path $HOME ".ssh/config"
if (-not (Test-Path $configPath)) { New-Item -ItemType File -Force -Path $configPath | Out-Null }
$keyFwd = $key -replace '\\', '/'
Add-Content $configPath "`nHost $nick`n    HostName $rhost`n    User $ruser`n    Port $port`n    IdentityFile $keyFwd"
Write-Host "Entry added for '$nick'."

# --- Test connection ---
Write-Host "`n--- Testing connection ---"
ssh $nick "echo 'Connection successful!'"

Write-Host "`nDone! Connect anytime with: ssh $nick"
