#!/usr/bin/env python3
"""Check RU/EN coverage and printf placeholders without changing string catalogs."""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOGS = [ROOT / "CurrencyConverterTest/Resources/Localizable.xcstrings",
            ROOT / "CurrencyConverterWidget/Localizable.xcstrings"]
FORMAT = re.compile(r"%(?:(\d+)\$)?[-+#0 ]*(?:\d+|\*)?(?:\.(?:\d+|\*))?(?:hh|ll|[hlLzjt])?([@diuoxXfFeEgGaAcCsSp])")


def units(node):
    if isinstance(node, dict):
        if "stringUnit" in node:
            yield node["stringUnit"]
        for key, value in node.items():
            if key != "stringUnit":
                yield from units(value)


def placeholders(value):
    return sorted(match.group(2) for match in FORMAT.finditer(value.replace("%%", "")))


def validate():
    errors = []
    for path in CATALOGS:
        catalog = json.loads(path.read_text())
        for key, item in catalog["strings"].items():
            if not key or item.get("shouldTranslate") is False:
                continue
            # Format-only keys need no translation and are language independent.
            if not FORMAT.sub("", key).strip(" /→=.,:0123456789"):
                continue
            for language in ("ru", "en"):
                localized = list(units(item.get("localizations", {}).get(language, {})))
                if not localized and language == catalog["sourceLanguage"]:
                    continue  # The source key is the source-language fallback.
                if not localized:
                    errors.append(f"{path.name}: {language}: missing {key!r}")
                for unit in localized:
                    if unit.get("state") != "translated" or not unit.get("value"):
                        errors.append(f"{path.name}: {language}: unfinished {key!r}")
                    if placeholders(unit.get("value", "")) != placeholders(key):
                        errors.append(f"{path.name}: {language}: placeholders differ for {key!r}")
    return errors


if __name__ == "__main__":
    failures = validate()
    if failures:
        print("\n".join(failures), file=sys.stderr)
        sys.exit(1)
    print("RU/EN coverage and placeholders passed for both catalogs")
