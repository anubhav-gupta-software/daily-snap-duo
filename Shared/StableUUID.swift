import Foundation

enum StableUUID {
    /// A UUID that both phones can recompute from a seed. Used for the practice partner.
    static func make(seed: String) -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)
        let high = PromptCalendar.stableHash(seed)
        let low = PromptCalendar.stableHash("uuid|\(seed)")
        for index in 0..<8 {
            bytes[index] = UInt8((high >> (index * 8)) & 0xff)
            bytes[index + 8] = UInt8((low >> (index * 8)) & 0xff)
        }
        bytes[6] = (bytes[6] & 0x0f) | 0x40
        bytes[8] = (bytes[8] & 0x3f) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
