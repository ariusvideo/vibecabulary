// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Glossary",
    platforms: [.macOS(.v14)],
    targets: [
        // Data model, file loading and search. No UI, so it is unit-testable.
        .target(name: "GlossaryCore"),
        // Menu bar app (AppKit shell + SwiftUI views).
        .executableTarget(name: "Glossary", dependencies: ["GlossaryCore"]),
        // Checks for GlossaryCore (`swift run GlossaryChecks`); CLT has no XCTest.
        .executableTarget(name: "GlossaryChecks", dependencies: ["GlossaryCore"]),
    ],
    swiftLanguageModes: [.v5]
)
