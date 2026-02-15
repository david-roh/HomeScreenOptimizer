// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "HomeScreenOptimizer",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Ingestion", targets: ["Ingestion"]),
        .library(name: "Profiles", targets: ["Profiles"]),
        .library(name: "Usage", targets: ["Usage"]),
        .library(name: "Optimizer", targets: ["Optimizer"]),
        .library(name: "Guide", targets: ["Guide"]),
        .library(name: "Simulation", targets: ["Simulation"]),
        .library(name: "Privacy", targets: ["Privacy"]),
        .executable(name: "HSOPrototype", targets: ["HSOPrototype"])
    ],
    targets: [
        .target(name: "Core"),
        .target(name: "Ingestion", dependencies: ["Core"]),
        .target(name: "Profiles", dependencies: ["Core"]),
        .target(name: "Usage", dependencies: ["Core"]),
        .target(name: "Optimizer", dependencies: ["Core", "Profiles"]),
        .target(name: "Guide", dependencies: ["Core", "Optimizer"]),
        .target(name: "Simulation", dependencies: ["Core", "Optimizer"]),
        .target(name: "Privacy", dependencies: ["Core"]),
        .executableTarget(name: "HSOPrototype", dependencies: ["Core", "Ingestion", "Profiles", "Optimizer", "Simulation", "Guide", "Privacy", "Usage"]),
        .testTarget(name: "CoreTests", dependencies: ["Core"]),
        .testTarget(name: "IngestionTests", dependencies: ["Ingestion", "Core"]),
        .testTarget(name: "ProfilesTests", dependencies: ["Profiles", "Core"])
    ]
)
