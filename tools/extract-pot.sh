#!/usr/bin/env bash
# Extract a single .pot file from all .rsj files produced by lazbuild.
#
# Usage: tools/extract-pot.sh [LIB_DIR] [OUT_POT]
#   LIB_DIR defaults to lib/x86_64-linux (set by bttwriter2.lpi)
#   OUT_POT defaults to cge/locale/btt-writer.pot
#
# Prereqs: rstconv (Free Pascal RTL), msgcat (gettext).
#
# Run after `lazbuild bttwriter2.lpi` so the .rsj files are current.

set -euo pipefail

LIB_DIR="${1:-lib/x86_64-linux}"
OUT_POT="${2:-cge/locale/btt-writer.pot}"

if [[ ! -d "$LIB_DIR" ]]; then
  echo "error: $LIB_DIR not found — run lazbuild first" >&2
  exit 1
fi

shopt -s nullglob
RSJ_FILES=("$LIB_DIR"/*.rsj)
if [[ ${#RSJ_FILES[@]} -eq 0 ]]; then
  echo "error: no .rsj files in $LIB_DIR" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_POT")"
TMPD=$(mktemp -d)
trap 'rm -rf "$TMPD"' EXIT

mkdir -p "$TMPD/raw" "$TMPD/merged"
for rsj in "${RSJ_FILES[@]}"; do
  unit=$(basename "$rsj" .rsj)
  rstconv -i "$rsj" -o "$TMPD/raw/$unit.po" -f po -c utf-8 2>/dev/null
  # Same English text can have multiple resourcestring keys in one unit
  # (e.g., rsCancelBtn and rsDupCancel both "Cancel"). msgcat refuses
  # dupes within a single file, so collapse each unit with msguniq first.
  msguniq --use-first "$TMPD/raw/$unit.po" -o "$TMPD/merged/$unit.po"
done

# Extract LFM-baked captions into their own .po fragment. These are keyed
# by component identifier path (e.g. tmainwindow.lblappname.caption),
# which is what LCL's TPOTranslator looks up at form-load time.
LFM_RAW="$TMPD/raw/_lfm.po"
{
  printf 'msgid ""\nmsgstr ""\n"MIME-Version: 1.0\\n"\n"Content-Type: text/plain; charset=utf-8\\n"\n"Content-Transfer-Encoding: 8bit\\n"\n'
  python3 "$(dirname "$0")/extract-lfm-strings.py"
} > "$LFM_RAW"
msguniq --use-first "$LFM_RAW" -o "$TMPD/merged/_lfm.po"

# Merge: --use-first keeps the first occurrence (alphabetical unit order).
# Stamp the result as a .pot template by clearing the Language header.
msgcat --use-first "$TMPD/merged"/*.po \
  | sed -e 's/^"Language: .*$/"Language: \\n"/' \
        -e '1,/^$/s|^"Project-Id-Version: .*$|"Project-Id-Version: btt-writer\\n"|' \
  > "$OUT_POT"

COUNT=$(grep -c '^msgid "' "$OUT_POT" || true)
echo "wrote $OUT_POT ($COUNT msgids from ${#RSJ_FILES[@]} units)"
