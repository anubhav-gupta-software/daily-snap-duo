import CloudKit
import Foundation

/// Optional iCloud sync. The iCloud capability is not in the default entitlements,
/// because a free Personal Team cannot sign it. The code is here so a paid account
/// can turn the capability on without rewriting the app. See the README.
struct CloudKitSyncBackend: SyncBackend {
    var containerID: String

    func upsertPair(_ pair: Duo, member: Member) async throws -> Duo {
        try await ensureAccount()
        let record = try await loadOrCreatePair(pair)
        var ids = stringList(record, key: "memberIDs")
        var names = stringList(record, key: "memberNames")
        let id = member.id.uuidString
        if let index = ids.firstIndex(of: id) {
            if names.indices.contains(index) {
                names[index] = member.displayName
            }
        } else {
            ids.append(id)
            names.append(member.displayName)
        }
        record["memberIDs"] = ids as NSArray
        record["memberNames"] = names as NSArray
        let saved = try await database.save(record)
        return duo(from: saved, fallback: pair)
    }

    func fetchSnaps(code: String, have: Set<UUID>) async throws -> [RemoteSnapPayload] {
        try await ensureAccount()
        let pairRecord: CKRecord
        do {
            pairRecord = try await database.record(for: CKRecord.ID(recordName: "pair-\(code)"))
        } catch let error as CKError where error.code == .unknownItem {
            return []
        }
        var payloads: [RemoteSnapPayload] = []
        for idString in stringList(pairRecord, key: "snapIDs") {
            guard let id = UUID(uuidString: idString), !have.contains(id) else { continue }
            let record: CKRecord
            do {
                record = try await database.record(for: CKRecord.ID(recordName: "snap-\(idString)"))
            } catch {
                continue
            }
            guard let back = assetData(record, key: "back"),
                  let front = assetData(record, key: "front"),
                  let author = record["authorId"] as? String,
                  let authorID = UUID(uuidString: author),
                  let dayKey = record["dayKey"] as? String,
                  let authorName = record["authorName"] as? String,
                  let capturedAt = record["capturedAt"] as? Date else {
                continue
            }
            let onTime = (record["onTime"] as? NSNumber)?.boolValue ?? true
            let snap = Snap(
                id: id,
                pairCode: code,
                dayKey: dayKey,
                authorId: authorID,
                authorName: authorName,
                capturedAt: capturedAt,
                backFilename: "",
                frontFilename: "",
                onTime: onTime
            )
            payloads.append(RemoteSnapPayload(snap: snap, back: back, front: front))
        }
        return payloads
    }

    func upload(snap: Snap, back: Data, front: Data) async throws {
        try await ensureAccount()
        let recordID = CKRecord.ID(recordName: "snap-\(snap.id.uuidString)")
        let record: CKRecord
        if let existing = try? await database.record(for: recordID) {
            record = existing
        } else {
            record = CKRecord(recordType: "DuoSnap", recordID: recordID)
        }
        record["pairCode"] = snap.pairCode as NSString
        record["dayKey"] = snap.dayKey as NSString
        record["authorId"] = snap.authorId.uuidString as NSString
        record["authorName"] = snap.authorName as NSString
        record["capturedAt"] = snap.capturedAt as NSDate
        record["onTime"] = NSNumber(value: snap.onTime)
        let backURL = try writeTemp(back, name: "\(snap.id.uuidString)-back.jpg")
        let frontURL = try writeTemp(front, name: "\(snap.id.uuidString)-front.jpg")
        record["back"] = CKAsset(fileURL: backURL)
        record["front"] = CKAsset(fileURL: frontURL)
        _ = try await database.save(record)
        try await appendSnapID(snap.id.uuidString, code: snap.pairCode)
    }

    static func containerIDFromBundle() -> String {
        if let value = Bundle.main.object(forInfoDictionaryKey: "CloudKitContainerID") as? String,
           !value.isEmpty,
           !value.contains("$(") {
            return value
        }
        return "iCloud.com.anubhavgupta.dailysnapduo"
    }

    private var database: CKDatabase {
        CKContainer(identifier: containerID).publicCloudDatabase
    }

    private func ensureAccount() async throws {
        do {
            let status = try await CKContainer(identifier: containerID).accountStatus()
            switch status {
            case .available:
                return
            case .noAccount:
                throw SyncError.message("Sign in to iCloud on this iPhone. iCloud sync also needs a paid developer account.")
            default:
                throw SyncError.message("iCloud isn't available. Use This iPhone or a shared relay with a free Apple ID.")
            }
        } catch let error as SyncError {
            throw error
        } catch {
            throw SyncError.message("iCloud isn't turned on for this install. A free Apple ID can't use it — pick another sync mode.")
        }
    }

    private func loadOrCreatePair(_ pair: Duo) async throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: "pair-\(pair.code)")
        if let existing = try? await database.record(for: recordID) {
            return existing
        }
        let record = CKRecord(recordType: "DuoPair", recordID: recordID)
        record["code"] = pair.code as NSString
        record["timeZone"] = pair.timeZoneIdentifier as NSString
        record["createdAt"] = pair.createdAt as NSDate
        record["memberIDs"] = [] as NSArray
        record["memberNames"] = [] as NSArray
        record["snapIDs"] = [] as NSArray
        return record
    }

    private func appendSnapID(_ id: String, code: String) async throws {
        let recordID = CKRecord.ID(recordName: "pair-\(code)")
        for _ in 0..<2 {
            guard let record = try? await database.record(for: recordID) else { return }
            var ids = stringList(record, key: "snapIDs")
            if !ids.contains(id) {
                ids.append(id)
            }
            record["snapIDs"] = ids as NSArray
            do {
                _ = try await database.save(record)
                return
            } catch let error as CKError where error.code == .serverRecordChanged {
                continue
            }
        }
    }

    private func duo(from record: CKRecord, fallback: Duo) -> Duo {
        let ids = stringList(record, key: "memberIDs")
        let names = stringList(record, key: "memberNames")
        var members: [Member] = []
        for (index, id) in ids.enumerated() {
            guard let uuid = UUID(uuidString: id) else { continue }
            let name = names.indices.contains(index) ? names[index] : "Friend"
            members.append(Member(id: uuid, displayName: name, isSample: false))
        }
        return Duo(
            code: (record["code"] as? String) ?? fallback.code,
            createdAt: (record["createdAt"] as? Date) ?? fallback.createdAt,
            timeZoneIdentifier: (record["timeZone"] as? String) ?? fallback.timeZoneIdentifier,
            members: members
        )
    }

    private func stringList(_ record: CKRecord, key: String) -> [String] {
        if let values = record[key] as? [String] { return values }
        if let values = record[key] as? [NSString] { return values.map { $0 as String } }
        return []
    }

    private func assetData(_ record: CKRecord, key: String) -> Data? {
        guard let asset = record[key] as? CKAsset, let url = asset.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private func writeTemp(_ data: Data, name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }
}
