$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$ReleaseDir = Join-Path $RepoRoot "src-tauri\target\x86_64-pc-windows-gnu\release"
$OutputDir = Join-Path $RepoRoot "artifacts"
$PackageRoot = Join-Path $RepoRoot "src-tauri\target\desktop-package"
$AppDir = Join-Path $PackageRoot "AIQuestionBank"
$ZipPath = Join-Path $OutputDir "ai-question-bank-desktop-windows.zip"

if (-not (Test-Path (Join-Path $ReleaseDir "ai-question-bank.exe"))) {
  throw "Release executable not found. Run the Tauri build first."
}

Remove-Item -LiteralPath $AppDir -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $AppDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Copy-Item (Join-Path $ReleaseDir "ai-question-bank.exe") (Join-Path $AppDir "ai-question-bank.exe") -Force
Copy-Item (Join-Path $ReleaseDir "backend.exe") (Join-Path $AppDir "backend.exe") -Force
Copy-Item (Join-Path $ReleaseDir "WebView2Loader.dll") (Join-Path $AppDir "WebView2Loader.dll") -Force

@(
  "AI Question Bank Desktop",
  "",
  "How to use:",
  "1. Extract the whole folder.",
  "2. Double-click ai-question-bank.exe.",
  "3. The desktop app starts the bundled FastAPI backend automatically.",
  "",
  "Notes:",
  "- Keep backend.exe and WebView2Loader.dll next to ai-question-bank.exe.",
  "- On first launch, Windows Security may ask for confirmation."
) | Set-Content -LiteralPath (Join-Path $AppDir "README.txt") -Encoding UTF8

Remove-Item -LiteralPath $ZipPath -Force -ErrorAction SilentlyContinue
Compress-Archive -Path (Join-Path $AppDir "*") -DestinationPath $ZipPath -Force

Get-Item $ZipPath | Select-Object FullName, Length
