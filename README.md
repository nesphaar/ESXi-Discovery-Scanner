# ESXi Network Discovery Tool (PowerShell)

Interactive PowerShell script for discovering VMware ESXi hosts across a network by scanning for VMware-specific services and web interface fingerprints.

This tool is designed for infrastructure administrators who need to quickly identify ESXi hosts in medium to large internal networks.

---

## 🔍 What This Script Does

The scanner detects potential ESXi hosts using:

- **TCP Port 902** — VMware management service  
- **TCP Port 443** — ESXi web interface  
- **Web title fingerprinting** — Matches `VMware` or `ESXi`

It provides:

- Live console progress
- Total hosts scanned counter
- ESXi hosts found counter
- Optional CSV export

---

## 🖥 Requirements

- Windows PowerShell 5.1+ or PowerShell 7+
- Network access to target subnets
- Permission to scan the network

---

## 🚀 How It Works

1. Script asks for:
   - Network base address (example: `192.168.1.0`)
   - CIDR mask (`16` or `24`)
   - Whether to export results to CSV

2. It then:
   - Iterates through all valid host IPs
   - Performs fast TCP checks with timeouts
   - Queries HTTPS service for ESXi signature
   - Displays real-time scan stats

---

## ▶️ Usage

```powershell
Set-ExecutionPolicy Bypass -Scope Process
.\Find-ESXi.ps1
