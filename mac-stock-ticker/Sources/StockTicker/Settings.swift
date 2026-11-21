import Foundation
import Combine

enum TickerPosition: String, CaseIterable, Identifiable {
    case top, bottom
    var id: String { rawValue }
    var label: String { self == .top ? "Arriba (debajo de la barra de menú)" : "Abajo (encima del Dock)" }
}

enum TickerSource: String, CaseIterable, Identifiable {
    case native, tradingView
    var id: String { rawValue }
    var label: String { self == .native ? "Propia (Yahoo + Finnhub)" : "Widget de TradingView" }
}

/// Preferencias persistidas en UserDefaults.
final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    @Published var symbols: [String] { didSet { d.set(symbols, forKey: "symbols") } }
    @Published var finnhubKey: String { didSet { d.set(finnhubKey, forKey: "finnhubKey") } }
    @Published var position: TickerPosition { didSet { d.set(position.rawValue, forKey: "position") } }
    /// Velocidad de desplazamiento en puntos por segundo.
    @Published var speed: Double { didSet { d.set(speed, forKey: "speed") } }
    @Published var height: Double { didSet { d.set(height, forKey: "height") } }
    @Published var opacity: Double { didSet { d.set(opacity, forKey: "opacity") } }
    /// Intervalo de consulta a Yahoo Finance, en segundos.
    @Published var pollInterval: Double { didSet { d.set(pollInterval, forKey: "pollInterval") } }
    /// Si está activo, los clics atraviesan el ticker y llegan a la ventana de abajo.
    @Published var clickThrough: Bool { didSet { d.set(clickThrough, forKey: "clickThrough") } }
    /// Qué se muestra en la franja: la cinta propia o el widget oficial de TradingView.
    @Published var source: TickerSource { didSet { d.set(source.rawValue, forKey: "source") } }
    /// Código de inserción copiado tal cual desde tradingview.com/widget (Ticker Tape).
    @Published var tradingViewEmbed: String { didSet { d.set(tradingViewEmbed, forKey: "tradingViewEmbed") } }
    /// Escala del widget de TradingView dentro de la franja.
    @Published var tradingViewZoom: Double { didSet { d.set(tradingViewZoom, forKey: "tradingViewZoom") } }

    static let defaultTradingViewEmbed = """
    <script type="module" src="https://widgets.tradingview-widget.com/w/en/tv-ticker-tape.js"></script>

    <tv-ticker-tape symbols="FOREXCOM:SPXUSD,FOREXCOM:NSXUSD,FOREXCOM:DJI,FX:EURUSD,BITSTAMP:BTCUSD,BITSTAMP:ETHUSD,CMCMARKETS:GOLD"></tv-ticker-tape>
    """

    private init() {
        symbols = d.stringArray(forKey: "symbols").map { Settings.parseSymbols($0.joined(separator: ",")) }
            ?? ["AAPL", "MSFT", "NVDA", "GOOGL", "AMZN", "GGAL", "YPF", "MELI", "^GSPC", "GGAL.BA", "^MERV"]
        finnhubKey = d.string(forKey: "finnhubKey") ?? ""
        position = TickerPosition(rawValue: d.string(forKey: "position") ?? "") ?? .bottom
        speed = d.object(forKey: "speed") as? Double ?? 70
        height = d.object(forKey: "height") as? Double ?? 28
        opacity = d.object(forKey: "opacity") as? Double ?? 0.88
        pollInterval = d.object(forKey: "pollInterval") as? Double ?? 15
        clickThrough = d.object(forKey: "clickThrough") as? Bool ?? false
        source = TickerSource(rawValue: d.string(forKey: "source") ?? "") ?? .native
        tradingViewEmbed = d.string(forKey: "tradingViewEmbed") ?? Settings.defaultTradingViewEmbed
        tradingViewZoom = d.object(forKey: "tradingViewZoom") as? Double ?? 1.0
    }

    /// Convierte "aapl, msft  ggal.ba" en ["AAPL", "MSFT", "GGAL.BA"], sin duplicados.
    static func parseSymbols(_ text: String) -> [String] {
        var seen = Set<String>()
        // Los teclados en español de Mac suelen producir circunflejos "parecidos" (ˆ, ＾)
        // que Yahoo no reconoce; los normalizamos al ^ común. También quitamos
        // caracteres invisibles que pueden colarse al copiar y pegar.
        let normalized = text
            .replacingOccurrences(of: "\u{02C6}", with: "^")   // ˆ modificador
            .replacingOccurrences(of: "\u{FF3E}", with: "^")   // ＾ ancho completo
            .replacingOccurrences(of: "\u{0302}", with: "")    // circunflejo combinable suelto
            .replacingOccurrences(of: "\u{200B}", with: "")    // espacio de ancho cero
            .replacingOccurrences(of: "\u{FEFF}", with: "")
        return normalized
            .split(whereSeparator: { $0 == "," || $0 == ";" || $0.isWhitespace })
            .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
