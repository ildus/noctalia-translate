# Agent notes

Personal Noctalia translator. Read `~/.cursor/skills/noctalia-plugins/SKILL.md` and `reference.md` before changing the plugin. Do not fetch docs.noctalia.dev unless a call documented there fails on this host.

## Do not commit personal data

The user's API base URL and API key must not appear in this repository. Manifest defaults for `base_url` and `api_key` stay empty. Fallbacks in `translate/lib/config.luau` stay empty.

Runtime config is `~/.local/state/noctalia/plugins/data/ildus/translate/config.json` (outside this repo): `baseUrl`, `apiKey`, `model`, `models`, `source`, `target`. `.gitignore` ignores `config.json` and `.env` if a copy lands in the tree. `load()` still accepts the older keys `base_url` and `api_key`.

Do not commit or rewrite the host shell config:

- GUI settings: `~/.local/state/noctalia/settings.toml` → `~/Sync/conf/.local/noctalia/settings.toml`
- Bar: `[bar.default]` left, `translate` in `end` after `clipboard`, `[widget.translate] type = "ildus/translate:translate"`
- niri: `~/.config/niri` → `~/Sync/conf/.config/niri/config.kdl`, `Mod+T` runs `noctalia msg panel-toggle ildus/translate:panel`
- Path source name `noctalia-translate` points at this repo. There is no drop-in symlink under `~/.local/share/noctalia/plugins`.

## Layout

Path sources scan subdirectories. `plugin.toml` lives in `translate/`, not at the repo root. Id `ildus/translate`. Version `1.3.0`. `plugin_api = 22` because entries `require("./lib/config.luau")`.

| Entry | Address | Role |
| --- | --- | --- |
| `widget.luau` | `ildus/translate:translate` | Glyph `language`, toggles the translator |
| `panel.luau` | `ildus/translate:panel` | Attached panel, exclusive keyboard focus |
| `settings.luau` | `ildus/translate:settings` | Floating, `persistent = true` |
| `lib/config.luau` |  | Shared load/save, language list, model JSON parse |

`.luau` hot-reloads. A new or removed panel, widget, or service is registered only by `noctalia msg plugins disable ildus/translate` and then `enable`. `config-reload` re-reads `settings.toml` and does not register a new panel.

## UI and translation

`<->` is a label, not a button. The two selects are a pair, default `de` / `ru`. Picking the same language on both sides moves the other side to its previous value.

`config.instruction` picks a direction when the scripts differ: Cyrillic (`ru`, `uk`), Han (`zh`), otherwise Latin. Matching script means that language is the source and the other select is the target. Same script (or no letters) tells the model the text is in one of the two languages and to translate into the other. Reply is translation only.

`POST {base}/v1/chat/completions` with `Authorization: Bearer`. Body includes `chat_template_kwargs.enable_thinking = false`. Gemma thinks by default and the wait looks like a hang. Parse `choices[1]` (Lua arrays are 1-based). `noctalia.http` `ok` means the transport worked, not HTTP 2xx.

Enter is the shell Validate key and closes a panel, which drops the HTTP callback so the user only sees `…`. Both panels set `capture_keys = ["return", "kp_enter"]`. Escape still closes.

`ui.input` is uncontrolled: `value` seeds once, a stable `key` keeps the text. `ui.select` `selectedIndex` is 0-based. `onChange` values are strings.

## Two panels, one config

Entries do not share Lua memory. `config.save` writes `config.json` and `noctalia.state.set("config", cfg)`. Both panels `state.watch` that key. The settings panel is `persistent` so opening it does not destroy the translator or its draft. Persistent forces floating placement, `dismiss_on_outside_click = false`, and forbids exclusive keyboard focus (`on_demand` here).

Declare `local render` before `state.watch`. A `local function` later in the chunk is not visible to an earlier closure.

Settings owns URL, key, and model. The translator owns the language pair. Each save writes the whole table from that entry's copy, so a watch must apply the other panel's save before this panel saves again.
