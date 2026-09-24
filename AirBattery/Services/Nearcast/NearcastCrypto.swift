import CryptoKit
import Foundation

func randomString(length: Int) -> String {
    let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
    var randomString = ""

    for _ in 0..<length {
        if let randomCharacter = characters.randomElement() {
            randomString.append(randomCharacter)
        }
    }
    return randomString
}

func generateNearcastCredentials() -> (groupID: String, sharingKey: String) {
    let groupID = NearcastCredentialFormat.groupPrefix + randomString(length: 16)
    let key = SymmetricKey(size: .bits256)
    let keyData = key.withUnsafeBytes { Data($0) }
    return (
        groupID,
        NearcastCredentialFormat.sharingKeyPrefix + keyData.base64EncodedString()
    )
}

func isNearcastCredentialValid(groupID: String, sharingKey: String) -> Bool {
    NearcastCredentialFormat.isValid(groupID: groupID, sharingKey: sharingKey)
}

func nearcastSetupCode(groupID: String, sharingKey: String) -> String? {
    NearcastCredentialFormat.setupCode(groupID: groupID, sharingKey: sharingKey)
}

func parseNearcastSetupCode(_ code: String) -> (groupID: String, sharingKey: String)? {
    NearcastCredentialFormat.parseSetupCode(code)
}

private func nearcastSymmetricKey(groupID: String, sharingKey: String) -> SymmetricKey? {
    guard sharingKey.hasPrefix(NearcastCredentialFormat.sharingKeyPrefix) else { return nil }
    let encoded = String(sharingKey.dropFirst(NearcastCredentialFormat.sharingKeyPrefix.count))
    guard let material = Data(base64Encoded: encoded) else { return nil }

    return HKDF<SHA256>.deriveKey(
        inputKeyMaterial: SymmetricKey(data: material),
        salt: Data(groupID.utf8),
        info: Data("AirBattery Nearcast v2".utf8),
        outputByteCount: 32
    )
}

func encryptNearcastString(
    _ string: String,
    groupID: String,
    sharingKey: String
) -> String? {
    guard isNearcastCredentialValid(groupID: groupID, sharingKey: sharingKey) else {
        return nil
    }

    guard let key = nearcastSymmetricKey(groupID: groupID, sharingKey: sharingKey) else {
        return nil
    }
    do {
        return try AES.GCM.seal(Data(string.utf8), using: key)
            .combined?
            .base64EncodedString()
    } catch {
        print("Nearcast encryption error: \(error)")
        return nil
    }
}

func decryptNearcastString(
    _ string: String,
    groupID: String,
    sharingKey: String
) -> String? {
    guard isNearcastCredentialValid(groupID: groupID, sharingKey: sharingKey) else {
        return nil
    }

    guard let key = nearcastSymmetricKey(groupID: groupID, sharingKey: sharingKey),
          let data = Data(base64Encoded: string)
    else {
        return nil
    }
    do {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let plaintext = try AES.GCM.open(sealedBox, using: key)
        return String(data: plaintext, encoding: .utf8)
    } catch {
        print("Nearcast decryption error: \(error)")
        return nil
    }
}
