$name    = Read-Host "Key name"
$dir     = Join-Path $HOME ".ssh/keys/$name"
$key     = Join-Path $dir "${name}id_ed25519"
$comment = "$([System.Environment]::UserName)@$(hostname)"

New-Item -ItemType Directory -Force -Path $dir | Out-Null

if ($env:OS -eq 'Windows_NT') {
    cmd /c "ssh-keygen -t ed25519 -f `"$key`" -C `"$comment`" -N `"`""
} else {
    ssh-keygen -t ed25519 -f "$key" -C $comment -N ""
}

Write-Host "`nPublic key (paste into ~/.ssh/authorized_keys on target machine):"
Get-Content "$key.pub"
