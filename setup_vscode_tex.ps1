[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$vscodeDir = Join-Path $repoRoot ".vscode"

New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null

$extensions = @"
{
  "recommendations": [
    "James-Yu.latex-workshop"
  ]
}
"@

$settings = @"
{
  "files.associations": {
    "*.tex": "latex"
  },
  "latex-workshop.latex.autoBuild.run": "onSave",
  "latex-workshop.latex.outDir": "%DIR%/out",
  "latex-workshop.view.pdf.viewer": "tab",
  "latex-workshop.view.pdf.internal.synctex.keybinding": "double-click",
  "latex-workshop.latex.tools": [
    {
      "name": "latexmk",
      "command": "latexmk",
      "args": [
        "-synctex=1",
        "-interaction=nonstopmode",
        "-file-line-error",
        "-pdf",
        "-outdir=%OUTDIR%",
        "%DOC%"
      ]
    },
    {
      "name": "xelatex",
      "command": "xelatex",
      "args": [
        "-synctex=1",
        "-interaction=nonstopmode",
        "-file-line-error",
        "-output-directory=%OUTDIR%",
        "%DOC%"
      ]
    },
    {
      "name": "pdflatex",
      "command": "pdflatex",
      "args": [
        "-synctex=1",
        "-interaction=nonstopmode",
        "-file-line-error",
        "-output-directory=%OUTDIR%",
        "%DOC%"
      ]
    }
  ],
  "latex-workshop.latex.recipes": [
    {
      "name": "latexmk (pdf)",
      "tools": [
        "latexmk"
      ]
    },
    {
      "name": "xelatex",
      "tools": [
        "xelatex"
      ]
    },
    {
      "name": "pdflatex",
      "tools": [
        "pdflatex"
      ]
    }
  ]
}
"@

$tasks = @"
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "LaTeX: Build (latexmk)",
      "type": "shell",
      "command": "latexmk",
      "args": [
        "-synctex=1",
        "-interaction=nonstopmode",
        "-file-line-error",
        "-pdf",
        "-outdir=out",
        "dissertation.tex"
      ],
      "group": "build",
      "problemMatcher": []
    }
  ]
}
"@

Set-Content -LiteralPath (Join-Path $vscodeDir "extensions.json") -Value $extensions -Encoding UTF8
Set-Content -LiteralPath (Join-Path $vscodeDir "settings.json") -Value $settings -Encoding UTF8
Set-Content -LiteralPath (Join-Path $vscodeDir "tasks.json") -Value $tasks -Encoding UTF8

Write-Host "VS Code LaTeX config written to: $vscodeDir" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1) Install extension: James-Yu.latex-workshop" -ForegroundColor DarkGray
Write-Host "  2) Install a TeX distribution (MiKTeX or TeX Live) so latexmk/xelatex exist on PATH" -ForegroundColor DarkGray
Write-Host "  3) Open dissertation.tex and save to auto-build" -ForegroundColor DarkGray
