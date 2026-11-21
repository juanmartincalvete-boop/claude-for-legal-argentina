import AppKit
import WebKit

/// Muestra el widget oficial "Ticker Tape" de TradingView usando el código de inserción
/// que el usuario copia desde tradingview.com/widget. No usa la cuenta ni la sesión de
/// TradingView: es el mismo widget público que se inserta en cualquier página web.
final class TradingViewView: WKWebView, WKNavigationDelegate, WKUIDelegate {
    /// Devuelve el menú propio de la app para reemplazar el menú contextual de WebKit.
    var menuProvider: (() -> NSMenu)?

    private var loadedHTML = ""
    private var backgroundAlpha: Double = 0.88

    init(frame: NSRect) {
        super.init(frame: frame, configuration: WKWebViewConfiguration())
        navigationDelegate = self
        uiDelegate = self
        setValue(false, forKey: "drawsBackground")  // fondo transparente
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no soportado") }

    func show(embed: String, backgroundAlpha: Double, zoom: Double) {
        pageZoom = CGFloat(zoom)
        self.backgroundAlpha = backgroundAlpha
        let html = Self.page(embed: embed, alpha: backgroundAlpha)
        guard html != loadedHTML else { return }
        loadedHTML = html
        loadHTMLString(html, baseURL: URL(string: "https://stockticker.local/"))
    }

    /// Cambia la opacidad del fondo sin recargar el widget.
    func setBackgroundAlpha(_ alpha: Double) {
        guard alpha != backgroundAlpha else { return }
        backgroundAlpha = alpha
        evaluateJavaScript("document.body.style.background='rgba(15,15,15,\(alpha))'")
    }

    func reloadWidget() {
        guard !loadedHTML.isEmpty else { return }
        loadHTMLString(loadedHTML, baseURL: URL(string: "https://stockticker.local/"))
    }

    private static func page(embed: String, alpha: Double) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
          html, body { margin: 0; padding: 0; height: 100%; overflow: hidden; }
          body { background: rgba(15,15,15,\(alpha)); display: flex; align-items: center; }
          body > * { width: 100%; }
        </style>
        </head>
        <body>
        \(embed)
        </body>
        </html>
        """
    }

    // MARK: - Enlaces: se abren en el navegador, no dentro de la franja

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = navigationAction.request.url { NSWorkspace.shared.open(url) }
        return nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { reloadWidget() }

    // MARK: - Clic derecho: menú de la app en lugar del de WebKit

    override func willOpenMenu(_ menu: NSMenu, with event: NSEvent) {
        guard let ours = menuProvider?() else { return }
        menu.removeAllItems()
        for item in ours.items {
            ours.removeItem(item)
            menu.addItem(item)
        }
    }
}
