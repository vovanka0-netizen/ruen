// RU→EN: клавиша ё (или своя, из меню) в любой программе Mac заменяет набранный русский текст английским.
// Программа запоминает, что набрано с клавиатуры после последнего Return, клика или
// смены окна. По ё стирает это и печатает перевод. Если ничего не набрано, переводит
// выделенный текст через копировать/вставить.

import Carbon
import Cocoa
import ServiceManagement
import SwiftUI
import Translation

let ru = Locale.Language(identifier: "ru")
let en = Locale.Language(identifier: "en")
let ourMark: Int64 = 0x52_55_45_4E  // метка наших нажатий, чтобы не ловить их самим

let defaults = UserDefaults.standard
var enabled = defaults.object(forKey: "enabled") as? Bool ?? true
// Клавиша перевода. hotCode = -1 значит «символ ё», где бы он ни был в раскладке.
var hotCode = defaults.object(forKey: "hotCode") as? Int64 ?? -1
var hotMods = UInt64(defaults.integer(forKey: "hotMods"))
var hotName = defaults.string(forKey: "hotName") ?? "ё"
var recording = false
let modMask: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
var typed = ""     // что набрано с клавиатуры в текущем поле
var busy = false
var tap: CFMachPort?
var statusItem: NSStatusItem!

func hasCyrillic(_ s: String) -> Bool {
  s.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
}

// ---------- перевод ----------

func translateApple(_ text: String) async -> String? {
  guard await LanguageAvailability().status(from: ru, to: en) == .installed else { return nil }
  let session = TranslationSession(installedSource: ru, target: en)
  return try? await session.translate(text).targetText
}

func translateGoogle(_ text: String) async -> String? {
  var c = URLComponents(string: "https://translate.googleapis.com/translate_a/single")!
  c.queryItems = [
    .init(name: "client", value: "gtx"), .init(name: "sl", value: "ru"),
    .init(name: "tl", value: "en"), .init(name: "dt", value: "t"), .init(name: "q", value: text),
  ]
  guard let (data, resp) = try? await URLSession.shared.data(from: c.url!),
    (resp as? HTTPURLResponse)?.statusCode == 200,
    let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
    let parts = json.first as? [[Any]]
  else { return nil }
  return parts.compactMap { $0.first as? String }.joined()
}

// Строки переводим по отдельности, чтобы не потерять переносы. Строки без кириллицы не трогаем.
func translate(_ text: String) async -> String? {
  var out: [String] = []
  for line in text.components(separatedBy: "\n") {
    if !hasCyrillic(line) { out.append(line); continue }
    let lead = line.prefix { $0 == " " }, trail = String(line.reversed().prefix { $0 == " " })
    var r = await translateApple(line)
    if r == nil { r = await translateGoogle(line) }
    guard let r else { return nil }
    out.append(lead + r.trimmingCharacters(in: .whitespaces) + trail)
  }
  return out.joined(separator: "\n")
}

// ---------- клавиша перевода ----------

let specialKeys: [Int64: String] = [
  122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8",
  101: "F9", 109: "F10", 103: "F11", 111: "F12", 49: "Space", 48: "Tab", 36: "Return",
]

// Буква на клавише в текущей раскладке, без учёта модификаторов.
func keyName(_ code: Int64) -> String {
  if let name = specialKeys[code] { return name }
  guard let src = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
    let ptr = TISGetInputSourceProperty(src, kTISPropertyUnicodeKeyLayoutData)
  else { return "#\(code)" }
  let data = Unmanaged<CFData>.fromOpaque(ptr).takeUnretainedValue() as Data
  var dead: UInt32 = 0
  var len = 0
  var chars = [UniChar](repeating: 0, count: 4)
  data.withUnsafeBytes { raw in
    _ = UCKeyTranslate(
      raw.bindMemory(to: UCKeyboardLayout.self).baseAddress!, UInt16(code),
      UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
      OptionBits(kUCKeyTranslateNoDeadKeysBit), &dead, 4, &len, &chars)
  }
  let s = String(utf16CodeUnits: chars, count: len)
  return s.isEmpty ? "#\(code)" : s.uppercased()
}

func modsName(_ f: CGEventFlags) -> String {
  (f.contains(.maskControl) ? "⌃" : "") + (f.contains(.maskAlternate) ? "⌥" : "")
    + (f.contains(.maskShift) ? "⇧" : "") + (f.contains(.maskCommand) ? "⌘" : "")
}

func setHotkey(code: Int64, mods: UInt64, name: String) {
  hotCode = code
  hotMods = mods
  hotName = name
  defaults.set(code, forKey: "hotCode")
  defaults.set(Int(mods), forKey: "hotMods")
  defaults.set(name, forKey: "hotName")
}

func isHotkey(_ code: Int64, _ flags: CGEventFlags, _ s: String) -> Bool {
  if hotCode < 0 { return s == "ё" && flags.isDisjoint(with: [.maskCommand, .maskControl, .maskAlternate]) }
  return code == hotCode && flags.intersection(modMask).rawValue == hotMods
}

// ---------- нажатия ----------

// Свой источник: наши нажатия не смешиваются с клавишами, которые человек держит.
let source = CGEventSource(stateID: .privateState)

// Ждём, пока отпустят ⌃⌥⇧⌘ от сочетания перевода, иначе Backspace станет ⌥Backspace и т. п.
func waitForModifiersUp() {
  for _ in 0..<200 {
    if CGEventSource.flagsState(.hidSystemState).isDisjoint(with: modMask) { return }
    usleep(10_000)
  }
}

func post(_ e: CGEvent?) {
  guard let e else { return }
  e.setIntegerValueField(.eventSourceUserData, value: ourMark)
  e.post(tap: .cghidEventTap)
  usleep(1500)
}

func pressKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
  for down in [true, false] {
    let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
    e?.flags = flags
    post(e)
  }
}

func typeText(_ s: String) {
  let u = Array(s.utf16)
  var i = 0
  while i < u.count {
    var chunk = Array(u[i..<min(i + 20, u.count)])
    for down in [true, false] {
      let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
      e?.flags = []
      e?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
      post(e)
    }
    i += 20
  }
}

func replaceTyped() {
  let text = typed
  typed = ""
  guard hasCyrillic(text) else { busy = false; return }
  Task.detached {
    let result = await translate(text)
    DispatchQueue.global().async {
      if let result {
        waitForModifiersUp()
        for _ in 0..<text.count { pressKey(51) }  // Backspace
        typeText(result)
      } else {
        NSSound.beep()
      }
      typed = ""
      busy = false
    }
  }
}

func translateSelection() {
  DispatchQueue.global().async {
    let pb = NSPasteboard.general
    let saved = pb.string(forType: .string)
    let before = pb.changeCount
    waitForModifiersUp()
    pressKey(8, flags: .maskCommand)  // ⌘C
    usleep(150_000)
    guard pb.changeCount != before, let text = pb.string(forType: .string), hasCyrillic(text) else {
      busy = false
      return
    }
    Task.detached {
      let result = await translate(text)
      DispatchQueue.global().async {
        if let result {
          pb.clearContents()
          pb.setString(result, forType: .string)
          pressKey(9, flags: .maskCommand)  // ⌘V
          usleep(300_000)
        } else {
          NSSound.beep()
        }
        pb.clearContents()
        if let saved { pb.setString(saved, forType: .string) }
        busy = false
      }
    }
  }
}

let resetKeys: Set<Int64> = [36, 76, 48, 53, 117, 115, 119, 116, 121, 123, 124, 125, 126]

func onEvent(_ type: CGEventType, _ event: CGEvent) -> CGEvent? {
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    return event
  }
  if event.getIntegerValueField(.eventSourceUserData) == ourMark { return event }
  if type != .keyDown { typed = ""; return event }  // клик мышью: курсор мог переехать

  let code = event.getIntegerValueField(.keyboardEventKeycode)
  let flags = event.flags
  var len = 0
  var chars = [UniChar](repeating: 0, count: 8)
  event.keyboardGetUnicodeString(maxStringLength: 8, actualStringLength: &len, unicodeString: &chars)
  let s = String(utf16CodeUnits: chars, count: len)

  if recording {  // следующее нажатие становится клавишей перевода, Esc отменяет
    recording = false
    if code != 53 {
      let mods = flags.intersection(modMask)
      setHotkey(code: code, mods: mods.rawValue, name: modsName(mods) + keyName(code))
    }
    DispatchQueue.main.async { delegate.refresh() }
    return nil
  }

  if enabled && isHotkey(code, flags, s) {
    if !busy {
      busy = true
      typed.isEmpty ? translateSelection() : replaceTyped()
    }
    return nil  // саму клавишу не печатаем
  }
  if busy { return event }

  if !flags.isDisjoint(with: [.maskCommand, .maskControl]) || resetKeys.contains(code) {
    typed = ""
  } else if code == 51 {
    if flags.contains(.maskAlternate) { typed = "" } else if !typed.isEmpty { typed.removeLast() }
  } else if len > 0 && !s.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) {
    typed += s
  }
  return event
}

// Если доступ отобрали, а перехват ещё работает, macOS может перестать принимать
// нажатия вообще. Поэтому сами снимаем перехват и ждём, пока доступ вернут.
func stopTap() {
  guard let t = tap else { return }
  CGEvent.tapEnable(tap: t, enable: false)
  CFMachPortInvalidate(t)
  tap = nil
}

func startTap() -> Bool {
  guard AXIsProcessTrusted() else { return false }
  let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.leftMouseDown.rawValue)
    | (1 << CGEventType.rightMouseDown.rawValue)
  tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
    eventsOfInterest: CGEventMask(mask),
    callback: { _, type, event, _ in
      if let e = onEvent(type, event) { return Unmanaged.passUnretained(e) }
      return nil
    }, userInfo: nil)
  guard let tap else { return false }
  let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
  CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
  CGEvent.tapEnable(tap: tap, enable: true)
  return true
}

// ---------- скачивание модели перевода ----------
// Скачать модель можно только через SwiftUI: .translationTask + prepareTranslation()
// показывает системный запрос. В Настройках кнопки для этого может не быть.

final class DownloadState: ObservableObject {
  @Published var config: TranslationSession.Configuration?
  @Published var message = "macOS спросит, скачать ли русский → английский. Нажмите «Скачать»."
}

struct DownloadView: View {
  @ObservedObject var state: DownloadState
  var done: () -> Void
  var body: some View {
    Text(state.message).multilineTextAlignment(.center).padding(30).frame(width: 380)
      .onAppear { state.config = .init(source: ru, target: en) }
      .translationTask(state.config) { session in
        do {
          try await session.prepareTranslation()
          let ok = await LanguageAvailability().status(from: ru, to: en) == .installed
          await MainActor.run {
            state.message = ok ? "Готово, перевод работает без интернета. Окно можно закрыть." : "Не скачалось, попробуйте ещё раз."
            done()
          }
        } catch {
          await MainActor.run { state.message = "Не получилось: \(error.localizedDescription)" }
        }
      }
  }
}

// ---------- значок в строке меню ----------

class App: NSObject, NSApplicationDelegate {
  let toggle = NSMenuItem(title: "Включено", action: #selector(flip), keyEquivalent: "")
  let hotkey = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  let change = NSMenuItem(title: "Сменить клавишу…", action: #selector(record), keyEquivalent: "")
  let reset = NSMenuItem(title: "Вернуть ё", action: #selector(resetHotkey), keyEquivalent: "")
  let engine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
  let download = NSMenuItem(title: "Скачать перевод на этот Mac…", action: #selector(downloadModel), keyEquivalent: "")
  var downloadWindow: NSWindow?
  let login = NSMenuItem(title: "Запускать при входе", action: #selector(flipLogin), keyEquivalent: "")
  let access = NSMenuItem(title: "Нет доступа: Настройки → Конфиденциальность → Универсальный доступ",
                          action: #selector(openSettings), keyEquivalent: "")

  func applicationDidFinishLaunching(_ n: Notification) {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let menu = NSMenu()
    for item in [toggle, change, reset, access, login, download] { item.target = self }
    for item in [toggle, .separator(), hotkey, change, reset, .separator(), engine, download, access, login, .separator(),
                 NSMenuItem(title: "Выйти", action: #selector(NSApp.terminate), keyEquivalent: "q")] {
      menu.addItem(item)
    }
    statusItem.menu = menu
    refresh()

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { _ in typed = "" }

    let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    _ = AXIsProcessTrustedWithOptions(opts)
    tryStart()
    Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
      if tap != nil && !AXIsProcessTrusted() {
        stopTap()
        self.tryStart()
      }
    }

    // Запустили руками, а не при входе в систему: сразу показываем меню,
    // иначе не видно, что программа открылась (значок мог спрятаться за вырезом экрана).
    let ev = NSAppleEventManager.shared().currentAppleEvent
    if ev?.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue != keyAELaunchedAsLogInItem {
      showMenu()
    }
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
    showMenu()
    return false
  }

  func showMenu() {
    DispatchQueue.main.async {
      statusItem.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }
  }

  func tryStart() {
    if startTap() { refresh(); return }
    refresh()
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.tryStart() }
  }

  func refresh() {
    statusItem.button?.title = tap == nil ? "rE ⚠︎" : enabled ? "rE" : "rE off"
    toggle.state = enabled ? .on : .off
    hotkey.title = recording ? "Нажмите новую клавишу (Esc — отмена)…" : "Клавиша перевода: \(hotName)"
    reset.isHidden = hotCode < 0
    login.state = SMAppService.mainApp.status == .enabled ? .on : .off
    access.isHidden = tap != nil
    Task {
      let st = await LanguageAvailability().status(from: ru, to: en)
      engine.title = st == .installed ? "Перевод: Apple, на этом Mac" : "Перевод: Google (через интернет)"
      download.isHidden = st == .installed
    }
  }

  @objc func flip() {
    enabled.toggle()
    UserDefaults.standard.set(enabled, forKey: "enabled")
    typed = ""
    refresh()
  }

  @objc func flipLogin() {
    if SMAppService.mainApp.status == .enabled {
      try? SMAppService.mainApp.unregister()
    } else {
      try? SMAppService.mainApp.register()
    }
    refresh()
  }

  @objc func record() {
    recording = true
    typed = ""
    refresh()
  }

  @objc func resetHotkey() {
    setHotkey(code: -1, mods: 0, name: "ё")
    refresh()
  }

  @objc func downloadModel() {
    if downloadWindow == nil {
      let w = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
      w.title = "RuEn: перевод на этом Mac"
      w.isReleasedWhenClosed = false
      w.contentView = NSHostingView(rootView: DownloadView(state: DownloadState()) { self.refresh() })
      w.center()
      downloadWindow = w
    }
    NSApp.activate(ignoringOtherApps: true)
    downloadWindow?.makeKeyAndOrderFront(nil)
  }

  @objc func openSettings() {
    NSWorkspace.shared.open(
      URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
  }
}

let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
