"""Validate locale completeness, substitutions and source translation references."""
from collections import Counter
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
media = root / "ApocalipseBR-ExtractionMapUtils/common/media"
translations = media / "lua/shared/Translate"


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f"Duplicate translation key: {key}"
        result[key] = value
    return result


def load(path):
    raw = path.read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf"), path
    return json.loads(raw.decode("utf-8"), object_pairs_hook=unique_object)


labels = {}
count = 0
for category, prefix in (("IG_UI", "IGUI_"), ("Sandbox", "Sandbox_")):
    english = load(translations / "EN" / f"{category}.json")
    portuguese = load(translations / "PTBR" / f"{category}.json")
    assert english.keys() == portuguese.keys(), f"Incomplete PTBR category: {category}"
    for key, value in english.items():
        assert key.startswith(prefix), key
        translated = portuguese[key]
        assert isinstance(value, str) and value.strip(), key
        assert isinstance(translated, str) and translated.strip(), key
        assert value.isascii(), f"Unexpected non-English or damaged text: {key}"
        placeholders = lambda text: Counter(re.findall(r"%\d+(?:\$[a-zA-Z])?", text))
        assert placeholders(value) == placeholders(translated), key
        assert Counter(re.findall(r"<[^>]+>", value)) == Counter(re.findall(r"<[^>]+>", translated)), key
        assert "\ufffd" not in translated and "??" not in translated, key
    labels.update(english)
    count += len(english)

# Literal references include both getText calls and shared dialogue definitions.
for path in (media / "lua").rglob("*.lua"):
    for key in re.findall(r'"((?:IGUI|Sandbox)_ApocExtractionMapUtils_[^"]+)"', path.read_text(encoding="utf-8")):
        if key.endswith("_"):  # Dynamic scope/status key families are checked below.
            continue
        assert key in labels, f"Missing translation in {path}: {key}"
for family, suffixes in {
    "ObjectivesScope": ("player", "team", "event"),
    "ObjectivesStatus": ("active", "complete", "locked", "unavailable", "unsupported"),
}.items():
    for suffix in suffixes:
        assert f"IGUI_ApocExtractionMapUtils_{family}_{suffix}" in labels
options = (media / "sandbox-options.txt").read_text(encoding="utf-8")
for name in re.findall(r"translation\s*=\s*(\w+)", options):
    for suffix in ("", "_tooltip"):
        assert f"Sandbox_{name}{suffix}" in labels

ptbr = load(translations / "PTBR/IG_UI.json")
assert ptbr["IGUI_ApocExtractionMapUtils_GuideHello"] == "Olá!"
assert ptbr["IGUI_ApocExtractionMapUtils_DialogGreeting"] == "Olá! Como posso ajudar?"
assert "você" in ptbr["IGUI_ApocExtractionMapUtils_DialogHelloReply"]
assert "estimado" in ptbr["IGUI_ApocExtractionMapUtils_EventRemaining"]
for suffix in ("HelloReply", "HelpReply", "ThanksReply"):
    assert len(ptbr["IGUI_ApocExtractionMapUtils_Dialog" + suffix]) <= 256
metadata = load(translations / "PTBR/language.json")
assert metadata == {"version": "1", "language_name": "Português (Brasil)"}
print(f"Passed {count} labels per locale, source references, placeholders, accents, JSON and BOM-free UTF-8 checks.")
