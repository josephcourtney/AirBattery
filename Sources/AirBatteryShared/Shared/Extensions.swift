import Foundation

extension String {
    package var local: String { NSLocalizedString(self, comment: "") }
}

extension Data {
    package func hexEncodedString() -> String {
        map { String(format: "%02hhx", $0) }.joined()
    }

    package func ascii() -> String? {
        var asciiString = ""
        for byte in self {
            asciiString.append(Character(UnicodeScalar(byte)))
        }
        return asciiString.replacingOccurrences(of: "\0", with: "")
    }
}
