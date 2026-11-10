# Reach the databases on your VPS as 127.0.0.1:<port> from Windows 10 (HeidiSQL, DBeaver, Navicat, php.exe ...),
# WITHOUT Docker. Settings come from stacks\databases\remote\.env (same file the Docker forwarder uses).
#   ssh    mode: ssh.exe tunnel (built into Windows 10: Settings > Apps > Optional features > OpenSSH Client)
#   direct mode: netsh portproxy 127.0.0.1:<port> -> <REMOTE_HOST>:<port>  (needs Administrator, NOT encrypted)
# The VPS-side socat proxy makes mysqld see every connection as root@127.0.0.1 either way.
#
#   remote-db.ps1                 start (foreground, Ctrl+C to quit; reconnects by itself)
#   remote-db.ps1 -Background     start hidden
#   remote-db.ps1 -Action stop    stop tunnel / remove portproxy rules
#   remote-db.ps1 -Action status
param(
    [ValidateSet('start', 'stop', 'status')][string]$Action = 'start',
    [switch]$Background,
    [switch]$Child
)
$ErrorActionPreference = 'Stop'

$root     = Split-Path -Parent $PSScriptRoot
$stackDir = Join-Path $root 'stacks\databases\remote'
$envFile  = Join-Path $stackDir '.env'
if (-not (Test-Path $envFile)) { $envFile = Join-Path $stackDir '.env.dev.example' }
$dataDir  = Join-Path $root 'data\ssh'
$pidFile  = Join-Path $dataDir 'remote-db.pid'

# ---- config -------------------------------------------------------------------------------
$cfg = @{}
foreach ($line in Get-Content $envFile) {
    if ($line -notmatch '^\s*#' -and $line -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.*?)\s*$') { $cfg[$Matches[1]] = $Matches[2] }
}
function Get-Cfg([string]$Key, $Default) {
    if ($cfg.ContainsKey($Key) -and $cfg[$Key] -ne '') { return $cfg[$Key] }
    return $Default
}

$engines = @(
    @{ Name = 'mysql56';  Local = 3306; Remote = 3306 },
    @{ Name = 'mysql84';  Local = 3307; Remote = 3307 },
    @{ Name = 'mariadb';  Local = 3308; Remote = 3308 },
    @{ Name = 'postgres'; Local = 5432; Remote = 5432 }
)
$enabled = (Get-Cfg 'COMPOSE_PROFILES' 'mysql56').Split(',') | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$forwards = @()
foreach ($e in $engines) {
    if ($enabled -contains $e.Name) {
        $up = $e.Name.ToUpper()
        $forwards += [pscustomobject]@{
            Name   = $e.Name
            Local  = [int](Get-Cfg "REMOTE_${up}_LOCAL_PORT" $e.Local)
            Remote = [int](Get-Cfg "REMOTE_${up}_PORT" $e.Remote)
        }
    }
}
if ($forwards.Count -eq 0) { throw "COMPOSE_PROFILES in $envFile lists no VPS engine (mysql56,mysql84,mariadb,postgres). This script tunnels to a VPS; for MySQL on this PC use 6-wsl-mysql-bridge-start.bat." }

$mode       = Get-Cfg 'REMOTE_MODE' 'ssh'
$remoteHost = Get-Cfg 'REMOTE_HOST' ''
if (-not $remoteHost -or $remoteHost -eq 'vps.example.com') { throw "Set REMOTE_HOST in $envFile first." }

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# ---- ssh mode -----------------------------------------------------------------------------
function Get-SshKey {
    $src = Join-Path $dataDir (Get-Cfg 'REMOTE_SSH_KEY' 'id_ed25519')
    if (-not (Test-Path $src)) { throw "Private key not found: $src  (create it: ssh-keygen -t ed25519 -f data\ssh\id_ed25519)" }
    # ssh.exe refuses keys other users can read -> private copy with a locked-down ACL, LF line endings
    $dir = Join-Path $env:USERPROFILE '.ssh'
    New-Item -ItemType Directory -Force $dir | Out-Null
    $dst = Join-Path $dir 'platform-remote-db'
    Remove-Item $dst -Force -ErrorAction SilentlyContinue
    $text = (Get-Content $src -Raw) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($dst, $text, (New-Object System.Text.UTF8Encoding($false)))
    & icacls.exe $dst /inheritance:r | Out-Null
    & icacls.exe $dst /grant:r "$($env:USERNAME):(R)" | Out-Null
    return $dst
}

function Start-Ssh {
    if (-not (Get-Command ssh.exe -ErrorAction SilentlyContinue)) {
        throw 'ssh.exe not found. Settings > Apps > Optional features > Add a feature > OpenSSH Client.'
    }
    $user   = Get-Cfg 'REMOTE_SSH_USER' ''
    if (-not $user) { throw "Set REMOTE_SSH_USER in $envFile." }
    $port   = Get-Cfg 'REMOTE_SSH_PORT' '22'
    $target = Get-Cfg 'REMOTE_SSH_TARGET_HOST' '127.0.0.1'
    $key    = Get-SshKey
    $sshArgs = @('-N', '-o', 'ExitOnForwardFailure=yes', '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3',
                 '-o', 'ConnectTimeout=15', '-o', 'StrictHostKeyChecking=accept-new', '-o', 'IdentitiesOnly=yes',
                 '-o', 'BatchMode=yes', '-i', $key, '-p', $port)
    foreach ($f in $forwards) {
        $sshArgs += @('-L', "127.0.0.1:$($f.Local):${target}:$($f.Remote)")
        Write-Host ("  {0,-9} 127.0.0.1:{1}  ->  {2}:{3} (via {4}@{5})" -f $f.Name, $f.Local, $target, $f.Remote, $user, $remoteHost) -ForegroundColor Green
    }
    $sshArgs += "$user@$remoteHost"
    Write-Host "Tunnel running. Connect as root to 127.0.0.1 on the ports above. Ctrl+C to quit." -ForegroundColor Cyan
    while ($true) {
        & ssh.exe @sshArgs
        Write-Host "Tunnel closed (exit $LASTEXITCODE). Reconnecting in 5 s ..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

function Stop-Ssh {
    if (-not (Test-Path $pidFile)) { Write-Host 'No background tunnel recorded.' -ForegroundColor Gray; return }
    $parent = [int](Get-Content $pidFile)
    $kids = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$parent" -ErrorAction SilentlyContinue)
    Stop-Process -Id $parent -Force -ErrorAction SilentlyContinue      # parent first, otherwise it respawns ssh
    foreach ($k in $kids) { Stop-Process -Id $k.ProcessId -Force -ErrorAction SilentlyContinue }
    Remove-Item $pidFile -Force -ErrorAction SilentlyContinue
    Write-Host 'Tunnel stopped.' -ForegroundColor Green
}

# ---- direct mode (netsh portproxy) ----------------------------------------------------------
function Start-Direct {
    foreach ($f in $forwards) {
        & netsh.exe interface portproxy delete v4tov4 listenaddress=127.0.0.1 listenport=$($f.Local) 2>$null | Out-Null
        & netsh.exe interface portproxy add v4tov4 listenaddress=127.0.0.1 listenport=$($f.Local) connectaddress=$remoteHost connectport=$($f.Remote) | Out-Null
        Write-Host ("  {0,-9} 127.0.0.1:{1}  ->  {2}:{3}" -f $f.Name, $f.Local, $remoteHost, $f.Remote) -ForegroundColor Green
    }
    Write-Host 'Portproxy rules are persistent (they survive reboots) until you run -Action stop.' -ForegroundColor Cyan
    Write-Host 'Direct mode is NOT encrypted - use it on a trusted network/VPN only.' -ForegroundColor Yellow
}

function Stop-Direct {
    foreach ($f in $forwards) {
        & netsh.exe interface portproxy delete v4tov4 listenaddress=127.0.0.1 listenport=$($f.Local) 2>$null | Out-Null
        Write-Host "removed 127.0.0.1:$($f.Local)" -ForegroundColor Gray
    }
}

# ---- dispatch -------------------------------------------------------------------------------
if ($mode -eq 'direct' -and $Action -ne 'status' -and -not (Test-Admin)) {
    Start-Process powershell -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Action', $Action)
    exit
}

switch ($Action) {
    'start' {
        if ($mode -eq 'direct') { Start-Direct; pause; break }
        if ($mode -ne 'ssh') { throw "REMOTE_MODE must be ssh or direct." }
        New-Item -ItemType Directory -Force $dataDir | Out-Null
        if ($Background -and -not $Child) {
            $p = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Action', 'start', '-Child')
            Set-Content -Path $pidFile -Value $p.Id
            Write-Host "Tunnel started in the background (pid $($p.Id)). Stop: 5-remote-db-stop.bat" -ForegroundColor Green
            pause
        } else {
            Start-Ssh
        }
    }
    'stop' {
        if ($mode -eq 'direct') { Stop-Direct } else { Stop-Ssh }
        pause
    }
    'status' {
        foreach ($f in $forwards) {
            $ok = (Test-NetConnection -ComputerName 127.0.0.1 -Port $f.Local -WarningAction SilentlyContinue).TcpTestSucceeded
            $color = 'Red'; $txt = 'closed'
            if ($ok) { $color = 'Green'; $txt = 'listening' }
            Write-Host ("{0,-9} 127.0.0.1:{1}  {2}" -f $f.Name, $f.Local, $txt) -ForegroundColor $color
        }
        if ($mode -eq 'direct') { & netsh.exe interface portproxy show v4tov4 }
        pause
    }
}
