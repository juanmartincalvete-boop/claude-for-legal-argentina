import Foundation

/// Precios operación por operación vía WebSocket de Finnhub (requiere API key gratuita de finnhub.io).
/// Se usa como capa "en vivo" sobre los datos de Yahoo; los símbolos que Finnhub no cubre
/// (p. ej. GGAL.BA o ^MERV) simplemente no reciben mensajes y siguen con Yahoo.
final class FinnhubStream {
    var onTrade: ((String, Double) -> Void)?

    private var task: URLSessionWebSocketTask?
    private var key = ""
    private var symbols: [String] = []
    private var generation = 0  // invalida reconexiones de conexiones anteriores

    private struct Message: Decodable {
        struct Trade: Decodable { let s: String; let p: Double }
        let type: String
        let data: [Trade]?
    }
    private struct Subscribe: Encodable { let type = "subscribe"; let symbol: String }

    /// Debe llamarse desde el hilo principal.
    func connect(key: String, symbols: [String]) {
        disconnect()
        self.key = key
        self.symbols = symbols
        open(generation)
    }

    func disconnect() {
        generation += 1
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func open(_ gen: Int) {
        guard gen == generation, !key.isEmpty, !symbols.isEmpty,
              var comps = URLComponents(string: "wss://ws.finnhub.io") else { return }
        comps.queryItems = [URLQueryItem(name: "token", value: key)]
        guard let url = comps.url else { return }

        let t = URLSession.shared.webSocketTask(with: url)
        task = t
        t.resume()
        let encoder = JSONEncoder()
        for s in symbols {
            if let data = try? encoder.encode(Subscribe(symbol: s)), let text = String(data: data, encoding: .utf8) {
                t.send(.string(text)) { _ in }
            }
        }
        receive(t, gen)
    }

    private func receive(_ t: URLSessionWebSocketTask, _ gen: Int) {
        t.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let s): self.handle(Data(s.utf8))
                case .data(let d): self.handle(d)
                @unknown default: break
                }
                self.receive(t, gen)
            case .failure:
                // Reintento simple; si cambió la configuración, `generation` ya no coincide y se descarta.
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.open(gen) }
            }
        }
    }

    private func handle(_ data: Data) {
        guard let msg = try? JSONDecoder().decode(Message.self, from: data),
              msg.type == "trade", let trades = msg.data else { return }
        // Nos quedamos con el último precio de cada símbolo dentro del lote.
        var last: [String: Double] = [:]
        for t in trades { last[t.s] = t.p }
        for (s, p) in last { onTrade?(s, p) }
    }
}
