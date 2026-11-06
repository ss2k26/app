param (
    [string]$ScriptFolder = $PSScriptRoot
)

[console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Cleanly trim any trailing whitespace or ghost spaces passed from the Batch wrapper
if ($ScriptFolder) { $ScriptFolder = $ScriptFolder.Trim() }
if (-not $ScriptFolder) { $ScriptFolder = $PSScriptRoot }

# Locate the mkcert output folder dynamically relative to wherever this script lives
$traefikCertsPath = Join-Path $ScriptFolder "stacks\shared-services\proxy-traefik\dev"
$rootPemFile = Join-Path $traefikCertsPath "rootCA.pem"
$rootCrtFile = Join-Path $traefikCertsPath "rootCA.crt"

Write-Host "Searching for local Root Certificate Authority..." -ForegroundColor Cyan

if (Test-Path $rootPemFile) {
    # Copy the raw .pem to a standard Windows .crt extension file cleanly
    Copy-Item -Path $rootPemFile -Destination $rootCrtFile -Force
    
    # Open the staged certificate object in memory to extract its unique Thumbprint
    $certObject = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2($rootCrtFile)
    $certThumbprint = $certObject.Thumbprint

    Write-Host "Checking if this specific certificate is already trusted in Windows..." -ForegroundColor Cyan
    
    # 🚀 Check the Windows Local Machine Store for the exact same Thumbprint
    $alreadyInstalled = Get-ChildItem -Path "Cert:\LocalMachine\Root" | Where-Object { $_.Thumbprint -eq $certThumbprint }

    if (-not $alreadyInstalled) {
        Write-Host "Certificate not found in store. Injecting into Windows Trusted Root..." -ForegroundColor Cyan
        
        # Installs the certificate into the LocalMachine Trusted Root Authority store securely
        Import-Certificate -FilePath $rootCrtFile -CertStoreLocation "Cert:\LocalMachine\Root" | Out-Null
        
        Write-Host "`nSuccess! Windows now completely trusts your local *.mysite.test domains!" -ForegroundColor Green
        Write-Host "Restart your browser (Chrome/Edge) to apply the green secure padlocks." -ForegroundColor Yellow
    } else {
        Write-Host "`nAlready trusted -> This specific certificate is already installed in Windows! (Skipped)" -ForegroundColor Gray
    }
} else {
    Write-Host "Error: Target certificate file not found at: $rootPemFile" -ForegroundColor Red
    Write-Host "Please ensure you have run your 'proxy-traefik' dev container stack at least once first!" -ForegroundColor Yellow
}

Write-Host "`nCertificate installation sequence complete." -ForegroundColor Cyan
pause
