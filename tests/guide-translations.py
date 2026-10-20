"""Validate the dedicated-server guide speech contract without starting the game."""
import json
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
path = root / "ApocalipseBR-ExtractionMapUtils/common/media/lua/shared/Translate/EN/IG_UI.json"
raw = path.read_bytes()
assert not raw.startswith(b"\xef\xbb\xbf"), "B42 translation file must be BOM-free UTF-8"
labels = json.loads(raw.decode("utf-8"))
prefix = "IGUI_ApocExtractionMapUtils_"
assert labels[prefix + "GuideHello"] == "Olá!"
for key in ("EventCountdown", "EventRemaining"):
    assert set(re.findall(r"%[0-9]", labels[prefix + key])) == {"%1", "%2"}, key
assert "estimado" in labels[prefix + "EventRemaining"], "Duration is an estimate, not a stop promise"
assert "%" not in labels[prefix + "EventNone"]
assert labels[prefix + "EventUnavailable"]
print("Passed guide greeting, placeholders, estimate wording, JSON and UTF-8 checks.")
