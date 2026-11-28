#!/usr/bin/env python3
"""Regenerate the offline emoji table from pinned Unicode/CLDR sources.

Downloads are cached outside the repository. Example:
    python3 Scripts/generate_emoji.py --cache /tmp/mboard-emoji-sources
Use --offline to regenerate from the verified cache without network access.
"""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import xml.etree.ElementTree as ET

SOURCES = {
    "emoji-test.txt": ("https://www.unicode.org/Public/17.0.0/emoji/emoji-test.txt", "1d8a944f88d7952f7ef7c5167fef3c67995bcae24543949710231b03a201acda"),
    "en.xml": ("https://raw.githubusercontent.com/unicode-org/cldr/release-48/common/annotations/en.xml", "8511aadd046fdba2f0ffe590266ced8bbf48175ad139b2675d85d7141057b235"),
    "my.xml": ("https://raw.githubusercontent.com/unicode-org/cldr/release-48/common/annotations/my.xml", "334f438de3464c151d57fa26aeb25adba7939cd845f40def40478485debc7b3d"),
    "derived-en.xml": ("https://raw.githubusercontent.com/unicode-org/cldr/release-48/common/annotationsDerived/en.xml", "d76bd041c8c9e7b00b716aff8b7d9dbf509877010e191d5efd068be2553e066e"),
    "derived-my.xml": ("https://raw.githubusercontent.com/unicode-org/cldr/release-48/common/annotationsDerived/my.xml", "a767ed31c4d878dcb98f7b7cb57268ebbedd94b9cb34f872eff22112ee6c43a4"),
}

# Informal queries supplement CLDR's names and keywords. These are MBoard's own
# aliases, not copied from another keyboard's search index.
ALIASES = {
    "😊": ["happy"], "😀": ["happy"], "😄": ["happy"],
    "😂": ["lol", "lmao"], "🤣": ["lol", "lmao", "rofl"],
    "🙏": ["thank you", "thankyou"], "👍": ["yes", "okay"],
    "👌": ["okay"], "❤️": ["love"], "🥰": ["love"],
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    for name, (url, digest) in SOURCES.items():
        path = args.cache / name
        if not path.exists() and not args.offline:
            subprocess.run(["curl", "--fail", "--location", "--connect-timeout", "10",
                            "--max-time", "30", url, "--output", str(path)], check=True)
        if hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            raise ValueError(f"Upstream checksum mismatch: {name}")

    annotations = {}
    for name in ("en.xml", "derived-en.xml", "my.xml", "derived-my.xml"):
        for annotation in ET.parse(args.cache / name).iter("annotation"):
            if not annotation.text or annotation.text == "↑↑↑":
                continue
            glyph = annotation.attrib["cp"].replace("\ufe0f", "")
            terms = annotations.setdefault(glyph, [])
            for term in annotation.text.split(" | "):
                if term not in terms:
                    terms.append(term)

    rows = []
    group = ""
    for line in (args.cache / "emoji-test.txt").read_text().splitlines():
        if line.startswith("# group: "):
            group = line.removeprefix("# group: ")
        match = re.match(r"^([0-9A-F ]+)\s*; fully-qualified\s*# \S+ E([\d.]+) (.+)$", line)
        if not match:
            continue
        codepoints, version, name = match.groups()
        glyph = "".join(chr(int(cp, 16)) for cp in codepoints.split())
        terms = annotations.get(glyph.replace("\ufe0f", ""), []) + ALIASES.get(glyph, [])
        rows.append("\t".join([group, glyph, name, " | ".join(dict.fromkeys(terms)), version]))
    output = Path(__file__).resolve().parents[1] / "Keyboard/Resources/Emoji.tsv"
    output.write_text("\n".join(rows) + "\n")
    print(f"Wrote {len(rows)} Emoji 17.0 entries with CLDR 48 English/Burmese annotations.")


if __name__ == "__main__":
    main()
