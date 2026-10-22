# RuEn

Type in Russian, press **ё**, get English. In any Mac app, including the terminal.

RuEn is a tiny menu bar app. It remembers what you typed in the current field. When you press the hotkey, it erases that text and types the English translation in its place. Nothing to select, no popup, no copy-paste.

- Works everywhere you can type: Terminal, Telegram, Slack, browsers, Claude Code, Notes.
- Translates on your Mac with Apple's built-in Translation. No account, no API key. Falls back to Google Translate if the Russian model isn't downloaded.
- Hotkey is **ё** by default (the key left of 1 or above Return on a Russian layout). You can set any other key in the menu.
- If you haven't typed anything, it translates the selected text instead.

## Install

1. Download `RuEn-0.2.zip` from [Releases](../../releases) and unzip it.
2. Move `RuEn.app` to Applications.
3. Right-click RuEn → **Open** → **Open**. The app isn't signed with an Apple developer ID, so a double-click is blocked the first time.
4. Allow RuEn in **System Settings → Privacy & Security → Accessibility**. It needs this to see and type keys.
5. "rE" appears in the menu bar. Type something in Russian anywhere and press ё.

Requires macOS 26 or later.

**On-device translation:** the first time, macOS may ask to download the Russian → English model. Until it's downloaded, RuEn uses Google Translate and your text goes to Google.

## How it works

- A `CGEventTap` sees your key presses and keeps the text typed since the last Return, Tab, Esc, arrow key, mouse click or app switch. Backspace removes a character.
- On the hotkey it sends that many Backspaces and types the translation as Unicode key events. That's why it works in terminals, where apps can't read the text field.
- With nothing typed, it copies the selection with ⌘C, translates it, pastes with ⌘V and restores your clipboard.
- Translation: `TranslationSession` (Apple Translation framework), on device.

## Limits

- If you move the cursor or paste text, RuEn forgets what was typed. Select the text and press the hotkey instead.
- Password fields are off limits by design of macOS.
- Russian → English only.

## Build

```sh
./build.sh   # needs Xcode Command Line Tools, makes dist/RuEn.app
```

---

## По-русски

Пишешь по-русски, жмёшь **ё**, получаешь английский. В любой программе на Mac, включая терминал. Перевод делается на компьютере встроенным переводчиком Apple, без ключей и регистрации.

Установка: скачать архив из [Releases](../../releases), перенести `RuEn.app` в «Программы», открыть правой кнопкой → «Открыть», разрешить в «Настройки → Конфиденциальность и безопасность → Универсальный доступ». Клавишу перевода можно сменить в меню значка «rE».

MIT License.
