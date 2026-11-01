# ---------------------------------------------------------------------------
# install_flutter.ps1
# Installe le SDK Flutter (version stable) sur Windows.
#
# A EXECUTER DANS TON PROPRE POWERSHELL (celui de Windows), PAS dans le shell
# de l'assistant (qui n'a pas d'acces HTTPS).
#
# Usage :
#   PowerShell en Administrateur :
#     Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
#     .\scripts\install_flutter.ps1
#
# Options :
#   -InstallDir "D:\dev"    dossier d'installation (defaut C:\src)
# ---------------------------------------------------------------------------
param(
  [string]$InstallDir = 'C:\src'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host '== Recuperation de la liste des versions Flutter ==' -ForegroundColor Cyan
$index = Invoke-RestMethod 'https://storage.googleapis.com/flutter_infra_release/releases/releases_windows.json'
$hash = $index.current_release.stable
$rel = $index.releases | Where-Object { $_.hash -eq $hash } | Select-Object -First 1
if (-not $rel) { throw "Impossible de determiner la version stable." }

$url = $index.base_url.TrimEnd('/') + '/' + $rel.archive
Write-Host "Version stable : $($rel.version)"
Write-Host "URL            : $url"

$zip = Join-Path $env:TEMP 'flutter_stable.zip'
Write-Host '== Telechargement (environ 1 Go, patience...) ==' -ForegroundColor Cyan
$ProgressPreference = 'SilentlyContinue'
Invoke-WebRequest -Uri $url -OutFile $zip

$target = Join-Path $InstallDir 'flutter'
if (Test-Path (Join-Path $target 'bin\flutter.bat')) {
  Write-Host "Flutter est deja present dans $target" -ForegroundColor Yellow
} else {
  if (-not (Test-Path $InstallDir)) { New-Item -ItemType Directory -Path $InstallDir | Out-Null }
  Write-Host "== Extraction vers $InstallDir ==" -ForegroundColor Cyan
  Expand-Archive -Path $zip -DestinationPath $InstallDir -Force
}

$bin = Join-Path $target 'bin'

Write-Host '== Ajout de Flutter au PATH utilisateur ==' -ForegroundColor Cyan
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
if ($null -eq $userPath) { $userPath = '' }
if ($userPath -notlike "*$bin*") {
  [Environment]::SetEnvironmentVariable('Path', ($userPath.TrimEnd(';') + ';' + $bin), 'User')
  Write-Host "PATH mis a jour. Rouvre ton terminal apres ce script."
}
$env:Path = $env:Path + ';' + $bin

Write-Host '== flutter --version ==' -ForegroundColor Cyan
& (Join-Path $bin 'flutter.bat') --version

Write-Host '== flutter doctor ==' -ForegroundColor Cyan
& (Join-Path $bin 'flutter.bat') doctor

Write-Host ''
Write-Host 'Termine.' -ForegroundColor Green
Write-Host 'Etapes suivantes (dans un NOUVEAU terminal) :'
Write-Host '  1) Installer Android Studio (SDK + emulateur) : https://developer.android.com/studio'
Write-Host '  2) flutter doctor --android-licenses   (repondre y)'
Write-Host '  3) cd "gpm_ebc"; flutter create .; flutter pub get; flutter run'
