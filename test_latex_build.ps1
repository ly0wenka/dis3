[CmdletBinding()]
param(
  [string]$TexFile = "dissertation.tex",
  [string]$OutDir = "out",
  [switch]$InstallMiKTeX,
  [switch]$Clean
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

function Have-Command([string]$name) {
  return $null -ne (Get-Command $name -ErrorAction SilentlyContinue)
}

function Add-ToPathIfMissing([string]$dir) {
  if (-not $dir) { return }
  if (-not (Test-Path -LiteralPath $dir)) { return }
  $parts = ($env:PATH -split ';') | Where-Object { $_ -ne '' }
  if ($parts -contains $dir) { return }
  $env:PATH = ($dir + ';' + $env:PATH)
}

function Try-UseMiKTeXBin() {
  $candidateDirs = @(
    "$env:LOCALAPPDATA\\Programs\\MiKTeX\\miktex\\bin\\x64",
    "$env:LOCALAPPDATA\\Programs\\MiKTeX\\miktex\\bin",
    "$env:ProgramFiles\\MiKTeX\\miktex\\bin\\x64",
    "$env:ProgramFiles\\MiKTeX\\miktex\\bin",
    "$env:ProgramFiles(x86)\\MiKTeX\\miktex\\bin\\x64",
    "$env:ProgramFiles(x86)\\MiKTeX\\miktex\\bin"
  )

  foreach ($dir in $candidateDirs) {
    if (-not $dir) { continue }
    if (-not (Test-Path -LiteralPath $dir)) { continue }
    $latexmk = Join-Path $dir "latexmk.exe"
    if (Test-Path -LiteralPath $latexmk) {
      Add-ToPathIfMissing $dir
      return $true
    }
  }

  return $false
}

function Ensure-MiKTeX() {
  if (Have-Command latexmk) { return }
  if (Try-UseMiKTeXBin) { return }
  if (Have-Command latexmk) { return }

  if (-not $InstallMiKTeX) {
    throw "Missing TeX tools (latexmk not found). Install MiKTeX or rerun with -InstallMiKTeX."
  }

  if (Have-Command winget) {
    Write-Host "Installing MiKTeX via winget..." -ForegroundColor Cyan
    & winget install --id MiKTeX.MiKTeX -e --source winget --accept-source-agreements --accept-package-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0) { throw "winget install failed with exit code $LASTEXITCODE" }
    return
  }

  if (Have-Command choco) {
    Write-Host "Installing MiKTeX via chocolatey..." -ForegroundColor Cyan
    & choco install miktex -y
    if ($LASTEXITCODE -ne 0) { throw "choco install failed with exit code $LASTEXITCODE" }
    return
  }

  throw "No installer found (need winget or choco). Install MiKTeX manually from https://miktex.org/download and ensure latexmk is on PATH."
}

$texPath = Join-Path $repoRoot $TexFile
if (-not (Test-Path -LiteralPath $texPath)) {
  throw "TeX file not found: $texPath"
}

Ensure-MiKTeX
if (-not (Have-Command latexmk) -and (Try-UseMiKTeXBin)) {
  # PATH adjusted, re-check below
}

New-Item -ItemType Directory -Force -Path (Join-Path $repoRoot $OutDir) | Out-Null

if ($Clean) {
  if (-not (Have-Command latexmk)) { throw "latexmk not found (cannot clean)." }
  Write-Host "Cleaning..." -ForegroundColor Cyan
  & latexmk -C -outdir=$OutDir $texPath
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if (-not (Have-Command latexmk)) {
  throw "latexmk still not found after install step. Restart your terminal/VS Code and try again."
}

Write-Host "Building $TexFile (XeLaTeX via latexmk)..." -ForegroundColor Cyan
& latexmk -xelatex -synctex=1 -interaction=nonstopmode -file-line-error -pdf -outdir=$OutDir $texPath
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$pdfPath = Join-Path (Join-Path $repoRoot $OutDir) ([System.IO.Path]::GetFileNameWithoutExtension($texPath) + ".pdf")
if (-not (Test-Path -LiteralPath $pdfPath)) {
  throw "Build finished but PDF not found: $pdfPath"
}

Write-Host "OK: $pdfPath" -ForegroundColor Green
