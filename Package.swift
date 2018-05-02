// swift-tools-version:4.0
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
            targets: ["Simulation", "Compiler"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Stiivi/ParserCombinator.git", from: "0.1.5"),
        .package(url: "../GraphvizWriter", .branch("master")),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Model",
            dependencies: []),
        .target(
            name: "Simulator",
            dependencies: []),
        .target(
            name: "Simulation",
            dependencies: ["Model", "Simulator"]),
        .target(
            name: "Compiler",
            dependencies: ["ParserCombinator", "Model"]),
        .target(
            name: "Tool",
            dependencies: ["Compiler", "Simulation", "GraphvizWriter"]),
        .testTarget(
            name: "Sepro18Tests",
            dependencies: ["Compiler", "Simulation"]),
    ]
)
