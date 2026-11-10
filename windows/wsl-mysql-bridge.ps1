# Lets Docker apps inside WSL2 reach the MySQL server installed on this Windows 10 PC as root@127.0.0.1.
#
# Problem: from WSL2 (NAT mode) you can only reach Windows via its "vEthernet (WSL)" IP, so MySQL sees
# the client as 172.x.x.x and refuses root (root is usually only allowed from localhost).
# Fix:     a netsh portproxy listens on that WSL-facing IP and opens its OWN connection to 127.0.0.1:3306
#          on this PC, so MySQL sees 127.0.0.1.
#
#   WSL container -> <Windows WSL IP>:13306 --portproxy--> 127.0.0.1:3306 (MySQL)
#
# The WSL IP changes after a reboot / wsl --shutdown. Re-run "start" (or use -Action install: runs it at every logon).
#   wsl-mysql-bridge.ps1                       start (default)
#   wsl-mysql-bridge.ps1 -Action stop|status|install|uninstall
#   -MysqlPort 3306   port MySQL listens on (Windows)      -BridgePort 13306   port exposed to WSL
param(
    [ValidateSet('start', 'stop', 'status', 'install', 'uninstall')][string]$Action = 'start',
    [int]$MysqlPort  = 3306,
    [int]$BridgePort = 13306,
    [switch]$Silent
)
$ErrorActionPreference = 'Stop'
$ruleName = 'platform WSL MySQL bridge'
$taskName = 'platform-wsl-mysql-bridge'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Done { if (-not $Silent) { pause } }

if (-not (Test-Admin)) {            # needs Administrator (netsh portproxy + firewall rule)
    $a = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"", '-Action', $Action, '-MysqlPort', $MysqlPort, '-BridgePort', $BridgePort)
    if ($Silent) { $a += '-Silent' }
    Start-Process powershell -Verb RunAs -ArgumentList $a
    exit
}

function Get-WslAdapter {
    return Get-NetAdapter -Name 'vEthernet (WSL*' -ErrorAction SilentlyContinue | Select-Object -First 1
}
function Get-WslIp($adapter) {
    $ip = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
    return $ip.IPAddress
}
function Wait-Wsl {
    $a = Get-WslAdapter
    if (-not $a) {                   # the adapter only exists while the WSL VM runs -> wake it
        try { & wsl.exe -e true 2>$null | Out-Null } catch { }
        for ($i = 0; $i -lt 30 -and -not $a; $i++) { Start-Sleep -Seconds 2; $a = Get-WslAdapter }
    }
    return $a
}

function Remove-Bridge {
    foreach ($l in (& netsh.exe interface portproxy show v4tov4)) {
        if ($l -match "^\s*(\S+)\s+$BridgePort\s+\S+\s+\d+\s*$") {
            & netsh.exe interface portproxy delete v4tov4 listenaddress=$($Matches[1]) listenport=$BridgePort | Out-Null
        }
    }
    Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}

switch ($Action) {
    'start' {
        $adapter = Wait-Wsl
        if (-not $adapter) { throw "Adapter 'vEthernet (WSL)' not found. Start WSL (open your Debian terminal) and run this again." }
        $ip = Get-WslIp $adapter
        if (-not (Get-NetTCPConnection -State Listen -LocalPort $MysqlPort -ErrorAction SilentlyContinue)) {
            Write-Host "Warning: nothing is listening on Windows port $MysqlPort yet - is MySQL running?" -ForegroundColor Yellow
        }
        Remove-Bridge
        & netsh.exe interface portproxy add v4tov4 listenaddress=$ip listenport=$BridgePort connectaddress=127.0.0.1 connectport=$MysqlPort | Out-Null
        # only the WSL network may use the bridge (not your LAN / Wi-Fi)
        New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $BridgePort `
            -InterfaceAlias $adapter.Name -RemoteAddress LocalSubnet -Profile Any | Out-Null
        Write-Host "Bridge up:  ${ip}:$BridgePort  ->  127.0.0.1:$MysqlPort   (MySQL sees 127.0.0.1)" -ForegroundColor Green
        Write-Host "In WSL:     bin/platform up remote        (COMPOSE_PROFILES=windows, WINDOWS_PORT=$BridgePort)" -ForegroundColor Cyan
        Write-Host "Apps:       DB_HOST=windows-mysql  DB_PORT=3309  user root" -ForegroundColor Cyan
        Done
    }
    'stop' {
        Remove-Bridge
        Write-Host 'Bridge removed.' -ForegroundColor Green
        Done
    }
    'status' {
        $adapter = Get-WslAdapter
        if ($adapter) { $ip = Get-WslIp $adapter; Write-Host "WSL adapter: $($adapter.Name)  ip $ip" -ForegroundColor Cyan }
        else { Write-Host 'WSL adapter not present (WSL not running).' -ForegroundColor Yellow }
        Write-Host '--- portproxy rules'; & netsh.exe interface portproxy show v4tov4
        $mysql = [bool](Get-NetTCPConnection -State Listen -LocalPort $MysqlPort -ErrorAction SilentlyContinue)
        Write-Host ("MySQL listening on Windows port {0}: {1}" -f $MysqlPort, $mysql)
        if ($adapter) {
            $ok = (Test-NetConnection -ComputerName $ip -Port $BridgePort -WarningAction SilentlyContinue).TcpTestSucceeded
            Write-Host ("Bridge {0}:{1} answers: {2}" -f $ip, $BridgePort, $ok)
        }
        Write-Host ("Firewall rule present: {0}" -f [bool](Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue))
        Write-Host ("Autostart task present: {0}" -f [bool](Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue))
        Done
    }
    'install' {
        $arg = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" -Action start -MysqlPort $MysqlPort -BridgePort $BridgePort -Silent"
        $act = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg
        $trg = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
        $pri = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest
        Register-ScheduledTask -TaskName $taskName -Action $act -Trigger $trg -Principal $pri -Force | Out-Null
        Write-Host "Autostart installed: the bridge is re-created at every logon (it starts WSL if needed)." -ForegroundColor Green
        Done
    }
    'uninstall' {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host 'Autostart removed.' -ForegroundColor Green
        Done
    }
}
