# ==========================================
# ESXi Discovery Scanner
# Interactive version
# ==========================================

Clear-Host
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "        ESXi Network Discovery Tool       " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# ---- USER INPUT ----
$networkInput = Read-Host "Enter network base (example: 192.168.1.0)"
$cidrInput    = Read-Host "Enter CIDR mask (example: 24)"

$exportChoice = Read-Host "Export results to CSV? (Y/N)"
$doExport = $exportChoice -match "^[Yy]"

if ($doExport) {
    $Output = Join-Path (Get-Location) "esxi_hosts.csv"
}

# ---- Counters ----
$totalScanned = 0
$esxiFound    = 0
$results      = @()

Write-Host "`nStarting scan..." -ForegroundColor Green

# ------------------------------------------------
# Fast TCP Port Check
# ------------------------------------------------
function Test-TcpPortFast {
    param (
        [string]$IP,
        [int]$Port,
        [int]$TimeoutMs = 3000
    )

    try {
        $client = New-Object System.Net.Sockets.TcpClient
        $iar = $client.BeginConnect($IP, $Port, $null, $null)
        $success = $iar.AsyncWaitHandle.WaitOne($TimeoutMs, $false)

        if (-not $success) {
            $client.Close()
            return $false
        }

        $client.EndConnect($iar)
        $client.Close()
        return $true
    }
    catch { return $false }
}

# ------------------------------------------------
# Trust self-signed certs
# ------------------------------------------------
add-type @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
    public bool CheckValidationResult(
        ServicePoint srvPoint, X509Certificate certificate,
        WebRequest request, int certificateProblem) {
        return true;
    }
}
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy


# ------------------------------------------------
# Calculate scan ranges from CIDR
# ------------------------------------------------
$baseParts = $networkInput.Split(".")
$oct1 = [int]$baseParts[0]
$oct2 = [int]$baseParts[1]
$oct3 = [int]$baseParts[2]

if ($cidrInput -eq "24") {
    $subnetStart = $oct3
    $subnetEnd   = $oct3
}
elseif ($cidrInput -eq "16") {
    $subnetStart = 0
    $subnetEnd   = 255
}
else {
    Write-Host "Only /16 and /24 supported in this version." -ForegroundColor Red
    exit
}

# ------------------------------------------------
# Scan Loop
# ------------------------------------------------
for ($subnet=$subnetStart; $subnet -le $subnetEnd; $subnet++) {

    Write-Host "`nScanning subnet $oct1.$oct2.$subnet.0/$cidrInput" -ForegroundColor DarkGray

    for ($node=1; $node -le 254; $node++) {

        $ip = "$oct1.$oct2.$subnet.$node"
        $totalScanned++

        $status = "Hosts scanned: $totalScanned | ESXi found: $esxiFound | Current: $ip"
        Write-Host "`r$status" -NoNewline

        $port902Open = Test-TcpPortFast -IP $ip -Port 902

        if ($port902Open) {

            Write-Host "`nPort 902 open on $ip (Possible ESXi)" -ForegroundColor Yellow

            $port443Open = Test-TcpPortFast -IP $ip -Port 443
            $webTitle = ""
            $esxiConfirmed = $false

            if ($port443Open) {
                try {
                    $resp = Invoke-WebRequest -Uri "https://$ip" -UseBasicParsing -TimeoutSec 5
                    if ($resp.ParsedHtml -and $resp.ParsedHtml.title) {
                        $webTitle = $resp.ParsedHtml.title

                        if ($webTitle -match "VMware|ESXi") {
                            $esxiConfirmed = $true
                            $esxiFound++
                            Write-Host "Confirmed ESXi host at $ip" -ForegroundColor Green
                        }
                    }
                }
                catch {
                    Write-Host "HTTPS reachable but title unreadable on $ip" -ForegroundColor DarkYellow
                }
            }

            $results += [PSCustomObject]@{
                IP_Address      = $ip
                Port_902_Open   = $true
                Port_443_Open   = $port443Open
                Web_Title       = $webTitle
                ESXi_Confirmed  = $esxiConfirmed
            }
        }
    }
}

# ------------------------------------------------
# Export Results
# ------------------------------------------------
if ($doExport -and $results.Count -gt 0) {
    $results | Export-Csv $Output -NoTypeInformation -Encoding UTF8
}

Write-Host "`n`n===== SCAN SUMMARY =====" -ForegroundColor Cyan
Write-Host "Total hosts scanned : $totalScanned"
Write-Host "ESXi hosts found    : $esxiFound"

if ($doExport) {
    Write-Host "Results saved to    : $Output"
}
