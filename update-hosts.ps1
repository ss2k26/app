param (
    [string]$ScriptFolder = $PSScriptRoot
)

# Force the terminal to process text formatting parameters using universal UTF8
[console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Cleanly trim any trailing whitespace or ghost spaces passed from the Batch file wrapper
if ($ScriptFolder) { $ScriptFolder = $ScriptFolder.Trim() }
if (-not $ScriptFolder) { $ScriptFolder = $PSScriptRoot }

$hostsPath = "$env:windir\System32\drivers\etc\hosts"

# Resolve the target app directory layout paths dynamically
$laravelAppsPath = Join-Path $ScriptFolder "stacks\laravel-apps"
$phpAppsPath = Join-Path $ScriptFolder "stacks\php-apps"
$appsPaths = @($laravelAppsPath, $phpAppsPath)

$targetDomains = [System.Collections.Generic.List[string]]::new()
$targetDomains.Add("portainer.mysite.test")

foreach ($appsPath in $appsPaths) {
    Write-Host "Scanning dynamic relative path: $appsPath" -ForegroundColor Cyan

    if (Test-Path $appsPath) {
        $apps = Get-ChildItem -Path $appsPath -Directory
        foreach ($app in $apps) {
            $appName = $app.Name.ToLower().Trim()
            if ($appName) { $targetDomains.Add("$appName.mysite.test") }
        }
    } else {
        Write-Host "Warning: Relative apps directory structure not found: $appsPath" -ForegroundColor Yellow
    }
}

Write-Host "Processing local Windows hosts mappings..." -ForegroundColor Cyan

# Load the current hosts file entries into memory array for native processing
$currentHostsContent = Get-Content -Path $hostsPath | ForEach-Object { $_.Trim() }

foreach ($domain in $targetDomains) {
    $hostsEntry = "127.0.0.1   $domain"
    
    # 🚀 Fixed: Native operator check syntax instead of broken pipeline strings
    $exists = $currentHostsContent -contains $hostsEntry

    if (-not $exists) {
        # Safely append the entry with a newline
        Add-Content -Path $hostsPath -Value "`n$hostsEntry"
        Write-Host "Successfully mapped -> $domain" -ForegroundColor Green
    } else {
        Write-Host "Already matched   -> $domain (Skipped)" -ForegroundColor Gray
    }
}
Write-Host "`nDynamic relative hosts automation complete!" -ForegroundColor Cyan
pause
