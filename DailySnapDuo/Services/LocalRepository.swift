import Foundation

enum JSONCoding {
    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

final class LocalRepository {
    let directory: URL
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DailySnapDuo", isDirectory: true)
        self.directory = base
        fileURL = base.appendingPathComponent("store.json")
        encoder = JSONCoding.encoder()
        decoder = JSONCoding.decoder()
    }

    var imagesDirectory: URL {
        directory.appendingPathComponent("images", isDirectory: true)
    }

    func load() -> StoreEnvelope {
        guard let data = try? Data(contentsOf: fileURL),
              let envelope = try? decoder.decode(StoreEnvelope.self, from: data) else {
            return .empty
        }
        return envelope
    }

    func save(_ envelope: StoreEnvelope) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(envelope)
        try data.write(to: fileURL, options: .atomic)
    }
}
