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


_TRAILING_PUNCT = ".,;:!?…"  # ASCII + horizontal ellipsis


def normalize(s: str) -> str:
    """Loose match key. Lowercase, collapse internal whitespace, strip
    leading/trailing whitespace and common trailing punctuation."""
    out = " ".join(s.split())  # collapse internal whitespace, strip ends
    out = out.lower().rstrip(_TRAILING_PUNCT).rstrip()
    return out


def build_normalized_index(en_index: dict[str, dict[str, str]]) -> dict[str, dict[str, str]]:
    """Build secondary index keyed by normalized English. Collisions keep first."""
    out: dict[str, dict[str, str]] = {}
    for en_text, langs in en_index.items():
        key = normalize(en_text)
        if not key:
            continue
        out.setdefault(key, langs)
    return out


def adjust_trailing(src: str, dst: str) -> str:
    """If src ends in trailing punctuation that dst doesn't, append it to dst.
    Keeps the translated string consistent with msgid (LCL prints msgid
    fallback when msgstr is empty, so trailing dots etc. should match)."""
    for ch in _TRAILING_PUNCT:
        if src.endswith(ch) and not dst.rstrip().endswith(ch):
            return dst.rstrip() + ch
    return dst


_MSGID_BLOCK = re.compile(
    r"""(?:^\#\:[^\n]*\n)*       # location comments
        ^msgid\s+\"(?P<id>(?:[^\"\\]|\\.)*)\"\n
        ^msgstr\s+\"\"\n
    """,
    re.MULTILINE | re.VERBOSE,
)

# Match any msgid/msgstr pair (translated or not) — used to read existing
# translations out of a previously-generated .po so we don't clobber them.
_ANY_PAIR = re.compile(
    r"""^msgid\s+\"(?P<id>(?:[^\"\\]|\\.)*)\"\n
        ^msgstr\s+\"(?P<str>(?:[^\"\\]|\\.)*)\"\n
    """,
    re.MULTILINE | re.VERBOSE,
)


def load_existing_translations(po_path: Path) -> dict[str, str]:
    """Return {msgid: msgstr} for entries with a non-empty msgstr."""
    out: dict[str, str] = {}
    if not po_path.exists():
        return out
    text = po_path.read_text(encoding="utf-8")
    for m in _ANY_PAIR.finditer(text):
        raw_id = m.group("id")
        raw_str = m.group("str")
        if not raw_id or not raw_str:
            continue
        out[_unescape_po(raw_id)] = _unescape_po(raw_str)
    return out


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


def render_po(
    lang: str,
    pot_text: str,
    en_index: dict[str, dict[str, str]],
    norm_index: dict[str, dict[str, str]],
    preserved: dict[str, str],
) -> tuple[str, int, int, int, int]:
    """Return (po_content, exact, normalized, preserved_count, total)."""
    exact_matches = 0
    norm_matches = 0
    preserved_count = 0
    total = 0

    def replace(m: re.Match) -> str:
        nonlocal exact_matches, norm_matches, preserved_count, total
        msgid_raw = m.group("id")
        if not msgid_raw:
            return m.group(0)
        total += 1
        text = _unescape_po(msgid_raw)

        # First priority: keep any translation the user already wrote.
        translation = preserved.get(text)
        if translation:
            preserved_count += 1
        else:
            translation = en_index.get(text, {}).get(lang)
            if translation:
                exact_matches += 1
            else:
                translation = norm_index.get(normalize(text), {}).get(lang)
                if translation:
                    norm_matches += 1
                    translation = adjust_trailing(text, translation)

        if translation:
            return m.group(0).replace(
                'msgstr ""', f'msgstr "{_escape_po(translation)}"'
            )
        return m.group(0)

    body = _MSGID_BLOCK.sub(replace, pot_text)
    body = _set_header(body, lang)
    return body, exact_matches, norm_matches, preserved_count, total


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
    norm_index = build_normalized_index(en_index)
    print(f"v1 index: {len(en_index)} unique English strings across {len(LANGS) - 1} target langs")

    pot_text = args.pot.read_text(encoding="utf-8")
    msgids = parse_pot_msgids(pot_text)
    print(f"pot: {len(msgids)} msgids")

    for lang in LANGS:
        if lang == "en":
            continue
        lang_dir = args.out_dir / lang
        out = lang_dir / "btt-writer.po"
        preserved = load_existing_translations(out)
        po_content, exact, norm, kept, total = render_po(
            lang, pot_text, en_index, norm_index, preserved
        )
        lang_dir.mkdir(parents=True, exist_ok=True)
        out.write_text(po_content, encoding="utf-8")
        filled = exact + norm + kept
        pct = (filled / total * 100) if total else 0
        print(
            f"  {lang}: {filled}/{total} ({pct:.0f}%) — "
            f"kept {kept}, exact {exact}, normalized {norm} -> {out}"
        )


if __name__ == "__main__":
    main()
