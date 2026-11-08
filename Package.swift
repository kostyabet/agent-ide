// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Deck",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Deck",
            path: "Sources/Deck"
        )
    ]
)
