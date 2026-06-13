import Foundation
import CryptoKit
import Security

// MARK: - Keychain

/// Thin wrapper over the macOS Keychain for storing small secrets
/// (the data-encryption key and the passcode hash). Items are scoped to this
/// app and protected by the OS — they are never written to our own files.
public enum Keychain {
    @discardableResult
    public static func set(_ data: Data, service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    public static func get(service: String, account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var out: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &out) == errSecSuccess else { return nil }
        return out as? Data
    }

    @discardableResult
    public static func delete(service: String, account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Vault (symmetric encryption)

/// Encrypts/decrypts blobs with AES-GCM. The 256-bit data-encryption key lives
/// in the Keychain (created on first use), so the on-disk history file is only
/// ever ciphertext and is not directly readable — even by other tools on the
/// same Mac that lack the key.
public struct Vault {
    let service: String
    private let keyAccount = "drawer.dek.v1"

    public init(service: String) { self.service = service }

    private func key() -> SymmetricKey {
        if let raw = Keychain.get(service: service, account: keyAccount), raw.count == 32 {
            return SymmetricKey(data: raw)
        }
        let new = SymmetricKey(size: .bits256)
        let raw = new.withUnsafeBytes { Data($0) }
        Keychain.set(raw, service: service, account: keyAccount)
        return new
    }

    public func encrypt(_ plaintext: Data) throws -> Data {
        let sealed = try AES.GCM.seal(plaintext, using: key())
        guard let combined = sealed.combined else { throw VaultError.sealFailed }
        return combined
    }

    public func decrypt(_ ciphertext: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: ciphertext)
        return try AES.GCM.open(box, using: key())
    }

    public enum VaultError: Error { case sealFailed }
}

// MARK: - Passcode (hashed, never stored in plaintext)

/// A private-mode passcode. We never store the passcode itself — only a random
/// 16-byte salt followed by `SHA-256(salt || passcode)`. Verification recomputes
/// the hash; there is no way back to the original passcode from what's stored.
public struct PasscodeStore {
    let service: String
    private let account = "drawer.passcode.v1"

    public init(service: String) { self.service = service }

    public var isSet: Bool { Keychain.get(service: service, account: account) != nil }

    public func set(_ passcode: String) {
        var salt = Data(count: 16)
        _ = salt.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 16, $0.baseAddress!) }
        let digest = hash(passcode, salt: salt)
        Keychain.set(salt + digest, service: service, account: account)
    }

    public func verify(_ passcode: String) -> Bool {
        guard let blob = Keychain.get(service: service, account: account), blob.count == 16 + 32 else { return false }
        let salt = blob.prefix(16)
        let stored = blob.suffix(32)
        let computed = hash(passcode, salt: Data(salt))
        // Constant-time-ish compare.
        return stored.elementsEqual(computed)
    }

    public func clear() { Keychain.delete(service: service, account: account) }

    private func hash(_ passcode: String, salt: Data) -> Data {
        var input = salt
        input.append(Data(passcode.utf8))
        return Data(SHA256.hash(data: input))
    }
}

// MARK: - Encrypted persistence for the clip history

/// Persists clip history to disk as an AES-GCM blob via `Vault`. The file under
/// Application Support holds only ciphertext.
public struct EncryptedClipPersistence {
    let vault: Vault
    let url: URL

    public init?(service: String, fileName: String = "history.enc") {
        guard let dir = try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
        ).appendingPathComponent("Tray", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.url = dir.appendingPathComponent(fileName)
        self.vault = Vault(service: service)
    }

    public func load() -> [ClipItem] {
        guard let cipher = try? Data(contentsOf: url),
              let plain = try? vault.decrypt(cipher),
              let items = try? JSONDecoder().decode([ClipItem].self, from: plain)
        else { return [] }
        return items
    }

    public func save(_ items: [ClipItem]) {
        guard let plain = try? JSONEncoder().encode(items),
              let cipher = try? vault.encrypt(plain) else { return }
        try? cipher.write(to: url, options: [.atomic, .completeFileProtection])
    }

    public func wipe() { try? FileManager.default.removeItem(at: url) }
}
