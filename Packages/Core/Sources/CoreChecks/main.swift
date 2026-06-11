import Foundation
import CryptoKit
import LicenseKit
import UpdateKit
import RemoteConfigKit

// Minimal CLT-runnable assertion harness (no XCTest dependency).
var failures = 0
func check(_ cond: Bool, _ msg: String) {
    if cond { print("  ✓ \(msg)") } else { print("  ✗ \(msg)"); failures += 1 }
}
func section(_ name: String) { print("\n▸ \(name)") }

// MARK: SemVer
section("SemVer")
check(SemVer("1.2.0") < SemVer("1.2.1"), "1.2.0 < 1.2.1")
check(SemVer("1.10.0") > SemVer("1.9.9"), "1.10.0 > 1.9.9")
check(SemVer("v2.0") > SemVer("1.9.9"), "v2.0 > 1.9.9")
check(SemVer("1.2") == SemVer("1.2.0"), "1.2 == 1.2.0")
check(!(SemVer("1.0.0") < SemVer("1.0.0")), "1.0.0 !< 1.0.0")
check(SemVer("1.0.0-beta") == SemVer("1.0.0"), "pre-release suffix ignored")

// MARK: UpdatePolicy
section("UpdatePolicy")
check(UpdatePolicy.evaluate(flags: .safeDefaults, currentVersion: "1.0.0") == .updatesDisabled,
      "updates disabled by default")
var f1 = FeatureFlags(); f1.updatesEnabled = true
check(UpdatePolicy.evaluate(flags: f1, currentVersion: "1.0.0") == .ok, "ok when updates enabled")
var f2 = FeatureFlags(); f2.forceUpdate = true; f2.minSupportedVersion = "1.5.0"
check(UpdatePolicy.evaluate(flags: f2, currentVersion: "1.4.0") == .forced(min: "1.5.0", current: "1.4.0"),
      "forced when below min")
var f3 = FeatureFlags(); f3.forceUpdate = true; f3.minSupportedVersion = "1.5.0"; f3.updatesEnabled = true
check(UpdatePolicy.evaluate(flags: f3, currentVersion: "1.5.0") == .ok, "not forced at/above min")

// MARK: License verification
section("License verification")
func makeLicense(_ license: License, key: Curve25519.Signing.PrivateKey) throws -> String {
    let payload = try JSONEncoder().encode(license)
    let sig = try key.signature(for: payload)
    return payload.base64EncodedString() + "." + sig.base64EncodedString()
}
do {
    let key = Curve25519.Signing.PrivateKey()
    let other = Curve25519.Signing.PrivateKey()
    let verifier = try LicenseVerifier(publicKeyData: key.publicKey.rawRepresentation)

    let valid = try makeLicense(License(email: "a@b.com", productID: "glaze", features: ["pro"]), key: key)
    check(verifier.verify(valid, expectedProductID: "glaze").isActive, "valid signature accepted")

    let wrongProduct = verifier.verify(valid, expectedProductID: "twinned")
    if case .invalid = wrongProduct { check(true, "wrong product rejected") } else { check(false, "wrong product rejected") }

    let tampered = try makeLicense(License(email: "a@b.com", productID: "glaze"), key: other)
    if case .invalid = verifier.verify(tampered, expectedProductID: "glaze") { check(true, "bad signature rejected") } else { check(false, "bad signature rejected") }

    let expired = try makeLicense(License(email: "a@b.com", productID: "glaze",
                                          expiresAt: Date().timeIntervalSince1970 - 100), key: key)
    if case .expired = verifier.verify(expired, expectedProductID: "glaze") { check(true, "expired detected") } else { check(false, "expired detected") }
} catch {
    check(false, "license crypto threw: \(error)")
}

// MARK: Free-period gating (everything free while paid is OFF)
section("Free-period gating")
MainActor.assumeIsolated {
    let remote = RemoteConfig(provider: LocalDefaultsProvider())
    let store = LicenseStore(verifier: nil, productID: "glaze")
    check(store.isAvailable("pro", remote: remote), "pro feature free when paid OFF")
    check(!store.shouldPaywall("pro", remote: remote), "no paywall when paid OFF")
}

print("\n" + (failures == 0 ? "✅ ALL CHECKS PASSED" : "❌ \(failures) CHECK(S) FAILED"))
exit(failures == 0 ? 0 : 1)
