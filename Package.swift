// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TvGuideApp",
    platforms: [.iOS(.v16)],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift", from: "6.0.0"),
    ],
    targets: [
        .target(
            name: "TvGuideApp",
            dependencies: [
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: ".",
            sources: ["App", "Core", "Database", "Models", "Views"],
            exclude: ["Readme.me", "Tests"],
            linkerSettings: [
                .linkedLibrary("z"),
            ]
        ),
    ]
)
