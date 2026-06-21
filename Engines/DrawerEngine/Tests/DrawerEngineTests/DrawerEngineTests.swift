import XCTest
@testable import DrawerEngine

// MARK: - Classification

final class ClassifyTests: XCTestCase {
    func testHttpUrl() {
        XCTAssertEqual(classify("https://example.com"), .url)
        XCTAssertEqual(classify("http://example.com"), .url)
        XCTAssertEqual(classify("  HTTPS://Example.com  "), .url)
        XCTAssertEqual(classify("www.example.com"), .url)
    }

    func testHexColor() {
        XCTAssertEqual(classify("#fff"), .color)
        XCTAssertEqual(classify("#FF8800"), .color)
        XCTAssertEqual(classify("#abc123"), .color)
    }

    func testBadHexIsText() {
        XCTAssertEqual(classify("#ff"), .text)        // wrong length
        XCTAssertEqual(classify("#ggg"), .text)       // not hex digits
        XCTAssertEqual(classify("fff"), .text)        // missing #
        XCTAssertEqual(classify("#12345"), .text)     // 5 chars
    }

    func testPlainText() {
        XCTAssertEqual(classify("hello world"), .text)
        XCTAssertEqual(classify("ftp://x"), .text)    // only http(s)/www are urls
    }
}

// MARK: - Inline arithmetic

final class EvaluateInlineTests: XCTestCase {
    func testBasicArithmetic() {
        XCTAssertEqual(evaluateInline("12*3"), "36")
        XCTAssertEqual(evaluateInline("2+2"), "4")
        XCTAssertEqual(evaluateInline("10-4"), "6")
    }

    func testFloatingDivision() {
        // Integer literals must still produce floating-point division.
        XCTAssertEqual(evaluateInline("10/4"), "2.5")
        XCTAssertEqual(evaluateInline("(2+2)/4"), "1")
    }

    func testFullWidthParens() {
        XCTAssertEqual(evaluateInline("（2+2)/4"), "1")
    }

    func testNonExpressionsReturnNil() {
        XCTAssertNil(evaluateInline("hello"))
        XCTAssertNil(evaluateInline("42"))            // bare number: no operator
        XCTAssertNil(evaluateInline(""))
        XCTAssertNil(evaluateInline("   "))
        XCTAssertNil(evaluateInline("+++"))           // no digit
        XCTAssertNil(evaluateInline("1 + abc"))       // disallowed chars
    }

    func testIntegerResultHasNoDecimal() {
        XCTAssertEqual(evaluateInline("3*3"), "9")
    }
}

// MARK: - ClipboardStore (no persistence -> in-memory, no Keychain needed)

@MainActor
final class ClipboardStoreTests: XCTestCase {
    func testAddClassifiesAndPrepends() {
        let store = ClipboardStore()
        store.add("hello")
        store.add("https://a.com")
        XCTAssertEqual(store.items.count, 2)
        XCTAssertEqual(store.items.first?.kind, .url)        // newest first
        XCTAssertEqual(store.items.last?.kind, .text)
    }

    func testAddPreservesExactTextButTrimsForEmptyCheck() {
        let store = ClipboardStore()
        store.add("   ")                                     // whitespace only -> ignored
        XCTAssertTrue(store.items.isEmpty)
        store.add("  keep me \n")                            // exact text retained
        XCTAssertEqual(store.items.first?.text, "  keep me \n")
    }

    func testConsecutiveDuplicateDeduped() {
        let store = ClipboardStore()
        store.add("dup")
        store.add("dup")
        XCTAssertEqual(store.items.count, 1)
        store.add("other")
        store.add("dup")                                     // non-consecutive dup allowed
        XCTAssertEqual(store.items.count, 3)
    }

    func testSearchCaseInsensitive() {
        let store = ClipboardStore()
        store.add("Apple")
        store.add("banana")
        XCTAssertEqual(store.search("APP").map(\.text), ["Apple"])
        XCTAssertEqual(store.search("").count, 2)            // empty query -> all
    }

    func testTogglePin() {
        let store = ClipboardStore()
        store.add("x")
        let id = store.items[0].id
        XCTAssertFalse(store.items[0].pinned)
        store.togglePin(id)
        XCTAssertTrue(store.items[0].pinned)
        store.togglePin(id)
        XCTAssertFalse(store.items[0].pinned)
    }

    func testRemove() {
        let store = ClipboardStore()
        store.add("a"); store.add("b")
        let id = store.items[0].id
        store.remove(id)
        XCTAssertEqual(store.items.map(\.text), ["a"])
    }

    func testClearUnpinnedKeepsPinned() {
        let store = ClipboardStore()
        store.add("a"); store.add("b")
        store.togglePin(store.items.first { $0.text == "a" }!.id)
        store.clearUnpinned()
        XCTAssertEqual(store.items.map(\.text), ["a"])
    }

    func testClearAllRemovesEverything() {
        let store = ClipboardStore()
        store.add("a"); store.togglePin(store.items[0].id)
        store.clearAll()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testTrimRespectsCapacityButKeepsPinned() {
        let store = ClipboardStore(capacity: 3)
        for i in 0..<5 { store.add("item\(i)") }
        XCTAssertEqual(store.items.count, 3)                 // capped
        // Pin the oldest survivor, then overflow again.
        let oldest = store.items.last!
        store.togglePin(oldest.id)
        for i in 5..<10 { store.add("more\(i)") }
        XCTAssertTrue(store.items.contains { $0.id == oldest.id }) // pinned survives cap
    }
}

// MARK: - Vault round-trip (Keychain-backed, isolated per-test service)

final class VaultTests: XCTestCase {
    func testEncryptDecryptRoundTrip() throws {
        let service = "com.plainware.tray.test.\(UUID().uuidString)"
        defer { Keychain.delete(service: service, account: "drawer.dek.v1") }
        let vault = Vault(service: service)
        let plaintext = Data("the quick brown fox 🦊".utf8)
        let cipher = try vault.encrypt(plaintext)
        XCTAssertNotEqual(cipher, plaintext)                 // actually encrypted
        let round = try vault.decrypt(cipher)
        XCTAssertEqual(round, plaintext)
    }

    func testDecryptWithWrongKeyFails() throws {
        let s1 = "com.plainware.tray.test.\(UUID().uuidString)"
        let s2 = "com.plainware.tray.test.\(UUID().uuidString)"
        defer {
            Keychain.delete(service: s1, account: "drawer.dek.v1")
            Keychain.delete(service: s2, account: "drawer.dek.v1")
        }
        let cipher = try Vault(service: s1).encrypt(Data("secret".utf8))
        XCTAssertThrowsError(try Vault(service: s2).decrypt(cipher))
    }
}

// MARK: - PasscodeStore (PBKDF2, isolated per-test service)

final class PasscodeStoreTests: XCTestCase {
    private func freshStore() -> (PasscodeStore, String) {
        let service = "com.plainware.tray.test.\(UUID().uuidString)"
        return (PasscodeStore(service: service), service)
    }

    func testSetVerifyClear() {
        let (store, service) = freshStore()
        defer { store.clear(); _ = service }
        XCTAssertFalse(store.isSet)
        store.set("1234")
        XCTAssertTrue(store.isSet)
        XCTAssertTrue(store.verify("1234"))
        XCTAssertFalse(store.verify("9999"))
        store.clear()
        XCTAssertFalse(store.isSet)
        XCTAssertFalse(store.verify("1234"))
    }

    func testPbkdf2DeterministicForSameSalt() {
        let salt = Data(repeating: 7, count: 16)
        let a = PasscodeStore.pbkdf2("pw", salt: salt, rounds: 1000)
        let b = PasscodeStore.pbkdf2("pw", salt: salt, rounds: 1000)
        XCTAssertEqual(a, b)
        XCTAssertEqual(a.count, 32)
        XCTAssertNotEqual(a, PasscodeStore.pbkdf2("pw2", salt: salt, rounds: 1000))
    }

    func testLegacyV1BlobAccepted() {
        // Construct a legacy 48-byte salt||SHA256(salt||passcode) blob and verify.
        let (store, service) = freshStore()
        defer { store.clear() }
        let salt = Data(repeating: 3, count: 16)
        var input = salt; input.append(Data("pass".utf8))
        let digest = Data(sha256Compat(input))
        var blob = salt; blob.append(digest)
        _ = Keychain.set(blob, service: service, account: "drawer.passcode.v1")
        XCTAssertTrue(store.verify("pass"))
        XCTAssertFalse(store.verify("nope"))
    }
}

// Small SHA-256 helper for the legacy-blob test that doesn't import CryptoKit at
// the test-file top level (engine already links it transitively).
import CryptoKit
private func sha256Compat(_ d: Data) -> [UInt8] { Array(SHA256.hash(data: d)) }
