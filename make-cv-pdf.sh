#!/usr/bin/env bash
# Regenerate the CV PDF from README.md (fully local: pandoc + chromium).
# Usage:
#   ./make-cv-pdf.sh                 # output name auto-detected from git branch
#   ./make-cv-pdf.sh README.md out.pdf
#
# Deps: pandoc, gawk, chromium (all already installed). No npm, no token cost.
#
# Print vs web: the PDF is meant to be the restrained, professional version,
# so by default it strips the shields.io badges (-> plain "A · B · C" text)
# and the section-heading emojis. The web README keeps both. Set
# STRIP_DECORATION=0 to keep badges/emoji in the PDF too.
set -euo pipefail
cd "$(dirname "$0")"

STRIP_DECORATION="${STRIP_DECORATION:-1}"

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

src="$md"
if [ "$STRIP_DECORATION" = "1" ]; then
  src="$tmp/in.md"
  # 1) Collapse consecutive shields.io badge images into one " · " text line
  #    (the badge alt text is the label, e.g. ![C](...) -> C).
  # 2) Strip emoji everywhere (headings + inline contact icons + flag), while
  #    preserving the → and ↔ arrows (U+2190-21FF) which are real content.
  # 3) Normalise the single space after list markers / headings left behind.
  gawk '
    /img\.shields\.io/ && /^!\[/ {
      if (match($0, /^!\[([^]]*)\]/, a)) list = list (n++ ? " · " : "") a[1]
      inb = 1; next
    }
    { if (inb) { print list; list = ""; n = 0; inb = 0 } print }
    END { if (inb) print list }
  ' "$md" \
  | perl -CSD -pe 's/[\x{1F000}-\x{1FAFF}\x{1F1E6}-\x{1F1FF}\x{2600}-\x{27BF}\x{2B00}-\x{2BFF}\x{FE0F}]//g' \
  | sed -E -e 's/^(#{1,6}) +/\1 /' -e 's/^([-*]) +/\1 /' > "$src"
fi

cat > "$tmp/style.css" <<'CSS'
@page { size: A4; margin: 12mm 15mm; }
body { font-family: "Noto Sans", "DejaVu Sans", sans-serif; font-size: 10pt; line-height: 1.28; color: #1a1a1a; }
header#title-block-header, .title { display: none; }   /* hide pandoc's auto title; the logo is the header */
h2 { border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-top: 13px; margin-bottom: 6px; font-size: 14pt; }
h3 { margin-bottom: 2px; font-size: 11.5pt; }
h3 + p, h3 + ul { margin-top: 2px; }
img { max-height: 80px; width: auto; }   /* caps the logo; data-URI embedding breaks src-based selectors */
p img { vertical-align: middle; }
ul { margin-top: 4px; padding-left: 18px; }
li { margin-bottom: 2px; }
a { color: #0a66c2; text-decoration: none; }
code { background: #f3f3f3; padding: 1px 3px; border-radius: 3px; font-size: 9.5pt; }
CSS

pandoc "$src" -f gfm -t html5 -s \
  --metadata title="CV" \
  --resource-path "$PWD" \
  --css "$tmp/style.css" \
  --embed-resources --standalone \
  -o "$tmp/cv.html"

chromium --headless=new --no-sandbox --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=15000 \
  --print-to-pdf="$out" \
  "$tmp/cv.html" 2>/dev/null

echo "Wrote $out ($(du -h "$out" | cut -f1), $(pdfinfo "$out" 2>/dev/null | awk '/^Pages/{print $2" pages"}'))"
