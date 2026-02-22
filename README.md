# HoverGPT 🚀

HoverGPT is a powerful, system-wide floating AI ghostwriter and assistant for macOS. It lives quietly in your background and immediately pops up context-aware AI directly at your cursor. Need help replying to an email? Rewriting code? Summarizing an article? HoverGPT reads your screen and highlighted text and provides professional, immediate answers.

### Features
* **Ghostwriter Hotkey:** Select any text and press `Cmd + Option + G` to instantly summon the AI with the selected text as context.
* **Context Aware:** HoverGPT silently captures a screenshot of your active application to help answer questions about your current work seamlessly.
* **Floating Launcher:** A persistent floating edge button lets you trigger the AI even if you prefer not to use keyboard shortcuts.
* **UI Themes:** Choose between Dark, Light, Neon, and Hacker aesthetics right from the settings.
* **Native Speed:** Uses macOS APIs to seamlessly read your clipboard and screen without brittle legacy automation scripts.

## Onboarding and Easy Setup

HoverGPT requires Python 3. Follow these simple steps:

1. Clone or copy this repository to your local machine.
2. Open your terminal and navigate inside the folder (`cd hover_gpt`).
3. Run the setup script:
   ```bash
   bash setup.sh
   ```
4. Start the app:
   ```bash
   source venv/bin/activate
   python main.py
   ```

### First Time Setup

* **API Key:** Click the **Settings ⚙️** icon in the UI and paste your Gemini API Key. (You can get one for free from Google AI Studio).
* **Mac Permissions:** macOS will block terminal apps from reading your screen by default. To fix this:
  Open **System Settings > Privacy & Security > Screen Recording**, and toggle your Terminal app (or VSCode/Cursor) to ON. This allows it to "see" your work when you trigger it!

## Usage
Simply highlight some text in *any application* and hit **Cmd + Option + G**. Or click the floating 🚀 button. The AI will pop up exactly where you are looking!
