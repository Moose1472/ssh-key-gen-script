Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Dwm {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@ -ErrorAction SilentlyContinue

# --- System theme ---
$reg  = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" -ErrorAction SilentlyContinue
$dark = ($reg.AppsUseLightTheme -eq 0)

# --- System accent color ---
try {
    $ar   = Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent" -ErrorAction Stop
    $abgr = $ar.AccentColorMenu
    $clrAccent = [System.Drawing.Color]::FromArgb(
        $abgr -band 0xFF, ($abgr -shr 8) -band 0xFF, ($abgr -shr 16) -band 0xFF)
} catch { $clrAccent = [System.Drawing.Color]::FromArgb(0, 120, 212) }

# --- Colors ---
if ($dark) {
    $bg  = [System.Drawing.Color]::FromArgb(32,  32,  32)
    $inp = [System.Drawing.Color]::FromArgb(40,  40,  40)
    $out = [System.Drawing.Color]::FromArgb(20,  20,  20)
    $bdr = [System.Drawing.Color]::FromArgb(60,  60,  60)
    $txt = [System.Drawing.Color]::White
    $sub = [System.Drawing.Color]::FromArgb(150, 150, 150)
} else {
    $bg  = [System.Drawing.Color]::FromArgb(243, 243, 243)
    $inp = [System.Drawing.Color]::White
    $out = [System.Drawing.Color]::FromArgb(248, 248, 248)
    $bdr = [System.Drawing.Color]::FromArgb(200, 200, 200)
    $txt = [System.Drawing.Color]::FromArgb(28,  28,  28)
    $sub = [System.Drawing.Color]::FromArgb(100, 100, 100)
}
$gn = [System.Drawing.Color]::FromArgb(78,  201, 176)
$rd = [System.Drawing.Color]::FromArgb(244, 71,  71)
$yl = [System.Drawing.Color]::FromArgb(220, 200, 80)

# --- Fonts ---
try {
    $fTitle = New-Object System.Drawing.Font("Segoe UI Variable Display", 15)
    $fBody  = New-Object System.Drawing.Font("Segoe UI Variable Text",    9)
    $fSmall = New-Object System.Drawing.Font("Segoe UI Variable Text",    8)
    $fBtn   = New-Object System.Drawing.Font("Segoe UI Variable Text",    10)
} catch {
    $fTitle = New-Object System.Drawing.Font("Segoe UI", 15)
    $fBody  = New-Object System.Drawing.Font("Segoe UI", 9)
    $fSmall = New-Object System.Drawing.Font("Segoe UI", 8)
    $fBtn   = New-Object System.Drawing.Font("Segoe UI", 10)
}
try   { $fMono = New-Object System.Drawing.Font("Cascadia Mono", 9) }
catch { $fMono = New-Object System.Drawing.Font("Consolas",      9) }

# --- Form ---
$form                 = New-Object System.Windows.Forms.Form
$form.Text            = "SSH Key Generator"
$form.Size            = New-Object System.Drawing.Size(480, 800)
$form.StartPosition   = "CenterScreen"
$form.BackColor       = $bg
$form.FormBorderStyle = "FixedSingle"
$form.MaximizeBox     = $false
$form.Font            = $fBody

$px = 24
$fw = $form.ClientSize.Width - ($px * 2)

# --- Windows 11 DWM effects ---
$form.Add_Shown({
    try {
        $v = 2; [Dwm]::DwmSetWindowAttribute($form.Handle, 33, [ref]$v, 4) | Out-Null
        if ($dark) { $v = 1; [Dwm]::DwmSetWindowAttribute($form.Handle, 20, [ref]$v, 4) | Out-Null }
    } catch {}
    $r = 5; $d = $r * 2; $w = $btnRun.Width; $h = $btnRun.Height
    $gp = New-Object System.Drawing.Drawing2D.GraphicsPath
    $gp.AddArc(0,      0,      $d, $d, 180, 90)
    $gp.AddArc($w - $d, 0,      $d, $d, 270, 90)
    $gp.AddArc($w - $d, $h - $d, $d, $d,   0, 90)
    $gp.AddArc(0,      $h - $d, $d, $d,  90, 90)
    $gp.CloseFigure()
    $btnRun.Region = New-Object System.Drawing.Region($gp)
})

# --- Header ---
$lblTitle = New-Object System.Windows.Forms.Label
$lblTitle.Text = "SSH Key Generator"; $lblTitle.Font = $fTitle
$lblTitle.ForeColor = $txt; $lblTitle.Location = New-Object System.Drawing.Point($px, 20)
$lblTitle.AutoSize = $true; $form.Controls.Add($lblTitle)

$lblSub = New-Object System.Windows.Forms.Label
$lblSub.Text = "Set up passwordless SSH access in one click"
$lblSub.ForeColor = $sub; $lblSub.Font = $fBody
$lblSub.Location = New-Object System.Drawing.Point($px, 50); $lblSub.AutoSize = $true
$form.Controls.Add($lblSub)

$sep = New-Object System.Windows.Forms.Panel
$sep.Location = New-Object System.Drawing.Point($px, 76)
$sep.Size = New-Object System.Drawing.Size($fw, 1); $sep.BackColor = $bdr
$form.Controls.Add($sep)

# --- Field builder ---
function Add-Field($label, $yPos, $default = "", $width = $fw) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $label; $l.ForeColor = $txt; $l.Font = $fBody
    $l.Location = New-Object System.Drawing.Point($px, $yPos); $l.AutoSize = $true
    $form.Controls.Add($l)
    $t = New-Object System.Windows.Forms.TextBox
    $t.Location = New-Object System.Drawing.Point($px, ($yPos + 22))
    $t.Size = New-Object System.Drawing.Size($width, 32)
    $t.Text = $default; $t.BackColor = $inp; $t.ForeColor = $txt
    $t.BorderStyle = "FixedSingle"; $t.Font = $fBody
    $form.Controls.Add($t); return $t
}

$y = 92
$txtName = Add-Field "Key Name"             $y;           $y += 62
$txtHost = Add-Field "Remote IP / Hostname" $y;           $y += 62
$txtUser = Add-Field "Remote Username"      $y;           $y += 62
$txtPort = Add-Field "SSH Port"             $y "22" 80

$chkWin = New-Object System.Windows.Forms.CheckBox
$chkWin.Text = "Remote machine is Windows"
$chkWin.Location = New-Object System.Drawing.Point(($px + 96), ($y + 24))
$chkWin.AutoSize = $true; $chkWin.ForeColor = $txt; $chkWin.BackColor = $bg
$form.Controls.Add($chkWin); $y += 62

$txtNick = Add-Field "SSH Nickname" $y;   $y += 26

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text = "Leave blank to use key name"; $lblHint.ForeColor = $sub; $lblHint.Font = $fSmall
$lblHint.Location = New-Object System.Drawing.Point($px, $y); $lblHint.AutoSize = $true
$form.Controls.Add($lblHint); $y += 42

# --- Button ---
$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Generate Key"; $btnRun.Font = $fBtn
$btnRun.Location = New-Object System.Drawing.Point($px, $y)
$btnRun.Size = New-Object System.Drawing.Size($fw, 40)
$btnRun.BackColor = $clrAccent; $btnRun.ForeColor = [System.Drawing.Color]::White
$btnRun.FlatStyle = "Flat"; $btnRun.FlatAppearance.BorderSize = 0
$form.Controls.Add($btnRun); $y += 52

# --- Output ---
$txtOut = New-Object System.Windows.Forms.RichTextBox
$txtOut.Location = New-Object System.Drawing.Point($px, $y)
$txtOut.Size = New-Object System.Drawing.Size($fw, ($form.ClientSize.Height - $y - $px))
$txtOut.BackColor = $out; $txtOut.ForeColor = $txt
$txtOut.ReadOnly = $true; $txtOut.BorderStyle = "None"
$txtOut.Font = $fMono; $txtOut.ScrollBars = "Vertical"
$form.Controls.Add($txtOut)

function Out($msg, $col = $null) {
    $txtOut.SelectionStart = $txtOut.TextLength; $txtOut.SelectionLength = 0
    $txtOut.SelectionColor = if ($col) { $col } else { $txt }
    $txtOut.AppendText("$msg`n"); $txtOut.ScrollToCaret()
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

    if (Test-Path $key) {
        $res = [System.Windows.Forms.MessageBox]::Show(
            "A key named '$name' already exists. Overwrite it?",
            "Key Exists", "YesNo", "Question")
        if ($res -ne "Yes") { $btnRun.Enabled = $true; return }
        Remove-Item -Force "$key", "$key.pub" -ErrorAction SilentlyContinue
    }

    # --- Generate ---
    Out "--- Generating key pair ---" $yl
    $comment = "$([System.Environment]::UserName)@$(hostname)"
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    cmd /c "ssh-keygen -t ed25519 -f `"$key`" -C `"$comment`" -N `"`"" 2>&1 | Out-Null
    if (Test-Path $key) { Out "✓ Key pair created" $gn }
    else { Out "✗ Failed to generate key pair" $rd; $btnRun.Enabled = $true; return }

    # --- Push ---
    Out ""; Out "--- Pushing public key ---" $yl
    Out "  Minimizing — enter your password in the console window..." $sub
    [System.Windows.Forms.Application]::DoEvents()
    $form.WindowState = "Minimized"
    scp -P $port "$key.pub" "${ruser}@${rhost}:temp_key.pub"
    $scpExit = $LASTEXITCODE
    $form.WindowState = "Normal"; $form.BringToFront()

    if ($scpExit -ne 0) {
        Out "✗ Could not reach $rhost — is SSH running on the remote machine?" $rd
        Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        $btnRun.Enabled = $true; return
    }
    Out "✓ Key transferred to remote machine" $gn

    # --- Install ---
    if ($isWin) {
        Out ""; Out "--- Applying Windows SSH fix ---" $yl
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
            Out "✓ Key installed in authorized locations" $gn
            Out "✓ SSH config updated"                   $gn
        } else { Out "✗ Windows SSH fix encountered an error" $rd }
    } else {
        Out ""; Out "--- Installing key ---" $yl
        ssh -p $port "${ruser}@${rhost}" "mkdir -p ~/.ssh && cat ~/temp_key.pub >> ~/.ssh/authorized_keys && rm ~/temp_key.pub && chmod 600 ~/.ssh/authorized_keys && chmod 700 ~/.ssh" 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) { Out "✓ Key installed in authorized_keys" $gn }
        else { Out "✗ Failed to install key on remote machine" $rd }
    }

    # --- SSH config ---
    Out ""; Out "--- Adding SSH config entry ---" $yl
    $configPath = Join-Path $HOME ".ssh/config"
    if (-not (Test-Path $configPath)) { New-Item -ItemType File -Force -Path $configPath | Out-Null }
    $keyFwd = $key -replace '\\', '/'
    Add-Content $configPath "`nHost $nick`n    HostName $rhost`n    User $ruser`n    Port $port`n    IdentityFile $keyFwd"
    Out "✓ Entry added for '$nick'" $gn

    # --- Test ---
    Out ""; Out "--- Testing connection ---" $yl
    $result = ssh -o BatchMode=yes -o ConnectTimeout=5 $nick "echo success" 2>&1
    if ($result -match "success") {
        Out "✓ Connection successful!" $gn
        Out ""
        Out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $gn
        Out "  Done! Test your connection anytime with:"
        Out ""
        Out "      ssh $nick"                           $gn
        Out ""
        Out "  No password should be asked for."       $sub
        Out "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" $gn
    } else {
        Out "✗ Connection test failed — check your settings" $rd
    }

    $btnRun.Enabled = $true
})

$form.ShowDialog() | Out-Null
