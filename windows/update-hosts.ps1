# Fallback when wildcard DNS is not used: maps every dev hostname found in stacks\*\*\.env
# (APP_HOST_DEV=..., PORTAINER_HOST_DEV=...) to 127.0.0.1. Idempotent: rewrites one managed block.
$ErrorActionPreference = 'Stop'
$root  = Split-Path -Parent $PSScriptRoot
$hosts = "$env:windir\System32\drivers\etc\hosts"
$begin = '# >>> platform dev hosts (managed) >>>'
$end   = '# <<< platform dev hosts (managed) <<<'

$names = New-Object System.Collections.Generic.SortedSet[string]
Get-ChildItem (Join-Path $root 'stacks') -Recurse -File |
    Where-Object { $_.Name -eq '.env' -or $_.Name -eq '.env.dev.example' } |
    ForEach-Object {
        Get-Content $_.FullName | ForEach-Object {
            if ($_ -match '^\s*[A-Z0-9_]*HOST_DEV\s*=\s*([A-Za-z0-9.-]+)\s*$' -and $Matches[1] -ne 'disabled.invalid') {
                [void]$names.Add($Matches[1].ToLower())
            }
        }
    }
if ($names.Count -eq 0) { Write-Host 'No *_HOST_DEV entries found.' -ForegroundColor Yellow; pause; exit 1 }

$lines = @(Get-Content $hosts)
$out = New-Object System.Collections.Generic.List[string]
$skip = $false
foreach ($l in $lines) {
    if ($l.Trim() -eq $begin) { $skip = $true; continue }
    if ($l.Trim() -eq $end)   { $skip = $false; continue }
    if (-not $skip) { $out.Add($l) }
}
while ($out.Count -gt 0 -and $out[$out.Count - 1].Trim() -eq '') { $out.RemoveAt($out.Count - 1) }
$out.Add('')
$out.Add($begin)
foreach ($n in $names) { $out.Add("127.0.0.1  $n"); Write-Host "mapped $n" -ForegroundColor Green }
$out.Add($end)
Set-Content -Path $hosts -Value $out -Encoding ASCII
ipconfig /flushdns | Out-Null
Write-Host "`nDone: $($names.Count) host(s)." -ForegroundColor Cyan
pause
