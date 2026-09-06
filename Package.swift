// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Cider",
    platforms: [.macOS("26.0")],
    products: [.executable(name: "Cider", targets: ["CiderApp"]), .executable(name: "cider-events", targets: ["CiderEventHelper"])],
    targets: [
        .target(name: "CiderDomain"),
        .executableTarget(name: "CiderEventHelper", dependencies: ["CiderDomain"]),
        .target(name: "CiderData", dependencies: ["CiderDomain"]),
        .target(name: "CiderUI", dependencies: ["CiderDomain"]),
        .target(name: "CiderPlatform", dependencies: ["CiderDomain", "CiderUI"], resources: [.copy("Resources")]),
        .executableTarget(name: "CiderApp", dependencies: ["CiderDomain", "CiderData", "CiderUI", "CiderPlatform"], path: ".", exclude: ["Vendor", "dist", "Sources", "Tests", "docs", "design", "output", "script", "AGENTS.md", "README.md"], sources: ["App", "Features"]),
        .testTarget(name: "CiderDomainTests", dependencies: ["CiderDomain", "CiderData"]),
        .testTarget(name: "CiderPlatformTests", dependencies: ["CiderPlatform"])
    ],
    swiftLanguageModes: [.v6]
)
