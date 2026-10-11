<#
.SYNOPSIS
  Builds the signed Windows installer: build\windows\installer\HisaabChat.msix

.DESCRIPTION
  1. The first time, creates a self-signed code-signing certificate
     (CN=Musaraf Hossain) in %USERPROFILE%\.hisaabchat\ (outside the repo).
     Keep that folder: updates must be signed with the same certificate.
  2. Builds the Windows release (talks to the production API unless
     -ApiBaseUrl is given) and packs it with `dart run msix:create`.
  3. Puts HisaabChat.msix, HisaabChat.cer and Install-HisaabChat.ps1 in
     build\windows\installer\ - zip that folder to share it.

  Run from the app folder:  powershell -File tool\windows\build_msix.ps1
#>
param(
  [string]$ApiBaseUrl = ''
)
$ErrorActionPreference = 'Stop'
$app = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $app

$subject = 'CN=Musaraf Hossain' # must match msix_config.publisher in pubspec.yaml
$certDir = Join-Path $env:USERPROFILE '.hisaabchat'
$pfx = Join-Path $certDir 'hisaabchat-signing.pfx'
$cer = Join-Path $certDir 'hisaabchat-signing.cer'
$passwordFile = Join-Path $certDir 'hisaabchat-signing.password'

if (-not (Test-Path $pfx)) {
  Write-Host "Creating a signing certificate in $certDir ..."
  New-Item -ItemType Directory -Force $certDir | Out-Null
  $cert = New-SelfSignedCertificate -Type Custom -Subject $subject `
    -KeyUsage DigitalSignature -FriendlyName 'HisaabChat code signing' `
    -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddYears(10) `
    -TextExtension @('2.5.29.37={text}1.3.6.1.5.5.7.3.3', '2.5.29.19={text}')
  $plain = [Convert]::ToBase64String((1..24 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]])
  Set-Content -Path $passwordFile -Value $plain -NoNewline
  $secure = ConvertTo-SecureString $plain -AsPlainText -Force
  Export-PfxCertificate -Cert $cert -FilePath $pfx -Password $secure | Out-Null
  Export-Certificate -Cert $cert -FilePath $cer | Out-Null
}
$password = Get-Content $passwordFile -Raw

$buildArgs = @()
if ($ApiBaseUrl) { $buildArgs += "--windows-build-args=--dart-define=API_BASE_URL=$ApiBaseUrl" }

Write-Host 'Building the Windows release and the MSIX ...'
& dart run msix:create --certificate-path $pfx --certificate-password $password @buildArgs
if ($LASTEXITCODE -ne 0) { throw "msix:create failed ($LASTEXITCODE)" }

$out = Join-Path $app 'build\windows\installer'
New-Item -ItemType Directory -Force $out | Out-Null
Copy-Item (Join-Path $app 'build\windows\x64\runner\Release\HisaabChat.msix') $out -Force
Copy-Item $cer (Join-Path $out 'HisaabChat.cer') -Force
Copy-Item (Join-Path $PSScriptRoot 'Install-HisaabChat.ps1') $out -Force

Write-Host ''
Write-Host "Done: $out"
Write-Host '  HisaabChat.msix          the installer'
Write-Host '  HisaabChat.cer           the certificate it is signed with'
Write-Host '  Install-HisaabChat.ps1   trusts the certificate (asks for admin once) and installs'
