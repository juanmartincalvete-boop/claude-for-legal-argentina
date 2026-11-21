import Foundation

struct Quote {
    let symbol: String
    var price: Double
    var previousClose: Double?
    var currency: String?
    /// Momento de la última operación recibida en tiempo real (Finnhub), si la hubo.
    var lastLiveTrade: Date?
    var updated: Date

    var change: Double? { previousClose.map { price - $0 } }
    var changePercent: Double? {
        guard let pc = previousClose, pc != 0 else { return nil }
        return (price - pc) / pc * 100
    }
}
