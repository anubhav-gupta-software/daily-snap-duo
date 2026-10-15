import Foundation

struct WidgetSnapshot: Codable, Equatable {
    enum State: String, Codable {
        case needsPairing
        case upcoming
        case yourTurn
        case locked
        case waitingForFriend
        case revealed
        case sealed
        case unavailable
    }

    var state: State
    var prompt: String
    var detail: String
    var friendName: String
    var updatedAt: Date

    static let fileName = "widget-snapshot.json"
    static let imageFileName = "widget-friend.jpg"

    static let unavailable = WidgetSnapshot(
        state: .unavailable,
        prompt: "Daily Snap Duo",
        detail: "Open the app to post today's snap.",
        friendName: "",
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

enum WidgetSnapshotStore {
    static func save(_ snapshot: WidgetSnapshot, imageData: Data?, bundle: Bundle = .main) {
        guard let directory = AppGroupLocator.containerURL(bundle: bundle) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        let jsonURL = directory.appendingPathComponent(WidgetSnapshot.fileName)
        try? data.write(to: jsonURL, options: .atomic)

        let imageURL = directory.appendingPathComponent(WidgetSnapshot.imageFileName)
        if let imageData, snapshot.state == .revealed {
            try? imageData.write(to: imageURL, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: imageURL)
        }
    }

    static func load(bundle: Bundle = .main) -> (WidgetSnapshot, Data?)? {
        guard let directory = AppGroupLocator.containerURL(bundle: bundle) else { return nil }
        let jsonURL = directory.appendingPathComponent(WidgetSnapshot.fileName)
        guard let data = try? Data(contentsOf: jsonURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let snapshot = try? decoder.decode(WidgetSnapshot.self, from: data) else { return nil }
        // Never hand the photo over unless this snapshot says it was revealed.
        let imageData: Data?
        if snapshot.state == .revealed {
            imageData = try? Data(contentsOf: directory.appendingPathComponent(WidgetSnapshot.imageFileName))
        } else {
            imageData = nil
        }
        return (snapshot, imageData)
    }
}
