// swift-tools-version:5.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Sepro18",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .executable(
            name: "sepro",
            targets: ["Tool"]),
        .library(
            name: "Sepro",
            targets: ["Simulation", "Compiler"])
    ],
    dependencies: [
        .package(url: "https://github.com/Stiivi/DotWriter.git", from: "0.1.0"),
        .package(url: "https://github.com/AgentFarms/ObjectGraph.git", from: "0.1.2")
    ],
    targets: [
        .target(
            name: "Model",
            dependencies: []),
        .target(
            name: "Simulator",
            dependencies: []),
        .target(
            name: "Compiler",
            dependencies: []),
        .target(
            name: "Simulation",
            dependencies: ["Model", "Simulator", "ObjectGraph"]),
        .target(
            name: "Tool",
            dependencies: ["Compiler", "Simulation", "DotWriter"]),
        .testTarget(
            name: "Sepro18Tests",
            dependencies: ["Compiler", "Simulation"])
    ]
)
