import Foundation
import CryptoKit
import RemoteConfigKit

/// A signed license. Payload is signed with the vendor's Ed25519 private key
/// (offline). The app embeds the matching public key and verifies locally — no
/// network needed. The real feature gate lives in each app's private engine;
/// this is the shared client verifier + store + UI model.
public struct License: Codable, Equatable, Sendable {
    public var email: String
    public var productID: String
    /// Unix seconds; `nil` = perpetual.
    public var expiresAt: Double?
    /// Feature identifiers this license unlocks.
    public var features: [String]

    public init(email: String, productID: String, expiresAt: Double? = nil, features: [String] = []) {
        self.email = email
        self.productID = productID
        self.expiresAt = expiresAt
        self.features = features
    }

    public func isExpired(now: Date = Date()) -> Bool {
        guard let expiresAt else { return false }
        return now.timeIntervalSince1970 > expiresAt
    }
}

public enum LicenseStatus: Equatable, Sendable {
    case unlicensed
    case valid(License)
    case expired(License)
    case invalid(reason: String)

    public var isActive: Bool { if case .valid = self { return true }; return false }
}

/// Verifies a license string of the form `base64(payloadJSON).base64(signature)`.
public struct LicenseVerifier: Sendable {
    private let publicKey: Curve25519.Signing.PublicKey

    /// - Parameter publicKeyData: 32-byte raw Ed25519 public key for this product.
    public init(publicKeyData: Data) throws {
        self.publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    }

    public func verify(_ licenseString: String, expectedProductID: String, now: Date = Date()) -> LicenseStatus {
        let parts = licenseString.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2,
              let payloadData = Data(base64Encoded: pad(parts[0])),
              let signature = Data(base64Encoded: pad(parts[1])) else {
            return .invalid(reason: "Malformed license key")
        }
        guard publicKey.isValidSignature(signature, for: payloadData) else {
            return .invalid(reason: "Signature does not match")
        }
        guard let license = try? JSONDecoder().decode(License.self, from: payloadData) else {
            return .invalid(reason: "Unreadable license payload")
        }
        guard license.productID == expectedProductID else {
            return .invalid(reason: "License is for a different product")
        }
        return license.isExpired(now: now) ? .expired(license) : .valid(license)
    }

    /// base64 from some encoders omits padding; restore it.
    private func pad(_ s: String) -> String {
        let r = s.count % 4
        return r == 0 ? s : s + String(repeating: "=", count: 4 - r)
    }
}

/// Persists the entered license string and exposes the current status, combined
/// with the remote `paidFeaturesEnabled` master switch.
@MainActor
public final class LicenseStore: ObservableObject {
    @Published public private(set) var status: LicenseStatus = .unlicensed

    private let verifier: LicenseVerifier?
    private let productID: String
    private let store: UserDefaults
    private let key = "mac_utilities.license.key"

    public init(verifier: LicenseVerifier?, productID: String, store: UserDefaults = .standard) {
        self.verifier = verifier
        self.productID = productID
        self.store = store
        if let saved = store.string(forKey: key) { _ = apply(saved) }
    }

    @discardableResult
    public func apply(_ licenseString: String) -> LicenseStatus {
        guard let verifier else { status = .invalid(reason: "No verifier configured"); return status }
        let s = verifier.verify(licenseString, expectedProductID: productID)
        status = s
        if s.isActive { store.set(licenseString, forKey: key) }
        return s
    }

    public func clear() {
        store.removeObject(forKey: key)
        status = .unlicensed
    }

    /// Whether the user may USE a (potentially pro) feature right now.
    ///
    /// While paid features are remotely OFF (the shipped default) everything is
    /// free → returns `true` for everyone. Once monetization is flipped ON, the
    /// feature is available only with an active license that grants it.
    public func isAvailable(_ feature: String, remote: RemoteConfig) -> Bool {
        guard remote.paidEnabled else { return true } // free period
        if case .valid(let lic) = status { return lic.features.contains(feature) }
        return false
    }

    /// Whether a paywall should be shown for `feature` (monetization on, and the
    /// user can't use it yet). Always `false` during the free period.
    public func shouldPaywall(_ feature: String, remote: RemoteConfig) -> Bool {
        remote.paidEnabled && !isAvailable(feature, remote: remote)
    }
}
