import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private let store = QuoteStore()
    private var panel: TickerPanel!
    private var tickerView: TickerView!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        panel = TickerPanel()
        tickerView = TickerView(frame: panel.contentLayoutRect)
        tickerView.autoresizingMask = [.width, .height]
        panel.contentView = tickerView

        let menu = buildMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "📈"
        statusItem.menu = menu
        tickerView.menu = buildMenu()  // clic derecho sobre el ticker

        store.onChange = { [weak self] in self?.refreshText() }

        applyAppearance()
        refreshText()
        panel.orderFrontRegardless()
        restartData()
        observeSettings()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.applyAppearance() }
        // Al despertar la Mac, reconectar enseguida.
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in self?.restartData() }
    }

    func applicationWillTerminate(_ notification: Notification) { store.stop() }

    // MARK: - Configuración reactiva

    private func observeSettings() {
        // receive(on:) difiere la ejecución hasta que el nuevo valor ya quedó guardado.
        Publishers.Merge3(settings.$symbols.map { _ in () },
                          settings.$finnhubKey.map { _ in () },
                          settings.$pollInterval.map { _ in () })
            .dropFirst(3)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] in self?.restartData() }
            .store(in: &cancellables)

        Publishers.Merge5(settings.$position.map { _ in () },
                          settings.$height.map { _ in () },
                          settings.$opacity.map { _ in () },
                          settings.$speed.map { _ in () },
                          settings.$clickThrough.map { _ in () })
            .dropFirst(5)
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.applyAppearance(); self?.refreshText() }
            .store(in: &cancellables)
    }

    private func restartData() {
        store.start(symbols: settings.symbols, finnhubKey: settings.finnhubKey, interval: settings.pollInterval)
    }

    private func applyAppearance() {
        let h = CGFloat(settings.height)
        panel.reposition(settings.position, height: h)
        panel.ignoresMouseEvents = settings.clickThrough
        tickerView.speed = CGFloat(settings.speed)
        tickerView.backgroundAlpha = CGFloat(settings.opacity)
    }

    private func refreshText() {
        let fontSize = max(10, CGFloat(settings.height) * 0.48)
        tickerView.setContent(TickerFormatter.make(symbols: settings.symbols, quotes: store.quotes,
                                                   failed: store.failed, fontSize: fontSize))
    }

    // MARK: - Menú

    private func buildMenu() -> NSMenu {
        let m = NSMenu()
        m.addItem(withTitle: "Configuración…", action: #selector(openSettings), keyEquivalent: ",").target = self
        m.addItem(withTitle: "Pausar desplazamiento", action: #selector(togglePause), keyEquivalent: "p").target = self
        m.addItem(withTitle: "Ocultar ticker", action: #selector(toggleVisible), keyEquivalent: "h").target = self
        m.addItem(withTitle: "Actualizar ahora", action: #selector(refreshNow), keyEquivalent: "r").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        m.delegate = self
        return m
    }

    @objc private func togglePause() { tickerView.userPaused.toggle() }

    @objc private func toggleVisible() {
        if panel.isVisible { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
    }

    @objc private func refreshNow() { restartData() }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let w = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
            w.title = "Stock Ticker — Configuración"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    // Actualiza los títulos dinámicos cada vez que se abre un menú.
    func menuNeedsUpdate(_ menu: NSMenu) {
        for item in menu.items {
            if item.action == #selector(togglePause) {
                item.title = tickerView.userPaused ? "Reanudar desplazamiento" : "Pausar desplazamiento"
            } else if item.action == #selector(toggleVisible) {
                item.title = panel.isVisible ? "Ocultar ticker" : "Mostrar ticker"
            }
        }
    }
}
