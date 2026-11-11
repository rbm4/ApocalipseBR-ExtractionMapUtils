"""Keep managed generator placement opt-in with unconfigured source coordinates."""
from pathlib import Path
import re
root = Path(__file__).resolve().parents[1]
script = (root / "ApocalipseBR-ExtractionMapUtils/common/media/sandbox-options.txt").read_text(encoding="utf-8")
for name, expected in {"LobbyFixedPower":"false", "LobbyGeneratorX":"-1", "LobbyGeneratorY":"-1", "LobbyGeneratorZ":"0"}.items():
    match = re.search(r"option ApocExtractionMapUtils\." + name + r"\s*\{([^}]+)\}", script)
    assert match, name
    value = re.search(r"\bdefault\s*=\s*([^,]+)", match.group(1))
    assert value and value.group(1).strip() == expected, name
print("lobby generator sandbox defaults verified")
