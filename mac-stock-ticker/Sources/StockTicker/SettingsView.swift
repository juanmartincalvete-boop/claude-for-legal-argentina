import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State private var symbolsText: String
    @State private var keyText: String
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    init(settings: Settings) {
        self.settings = settings
        _symbolsText = State(initialValue: settings.symbols.joined(separator: ", "))
        _keyText = State(initialValue: settings.finnhubKey)
    }

    var body: some View {
        Form {
            Section("Símbolos") {
                TextField("AAPL, MSFT, GGAL.BA, ^MERV, BTC-USD", text: $symbolsText, axis: .vertical)
                    .lineLimit(2...5)
                Text("Separados por coma o espacio. Formato Yahoo Finance: acciones de BYMA con sufijo .BA (GGAL.BA, YPFD.BA), índices con ^ (^GSPC, ^MERV), cripto como BTC-USD.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Tiempo real (opcional)") {
                SecureField("API key de Finnhub", text: $keyText)
                Text("Con una clave gratuita de finnhub.io, las acciones de EE.UU. se actualizan operación por operación (● verde). Sin clave, se consulta Yahoo Finance cada pocos segundos.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Aplicar símbolos y clave") {
                    settings.symbols = Settings.parseSymbols(symbolsText)
                    settings.finnhubKey = keyText.trimmingCharacters(in: .whitespacesAndNewlines)
                    symbolsText = settings.symbols.joined(separator: ", ")
                }
                .keyboardShortcut(.defaultAction)
            }

            Section("Apariencia") {
                Picker("Posición", selection: $settings.position) {
                    ForEach(TickerPosition.allCases) { Text($0.label).tag($0) }
                }
                LabeledContent("Velocidad") { Slider(value: $settings.speed, in: 15...250) }
                LabeledContent("Alto") { Slider(value: $settings.height, in: 18...56, step: 1) }
                LabeledContent("Opacidad del fondo") { Slider(value: $settings.opacity, in: 0.2...1) }
                Toggle("Dejar pasar los clics a la ventana de abajo", isOn: $settings.clickThrough)
            }

            Section("Datos") {
                Stepper("Consultar Yahoo cada \(Int(settings.pollInterval)) s",
                        value: $settings.pollInterval, in: 5...300, step: 5)
            }

            Section("Sistema") {
                Toggle("Abrir al iniciar sesión", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() }
                            else { try SMAppService.mainApp.unregister() }
                            loginError = nil
                        } catch {
                            loginError = "No se pudo cambiar (funciona sólo con la app empaquetada como .app): \(error.localizedDescription)"
                        }
                    }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .padding(.vertical, 8)
    }
}
