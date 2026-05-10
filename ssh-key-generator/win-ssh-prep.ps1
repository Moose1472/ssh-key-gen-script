# Self-elevate to admin if not already
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm https://graysden.com/win-ssh-prep.ps1 | iex`"" -Wait
    exit
}

# --- Install OpenSSH Server if missing ---
Write-Host "`n--- Checking OpenSSH Server ---"
if (-not (Get-Service -Name sshd -ErrorAction SilentlyContinue)) {
    Write-Host "Installing OpenSSH Server (this may take a few minutes)..."
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
} else {
    Write-Host "OpenSSH Server already installed."
}

# --- Start and enable sshd ---
Write-Host "`n--- Starting SSH service ---"
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
Write-Host "SSH service running and set to start automatically."

# --- Fix authorized_keys location for admin accounts ---
Write-Host "`n--- Fixing SSH config for key-based auth ---"
$config  = "C:\ProgramData\ssh\sshd_config"
$content = Get-Content $config
$content = $content -replace "^Match Group administrators",      "#Match Group administrators"
$content = $content -replace "^(\s+AuthorizedKeysFile __PROGRAMDATA__.*)", "#`$1"
Set-Content $config $content
Restart-Service sshd
Write-Host "SSH config updated."

# --- Create .ssh and authorized_keys if missing ---
Write-Host "`n--- Checking SSH directory ---"
$sshDir  = Join-Path $HOME ".ssh"
$authKeys = Join-Path $sshDir "authorized_keys"
if (-not (Test-Path $sshDir))     { New-Item -ItemType Directory -Force -Path $sshDir   | Out-Null }
if (-not (Test-Path $authKeys))   { New-Item -ItemType File      -Force -Path $authKeys | Out-Null }
Write-Host "SSH directory ready."

# --- Done ---
Write-Host "`n--- This machine is ready to accept SSH keys ---"
Write-Host "Use one of these IPs when running the key generator from another machine:"
ipconfig | findstr /i "IPv4"
Write-Host ""
