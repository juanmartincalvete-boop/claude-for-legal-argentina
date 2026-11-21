// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "StockTicker",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "StockTicker",
            path: "Sources/StockTicker"
        )
    ]
)
