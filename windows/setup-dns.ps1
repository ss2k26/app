# One-time: send every *.mysite.test lookup to the dnsmasq container (127.0.0.1:53).
# After this you never edit the hosts file again. Requires:  bin/platform up dns   (WSL)
param([string]$Domain = 'mysite.test', [switch]$Remove)
$ErrorActionPreference = 'Stop'
$ns = ".$Domain"

Get-DnsClientNrptRule | Where-Object { $_.Namespace -contains $ns } | ForEach-Object { Remove-DnsClientNrptRule -Name $_.Name -Force }
if ($Remove) { Write-Host "Removed DNS rule for $ns" -ForegroundColor Yellow; pause; exit 0 }

Add-DnsClientNrptRule -Namespace $ns -NameServers '127.0.0.1' -Comment 'platform dev wildcard DNS'
Clear-DnsClientCache
Write-Host "Rule added: $ns -> 127.0.0.1" -ForegroundColor Green

Write-Host "Testing (needs the 'dns' stack running)..." -ForegroundColor Cyan
try {
    $r = Resolve-DnsName "check.$Domain" -Type A -ErrorAction Stop
    Write-Host "OK: check.$Domain -> $($r.IPAddress)" -ForegroundColor Green
} catch {
    Write-Host "Lookup failed. Docker in WSL2 may not forward UDP/53 to Windows." -ForegroundColor Red
    Write-Host "Use 3-update-hosts.bat instead (run this script with -Remove to undo), or enable WSL 'networkingMode=mirrored'." -ForegroundColor Yellow
}
pause
