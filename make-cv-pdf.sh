#!/usr/bin/env bash
# Regenerate the CV PDF from README.md (fully local: pandoc + chromium).
# Usage:
#   ./make-cv-pdf.sh                 # output name auto-detected from git branch
#   ./make-cv-pdf.sh README.md out.pdf
#
# Deps: pandoc, chromium (both already installed). No npm, no network token cost.
# Note: the shields.io badges are fetched over the network at build time.
set -euo pipefail
cd "$(dirname "$0")"

md="${1:-README.md}"
if [ -n "${2:-}" ]; then
  out="$2"
elif [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "es" ]; then
  out="ResumeAds-ES.pdf"
else
  out="Adrian_cv_print.pdf"
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/style.css" <<'CSS'
@page { size: A4; margin: 14mm 16mm; }
body { font-family: "Noto Sans", "DejaVu Sans", sans-serif; font-size: 10.5pt; line-height: 1.45; color: #1a1a1a; }
header#title-block-header, .title { display: none; }   /* hide pandoc's auto title; the logo is the header */
h2 { border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-top: 18px; font-size: 15pt; }
h3 { margin-bottom: 2px; font-size: 12pt; }
h3 + p, h3 + ul { margin-top: 2px; }
p img { vertical-align: middle; }
img[src$=".svg"] { height: 54px; }
ul { margin-top: 4px; padding-left: 18px; }
li { margin-bottom: 2px; }
a { color: #0a66c2; text-decoration: none; }
code { background: #f3f3f3; padding: 1px 3px; border-radius: 3px; font-size: 9.5pt; }
CSS

pandoc "$md" -f gfm -t html5 -s \
  --metadata title="CV" \
  --css "$tmp/style.css" \
  --embed-resources --standalone \
  -o "$tmp/cv.html"

chromium --headless=new --no-sandbox --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=15000 \
  --print-to-pdf="$out" \
  "$tmp/cv.html" 2>/dev/null

echo "Wrote $out ($(du -h "$out" | cut -f1), $(pdfinfo "$out" 2>/dev/null | awk '/^Pages/{print $2" pages"}'))"
