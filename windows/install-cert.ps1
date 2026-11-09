# Trust the platform's local Root CA (made by mkcert inside the Traefik "certs" container)
# so https://*.mysite.test shows a green padlock. Safe to re-run.
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$rootCa = Join-Path $root 'certs\mkcert\rootCA.pem'

Write-Host "Looking for $rootCa" -ForegroundColor Cyan
if (-not (Test-Path $rootCa)) {
    Write-Host "Not found. Start the proxy once first:  bin/platform up traefik  (WSL)" -ForegroundColor Red
    pause; exit 1
}

$crt = Join-Path $env:TEMP 'platform-rootCA.crt'
Copy-Item $rootCa $crt -Force
$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($crt)

$exists = Get-ChildItem Cert:\LocalMachine\Root | Where-Object { $_.Thumbprint -eq $cert.Thumbprint }
if ($exists) {
    Write-Host "Already trusted ($($cert.Subject))." -ForegroundColor Gray
} else {
    Import-Certificate -FilePath $crt -CertStoreLocation Cert:\LocalMachine\Root | Out-Null
    Write-Host "Trusted: $($cert.Subject)" -ForegroundColor Green
    Write-Host "Restart Chrome/Edge. Firefox: about:config -> security.enterprise_roots.enabled = true" -ForegroundColor Yellow
}
pause
