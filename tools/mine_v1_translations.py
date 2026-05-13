#!/usr/bin/env python3
"""Seed cge/locale/<lang>/btt-writer.po from BTT-Writer Desktop v1 JSON.

Strategy: legacy v1 keys (`bemode_maintext`) bear no relation to new
resourcestring keys (`rsBlindEditCaption`). The only stable join column
is the *English text*. Build a map en_text -> {lang: text} from the v1
JSON files, then walk the new .pot file and emit per-language .po files
with msgstr filled in where the English msgid was found.

Run after tools/extract-pot.sh has refreshed cge/locale/btt-writer.pot.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

DEFAULT_V1_DIR = Path("/home/jdwood/Development/WA/mondele/BTT-Writer-Desktop/i18n")
DEFAULT_POT = Path("cge/locale/btt-writer.pot")
DEFAULT_OUT_DIR = Path("cge/locale")
LANGS = ["en", "es-419", "fa", "fr", "pt-br", "ru"]


def load_v1(v1_dir: Path) -> dict[str, dict[str, str]]:
    """Return {key: {lang: text}} from v1 JSON files."""
    by_key: dict[str, dict[str, str]] = {}
    for lang in LANGS:
        path = v1_dir / f"{lang}.json"
        if not path.exists():
            print(f"warn: missing {path}", file=sys.stderr)
            continue
        raw = json.loads(path.read_text(encoding="utf-8"))
        for key, value in raw.items():
            if not isinstance(value, str):
                continue
            by_key.setdefault(key, {})[lang] = value
    return by_key


def build_en_index(by_key: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    """Return {en_text: {lang: text}}."""
    index: dict[str, dict[str, str]] = {}
    for key, langs in by_key.items():
        en_text = langs.get("en")
        if not en_text:
            continue
        index[en_text] = {lang: text for lang, text in langs.items() if lang != "en"}
    return index


_MSGID_BLOCK = re.compile(
    r"""(?:^\#\:[^\n]*\n)*       # location comments
        ^msgid\s+\"(?P<id>(?:[^\"\\]|\\.)*)\"\n
        ^msgstr\s+\"\"\n
    """,
    re.MULTILINE | re.VERBOSE,
)


def parse_pot_msgids(pot_text: str) -> list[str]:
    """Return ordered list of msgid strings from .pot (skips empty header)."""
    out: list[str] = []
    for match in _MSGID_BLOCK.finditer(pot_text):
        raw = match.group("id")
        if not raw:
            continue
        out.append(_unescape_po(raw))
    return out


def _unescape_po(s: str) -> str:
    return s.replace(r"\n", "\n").replace(r"\t", "\t").replace(r"\"", '"').replace(r"\\", "\\")


def _escape_po(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def render_po(lang: str, pot_text: str, en_index: dict[str, dict[str, str]]) -> tuple[str, int, int]:
    """Return (po_content, matched_count, total_count) for given language."""
    matched = 0
    total = 0

    def replace(m: re.Match) -> str:
        nonlocal matched, total
        msgid_raw = m.group("id")
        if not msgid_raw:
            return m.group(0)
        total += 1
        text = _unescape_po(msgid_raw)
        translation = en_index.get(text, {}).get(lang)
        if translation:
            matched += 1
            return m.group(0).replace(
                'msgstr ""', f'msgstr "{_escape_po(translation)}"'
            )
        return m.group(0)

    body = _MSGID_BLOCK.sub(replace, pot_text)
    body = _set_header(body, lang)
    return body, matched, total


def _set_header(po_text: str, lang: str) -> str:
    po_text = re.sub(
        r'^"Language:[^"]*"$',
        f'"Language: {lang}\\\\n"',
        po_text,
        count=1,
        flags=re.MULTILINE,
    )
    return po_text


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--v1-dir", type=Path, default=DEFAULT_V1_DIR)
    ap.add_argument("--pot", type=Path, default=DEFAULT_POT)
    ap.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = ap.parse_args()

    if not args.pot.exists():
        sys.exit(f"error: {args.pot} not found — run tools/extract-pot.sh first")
    if not args.v1_dir.exists():
        sys.exit(f"error: v1 i18n dir {args.v1_dir} not found")

    by_key = load_v1(args.v1_dir)
    en_index = build_en_index(by_key)
    print(f"v1 index: {len(en_index)} unique English strings across {len(LANGS) - 1} target langs")

    pot_text = args.pot.read_text(encoding="utf-8")
    msgids = parse_pot_msgids(pot_text)
    print(f"pot: {len(msgids)} msgids")

    for lang in LANGS:
        if lang == "en":
            continue
        po_content, matched, total = render_po(lang, pot_text, en_index)
        lang_dir = args.out_dir / lang
        lang_dir.mkdir(parents=True, exist_ok=True)
        out = lang_dir / "btt-writer.po"
        out.write_text(po_content, encoding="utf-8")
        pct = (matched / total * 100) if total else 0
        print(f"  {lang}: {matched}/{total} matched ({pct:.0f}%) -> {out}")


if __name__ == "__main__":
    main()
