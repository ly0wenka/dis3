[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$InputDocx,

  [Parameter(Position = 1)]
  [string]$OutputTex,

  [string]$MediaDir,

  [switch]$All,

  [switch]$Fragment,

  [switch]$Overwrite,

  [switch]$NoDownload,

  [string[]]$PandocArgs = @()
)

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot

function Get-FullPath([string]$path, [string]$baseDir) {
  if (-not $path) { return $null }
  if ([System.IO.Path]::IsPathRooted($path)) {
    return [System.IO.Path]::GetFullPath($path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $baseDir $path))
}

function Get-PandocExe([switch]$NoDownload) {
  if ($env:PANDOC_PATH) {
    $candidate = $env:PANDOC_PATH
    if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
  }

  $cmd = Get-Command pandoc -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }

  $toolsDir = Join-Path $repoRoot "tools\\pandoc"
  $existing = Get-ChildItem -Path $toolsDir -Recurse -Filter "pandoc.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($existing) { return $existing.FullName }

  if ($NoDownload) {
    throw "pandoc not found. Install pandoc or set PANDOC_PATH."
  }

  Install-Pandoc

  $downloaded = Get-ChildItem -Path $toolsDir -Recurse -Filter "pandoc.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($downloaded) { return $downloaded.FullName }

  throw "pandoc download completed but pandoc.exe was not found under tools\\pandoc."
}

function Install-Pandoc() {
  $toolsDir = Join-Path $repoRoot "tools\\pandoc"
  $downloadDir = Join-Path $toolsDir "downloads"
  $distDir = Join-Path $toolsDir "dist"

  New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null

  $headers = @{ "User-Agent" = "dis3-docx-to-tex" }
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/jgm/pandoc/releases/latest" -Headers $headers
  $asset = $release.assets | Where-Object { $_.name -match 'windows-x86_64\.zip$' } | Select-Object -First 1
  if (-not $asset) {
    throw "Could not find a pandoc windows-x86_64.zip asset in the latest release."
  }

  $zipName = $asset.name
  $zipPath = Join-Path $downloadDir $zipName

  if (-not (Test-Path -LiteralPath $zipPath)) {
    Write-Host "Downloading pandoc $($release.tag_name)..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -Headers $headers
  }

  if (Test-Path -LiteralPath $distDir) {
    Remove-Item -Recurse -Force -LiteralPath $distDir
  }
  New-Item -ItemType Directory -Force -Path $distDir | Out-Null

  Write-Host "Extracting pandoc..." -ForegroundColor Cyan
  Expand-Archive -LiteralPath $zipPath -DestinationPath $distDir -Force
}

function Convert-OneDocxToTex([string]$docxPath, [string]$texPath, [string]$mediaPath, [switch]$Fragment, [switch]$Overwrite, [string[]]$PandocArgs) {
  $pandocExe = Get-PandocExe -NoDownload:$NoDownload

  $texDir = Split-Path -Parent $texPath
  if ($texDir -and -not (Test-Path -LiteralPath $texDir)) {
    New-Item -ItemType Directory -Force -Path $texDir | Out-Null
  }

  if (Test-Path -LiteralPath $texPath) {
    if (-not $Overwrite) {
      throw "Output exists: $texPath (use -Overwrite to replace)."
    }
    Remove-Item -Force -LiteralPath $texPath
  }

  if ($mediaPath) {
    New-Item -ItemType Directory -Force -Path $mediaPath | Out-Null
  }

  $args = @(
    $docxPath,
    "--from=docx",
    "--to=latex",
    "--wrap=none",
    ("--output=" + $texPath)
  )

  if ($mediaPath) {
    $args += ("--extract-media=" + $mediaPath)
  }

  if (-not $Fragment) {
    $args += "--standalone"
  }

  if ($PandocArgs -and $PandocArgs.Count -gt 0) {
    $args += $PandocArgs
  }

  Write-Host "Running pandoc:" -ForegroundColor Cyan
  Write-Host "  $pandocExe $($args -join ' ')" -ForegroundColor DarkGray

  & $pandocExe @args
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  if (-not (Test-Path -LiteralPath $texPath)) {
    throw "pandoc finished but output was not created: $texPath"
  }

  Write-Host "Wrote: $texPath" -ForegroundColor Green
}

if ($All) {
  $docxFiles = Get-ChildItem -Path $repoRoot -Recurse -File -Filter "*.docx" |
    Where-Object { $_.FullName -notlike "*\\.git\\*" -and $_.FullName -notlike "*\\tools\\pandoc\\*" }

  if (-not $docxFiles -or $docxFiles.Count -eq 0) {
    throw "No .docx files found under $repoRoot"
  }

  foreach ($docx in $docxFiles) {
    $docxPath = $docx.FullName
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($docxPath)
    $outTex = Join-Path (Split-Path -Parent $docxPath) ($baseName + ".pandoc.tex")
    $media = Join-Path $repoRoot ("media\\" + $baseName)
    Convert-OneDocxToTex -docxPath $docxPath -texPath $outTex -mediaPath $media -Fragment:$Fragment -Overwrite:$Overwrite -PandocArgs $PandocArgs
  }
  exit 0
}

if (-not $InputDocx) {
  $defaultDocx = Join-Path $repoRoot "dis_K_100.docx"
  if (Test-Path -LiteralPath $defaultDocx) {
    $InputDocx = $defaultDocx
  } else {
    $firstDocx = Get-ChildItem -Path $repoRoot -File -Filter "*.docx" | Select-Object -First 1
    if (-not $firstDocx) { throw "No .docx files found in $repoRoot" }
    $InputDocx = $firstDocx.FullName
  }
}

$docxPath = Get-FullPath $InputDocx $repoRoot
if (-not (Test-Path -LiteralPath $docxPath)) {
  throw "Input .docx not found: $docxPath"
}

if (-not $OutputTex) {
  if ((Split-Path -Leaf $docxPath) -ieq "dis_K_100.docx") {
    $OutputTex = Join-Path $repoRoot "dissertation.pandoc.tex"
  } else {
    $baseName = [System.IO.Path]::GetFileNameWithoutExtension($docxPath)
    $OutputTex = Join-Path $repoRoot ($baseName + ".pandoc.tex")
  }
}

$texPath = Get-FullPath $OutputTex $repoRoot

if (-not $MediaDir) {
  $MediaDir = Join-Path $repoRoot "media"
}
$mediaPath = Get-FullPath $MediaDir $repoRoot

Convert-OneDocxToTex -docxPath $docxPath -texPath $texPath -mediaPath $mediaPath -Fragment:$Fragment -Overwrite:$Overwrite -PandocArgs $PandocArgs
