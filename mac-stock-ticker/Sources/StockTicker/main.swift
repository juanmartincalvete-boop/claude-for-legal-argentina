import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Sin ícono en el Dock: la app vive en la barra de menú y en la franja del ticker.
app.setActivationPolicy(.accessory)
app.run()
