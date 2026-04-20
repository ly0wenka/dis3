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

function Ensure-MiKTeX() {
  if (Have-Command latexmk) { return }

  if (-not $InstallMiKTeX) {
    throw "Missing TeX tools (latexmk not found). Install MiKTeX or rerun with -InstallMiKTeX."
  }

  if (Have-Command winget) {
    Write-Host "Installing MiKTeX via winget..." -ForegroundColor Cyan
    & winget install --id MiKTeX.MiKTeX -e --source winget
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
