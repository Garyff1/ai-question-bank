$ErrorActionPreference = "Stop"

$MinGwRoot = $env:MINGW64_ROOT
if (-not $MinGwRoot) {
  $DefaultRoot = "H:\DevTools\mingw-w64-gcc\xpack-mingw-w64-gcc-15.2.0-2"
  if (Test-Path $DefaultRoot) {
    $MinGwRoot = $DefaultRoot
  }
}

if (-not $MinGwRoot -or -not (Test-Path $MinGwRoot)) {
  throw "MinGW-w64 was not found. Install MinGW-w64 or set MINGW64_ROOT."
}

$BinDir = Join-Path $MinGwRoot "bin"
$TargetBinDir = Join-Path $MinGwRoot "x86_64-w64-mingw32\bin"

if (-not (Test-Path (Join-Path $BinDir "gcc.exe"))) {
  $Gcc = Join-Path $BinDir "x86_64-w64-mingw32-gcc.exe"
  if (Test-Path $Gcc) {
    Copy-Item $Gcc (Join-Path $BinDir "gcc.exe") -Force
  }
}

if (-not (Test-Path (Join-Path $BinDir "windres.exe"))) {
  $Windres = Join-Path $BinDir "x86_64-w64-mingw32-windres.exe"
  if (Test-Path $Windres) {
    Copy-Item $Windres (Join-Path $BinDir "windres.exe") -Force
  }
}

$env:Path = "$env:USERPROFILE\.cargo\bin;$BinDir;$TargetBinDir;C:\Program Files\nodejs;$env:Path"
$env:RUSTUP_TOOLCHAIN = "stable-x86_64-pc-windows-gnu"

Write-Host "GNU Tauri build environment ready."
Write-Host "MinGW-w64: $MinGwRoot"
