# ==========================================
# ESXi Discovery Scanner (Practical Mode)
# ==========================================

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        ESXi Network Discovery Tool       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$networkInput = Read-Host "Enter network base (example: 192.168.1.0)"
$cidrInput    = Read-Host "Enter CIDR mask (16 or 24)"

$exportChoice = Read-Host "Export results to TXT report? (Y/N)"
$doExport = $exportChoice -match "^[Yy]"
if ($doExport) { $Output = Join-Path (Get-Location) "esxi_hosts.txt" }

$totalScanned = 0
$esxiFound    = 0
$results      = @()

Write-Host "`nStarting scan..." -ForegroundColor Green

function Test-TcpPortFast {
    param ($IP, $Port, $TimeoutMs = 3000)
    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($IP, $Port, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)
        if (-not $success) { $client.Close(); return $false }
        $client.EndConnect($iar); $client.Close(); return $true
    } catch { return $false }
}

# Trust self-signed certs
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(ServicePoint s, X509Certificate c, WebRequest r, int p) { return true; }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$baseParts = $networkInput.Split(".")
$oct1 = [int]$baseParts[0]
$oct2 = [int]$baseParts[1]
$oct3 = [int]$baseParts[2]

if ($cidrInput -eq "24") { $subnetStart=$oct3; $subnetEnd=$oct3 }
elseif ($cidrInput -eq "16") { $subnetStart=0; $subnetEnd=255 }
else { Write-Host "Only /16 and /24 supported." -ForegroundColor Red; exit }

for ($subnet=$subnetStart; $subnet -le $subnetEnd; $subnet++) {

    Write-Host "`nScanning subnet $oct1.$oct2.$subnet.0/$cidrInput" -ForegroundColor DarkGray

    for ($node=1; $node -le 254; $node++) {

        $ip = "$oct1.$oct2.$subnet.$node"
        $totalScanned++

        Write-Host "`rHosts scanned: $totalScanned | ESXi suspects: $esxiFound | Current: $ip" -NoNewline

        $port902Open = Test-TcpPortFast $ip 902

        if ($port902Open) {

            $esxiFound++
            Write-Host "`nPOSSIBLE ESXi detected at $ip — PLEASE CONFIRM" -ForegroundColor Yellow

            $port443Open = Test-TcpPortFast $ip 443
            $webTitle = ""

            if ($port443Open) {
                try {
                    $resp = Invoke-WebRequest -Uri "https://$ip" -UseBasicParsing -TimeoutSec 5
                    if ($resp.ParsedHtml.title) { $webTitle = $resp.ParsedHtml.title }
                } catch {}
            }

            $results += "IP: $ip | Port902: OPEN | Port443: $port443Open | Title: $webTitle | Status: POSSIBLE ESXi - PLEASE CONFIRM"
        }
    }
}

if ($doExport -and $results.Count -gt 0) {
    "===== ESXi Discovery Report =====" | Out-File $Output
    "Generated: $(Get-Date)" | Out-File $Output -Append
    "Total Hosts Scanned: $totalScanned" | Out-File $Output -Append
    "ESXi Suspects Found: $esxiFound" | Out-File $Output -Append
    "" | Out-File $Output -Append
    $results | Out-File $Output -Append
}

Write-Host "`n`n===== SCAN SUMMARY =====" -ForegroundColor Cyan
Write-Host "Total hosts scanned : $totalScanned"
Write-Host "ESXi suspects found : $esxiFound"
if ($doExport) { Write-Host "Report saved to     : $Output" }
