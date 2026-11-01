import Darwin
import Foundation
import Security

enum ConnectionAuthorization {
    static func isContainingApp(_ connection: NSXPCConnection) -> Bool {
        guard connection.effectiveUserIdentifier == geteuid() else { return false }

        // Only the signed executable in this service's enclosing app is allowed.
        // This works for local ad hoc signatures as well as Developer ID builds.
        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard appURL.pathExtension == "app" else { return false }
        let expectedExecutable = appURL.appendingPathComponent("Contents/MacOS/iCloudDriveManager")
            .standardizedFileURL.resolvingSymlinksInPath()
        let attributes = [kSecGuestAttributePid as String: NSNumber(value: connection.processIdentifier)]
        var guest: SecCode?
        guard SecCodeCopyGuestWithAttributes(nil, attributes as CFDictionary, SecCSFlags(), &guest) == errSecSuccess,
            let guest,
            SecCodeCheckValidity(guest, SecCSFlags(), nil) == errSecSuccess
        else { return false }

        var staticCode: SecStaticCode?
        guard SecCodeCopyStaticCode(guest, SecCSFlags(), &staticCode) == errSecSuccess,
            let staticCode
        else { return false }

        var information: CFDictionary?
        guard
            SecCodeCopySigningInformation(
                staticCode, SecCSFlags(rawValue: kSecCSSigningInformation), &information
            ) == errSecSuccess,
            let values = information as? [String: Any],
            values[kSecCodeInfoIdentifier as String] as? String == "com.local.iCloudDriveManager",
            let executable = values[kSecCodeInfoMainExecutable as String] as? URL
        else { return false }
        return executable.standardizedFileURL.resolvingSymlinksInPath() == expectedExecutable
    }
}
