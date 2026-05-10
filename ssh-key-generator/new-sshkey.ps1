Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- Detect system theme ---
$reg  = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
$dark = ($reg.AppsUseLightTheme -eq 0)

$clrBg     = if ($dark) { [System.Drawing.Color]::FromArgb(30,  30,  30)  } else { [System.Drawing.Color]::FromArgb(243, 243, 243) }
$clrInput  = if ($dark) { [System.Drawing.Color]::FromArgb(51,  51,  55)  } else { [System.Drawing.Color]::White }
$clrOutput = if ($dark) { [System.Drawing.Color]::FromArgb(20,  20,  20)  } else { [System.Drawing.Color]::FromArgb(248, 248, 248) }
$clrText   = if ($dark) { [System.Drawing.Color]::White                    } else { [System.Drawing.Color]::FromArgb(32,  32,  32) }
$clrHint   = [System.Drawing.Color]::Gray
$clrBtn    = [System.Drawing.Color]::FromArgb(0, 120, 212)
$colGreen  = [System.Drawing.Color]::FromArgb(78,  201, 176)
$colRed    = [System.Drawing.Color]::FromArgb(244, 71,  71)
$colYellow = [System.Drawing.Color]::FromArgb(220, 200, 80)

try   { $monoFont = New-Object System.Drawing.Font("Cascadia Mono", 9) }
catch { $monoFont = New-Object System.Drawing.Font("Consolas", 9) }

# --- Form ---
$form                  = New-Object System.Windows.Forms.Form
$form.Text             = "SSH Key Generator"
$form.Size             = New-Object System.Drawing.Size(520, 680)
$form.StartPosition    = "CenterScreen"
$form.BackColor        = $clrBg
$form.FormBorderStyle  = "FixedSingle"
$form.MaximizeBox      = $false
$form.Font             = New-Object System.Drawing.Font("Segoe UI", 9)

# --- Helpers ---
function New-Label($text, $x, $y) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Location = New-Object System.Drawing.Point($x, $y)
    $l.AutoSize = $true; $l.ForeColor = $clrText
    $form.Controls.Add($l); return $l
}
function New-Field($x, $y, $w, $val = "") {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($x, $y)
    $t.Size = New-Object System.Drawing.Size($w, 26)
    $t.Text = $val; $t.BackColor = $clrInput; $t.ForeColor = $clrText
    $t.BorderStyle = "FixedSingle"
    $form.Controls.Add($t); return $t
}

$lx = 20; $ix = 190; $iw = 280

$y = 24
New-Label "Key Name:"             $lx $y | Out-Null; $txtName = New-Field $ix $y $iw
$y += 38
New-Label "Remote IP / Hostname:" $lx $y | Out-Null; $txtHost = New-Field $ix $y $iw
$y += 38
New-Label "Remote Username:"      $lx $y | Out-Null; $txtUser = New-Field $ix $y $iw
$y += 38
New-Label "SSH Port:"             $lx $y | Out-Null; $txtPort = New-Field $ix $y 60 "22"
$y += 38

$chkWin = New-Object System.Windows.Forms.CheckBox
$chkWin.Text = "Remote machine is Windows"
$chkWin.Location = New-Object System.Drawing.Point($ix, $y)
$chkWin.AutoSize = $true; $chkWin.ForeColor = $clrText; $chkWin.BackColor = $clrBg
$form.Controls.Add($chkWin)
$y += 38

New-Label "SSH Nickname:" $lx $y | Out-Null; $txtNick = New-Field $ix $y $iw
$hint = New-Object System.Windows.Forms.Label
$hint.Text = "(leave blank to use key name)"; $hint.ForeColor = $clrHint
$hint.Location = New-Object System.Drawing.Point($ix, ($y + 28))
$hint.AutoSize = $true
$hint.Font = New-Object System.Drawing.Font("Segoe UI", 8)
$form.Controls.Add($hint)
$y += 62

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Generate Key"
$btnRun.Location = New-Object System.Drawing.Point($lx, $y)
$btnRun.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 40), 38)
$btnRun.BackColor = $clrBtn; $btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.FlatStyle = "Flat"; $btnRun.FlatAppearance.BorderSize = 0
$btnRun.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnRun)
$y += 50

$txtOut = New-Object System.Windows.Forms.RichTextBox
$txtOut.Location = New-Object System.Drawing.Point($lx, $y)
$txtOut.Size = New-Object System.Drawing.Size(($form.ClientSize.Width - 40), ($form.ClientSize.Height - $y - 40))
$txtOut.BackColor = $clrOutput; $txtOut.ForeColor = $clrText
$txtOut.ReadOnly = $true; $txtOut.BorderStyle = "None"
$txtOut.Font = $monoFont; $txtOut.ScrollBars = "Vertical"
$form.Controls.Add($txtOut)

# --- Output helper ---
function Out($msg, $col = $null) {
    $txtOut.SelectionStart = $txtOut.TextLength; $txtOut.SelectionLength = 0
    $txtOut.SelectionColor = if ($col) { $col } else { $clrText }
    $txtOut.AppendText("$msg`n")
    $txtOut.ScrollToCaret()
    [System.Windows.Forms.Application]::DoEvents()
}

# --- Button logic ---
$btnRun.Add_Click({
    $name  = $txtName.Text.Trim()
    $rhost = $txtHost.Text.Trim()
    $ruser = $txtUser.Text.Trim()
    $port  = if ($txtPort.Text.Trim()) { $txtPort.Text.Trim() } else { "22" }
    $isWin = $chkWin.Checked
    $nick  = if ($txtNick.Text.Trim()) { $txtNick.Text.Trim() } else { $name }

    if (-not $name -or -not $rhost -or -not $ruser) {
        [System.Windows.Forms.MessageBox]::Show(
            "Please fill in Key Name, Remote IP, and Username.",
            "Missing Fields", "OK", "Warning") | Out-Null
        return
    }

    $btnRun.Enabled = $false
    $txtOut.Clear()

    $dir = Join-Path $HOME ".ssh/keys/$name"
    $key = Join-Path $dir "${name}id_ed25519"

    # Check for existing key
    if (Test-Path $key) {
        $res = [System.Windows.Forms.MessageBox]::Show(
            "A key named '$name' already exists. Overwrite it?",
            "Key Exists", "YesNo", "Question")
        if ($res -ne "Yes") { $btnRun.Enabled = $true; return }
        Remove-Item -Force "$key", "$key.pub" -ErrorAction SilentlyContinue
    }

    # --- Generate key pair ---
    Out "--- Generating key pair ---" $colYellow
    $comment = "$([System.Environment]::UserName)@$(hostname)"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    cmd /c "ssh-keygen -t ed25519 -f `"$key`" -C `"$comment`" -N `"`"" 2>&1 | Out-Null
    if (Test-Path $key) { Out "✓ Key pair created" $colGreen }
    else { Out "✗ Failed to generate key pair" $colRed; $btnRun.Enabled = $true; return }

    # --- Push public key ---
    Out ""; Out "--- Pushing public key ---" $colYellow
    Out "  Minimizing — enter your password in the console window..." $clrHint
    [System.Windows.Forms.Application]::DoEvents()
    $form.WindowState = "Minimized"
    scp -P $port "$key.pub" "${ruser}@${rhost}:temp_key.pub"
    $scpExit = $LASTEXITCODE
    $form.WindowState = "Normal"; $form.BringToFront()
    if ($scpExit -ne 0) {
        Out "✗ Could not reach $rhost — is SSH running on the remote machine?" $colRed
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        $btnRun.Enabled = $true; return
    }
    Out "✓ Key transferred to remote machine" $colGreen

    # --- Install key ---
    if ($isWin) {
        Out ""; Out "--- Applying Windows SSH fix ---" $colYellow
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
        ssh -p $port "${ruser}@${rhost}" "powershell -EncodedCommand $enc" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Out "✓ Key installed in authorized locations" $colGreen
            Out "✓ SSH config updated"                    $colGreen
        } else { Out "✗ Windows SSH fix encountered an error" $colRed }
    } else {
        Out ""; Out "--- Installing key ---" $colYellow
        ssh -p $port "${ruser}@${rhost}" "mkdir -p ~/.ssh && cat ~/temp_key.pub >> ~/.ssh/authorized_keys && rm ~/temp_key.pub && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Out "✓ Key installed in authorized_keys" $colGreen }
        else { Out "✗ Failed to install key on remote machine" $colRed }
    }

    # --- SSH config ---
    Out ""; Out "--- Adding SSH config entry ---" $colYellow
    $configPath = Join-Path $HOME ".ssh/config"
    if (-not (Test-Path $configPath)) { New-Item -ItemType File -Force -Path $configPath | Out-Null }
    $keyFwd = $key -replace '\\', '/'
    Add-Content $configPath "`nHost $nick`n    HostName $rhost`n    User $ruser`n    Port $port`n    IdentityFile $keyFwd"
    Out "✓ Entry added for '$nick'" $colGreen

    # --- Test connection ---
    Out ""; Out "--- Testing connection ---" $colYellow
    $result = ssh -o BatchMode=yes -o ConnectTimeout=5 $nick "echo success" 2>&1
    if ($result -match "success") {
        Out "✓ Connection successful!" $colGreen
        Out ""
        Out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $colGreen
        Out "  Done! Test your connection anytime with:"
        Out ""
        Out "      ssh $nick"                            $colGreen
        Out ""
        Out "  No password will be asked."              $clrHint
        Out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $colGreen
    } else {
        Out "✗ Connection test failed — check your settings" $colRed
    }

    $btnRun.Enabled = $true
})

$form.ShowDialog() | Out-Null
