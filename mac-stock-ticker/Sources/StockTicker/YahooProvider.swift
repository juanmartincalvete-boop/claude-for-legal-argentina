import Foundation

/// Consulta el endpoint público (no oficial) de gráficos de Yahoo Finance.
/// No requiere clave y cubre acciones de EE.UU., BYMA (sufijo .BA), índices (^GSPC, ^MERV),
/// cripto (BTC-USD), monedas (EURUSD=X), etc.
struct YahooProvider {
    enum FetchError: Error { case badURL, http(Int), noData }

    private struct ChartResponse: Decodable {
        struct Chart: Decodable { let result: [Result]? }
        struct Result: Decodable { let meta: Meta }
        struct Meta: Decodable {
            let symbol: String?
            let currency: String?
            let regularMarketPrice: Double?
            let previousClose: Double?
            let chartPreviousClose: Double?
        }
        let chart: Chart
    }

    func fetch(_ symbol: String) async throws -> Quote {
        guard let encoded = symbol.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(.init(charactersIn: ".-"))),
              var comps = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(encoded)")
        else { throw FetchError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "interval", value: "1d"),
            URLQueryItem(name: "range", value: "1d"),
        ]
        guard let url = comps.url else { throw FetchError.badURL }

        var req = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        req.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 { throw FetchError.http(http.statusCode) }

        let decoded = try JSONDecoder().decode(ChartResponse.self, from: data)
        guard let meta = decoded.chart.result?.first?.meta, let price = meta.regularMarketPrice else {
            throw FetchError.noData
        }
        return Quote(
            symbol: symbol,
            price: price,
            previousClose: meta.previousClose ?? meta.chartPreviousClose,
            currency: meta.currency,
            lastLiveTrade: nil,
            updated: Date()
        )
    }
}
