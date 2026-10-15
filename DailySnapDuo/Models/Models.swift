import Foundation

struct Profile: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var createdAt: Date
}

struct Member: Codable, Equatable, Identifiable {
    var id: UUID
    var displayName: String
    var isSample: Bool
}

struct Duo: Codable, Equatable {
    var code: String
    var createdAt: Date
    var timeZoneIdentifier: String
    var members: [Member]

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    func partner(for userID: UUID) -> Member? {
        members.first { $0.id != userID }
    }
}

struct Snap: Codable, Equatable, Identifiable {
    var id: UUID
    var pairCode: String
    var dayKey: String
    var authorId: UUID
    var authorName: String
    var capturedAt: Date
    var backFilename: String
    var frontFilename: String
    var onTime: Bool
}

enum SyncMode: String, Codable, CaseIterable, Identifiable {
    case local
    case http
    case cloudKit

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local:
            "This iPhone"
        case .http:
            "Shared relay"
        case .cloudKit:
            "iCloud"
        }
    }

    var detail: String {
        switch self {
        case .local:
            "Snaps stay on this phone. Pass a file or add a practice partner to try the reveal."
        case .http:
            "Two phones share a small relay you run yourself. No account required."
        case .cloudKit:
            "Syncs through iCloud. Needs a paid Apple Developer account and the iCloud capability."
        }
    }
}

struct AppSettings: Codable, Equatable {
    var syncMode: SyncMode
    var serverURL: String
    var notificationsEnabled: Bool
    var dismissedNotificationPrompt: Bool
    var samplePartner: Bool

    static let `default` = AppSettings(
        syncMode: .local,
        serverURL: "",
        notificationsEnabled: true,
        dismissedNotificationPrompt: false,
        samplePartner: false
    )
}

struct StoreEnvelope: Codable, Equatable {
    var version: Int
    var profile: Profile?
    var pair: Duo?
    var snaps: [Snap]
    var settings: AppSettings

    static let empty = StoreEnvelope(
        version: 1,
        profile: nil,
        pair: nil,
        snaps: [],
        settings: .default
    )
}

struct SnapExchange: Codable, Equatable {
    var version: Int
    var pair: Duo
    var snaps: [ExchangeSnap]

    static let currentVersion = 1
}

struct ExchangeSnap: Codable, Equatable {
    var snap: Snap
    var backBase64: String
    var frontBase64: String
}
