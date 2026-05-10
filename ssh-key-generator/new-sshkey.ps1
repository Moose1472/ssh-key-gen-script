$name   = Read-Host "Key name"
$rhost  = Read-Host "Remote machine IP or hostname"
$ruser  = Read-Host "Username on remote machine"
$port   = Read-Host "SSH port (press Enter for 22)"
if (-not $port) { $port = "22" }
$is_win = Read-Host "Is the remote machine Windows? (y/N)"
$nick   = Read-Host "SSH config nickname (press Enter to use key name)"
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
scp -P $port "$key.pub" "${ruser}@${rhost}:temp_key.pub"
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nERROR: Could not reach $rhost on port $port. Is SSH running on the remote machine?"
    Remove-Item -Recurse -Force $dir
    exit 1
}

if ($is_win -match "^[Yy]") {
    # Windows remote: write key to both auth locations, fix sshd_config — no restart needed
    Write-Host "`n--- Installing key and applying Windows SSH fix ---"
    $ps_cmd = '
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
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($ps_cmd)
    $enc   = [System.Convert]::ToBase64String($bytes)
    ssh -p $port "${ruser}@${rhost}" "powershell -EncodedCommand $enc"
} else {
    # Linux/macOS remote: run standard bash commands
    ssh -p $port "${ruser}@${rhost}" "mkdir -p ~/.ssh && cat ~/temp_key.pub >> ~/.ssh/authorized_keys && rm ~/temp_key.pub && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh"
}

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
