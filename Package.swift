// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Cider",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Cider", targets: ["CiderApp"]), .executable(name: "cider-events", targets: ["CiderEventHelper"]), .executable(name: "cider-cli", targets: ["CiderCLI"])],
    targets: [
        .target(name: "CiderDomain"),
        .executableTarget(name: "CiderEventHelper", dependencies: ["CiderDomain"]),
        .systemLibrary(name: "CSQLite"),
        .target(name: "CiderData", dependencies: ["CiderDomain", "CSQLite"], resources: [.copy("LinkedWork/Schema.sql")]),
        .executableTarget(name: "CiderCLI", dependencies: ["CiderDomain", "CiderData"]),
        .target(name: "CiderUI", dependencies: ["CiderDomain"]),
        .target(name: "CiderPlatform", dependencies: ["CiderDomain", "CiderUI"], resources: [.copy("Resources")]),
        .executableTarget(name: "CiderApp", dependencies: ["CiderDomain", "CiderData", "CiderUI", "CiderPlatform"], path: ".", exclude: ["Vendor", "dist", "Sources", "Tests", "docs", "design", "output", "script", "AGENTS.md", "README.md"], sources: ["App", "Features"]),
        .testTarget(name: "CiderDomainTests", dependencies: ["CiderDomain", "CiderData"]),
        .testTarget(name: "CiderPlatformTests", dependencies: ["CiderPlatform"]),
        .testTarget(name: "CiderLinkedWorkTests", dependencies: ["CiderDomain", "CiderData", "CiderUI", "CSQLite"], resources: [.copy("Fixtures")]),
        .testTarget(name: "CiderIntegrationTests", dependencies: ["CiderApp"])
    ],
    swiftLanguageModes: [.v6]
)
