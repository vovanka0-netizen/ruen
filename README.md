# RuEn

Type in Russian, press **ё**, get English. In any Mac app, including the terminal.

RuEn is a tiny menu bar app. It remembers what you typed in the current field. When you press the hotkey, it erases that text and types the English translation in its place. Nothing to select, no popup, no copy-paste.

- Meant for any app with a text field. Tested in Terminal (including Claude Code); reports from other apps are welcome.
- Translates on your Mac with Apple's built-in Translation. No account, no API key. Until the Russian model is downloaded, it falls back to Google Translate.
- Hotkey is **ё** by default (the key left of 1, or above Return on the Mac Russian layout). Shift+Ё still types a capital Ё. You can set any other key or combo in the menu, e.g. ⌃\ or ⌥\.
- If you haven't typed anything, it translates the selected text instead.

## Install

Requires macOS 26 or later. Apple Silicon and Intel.

1. Download **RuEn-1.0.0.dmg** from [Releases](https://github.com/vovanka0-netizen/ruen/releases/latest), open it and drag RuEn to Applications.
2. Open RuEn from Applications. macOS will say it can't verify the developer: the app isn't notarized by Apple. Click **Done**.
3. Go to **System Settings → Privacy & Security**, scroll down, click **Open Anyway** next to RuEn, and confirm.
   (Or in Terminal: `xattr -dr com.apple.quarantine /Applications/RuEn.app`, then open it.)
4. RuEn asks for **Accessibility** access. Allow it in **System Settings → Privacy & Security → Accessibility**. It needs this to see and type keys.
5. "rE" appears in the menu bar and its menu opens. Choose **Скачать перевод на этот Mac…** (download translation) to translate offline, and **Запускать при входе** (launch at login) to keep it always on.

Type something in Russian anywhere and press ё.

On a MacBook with a notch, the "rE" icon may hide behind it. Open RuEn from Applications again and the menu appears at the mouse pointer.

## Menu

- **Включено**: on/off.
- **Клавиша перевода / Сменить клавишу…**: press any key or combo to make it the hotkey, Esc to cancel. **Вернуть ё** restores the default.
- **Скачать перевод на этот Mac…**: downloads Apple's Russian → English model. Shown only while it's missing.
- **Запускать при входе**: start at login.

(The menu is in Russian, since that's who it's for.)

## How it works

- A `CGEventTap` sees your key presses and keeps the text typed since the last Return, Tab, Esc, arrow key, mouse click or app switch. Backspace removes a character.
- On the hotkey it waits for you to release modifiers, sends that many Backspaces and types the translation as Unicode key events. That's why it works in terminals, where other apps can't read the text field.
- With nothing typed, it copies the selection with ⌘C, translates it, pastes with ⌘V and restores your clipboard.
- Translation: `TranslationSession` from Apple's Translation framework, on device. Fallback: Google Translate's public endpoint.
- If Accessibility access is revoked while it runs, RuEn removes its event tap right away.

## Limits

- If you move the cursor or paste text, RuEn forgets what was typed. Select the text and press the hotkey instead.
- Password fields are off limits by design of macOS.
- Russian → English only.

## Build

```sh
./build.sh   # Xcode Command Line Tools; makes dist/RuEn.app, .zip and .dmg
```

`build.sh` signs with a certificate named "RuEn Local Signing" if your keychain has one (create it in Keychain Access → Certificate Assistant → Create a Certificate, type Code Signing). With a stable certificate, macOS keeps the Accessibility permission across rebuilds. Without one it signs ad hoc.

---

## По-русски

Пишешь по-русски, жмёшь **ё**, получаешь английский. В любой программе на Mac, включая терминал. Переводит встроенный переводчик Apple прямо на компьютере, без ключей и регистрации.

**Установка (macOS 26+):**
1. Скачать **RuEn-1.0.0.dmg** из [Releases](https://github.com/vovanka0-netizen/ruen/releases/latest), открыть и перетащить RuEn в «Программы».
2. Открыть RuEn. macOS скажет, что не может проверить разработчика: программа не заверена Apple. Нажать «Готово».
3. **Системные настройки → Конфиденциальность и безопасность**, внизу «Всё равно открыть» напротив RuEn.
4. Разрешить RuEn в **«Универсальный доступ»**.
5. В меню «rE» выбрать **«Скачать перевод на этот Mac…»** и **«Запускать при входе»**.

Клавишу перевода можно сменить в меню, например на ⌃\.

MIT License.
