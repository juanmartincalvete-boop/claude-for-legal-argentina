import Foundation

/// Junta las cotizaciones de Yahoo (consulta periódica) y Finnhub (tiempo real).
/// Todo el estado se lee y escribe en el hilo principal.
final class QuoteStore {
    private(set) var quotes: [String: Quote] = [:]
    private(set) var failed: Set<String> = []
    var onChange: (() -> Void)?

    private var pollTask: Task<Void, Never>?
    private let yahoo = YahooProvider()
    private let stream = FinnhubStream()
    private var symbols: [String] = []

    func start(symbols: [String], finnhubKey: String, interval: TimeInterval) {
        stop()
        self.symbols = symbols
        quotes = quotes.filter { symbols.contains($0.key) }
        failed = failed.intersection(symbols)
        onChange?()

        let yahoo = self.yahoo
        let wait = UInt64(max(interval, 5) * 1_000_000_000)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await withTaskGroup(of: (String, Quote?).self) { group in
                    for s in symbols { group.addTask { (s, try? await yahoo.fetch(s)) } }
                    var results: [(String, Quote?)] = []
                    for await r in group { results.append(r) }
                    DispatchQueue.main.async { self?.mergePoll(results) }
                }
                try? await Task.sleep(nanoseconds: wait)
            }
        }

        let key = finnhubKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            stream.onTrade = { [weak self] symbol, price in
                DispatchQueue.main.async { self?.applyTrade(symbol, price) }
            }
            stream.connect(key: key, symbols: symbols)
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        stream.disconnect()
    }

    private func mergePoll(_ results: [(String, Quote?)]) {
        for (s, q) in results where symbols.contains(s) {
            guard var q else { failed.insert(s); continue }
            failed.remove(s)
            if let existing = quotes[s], let live = existing.lastLiveTrade, Date().timeIntervalSince(live) < 60 {
                // Hay precio en vivo reciente: lo conservamos y sólo actualizamos el cierre anterior.
                q.price = existing.price
                q.lastLiveTrade = live
            }
            quotes[s] = q
        }
        onChange?()
    }

    private func applyTrade(_ symbol: String, _ price: Double) {
        guard symbols.contains(symbol) else { return }
        var q = quotes[symbol] ?? Quote(symbol: symbol, price: price, previousClose: nil, currency: nil,
                                        lastLiveTrade: nil, updated: Date())
        q.price = price
        q.lastLiveTrade = Date()
        q.updated = Date()
        quotes[symbol] = q
        failed.remove(symbol)
        onChange?()
    }
}
