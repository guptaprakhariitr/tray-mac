import XCTest
import Foundation
import CryptoKit
@testable import LicenseKit
@testable import UpdateKit
@testable import RemoteConfigKit

final class SemVerTests: XCTestCase {
    func testComparison() {
        XCTAssertTrue(SemVer("1.2.0") < SemVer("1.2.1"))
        XCTAssertTrue(SemVer("1.10.0") > SemVer("1.9.9"))
        XCTAssertTrue(SemVer("v2.0") > SemVer("1.9.9"))
        XCTAssertEqual(SemVer("1.2"), SemVer("1.2.0"))
        XCTAssertFalse(SemVer("1.0.0") < SemVer("1.0.0"))
        XCTAssertEqual(SemVer("1.0.0-beta"), SemVer("1.0.0")) // suffix ignored
    }
}

final class UpdatePolicyTests: XCTestCase {
    func testDisabledByDefault() {
        XCTAssertEqual(UpdatePolicy.evaluate(flags: .safeDefaults, currentVersion: "1.0.0"), .updatesDisabled)
    }
    func testEnabledWhenFlagOn() {
        var f = FeatureFlags(); f.updatesEnabled = true
        XCTAssertEqual(UpdatePolicy.evaluate(flags: f, currentVersion: "1.0.0"), .ok)
    }
    func testForcedWhenBelowMin() {
        var f = FeatureFlags(); f.forceUpdate = true; f.minSupportedVersion = "1.5.0"
        XCTAssertEqual(UpdatePolicy.evaluate(flags: f, currentVersion: "1.4.0"),
                       .forced(min: "1.5.0", current: "1.4.0"))
    }
    func testNotForcedWhenAtOrAboveMin() {
        var f = FeatureFlags(); f.forceUpdate = true; f.minSupportedVersion = "1.5.0"; f.updatesEnabled = true
        XCTAssertEqual(UpdatePolicy.evaluate(flags: f, currentVersion: "1.5.0"), .ok)
    }
}

final class LicenseTests: XCTestCase {
    private func makeLicense(_ license: License, key: Curve25519.Signing.PrivateKey) throws -> String {
        let payload = try JSONEncoder().encode(license)
        let sig = try key.signature(for: payload)
        return payload.base64EncodedString() + "." + sig.base64EncodedString()
    }

    func testValidSignatureAccepted() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)
        let str = try makeLicense(License(email: "a@b.com", productID: "glaze", features: ["pro"]), key: key)
        XCTAssertTrue(verifier.verify(str, expectedProductID: "glaze").isActive)
    }

    func testWrongProductRejected() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)
        let str = try makeLicense(License(email: "a@b.com", productID: "glaze"), key: key)
        guard case .invalid = verifier.verify(str, expectedProductID: "twinned") else {
            return XCTFail("expected invalid for product mismatch")
        }
    }

    func testTamperedSignatureRejected() throws {
        let key = Curve25519.Signing.PrivateKey()
        let other = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)
        let str = try makeLicense(License(email: "a@b.com", productID: "glaze"), key: other)
        guard case .invalid = verifier.verify(str, expectedProductID: "glaze") else {
            return XCTFail("expected invalid for bad signature")
        }
    }

    func testExpiredDetected() throws {
        let key = Curve25519.Signing.PrivateKey()
        let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)
        let past = Date().timeIntervalSince1970 - 100
        let str = try makeLicense(License(email: "a@b.com", productID: "glaze", expiresAt: past), key: key)
        guard case .expired = verifier.verify(str, expectedProductID: "glaze") else {
            return XCTFail("expected expired")
        }
    }
}

final class GatingTests: XCTestCase {
    @MainActor func testEverythingFreeWhenPaidOff() {
        let remote = RemoteConfig(provider: LocalDefaultsProvider()) // paid OFF
        let store = LicenseStore(verifier: nil, productID: "glaze")
        XCTAssertTrue(store.isAvailable("pro", remote: remote))
        XCTAssertFalse(store.shouldPaywall("pro", remote: remote))
    }
}
