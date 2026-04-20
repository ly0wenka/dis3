# dis3

## DOCX → LaTeX (.tex)

This repo includes a converter script that uses **pandoc** to convert `.docx` files to `.tex`.

### Quick start (Windows)

```powershell
.\convert_docx_to_tex.ps1
```

By default this converts `dis_K_100.docx` → `dissertation.pandoc.tex` and extracts images to `media\`.

### Useful options

```powershell
# Convert a specific file
.\convert_docx_to_tex.ps1 -InputDocx dis_K_100.docx -OutputTex out.tex -Overwrite

# Convert all .docx files under the repo
.\convert_docx_to_tex.ps1 -All

# Produce a LaTeX fragment (no \\documentclass / preamble)
.\convert_docx_to_tex.ps1 -Fragment
```

### Pandoc installation

- If `pandoc` is already installed and on `PATH`, the script uses it.
- Otherwise it downloads a portable pandoc build into `tools\pandoc\` (gitignored).
- You can also set `PANDOC_PATH` to point to your pandoc executable.

## Build/test LaTeX locally

```powershell
.\test_latex_build.ps1 -InstallMiKTeX
```

This builds `dissertation.tex` with XeLaTeX via `latexmk` and writes the PDF to `out\`.
