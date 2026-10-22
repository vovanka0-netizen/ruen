// Рисует значок «rE» и собирает AppIcon.icns: swift icon.swift
import Cocoa

func draw(_ px: Int) -> Data {
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  let s = CGFloat(px), inset = s * 0.1, box = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
  let shape = NSBezierPath(roundedRect: box, xRadius: box.width * 0.225, yRadius: box.width * 0.225)
  NSGradient(starting: NSColor(red: 0.16, green: 0.42, blue: 0.98, alpha: 1),
             ending: NSColor(red: 0.42, green: 0.25, blue: 0.93, alpha: 1))!.draw(in: shape, angle: -60)
  let font = NSFont.systemFont(ofSize: s * 0.42, weight: .heavy)
  let r = NSAttributedString(string: "r", attributes: [.font: font, .foregroundColor: NSColor(white: 1, alpha: 0.7)])
  let e = NSAttributedString(string: "E", attributes: [.font: font, .foregroundColor: NSColor.white])
  let text = NSMutableAttributedString(attributedString: r); text.append(e)
  let size = text.size()
  text.draw(at: NSPoint(x: (s - size.width) / 2, y: (s - size.height) / 2 + s * 0.01))
  NSGraphicsContext.restoreGraphicsState()
  return rep.representation(using: .png, properties: [:])!
}

let dir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.iconset")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
  try! draw(base).write(to: dir.appendingPathComponent("icon_\(base)x\(base).png"))
  try! draw(base * 2).write(to: dir.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
