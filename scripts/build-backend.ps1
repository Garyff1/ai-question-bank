param(
  [string]$Python = "",
  [string]$TargetTriple = ""
)

$ErrorActionPreference = "Stop"
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}
$RepoRoot = Split-Path -Parent $PSScriptRoot
$BackendDir = Join-Path $RepoRoot "backend"
$BinaryDir = Join-Path $RepoRoot "src-tauri\binaries"

function Invoke-ProjectPython {
  if ($Python) {
    & $Python @args
    return
  }
  $pyLauncher = Get-Command py -ErrorAction SilentlyContinue
  if ($pyLauncher) {
    & py -3 @args
    return
  }
  & python @args
}

Push-Location $BackendDir
try {
  $oldErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  Invoke-ProjectPython "-m" "PyInstaller" "--version" *> $null
  $hasPyInstaller = $LASTEXITCODE -eq 0
  $ErrorActionPreference = $oldErrorActionPreference

  if (-not $hasPyInstaller) {
    Invoke-ProjectPython "-m" "pip" "install" "pyinstaller"
  }

  Invoke-ProjectPython "-m" "PyInstaller" "--noconfirm" "backend.spec"
  if ($LASTEXITCODE -ne 0) {
    throw "PyInstaller build failed."
  }
}
finally {
  Pop-Location
}

if (-not $TargetTriple) {
  $TargetTriple = "x86_64-pc-windows-msvc"
  $rustc = Get-Command rustc -ErrorAction SilentlyContinue
  if ($rustc) {
    $triple = (& rustc -Vv | Select-String "host:").ToString().Split(":", 2)[1].Trim()
    if ($triple) { $TargetTriple = $triple }
  }
}

New-Item -ItemType Directory -Force -Path $BinaryDir | Out-Null
$SourceExe = Join-Path $BackendDir "dist\backend.exe"
$TargetExe = Join-Path $BinaryDir "backend-$TargetTriple.exe"
Copy-Item -LiteralPath $SourceExe -Destination $TargetExe -Force

Write-Host "Backend sidecar ready: $TargetExe"
