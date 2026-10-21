# English and Brazilian Portuguese labels

Status: implemented; awaiting in-game validation.

The main mod's English UI category contained Portuguese guide/event dialogue
and damaged accents in NPC conversations. English players therefore saw mixed
languages. There was no complete Brazilian Portuguese translation category.

`common/media/lua/shared/Translate/EN/IG_UI.json` now contains English dialogue
and event announcements. `EN/Sandbox.json` has clearer English tooltips.
`PTBR/IG_UI.json` and `PTBR/Sandbox.json` translate all 52 existing keys, including
objectives and sandbox settings, with corrected Portuguese accents. Keys and
substitution arguments are preserved; no Lua labels or gameplay logic changed.

The game uses `PTBR`, rather than `PT-BR`, for Brazilian Portuguese. This matches
the installed game's `media/lua/shared/Translate/PTBR/language.json`. The new
folder includes matching `language.json` metadata. Local decompiled
`zombie/core/Languages.java` discovers `language.json`, and `Translator.java`
loads categories by language name. No legacy `language.txt` was added.

Validation from the repository root:

```powershell
python tests/translation-locales.py
python tests/guide-translations.py
python tests/human-dialogue-labels.py
```

All three checks passed. Coverage includes complete matching category key sets,
duplicate keys, source references, sandbox option references, substitution/tag
parity, corrected accents, speech length limits, valid JSON and BOM-free UTF-8.
The guide regression check now expects English fallback text.

Related behavior: [NPC dialogue](../features/npc-dialogue.md) and
[guide announcements](../features/postgresql-event-control.md). Dedicated-server
speech follows the server language, so changing EN also changes the default
server greeting to English. Client rendering and server-selected speech language
have not been tested in game.
