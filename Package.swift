// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "iCloudDriveManager",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "iCloudDriveManager", targets: ["iCloudDriveManager"]),
        .library(name: "DriveCore", targets: ["DriveCore"]),
        .library(name: "DrivePersistence", targets: ["DrivePersistence"]),
    ],
    targets: [
        .target(name: "DriveCore"),
        .target(name: "DrivePersistence"),
        .executableTarget(
            name: "iCloudDriveManager", dependencies: ["DriveCore", "DrivePersistence"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "DriveCoreTests", dependencies: ["DriveCore"]),
        .testTarget(name: "DrivePersistenceTests", dependencies: ["DrivePersistence"]),
        .testTarget(name: "DriveAppTests", dependencies: ["iCloudDriveManager"]),
    ],
    swiftLanguageModes: [.v5]
)
