#!/usr/bin/env bash
# ----------------------------------------------------------------------
# scripts/build_report.sh
#
# One-shot compile of author-kit-CVPR2026-v1-latex-/report.tex
# (PDF + cross-references + bibliography) on macOS / Linux.
#
# Usage:
#     bash scripts/build_report.sh                # build report.pdf
#     bash scripts/build_report.sh --clean        # clean aux files first
#     bash scripts/build_report.sh --open         # open the PDF after build
#
# Requires a working TeX distribution (BasicTeX / MacTeX / TeX Live).
# If pdflatex is not on PATH, the script tries common BasicTeX/MacTeX
# locations on macOS.
# ----------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"
TEX_DIR="$PROJECT_ROOT/author-kit-CVPR2026-v1-latex-"
TEX_MAIN="report"

DO_CLEAN=0
DO_OPEN=0
for arg in "$@"; do
    case "$arg" in
        --clean) DO_CLEAN=1 ;;
        --open)  DO_OPEN=1 ;;
        -h|--help)
            sed -n '1,20p' "$0"; exit 0 ;;
    esac
done

# Try to locate a TeX binary if not already on PATH.
if ! command -v pdflatex >/dev/null 2>&1; then
    for d in /Library/TeX/texbin /usr/local/texlive/2024basic/bin/universal-darwin \
             /usr/local/texlive/2024/bin/universal-darwin \
             /usr/local/texlive/2023basic/bin/universal-darwin \
             /opt/homebrew/bin /usr/local/bin; do
        if [[ -x "$d/pdflatex" ]]; then
            export PATH="$d:$PATH"
            echo "[build_report] added $d to PATH"
            break
        fi
    done
fi

if ! command -v pdflatex >/dev/null 2>&1; then
    echo "[build_report] ERROR: no pdflatex on PATH." >&2
    echo "  Install BasicTeX (recommended on macOS):" >&2
    echo "    curl -fL -o /tmp/BasicTeX.pkg https://mirror.ctan.org/systems/mac/mactex/mactex-basictex-20240311.pkg" >&2
    echo "    sudo installer -pkg /tmp/BasicTeX.pkg -target /" >&2
    echo "    eval \"\$(/usr/libexec/path_helper)\"" >&2
    echo "    sudo tlmgr update --self && sudo tlmgr install latexmk multirow subcaption caption type1cm" >&2
    exit 1
fi

cd "$TEX_DIR"
echo "[build_report] working dir: $TEX_DIR"
echo "[build_report] pdflatex   : $(command -v pdflatex)"

if [[ $DO_CLEAN -eq 1 ]]; then
    echo "[build_report] cleaning aux files..."
    rm -f "$TEX_MAIN".{aux,bbl,blg,brf,log,out,toc,fls,fdb_latexmk,synctex.gz}
fi

# Prefer latexmk if available; otherwise do the manual 4-pass.
if command -v latexmk >/dev/null 2>&1; then
    echo "[build_report] using latexmk"
    latexmk -pdf -interaction=nonstopmode -halt-on-error "$TEX_MAIN.tex"
else
    echo "[build_report] latexmk not found, doing manual 4-pass"
    pdflatex -interaction=nonstopmode -halt-on-error "$TEX_MAIN.tex"
    if command -v bibtex >/dev/null 2>&1; then
        bibtex "$TEX_MAIN" || true
    else
        echo "[build_report] WARN: bibtex missing, citations may be unresolved"
    fi
    pdflatex -interaction=nonstopmode -halt-on-error "$TEX_MAIN.tex"
    pdflatex -interaction=nonstopmode -halt-on-error "$TEX_MAIN.tex"
fi

PDF_PATH="$TEX_DIR/$TEX_MAIN.pdf"
if [[ -f "$PDF_PATH" ]]; then
    SZ=$(wc -c < "$PDF_PATH" | awk '{printf "%.1f MB", $1/1048576}')
    echo "[build_report] DONE -> $PDF_PATH ($SZ)"
    if [[ $DO_OPEN -eq 1 ]] && command -v open >/dev/null 2>&1; then
        open "$PDF_PATH"
    fi
else
    echo "[build_report] FAILED: $PDF_PATH not produced." >&2
    exit 1
fi
