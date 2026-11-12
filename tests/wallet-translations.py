"""Validate wallet B42 catalogs, default language and display-key coverage."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
lua = root / 'ApocalipseBR-Wallet/common/media/lua'
translate = lua / 'shared/Translate'
catalogs = {lang: json.loads((translate / lang / 'UI.json').read_text(encoding='utf-8'))
            for lang in ('EN', 'PTBR')}
assert catalogs['EN'] == catalogs['PTBR'], 'Wallet fallback must remain Brazilian Portuguese'
keys = set(catalogs['PTBR'])
assert len(keys) >= 28
assert 'UI_ApocWallet_MarketTune' in keys
for lang, catalog in catalogs.items():
    assert all(key.startswith('UI_ApocWallet_') and value for key, value in catalog.items())
    assert all('?' not in value and '\ufffd' not in value for value in catalog.values())
    assert (translate / lang / 'language.txt').is_file()
    for key, value in catalog.items():
        placeholders = re.findall(r'%\d', value)
        assert placeholders == re.findall(r'%\d', catalogs['EN'][key]), (lang, key, value)
        assert set(placeholders) <= {'%1', '%2', '%3', '%4'}, (lang, key)
for path in lua.rglob('*.lua'):
    for key in re.findall(r"['\"](UI_ApocWallet_[^'\"]+)['\"]", path.read_text(encoding='utf-8')):
        assert key in keys or key == 'UI_ApocWallet_Skin_', (path, key)
layout = (lua / 'client/ApocWallet/UI/RadioLayout.lua').read_text(encoding='utf-8')
for skin in re.findall(r'"([a-z]+)"', layout):
    assert 'UI_ApocWallet_Skin_' + skin in keys, skin
for path in list(translate.rglob('*')) + [lua / 'client/ApocWallet/UI/RadioWindow.lua']:
    if path.is_file():
        assert not path.read_bytes().startswith(b'\xef\xbb\xbf'), path
        path.read_text(encoding='utf-8')
assert catalogs['PTBR']['UI_ApocWallet_Title'] == 'Carteira'
assert catalogs['PTBR']['UI_ApocWallet_Sync'] == 'Sincronizar'
assert catalogs['PTBR']['UI_ApocWallet_Skin_bloodmoon'] == 'Lua de sangue'
assert catalogs['PTBR']['UI_ApocWallet_Unavailable'] == 'Saldo indisponível'
assert catalogs['PTBR']['UI_ApocWallet_Skin_standard'] == 'Padrão'
fixture = (root / 'tests/wallet-radio-ui.lua').read_text(encoding='utf-8')
for key, value in catalogs['PTBR'].items():
    if '_Courier' not in key and '_Market' not in key:
        assert key + '=' + json.dumps(value, ensure_ascii=False) in fixture, key
print('Passed wallet translation catalog, fallback, placeholder, skin, key and UTF-8 checks.')
