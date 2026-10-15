import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Talks to `sync-server/server.py`. The invite code is the only credential,
/// so this is for a LAN or a server you trust, not for private photos on the open internet.
struct HTTPSyncBackend: SyncBackend {
    var baseURL: URL
    var session: URLSession

    init(baseURL: URL, session: URLSession = HTTPSyncBackend.makeSession()) {
        self.baseURL = baseURL
        self.session = session
    }

    func upsertPair(_ pair: Duo, member: Member) async throws -> Duo {
        let body = PairBody(
            code: pair.code,
            timeZone: pair.timeZoneIdentifier,
            createdAt: pair.createdAt,
            member: member
        )
        let wire: PairWire = try await send(path: "/v1/pairs", method: "POST", body: body)
        return wire.duo()
    }

    func fetchSnaps(code: String, have: Set<UUID>) async throws -> [RemoteSnapPayload] {
        let wire: PairWire = try await send(path: "/v1/pairs/\(code)", method: "GET", body: Optional<String>.none)
        var payloads: [RemoteSnapPayload] = []
        for summary in wire.snaps where !have.contains(summary.id) {
            let full: SnapWire = try await send(
                path: "/v1/pairs/\(code)/snaps/\(summary.id.uuidString)",
                method: "GET",
                body: Optional<String>.none
            )
            guard let back = full.backBase64.flatMap({ Data(base64Encoded: $0) }),
                  let front = full.frontBase64.flatMap({ Data(base64Encoded: $0) }) else {
                continue
            }
            payloads.append(RemoteSnapPayload(snap: full.snap(pairCode: code), back: back, front: front))
        }
        return payloads
    }

    func upload(snap: Snap, back: Data, front: Data) async throws {
        let wire = SnapWire(
            id: snap.id,
            dayKey: snap.dayKey,
            authorId: snap.authorId,
            authorName: snap.authorName,
            capturedAt: snap.capturedAt,
            onTime: snap.onTime,
            backBase64: back.base64EncodedString(),
            frontBase64: front.base64EncodedString()
        )
        let _: SnapWire = try await send(
            path: "/v1/pairs/\(snap.pairCode)/snaps",
            method: "POST",
            body: wire
        )
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        return URLSession(configuration: configuration)
    }

    private func send<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body?
    ) async throws -> Response {
        let root = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: root + path) else {
            throw SyncError.message("That relay address isn't a URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONCoding.encoder().encode(body)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw SyncError.message("The relay didn't answer.")
            }
            guard (200...299).contains(http.statusCode) else {
                if let message = try? JSONCoding.decoder().decode(ErrorBody.self, from: data).error {
                    throw SyncError.message(message)
                }
                throw SyncError.message("The relay returned an error (\(http.statusCode)).")
            }
            do {
                return try JSONCoding.decoder().decode(Response.self, from: data)
            } catch {
                throw SyncError.message("The relay sent something I couldn't read.")
            }
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError.message("Couldn't reach the relay. Check the address and that both devices are on the same Wi-Fi.")
        }
    }
}

private struct PairBody: Encodable {
    var code: String
    var timeZone: String
    var createdAt: Date
    var member: Member
}

private struct PairWire: Decodable {
    var code: String
    var timeZone: String
    var createdAt: Date
    var members: [Member]
    var snaps: [SnapWire]

    func duo() -> Duo {
        Duo(code: code, createdAt: createdAt, timeZoneIdentifier: timeZone, members: members)
    }
}

private struct SnapWire: Codable {
    var id: UUID
    var dayKey: String
    var authorId: UUID
    var authorName: String
    var capturedAt: Date
    var onTime: Bool
    var backBase64: String?
    var frontBase64: String?

    func snap(pairCode: String) -> Snap {
        Snap(
            id: id,
            pairCode: pairCode,
            dayKey: dayKey,
            authorId: authorId,
            authorName: authorName,
            capturedAt: capturedAt,
            backFilename: "",
            frontFilename: "",
            onTime: onTime
        )
    }
}

private struct ErrorBody: Decodable {
    var error: String
}
