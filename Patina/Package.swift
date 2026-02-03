// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Patina",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Patina", targets: ["Patina"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Patina",
            dependencies: ["PatinaCoreFFI"],
            path: "Patina"
        ),
        .target(
            name: "PatinaCoreFFI",
            dependencies: [],
            path: "PatinaCoreFFI",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include")
            ],
            linkerSettings: [
                .linkedLibrary("patina_core", .when(platforms: [.macOS])),
                .unsafeFlags(["-L../../patina-core/target/release"])
            ]
        )
    ]
)
