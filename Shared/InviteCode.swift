import Foundation

enum InviteCode {
    static let alphabet: [Character] = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
    static let length = 6

    static func generate() -> String {
        var generator = SystemRandomNumberGenerator()
        return generate(using: &generator)
    }

    static func generate(using generator: inout some RandomNumberGenerator) -> String {
        String((0..<length).map { _ in alphabet.randomElement(using: &generator)! })
    }

    static func normalize(_ raw: String) -> String {
        let filtered = raw.uppercased().filter { alphabet.contains($0) }
        return String(filtered.prefix(length))
    }

    static func isValid(_ code: String) -> Bool {
        code.count == length && code.allSatisfy { alphabet.contains($0) }
    }
}
