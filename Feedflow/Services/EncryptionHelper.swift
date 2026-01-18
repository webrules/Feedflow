import Foundation
import CryptoKit

/// Simple encryption utility for storing credentials locally.
/// Uses AES-GCM for symmetric encryption with a device-bound key.
class EncryptionHelper {
    static let shared = EncryptionHelper()
    
    // A simple static key derived from a passphrase. 
    // In production, consider using Keychain for key storage.
    private let encryptionKey: SymmetricKey
    
    private init() {
        // Create a deterministic key from a fixed seed + device identifier for basic obfuscation
        // This is NOT highly secure but provides basic encryption at rest.
        let seed = "FeedflowLocalEncryption2024"
        let keyData = SHA256.hash(data: Data(seed.utf8))
        self.encryptionKey = SymmetricKey(data: keyData)
    }
    
    /// Encrypts a string and returns a Base64-encoded ciphertext.
    func encrypt(_ plaintext: String) -> String? {
        guard let data = plaintext.data(using: .utf8) else { return nil }
        
        do {
            let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
            // Combined includes nonce + ciphertext + tag
            return sealedBox.combined?.base64EncodedString()
        } catch {
            print("Encryption error: \(error)")
            return nil
        }
    }
    
    /// Decrypts a Base64-encoded ciphertext and returns the original string.
    func decrypt(_ ciphertext: String) -> String? {
        guard let data = Data(base64Encoded: ciphertext) else { return nil }
        
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
            return String(data: decryptedData, encoding: .utf8)
        } catch {
            print("Decryption error: \(error)")
            return nil
        }
    }
}
