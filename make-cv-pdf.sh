#!/usr/bin/env bash
# Regenerate the CV PDF from README.md (fully local: pandoc + chromium).
# Usage:
#   ./make-cv-pdf.sh                 # output name auto-detected from git branch
#   ./make-cv-pdf.sh README.md out.pdf
#
# Deps: pandoc, gawk, perl, chromium (all preinstalled). No npm, no token cost.
# The body font (Spectral, OFL) is vendored in ./fonts, so rendering is
# identical on any machine and the default build needs no network.
#
# Print vs web: the PDF is the restrained, professional version, so by default
# it strips the shields.io badges (-> plain "A · B · C" text) and the section
# emojis. The web README keeps both. Set STRIP_DECORATION=0 to keep them.
set -euo pipefail
cd "$(dirname "$0")"

STRIP_DECORATION="${STRIP_DECORATION:-1}"
fontdir="$PWD/fonts"

md="${1:-README.md}"
if [ -n "${2:-}" ]; then
  out="$2"
elif [ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" = "es" ]; then
  out="Adrian_Skar_CV_ES.pdf"
else
  out="Adrian_Skar_CV_EN.pdf"
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

# Note: heredoc is unquoted so $fontdir expands; the CSS below uses no other
# shell metacharacters ($ or backticks), so this is safe.
cat > "$tmp/style.css" <<CSS
@font-face { font-family:'Spectral'; font-weight:400; font-style:normal; src:url('$fontdir/Spectral-Regular.ttf'); }
@font-face { font-family:'Spectral'; font-weight:400; font-style:italic; src:url('$fontdir/Spectral-Italic.ttf'); }
@font-face { font-family:'Spectral'; font-weight:600; font-style:normal; src:url('$fontdir/Spectral-SemiBold.ttf'); }
@font-face { font-family:'Spectral'; font-weight:700; font-style:normal; src:url('$fontdir/Spectral-Bold.ttf'); }
@page { size: A4; margin: 12mm 15mm; }
body { font-family: 'Spectral', 'Noto Serif', serif; font-size: 10pt; line-height: 1.27; color: #1a1a1a; }
header#title-block-header, .title { display: none; }   /* hide pandoc's auto title; the logo is the header */
h2 { font-weight: 600; text-transform: uppercase; letter-spacing: 0.08em; border-bottom: 1px solid #ddd; padding-bottom: 3px; margin-top: 20px; margin-bottom: 6px; font-size: 12.5pt; }
body > h2:first-of-type { margin-top: 28px; }   /* extra air below the logo/subtitle header */
h3 { font-weight: 600; margin-bottom: 2px; font-size: 11.5pt; }
h3 + p, h3 + ul { margin-top: 2px; }
body > p:first-of-type img { display: block; margin: 0 auto; width: 42%; height: auto; }  /* the logo (data-URI embedding breaks src-based selectors) */
p img { vertical-align: middle; }
ul { margin-top: 4px; padding-left: 18px; }
li { margin-bottom: 2px; }
a { color: #0a66c2; text-decoration: none; }
code { font-family: monospace; background: #f3f3f3; padding: 1px 3px; border-radius: 3px; font-size: 9.5pt; }
CSS

pandoc "$src" -f gfm -t html5 -s \
  --metadata title="CV" \
  --resource-path "$PWD" \
  --css "$tmp/style.css" \
  --embed-resources --standalone \
  -o "$tmp/cv.html"

log="$tmp/chromium.log"
if ! chromium --headless=new --disable-gpu \
     --no-pdf-header-footer \
     --virtual-time-budget=15000 \
     --print-to-pdf="$out" \
     "$tmp/cv.html" >"$log" 2>&1; then
  echo "ERROR: chromium failed to render the PDF:" >&2
  cat "$log" >&2
  exit 1
fi
if [ ! -s "$out" ]; then
  echo "ERROR: $out was not created or is empty:" >&2
  cat "$log" >&2
  exit 1
fi

echo "Wrote $out ($(du -h "$out" | cut -f1), $(pdfinfo "$out" 2>/dev/null | awk '/^Pages/{print $2" pages"}'))"
