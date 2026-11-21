import AppKit
import QuartzCore

/// Franja que dibuja el texto y lo desplaza de derecha a izquierda en bucle continuo.
final class TickerView: NSView {
    var speed: CGFloat = 70
    var backgroundAlpha: CGFloat = 0.88 { didSet { needsDisplay = true } }
    var userPaused = false

    private var content = NSAttributedString()
    private var contentWidth: CGFloat = 1
    private var offset: CGFloat = 0
    private var timer: Timer?
    private var lastTime: CFTimeInterval = CACurrentMediaTime()
    private var hovering = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no soportado") }

    deinit { timer?.invalidate() }

    func setContent(_ s: NSAttributedString) {
        content = s
        contentWidth = max(ceil(s.size().width), 1)
        offset = offset.truncatingRemainder(dividingBy: contentWidth)
        needsDisplay = true
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let dt = min(now - lastTime, 0.1)
        lastTime = now
        guard !userPaused, !hovering else { return }
        offset -= speed * CGFloat(dt)
        if offset <= -contentWidth { offset += contentWidth }
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor(calibratedWhite: 0.06, alpha: backgroundAlpha).setFill()
        bounds.fill()
        let y = (bounds.height - content.size().height) / 2
        var x = offset
        while x < bounds.width {
            content.draw(at: NSPoint(x: x, y: y))
            x += contentWidth
        }
    }

    // Pausa al pasar el mouse por encima (útil para leer un valor).
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero,
                                       options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                       owner: self, userInfo: nil))
    }
    override func mouseEntered(with event: NSEvent) { hovering = true }
    override func mouseExited(with event: NSEvent) { hovering = false }
}

/// Arma el texto del ticker: "AAPL 189,23 ▲ +1,25 (+0,66%)  •  MSFT ..."
enum TickerFormatter {
    private static let number: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        return f
    }()

    static func make(symbols: [String], quotes: [String: Quote], failed: Set<String>, fontSize: CGFloat) -> NSAttributedString {
        let bold = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .bold)
        let regular = NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .regular)
        let white = NSColor(calibratedWhite: 0.95, alpha: 1)
        let gray = NSColor(calibratedWhite: 0.55, alpha: 1)
        let green = NSColor(calibratedRed: 0.20, green: 0.85, blue: 0.40, alpha: 1)
        let red = NSColor(calibratedRed: 1.00, green: 0.35, blue: 0.35, alpha: 1)

        let out = NSMutableAttributedString()
        func add(_ text: String, _ font: NSFont, _ color: NSColor) {
            out.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
        }

        if symbols.isEmpty {
            add("Sin símbolos configurados — abrí Configuración desde el ícono 📈 de la barra de menú", regular, gray)
            add("        ", regular, gray)
            return out
        }

        for s in symbols {
            add(s + " ", bold, white)
            if let q = quotes[s] {
                add(format(q.price), regular, white)
                if let ch = q.change, let pct = q.changePercent {
                    let color = ch > 0 ? green : (ch < 0 ? red : gray)
                    let arrow = ch > 0 ? "▲" : (ch < 0 ? "▼" : "■")
                    let sign = ch > 0 ? "+" : ""
                    add(" \(arrow) \(sign)\(format(ch)) (\(sign)\(format(pct))%)", regular, color)
                }
                if q.lastLiveTrade.map({ Date().timeIntervalSince($0) < 60 }) == true {
                    add(" ●", regular, green)  // indicador de dato en vivo
                }
            } else {
                add(failed.contains(s) ? "N/D" : "…", regular, gray)
            }
            add("     •     ", regular, gray)
        }
        return out
    }

    private static func format(_ v: Double) -> String {
        number.string(from: NSNumber(value: v)) ?? String(format: "%.2f", v)
    }
}
