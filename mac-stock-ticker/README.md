# Stock Ticker para macOS

Una franja fina con cotizaciones que se desplazan, como una cinta bursátil.
Queda **siempre visible por encima de las demás ventanas**, en todos los Espacios
y también junto a apps en pantalla completa, mientras usás otros programas.

```
AAPL 189,23 ▲ +1,25 (+0,66%) ●     •     GGAL.BA 6.420,00 ▼ -85,00 (-1,31%)     •     ^MERV ...
```

- Verde ▲ sube, rojo ▼ baja (respecto del cierre anterior).
- `●` verde: precio recibido en tiempo real por Finnhub en el último minuto.
- `…` todavía cargando · `N/D` Yahoo no devolvió datos para ese símbolo.

## Requisitos

- macOS 13 (Ventura) o posterior.
- Command Line Tools de Xcode (alcanza con `xcode-select --install`; no hace falta Xcode completo).

## Instalación

```bash
git clone <este repo> && cd claude-for-legal-argentina/mac-stock-ticker

# Opción A: probarla directamente
swift run -c release

# Opción B: generar la app (recomendado)
./build-app.sh
mv StockTicker.app /Applications/
open /Applications/StockTicker.app
```

La app no muestra ícono en el Dock: se maneja desde el ícono **📈** de la barra de menú
o con **clic derecho sobre el ticker**.

## Uso

Menú 📈:

| Opción | Atajo | Qué hace |
|---|---|---|
| Configuración… | ⌘, | Símbolos, clave de Finnhub, posición, velocidad, alto, opacidad |
| Pausar desplazamiento | ⌘P | Congela la cinta |
| Ocultar / Mostrar ticker | ⌘H | |
| Actualizar ahora | ⌘R | Fuerza una consulta |
| Salir | ⌘Q | |

Pasar el mouse por encima de la cinta también la pausa, para leer un valor con calma.
Si preferís que la cinta no intercepte clics, activá *“Dejar pasar los clics a la ventana de abajo”*.

### Símbolos

Se usan los códigos de Yahoo Finance:

| Tipo | Ejemplos |
|---|---|
| Acciones / ADRs de EE.UU. | `AAPL`, `MSFT`, `GGAL`, `YPF`, `MELI` |
| Acciones de BYMA (pesos) | `GGAL.BA`, `YPFD.BA`, `PAMP.BA`, `ALUA.BA` |
| Índices | `^GSPC` (S&P 500), `^IXIC` (Nasdaq), `^MERV` (Merval) |
| Cripto | `BTC-USD`, `ETH-USD` |
| Monedas | `EURUSD=X`, `ARS=X` |

## Fuentes de datos

1. **Yahoo Finance (siempre, sin clave).** Se consulta cada N segundos (15 por defecto,
   configurable). Aporta precio y cierre anterior para todos los mercados. Es un endpoint
   público pero **no oficial**: puede cambiar sin aviso, y según el mercado los precios
   pueden tener demora (Yahoo indica en su sitio la demora de cada bolsa).
2. **Finnhub (opcional, tiempo real).** Creando una cuenta gratuita en
   [finnhub.io](https://finnhub.io) obtenés una API key; pegala en Configuración y las
   acciones de EE.UU. se actualizan operación por operación vía WebSocket. Los símbolos que
   Finnhub no cubre (p. ej. `.BA` o índices) siguen actualizándose con Yahoo.

La clave se guarda en las preferencias locales del usuario (`UserDefaults`), no se envía a
ningún lado salvo a Finnhub.

## Modo "Widget de TradingView"

En **Configuración → Fuente de datos** podés elegir *Widget de TradingView*. En ese modo la
franja muestra el widget oficial y gratuito **Ticker Tape** de TradingView, en lugar de la cinta propia:

1. Entrá a https://tradingview.com/widget/ y elegí **Ticker Tape**.
2. Cargá tus símbolos con el prefijo del mercado (por ejemplo `MATBAROFEX:...`, `BCBA:GGAL`).
3. Copiá el código que te da la página y pegalo completo en **Código del widget de TradingView**.
4. Clic en **Aplicar código**. Ajustá **Alto** y **Tamaño del widget** hasta que entre bien en la franja.

El widget es el mismo que se inserta en cualquier página web: **no usa tu cuenta ni tu
suscripción de TradingView**, y los datos (y su demora) son los que TradingView publica en sus
widgets gratuitos. Al hacer clic en un símbolo se abre TradingView en el navegador. La app no
extrae datos de TradingView: sólo muestra el widget.

## Estructura

```
Sources/StockTicker/
  main.swift            arranque de la app (sin ícono en el Dock)
  AppDelegate.swift     menú de barra, ventana de configuración, cableado general
  TickerPanel.swift     ventana sin bordes, siempre al frente, en todos los Espacios
  TickerView.swift      dibujo y desplazamiento de la cinta + formato del texto
  QuoteStore.swift      combina Yahoo (consulta periódica) y Finnhub (en vivo)
  YahooProvider.swift   cliente de Yahoo Finance
  FinnhubStream.swift   cliente WebSocket de Finnhub con reconexión
  Settings.swift        preferencias persistidas
  SettingsView.swift    pantalla de configuración (SwiftUI)
  TradingViewView.swift muestra el widget Ticker Tape de TradingView
build-app.sh            genera StockTicker.app firmada localmente
```

## Limitaciones conocidas

- macOS no permite a apps de terceros “reservar” una franja de pantalla como hace el Dock:
  la cinta se superpone al borde de las ventanas maximizadas. Elegí arriba o abajo según lo
  que menos te moleste, o bajá la opacidad.
- Se muestra en la pantalla principal (con varios monitores, la que tiene la barra de menú activa).
- “Abrir al iniciar sesión” funciona sólo con la app empaquetada (`build-app.sh`), no con `swift run`.
