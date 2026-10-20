"""Check NPC dialogue translation references and BOM-free source encoding."""
import json
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
lua = root / "ApocalipseBR-ExtractionMapUtils/common/media/lua"
category = lua / "shared/Translate/EN/IG_UI.json"
labels = json.loads(category.read_text(encoding="utf-8"))
files = [category, lua / "shared/ApocExtractionMapUtils_HumanDialogs.lua",
    lua / "server/ApocExtractionMapUtils_HumanDialogsServer.lua",
    lua / "client/ApocExtractionMapUtils_HumanDialogsClient.lua",
    lua / "client/ApocExtractionMapUtils_HumanDialogPanel.lua"]
keys = set()
for path in files:
    raw = path.read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf"), path
    text = raw.decode("utf-8")
    if path.suffix == ".lua":
        keys.update(re.findall(r'"(IGUI_ApocExtractionMapUtils_Dialog\w+)"', text))
for key in keys:
    assert isinstance(labels.get(key), str) and labels[key].strip(), key
assert "%1" in labels["IGUI_ApocExtractionMapUtils_DialogTalk"]
for suffix in ("HelloReply", "HelpReply", "ThanksReply"):
    assert len(labels["IGUI_ApocExtractionMapUtils_Dialog" + suffix]) <= 256
print(f"Passed {len(keys)} NPC dialogue label references, speech limits, JSON and UTF-8 checks.")
