import Foundation
import LocalAuthentication

enum NoctisUnlockError: LocalizedError {
    case unavailable
    case denied

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Device authentication is unavailable."
        case .denied:
            return "Authentication was not successful."
        }
    }
}

/// Uses device owner authentication. Does not store biometric data or device passcodes.
struct NoctisDeviceAuthenticator {
    func unlock(reason: String = "Unlock your private Noctis conversations") async throws {
        let context = LAContext()
        context.localizedCancelTitle = "Cancel"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw error ?? NoctisUnlockError.unavailable
        }
        let success = try await context.evaluatePolicy(
            .deviceOwnerAuthentication,
            localizedReason: reason
        )
        guard success else { throw NoctisUnlockError.denied }
    }
}
