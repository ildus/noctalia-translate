# Translate

A [Noctalia](https://noctalia.dev) bar plugin. The bar shows a language icon. Clicking it opens a panel: pick two languages, type text in either of them, and the translation into the other appears below.

Translation goes through an OpenAI-compatible API (`GET /v1/models` and `POST /v1/chat/completions`). The base URL, API key, and model are set in the plugin and stored outside this repository.

Tested with Noctalia v5.2.1. The manifest asks for plugin API 22.

## Install

This repository is a path source. Noctalia scans its subdirectories, and the plugin lives in `translate/` because the id is `ildus/translate`.

```bash
noctalia msg plugins source add noctalia-translate path /path/to/noctalia-translate
noctalia msg plugins enable ildus/translate
```

Add a bar widget. In Noctalia settings (`settings.toml`):

```toml
[widget.translate]
type = "ildus/translate:translate"
```

Put `translate` in that bar's widget list (`start`, `center`, or `end`). If the list is missing, the bar is using built-in defaults. Read the current list before writing one, so other widgets stay put.

Open the panel from the icon, or with:

```bash
noctalia msg panel-toggle ildus/translate:panel
```

## Use

The panel shows two language menus with `<->` between them. That mark means the pair works in both directions. Text in either selected language is translated into the other. The default pair is Deutsch and Русский: Cyrillic text is translated into German, other text into Russian. When both languages use the same writing system, the model decides which of the two the text is in.

The translation appears under the input. Enter submits it and leaves the panel open. Escape closes the panel. The copy button copies the translation.

The gear opens a separate settings window (URL, API key, model list). It stays open if you go back to the translator. Settings are saved as `config.json` in the Noctalia plugin data directory, not in this repository.

## License

MIT
