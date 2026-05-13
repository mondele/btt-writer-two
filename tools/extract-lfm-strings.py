#!/usr/bin/env python3
"""Extract translatable strings from Lazarus .lfm files into a .po fragment.

LCL's TPOTranslator looks up form properties by the identifier path
<formclass>.<comp1>.<comp2>...<propname>, all lowercase, with dots as
separators. We walk each .lfm file, track the nested `object` path, and
emit a .po entry per Caption / Text / Hint property whose value is a
single-quoted string literal.

Usage: tools/extract-lfm-strings.py [LFM_FILE ...] [-o OUT_FILE]
Default scans *.lfm in the current directory; output goes to stdout.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

TRANSLATABLE_PROPS = {"caption", "text", "hint", "title"}

# Match an `object Name: TClass` line, capturing Name and TClass.
RE_OBJECT_OPEN = re.compile(r"^\s*object\s+(\w+)\s*:\s*(\w+)\s*$", re.IGNORECASE)
# Match end-of-object line.
RE_OBJECT_END = re.compile(r"^\s*end\s*$", re.IGNORECASE)
# Property = 'value'   (single-quoted)
# Lazarus escapes a literal single quote by doubling it: 'it''s'.
RE_PROP_SQ = re.compile(r"^\s*([A-Za-z_][\w.]*)\s*=\s*'((?:[^']|'')*)'\s*$")


def unescape_lfm_quote(s: str) -> str:
    return s.replace("''", "'")


def po_escape(s: str) -> str:
    return (
        s.replace("\\", "\\\\")
        .replace('"', '\\"')
        .replace("\n", "\\n")
        .replace("\t", "\\t")
    )


def extract_file(path: Path) -> list[tuple[str, str]]:
    """Return list of (identifier_path, raw_text) for translatable props."""
    entries: list[tuple[str, str]] = []
    stack: list[str] = []  # component names, deepest last; root is form class
    with path.open(encoding="utf-8") as fh:
        for line in fh:
            m_open = RE_OBJECT_OPEN.match(line)
            if m_open:
                comp_name, comp_class = m_open.group(1), m_open.group(2)
                if not stack:
                    # Root: use the class name, not the instance name.
                    stack.append(comp_class.lower())
                else:
                    stack.append(comp_name.lower())
                continue
            if RE_OBJECT_END.match(line):
                if stack:
                    stack.pop()
                continue
            m_prop = RE_PROP_SQ.match(line)
            if m_prop and stack:
                prop = m_prop.group(1).lower()
                # Property names like "Caption", "Anchors.AnchorOptions.Caption"
                # — translate any property whose final dot-segment is in the
                # whitelist.
                final = prop.rsplit(".", 1)[-1]
                if final not in TRANSLATABLE_PROPS:
                    continue
                value = unescape_lfm_quote(m_prop.group(2))
                if not value.strip():
                    continue
                ident = ".".join(stack + [prop])
                entries.append((ident, value))
    return entries


def render_po(entries: list[tuple[str, str, str]]) -> str:
    """entries: list of (identifier, source_path, value).
    Returns .po fragment (no header — caller merges into the main .pot)."""
    # Dedup by (identifier) — only one msgstr per key.
    seen: dict[str, tuple[str, str]] = {}
    for ident, src, value in entries:
        seen.setdefault(ident, (src, value))

    out: list[str] = []
    for ident, (src, value) in seen.items():
        out.append("")
        # The #: comment becomes TPOFileItem.Identifier in LCL's parser
        # (colon-to-dot substitution is applied). TPOFile.Translate looks
        # up by lowercase identifier, which matches what TPOTranslator
        # constructs at form-load time: <formclass>.<comp>.<prop>.
        out.append(f"#: {ident}")
        out.append(f'msgid "{po_escape(value)}"')
        out.append('msgstr ""')
    out.append("")
    return "\n".join(out)


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("lfm", nargs="*", type=Path)
    ap.add_argument("-o", "--out", type=Path, default=None)
    args = ap.parse_args()

    lfm_files: list[Path]
    if args.lfm:
        lfm_files = args.lfm
    else:
        lfm_files = sorted(Path(".").glob("*.lfm"))
    if not lfm_files:
        sys.exit("error: no .lfm files found")

    all_entries: list[tuple[str, str, str]] = []
    for path in lfm_files:
        for ident, value in extract_file(path):
            all_entries.append((ident, str(path), value))

    fragment = render_po(all_entries)
    if args.out:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(fragment, encoding="utf-8")
        print(f"wrote {args.out} ({sum(1 for _ in fragment.splitlines() if _.startswith('msgid '))} entries)")
    else:
        sys.stdout.write(fragment)


if __name__ == "__main__":
    main()
