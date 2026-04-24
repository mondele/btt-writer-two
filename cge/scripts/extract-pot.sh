#!/bin/bash
# Extract translatable strings from CGE code into a Crowdin-ready .pot file.
#
# How it works:
#   1. Builds the CGE project so FPC emits .rsj files (one per unit with
#      resourcestring declarations) into castle-engine-output/.../lazarus-lib/.
#   2. Converts each .rsj into a .po fragment via `rstconv`.
#   3. Concatenates the fragments, dedupes the headers, and writes one
#      master btt-writer-cge.pot under cge/locale/.
#
# The .pot is what Crowdin imports; translators produce per-language .po
# files that live next to it (e.g. btt-writer-cge.fr.po).
#
# Requirements: fpc/lazbuild, castle-engine CLI, rstconv (fpc package).
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CGE_DIR="$(cd "$HERE/.." && pwd)"
LOCALE_DIR="$CGE_DIR/locale"
OUT_POT="$LOCALE_DIR/btt-writer-cge.pot"

mkdir -p "$LOCALE_DIR"

echo "→ Building CGE project to refresh .rsj files …"
cd "$CGE_DIR"
# Allow override via env; otherwise fall back to common install locations.
: "${CASTLE_ENGINE:=}"
if [[ -z "$CASTLE_ENGINE" ]]; then
  if command -v castle-engine >/dev/null 2>&1; then
    CASTLE_ENGINE="castle-engine"
  elif [[ -x "$HOME/Installers/Linux/Binary/castle_game_engine/bin/castle-engine" ]]; then
    CASTLE_ENGINE="$HOME/Installers/Linux/Binary/castle_game_engine/bin/castle-engine"
  else
    echo "castle-engine not found; set CASTLE_ENGINE env var to the binary path" >&2
    exit 1
  fi
fi
"$CASTLE_ENGINE" compile >/dev/null

RSJ_DIR="$CGE_DIR/castle-engine-output/standalone/lazarus-lib/x86_64-linux"
if [[ ! -d "$RSJ_DIR" ]]; then
  # Debug build output location
  RSJ_DIR="$(find "$CGE_DIR/castle-engine-output" -name '*.rsj' -printf '%h\n' 2>/dev/null | sort -u | head -1 || true)"
fi
if [[ -z "$RSJ_DIR" || ! -d "$RSJ_DIR" ]]; then
  echo "No .rsj files found — did the build succeed?" >&2
  exit 1
fi

echo "→ Converting .rsj fragments from $RSJ_DIR"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Only extract from units we control (skip engine units)
CGE_UNITS=(CGEStrings GameViewHome GameViewLogin GameViewTerms GameViewSettings \
           GameViewNewProject GameViewImport GameViewFeedback GameViewEditor \
           GameViewRead GameViewBlindEdit GameViewChunkEdit GameInitialize)

> "$TMPDIR/merged.po"
for unit in "${CGE_UNITS[@]}"; do
  RSJ="$RSJ_DIR/$unit.rsj"
  if [[ -f "$RSJ" ]]; then
    rstconv -i "$RSJ" -o "$TMPDIR/$unit.po" -c utf-8 2>/dev/null || true
    if [[ -f "$TMPDIR/$unit.po" ]]; then
      cat "$TMPDIR/$unit.po" >> "$TMPDIR/merged.po"
      echo "" >> "$TMPDIR/merged.po"
    fi
  fi
done

# Synthesize a minimal .pot header and strip per-file headers from fragments.
{
  cat <<HEADER
# BTT-Writer CGE translation template.
# Copyright (C) $(date +%Y) Wycliffe Associates.
# This file is distributed under the same license as the BTT-Writer package.
#
msgid ""
msgstr ""
"Project-Id-Version: btt-writer-cge\n"
"POT-Creation-Date: $(date +%Y-%m-%dT%H:%M%z)\n"
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"
"Language: \n"

HEADER
  # Drop the empty msgid "" header blocks from each per-unit fragment.
  awk '
    BEGIN { skip = 0 }
    /^msgid ""/ { skip = 1; next }
    skip && /^msgstr ""/ { next }
    skip && /^$/ { skip = 0; next }
    skip && /^"/ { next }
    { skip = 0; print }
  ' "$TMPDIR/merged.po"
} > "$OUT_POT"

echo "✓ wrote $OUT_POT"
wc -l "$OUT_POT"
