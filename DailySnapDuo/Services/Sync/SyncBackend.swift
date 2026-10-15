import Foundation

struct RemoteSnapPayload {
    var snap: Snap
    var back: Data
    var front: Data
}

protocol SyncBackend {
    func upsertPair(_ pair: Duo, member: Member) async throws -> Duo
    func fetchSnaps(code: String, have: Set<UUID>) async throws -> [RemoteSnapPayload]
    func upload(snap: Snap, back: Data, front: Data) async throws
}

enum SyncError: LocalizedError {
    case message(String)

    var errorDescription: String? {
        switch self {
        case .message(let text):
            text
        }
    }
}
