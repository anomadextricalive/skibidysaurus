# Skibidysaurus

Skibidysaurus is a native macOS menu bar AI assistant.
Use `Cmd + Option + G` on selected text to pop up context-aware AI right where you're working.

## What it does

- menu bar app (no dock clutter)
- global hotkey trigger: `Cmd + Option + G`
- grabs selected text + optional screen context
- inline prompt + markdown response
- response copy button + recent prompt history
- engine dropdown: Gemini, Ollama, OpenAI, Claude

## Quick install (recommended)

this installs everything for you:

1. clone repo
2. run installer

```bash
git clone https://github.com/anomadextricalive/skibidysaurus
cd skibidysaurus
bash install_macos.sh
```

installer does all of this automatically:

- creates backend home at `~/Library/Application Support/Skibidysaurus`
- creates python venv + installs dependencies
- builds release Swift app
- installs `Skibidysaurus.app` into `/Applications` (or `~/Applications` if needed)

launch after install:

```bash
open -a Skibidysaurus
```

## First launch checklist

1. open app from Applications
2. grant Screen Recording permission when macOS asks
3. open settings and add the key for whichever provider you want (Gemini/OpenAI/Claude)
4. highlight text anywhere and press `Cmd + Option + G`

## LLM provider notes

- **Ollama (local):** default model is `llava:latest` for screen-aware prompts.  
  if you use a text-only model, Skibidysaurus auto-falls back to text mode and still responds.
- **OpenAI:** set API key in settings, then choose `OpenAI` in the model dropdown.
- **Claude:** set Anthropic API key in settings, then choose `Claude` in the model dropdown.

## Manual install (advanced)

if you want full control:

```bash
# backend setup
python3 -m venv "$HOME/Library/Application Support/Skibidysaurus/venv"
"$HOME/Library/Application Support/Skibidysaurus/venv/bin/pip" install -r requirements.txt

# swift app build
cd SkibidysaurusApp
swift build -c release
```

then package/copy the app bundle manually, or use `install_macos.sh` for the bundle step.

## Dev run (without install)

```bash
bash setup.sh
source venv/bin/activate
python main.py
```

## Troubleshooting

- **app opens but no AI response:** check Gemini API key in settings.
- **errors about python/venv:** run `bash install_macos.sh` again.
- **no context from screen:** enable Screen Recording in macOS privacy settings.
