<#
.SYNOPSIS
  Installs (or updates) HisaabChat from the files next to this script.

.DESCRIPTION
  HisaabChat.msix is signed with a self-signed certificate, so Windows has
  to trust HisaabChat.cer before it will install it. The first run asks for
  administrator rights once to add the certificate to "Trusted People";
  later updates install without asking.

  Right-click this file > Run with PowerShell, or:
    powershell -ExecutionPolicy Bypass -File Install-HisaabChat.ps1
#>
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$cer = Join-Path $here 'HisaabChat.cer'
$msix = Join-Path $here 'HisaabChat.msix'

$cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $cer
$trusted = Get-ChildItem Cert:\LocalMachine\TrustedPeople | Where-Object Thumbprint -eq $cert.Thumbprint
if (-not $trusted) {
  Write-Host 'Trusting the HisaabChat certificate (Windows will ask for permission) ...'
  $command = "Import-Certificate -FilePath '$cer' -CertStoreLocation Cert:\LocalMachine\TrustedPeople | Out-Null"
  Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile', '-Command', $command
}

Write-Host 'Installing HisaabChat ...'
Add-AppxPackage -Path $msix -ForceUpdateFromAnyVersion
Write-Host 'Done. Open HisaabChat from the Start menu.'
