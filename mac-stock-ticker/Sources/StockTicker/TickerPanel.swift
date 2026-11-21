import AppKit

/// Ventana sin bordes, siempre por encima de las demás, presente en todos los Espacios
/// y también junto a apps en pantalla completa. No roba el foco al hacer clic.
final class TickerPanel: NSPanel {
    init() {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 800, height: 28),
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func reposition(_ position: TickerPosition, height: CGFloat) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        // visibleFrame excluye la barra de menú y el Dock.
        let vf = screen.visibleFrame
        let y = position == .top ? vf.maxY - height : vf.minY
        setFrame(NSRect(x: vf.minX, y: y, width: vf.width, height: height), display: true)
    }
}
