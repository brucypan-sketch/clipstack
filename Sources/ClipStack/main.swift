import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Menu-bar-only app; also set in the bundle's Info.plist (LSUIElement), but
// this keeps `swift run` / bare-binary runs out of the Dock too.
app.setActivationPolicy(.accessory)
app.run()
