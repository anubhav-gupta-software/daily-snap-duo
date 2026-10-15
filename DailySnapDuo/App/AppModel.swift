import Foundation
import UIKit
import UserNotifications
import WidgetKit

@MainActor
@Observable
final class AppModel {
    private(set) var profile: Profile?
    private(set) var pair: Duo?
    private(set) var snaps: [Snap]
    var settings: AppSettings
    var banner: String?
    var notificationAuthorization: UNAuthorizationStatus = .notDetermined

    private let repository: LocalRepository
    private let images: ImageStore
    private let notifications: NotificationScheduler
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(repository: LocalRepository = LocalRepository(), notifications: NotificationScheduler = NotificationScheduler()) {
        self.repository = repository
        self.notifications = notifications
        images = ImageStore(directory: repository.imagesDirectory)
        encoder = JSONCoding.encoder()
        decoder = JSONCoding.decoder()
        let stored = repository.load()
        profile = stored.profile
        pair = stored.pair
        snaps = stored.snaps
        settings = stored.settings
    }

    var partnerName: String {
        guard let profile, let pair else { return "Your friend" }
        return pair.partner(for: profile.id)?.displayName ?? "Your friend"
    }

    func todaySchedule(now: Date = Date()) -> PromptCalendar.Schedule? {
        guard let pair else { return nil }
        return PromptCalendar.schedule(code: pair.code, now: now, timeZone: pair.timeZone)
    }

    func mySnap(on dayKey: String) -> Snap? {
        guard let profile, let pair else { return nil }
        return snaps.first { $0.dayKey == dayKey && $0.authorId == profile.id && $0.pairCode == pair.code }
    }

    func partnerSnap(on dayKey: String) -> Snap? {
        guard let profile, let pair else { return nil }
        return snaps.first { $0.dayKey == dayKey && $0.authorId != profile.id && $0.pairCode == pair.code }
    }

    func status(for dayKey: String, now: Date = Date()) -> DayStatus? {
        guard let pair else { return nil }
        let schedule = PromptCalendar.schedule(code: pair.code, dayKey: dayKey, timeZone: pair.timeZone)
        return RevealRule.status(
            now: now,
            schedule: schedule,
            youPosted: mySnap(on: dayKey) != nil,
            friendPosted: partnerSnap(on: dayKey) != nil
        )
    }

    func historyDayKeys(now: Date = Date()) -> [String] {
        guard let pair else { return [] }
        return PromptCalendar.dayKeys(from: pair.createdAt, through: now, timeZone: pair.timeZone)
    }

    func image(named filename: String) -> UIImage? {
        images.load(filename)
    }

    func streak(now: Date = Date()) -> Int {
        guard let pair, let profile else { return 0 }
        let keys = PromptCalendar.dayKeys(from: pair.createdAt, through: now, timeZone: pair.timeZone)
        var count = 0
        for key in keys {
            let schedule = PromptCalendar.schedule(code: pair.code, dayKey: key, timeZone: pair.timeZone)
            let you = snaps.contains { $0.dayKey == key && $0.authorId == profile.id }
            let them = snaps.contains { $0.dayKey == key && $0.authorId != profile.id }
            if you && them {
                count += 1
                continue
            }
            if key == schedule.dayKey, now <= schedule.closesAt, key == keys.first {
                continue
            }
            break
        }
        return count
    }

    func onForeground() async {
        notificationAuthorization = await notifications.status()
        ensureSamplePartnerSnap()
        publishWidget()
        await notifications.clearBadge()
        await notifications.reschedule(
            pair: pair,
            profileID: profile?.id,
            snaps: snaps,
            enabled: settings.notificationsEnabled
        )
    }

    func enableNotifications() async {
        let granted = await notifications.request()
        notificationAuthorization = await notifications.status()
        settings.dismissedNotificationPrompt = true
        if granted {
            settings.notificationsEnabled = true
        }
        persist()
        await notifications.reschedule(
            pair: pair,
            profileID: profile?.id,
            snaps: snaps,
            enabled: settings.notificationsEnabled
        )
    }

    func dismissNotificationPrompt() {
        settings.dismissedNotificationPrompt = true
        persist()
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func dismissBanner() {
        banner = nil
    }

    @discardableResult
    func startDuo(name: String) -> Bool {
        guard let profile = makeProfile(named: name) else { return false }
        self.profile = profile
        pair = Duo(
            code: InviteCode.generate(),
            createdAt: Date(),
            timeZoneIdentifier: TimeZone.current.identifier,
            members: [Member(id: profile.id, displayName: profile.displayName, isSample: false)]
        )
        snaps = []
        persist()
        publishWidget()
        Task { await rescheduleNotifications() }
        return true
    }

    @discardableResult
    func joinDuo(name: String, code rawCode: String) -> Bool {
        let code = InviteCode.normalize(rawCode)
        guard InviteCode.isValid(code) else {
            banner = "Enter the 6 character code from your friend."
            return false
        }
        guard let profile = self.profile ?? makeProfile(named: name) else { return false }
        self.profile = profile
        if pair?.code != code {
            pair = Duo(
                code: code,
                createdAt: Date(),
                timeZoneIdentifier: TimeZone.current.identifier,
                members: [Member(id: profile.id, displayName: profile.displayName, isSample: false)]
            )
            snaps = []
        }
        persist()
        publishWidget()
        Task { await rescheduleNotifications() }
        return true
    }

    func rename(_ name: String) {
        let trimmed = sanitize(name)
        guard var profile, !trimmed.isEmpty else {
            banner = "Add a name first."
            return
        }
        profile.displayName = trimmed
        self.profile = profile
        if var pair, let index = pair.members.firstIndex(where: { $0.id == profile.id }) {
            pair.members[index].displayName = trimmed
            self.pair = pair
        }
        snaps = snaps.map { snap in
            guard snap.authorId == profile.id else { return snap }
            var copy = snap
            copy.authorName = trimmed
            return copy
        }
        persist()
        publishWidget()
    }

    func leavePair() {
        for snap in snaps {
            images.remove(snap.backFilename)
            images.remove(snap.frontFilename)
        }
        snaps = []
        pair = nil
        settings.samplePartner = false
        persist()
        publishWidget()
        Task { await rescheduleNotifications() }
    }

    func setSamplePartner(_ enabled: Bool) {
        guard var pair, let profile else {
            banner = "Start a duo before adding a practice partner."
            return
        }
        if enabled, let existing = pair.partner(for: profile.id), !existing.isSample {
            settings.samplePartner = false
            banner = "You're already paired with \(existing.displayName)."
            persist()
            return
        }
        settings.samplePartner = enabled
        if enabled {
            if pair.partner(for: profile.id) == nil {
                let riley = Member(
                    id: StableUUID.make(seed: "riley|\(pair.code)"),
                    displayName: "Riley",
                    isSample: true
                )
                pair.members.append(riley)
                self.pair = pair
            }
        } else if let current = self.pair {
            let sampleIDs = Set(current.members.filter(\.isSample).map(\.id))
            pair.members.removeAll { $0.isSample }
            self.pair = pair
            let removed = snaps.filter { sampleIDs.contains($0.authorId) }
            snaps.removeAll { sampleIDs.contains($0.authorId) }
            for snap in removed {
                images.remove(snap.backFilename)
                images.remove(snap.frontFilename)
            }
        }
        persist()
        ensureSamplePartnerSnap()
        publishWidget()
    }

    func noteSettingsChanged() {
        persist()
        Task { await rescheduleNotifications() }
    }

    @discardableResult
    func post(back: UIImage, front: UIImage, now: Date = Date()) async -> Bool {
        guard let profile, let pair else {
            banner = "Pair up before you post."
            return false
        }
        let schedule = PromptCalendar.schedule(code: pair.code, now: now, timeZone: pair.timeZone)
        if now < schedule.opensAt {
            banner = "Today's prompt isn't open yet."
            return false
        }
        if now > schedule.closesAt {
            banner = "Today's window has closed."
            return false
        }
        if mySnap(on: schedule.dayKey) != nil {
            banner = "You already posted today."
            return false
        }

        let id = UUID()
        do {
            let backName = try images.saveJPEG(back, name: "\(id.uuidString)-back")
            let frontName = try images.saveJPEG(front, name: "\(id.uuidString)-front")
            let snap = Snap(
                id: id,
                pairCode: pair.code,
                dayKey: schedule.dayKey,
                authorId: profile.id,
                authorName: profile.displayName,
                capturedAt: now,
                backFilename: backName,
                frontFilename: frontName,
                onTime: now <= schedule.onTimeUntil
            )
            snaps.append(snap)
            persist()
            ensureSamplePartnerSnap(now: now)
            publishWidget(now: now)
            await rescheduleNotifications()
            return true
        } catch {
            banner = error.localizedDescription
            return false
        }
    }

    func makeExchangeFile() throws -> URL? {
        guard let pair else { return nil }
        var packed: [ExchangeSnap] = []
        for snap in snaps {
            guard let back = images.data(for: snap.backFilename),
                  let front = images.data(for: snap.frontFilename) else { continue }
            packed.append(
                ExchangeSnap(
                    snap: snap,
                    backBase64: back.base64EncodedString(),
                    frontBase64: front.base64EncodedString()
                )
            )
        }
        let exchange = SnapExchange(version: SnapExchange.currentVersion, pair: pair, snaps: packed)
        let data = try encoder.encode(exchange)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Snap-\(pair.code).snapduo")
        try data.write(to: url, options: .atomic)
        return url
    }

    func importExchange(from url: URL) throws {
        guard let profile else {
            throw ExchangeError.needProfile
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer {
            if accessed { url.stopAccessingSecurityScopedResource() }
        }
        let data = try Data(contentsOf: url)
        let exchange: SnapExchange
        do {
            exchange = try decoder.decode(SnapExchange.self, from: data)
        } catch {
            throw ExchangeError.unreadable
        }
        try merge(exchange, profile: profile)
        ensureSamplePartnerSnap()
        publishWidget()
        Task { await rescheduleNotifications() }
    }

    func ensureSamplePartnerSnap(now: Date = Date()) {
        guard settings.samplePartner, let pair, let riley = pair.members.first(where: \.isSample) else { return }
        let schedule = PromptCalendar.schedule(code: pair.code, now: now, timeZone: pair.timeZone)
        guard now >= schedule.opensAt else { return }
        guard !snaps.contains(where: { $0.authorId == riley.id && $0.dayKey == schedule.dayKey }) else { return }

        let id = StableUUID.make(seed: "riley-snap|\(pair.code)|\(schedule.dayKey)")
        let seed = PromptCalendar.stableHash("\(pair.code)|\(schedule.dayKey)")
        let artwork = SampleArtwork.standInPair(seed: seed)
        do {
            let backName = try images.saveJPEG(artwork.back, name: "\(id.uuidString)-back")
            let frontName = try images.saveJPEG(artwork.front, name: "\(id.uuidString)-front")
            let capturedAt = schedule.opensAt.addingTimeInterval(45)
            snaps.append(
                Snap(
                    id: id,
                    pairCode: pair.code,
                    dayKey: schedule.dayKey,
                    authorId: riley.id,
                    authorName: riley.displayName,
                    capturedAt: capturedAt,
                    backFilename: backName,
                    frontFilename: frontName,
                    onTime: true
                )
            )
            persist()
        } catch {
            banner = "Couldn't draw the practice snap."
        }
    }

    func publishWidget(now: Date = Date()) {
        let snapshot: WidgetSnapshot
        var imageData: Data?

        guard let pair, profile != nil else {
            snapshot = WidgetSnapshot(
                state: .needsPairing,
                prompt: "Pair with a friend",
                detail: "One prompt. Two cameras.",
                friendName: "",
                updatedAt: now
            )
            WidgetSnapshotStore.save(snapshot, imageData: nil)
            WidgetCenter.shared.reloadAllTimelines()
            return
        }

        let schedule = PromptCalendar.schedule(code: pair.code, now: now, timeZone: pair.timeZone)
        let mine = mySnap(on: schedule.dayKey)
        let theirs = partnerSnap(on: schedule.dayKey)
        let status = RevealRule.status(
            now: now,
            schedule: schedule,
            youPosted: mine != nil,
            friendPosted: theirs != nil
        )
        let friend = partnerName
        let time = schedule.opensAt.formatted(date: .omitted, time: .shortened)

        switch status.phase {
        case .revealed:
            snapshot = WidgetSnapshot(
                state: .revealed,
                prompt: schedule.prompt,
                detail: friend,
                friendName: friend,
                updatedAt: now
            )
            if let theirs {
                imageData = images.widgetJPEG(for: theirs.backFilename)
            }
        case .locked:
            snapshot = WidgetSnapshot(
                state: .locked,
                prompt: schedule.prompt,
                detail: "Post yours to see \(friend)",
                friendName: friend,
                updatedAt: now
            )
        case .yourTurn:
            snapshot = WidgetSnapshot(
                state: .yourTurn,
                prompt: schedule.prompt,
                detail: "It's time to snap",
                friendName: friend,
                updatedAt: now
            )
        case .waitingForFriend:
            snapshot = WidgetSnapshot(
                state: .waitingForFriend,
                prompt: schedule.prompt,
                detail: "Waiting for \(friend)",
                friendName: friend,
                updatedAt: now
            )
        case .sealed:
            snapshot = WidgetSnapshot(
                state: .sealed,
                prompt: schedule.prompt,
                detail: "Today stayed sealed",
                friendName: friend,
                updatedAt: now
            )
        case .upcoming:
            if let previous = latestRevealedSnap(before: schedule.dayKey) {
                let previousPrompt = PromptCalendar.schedule(
                    code: pair.code,
                    dayKey: previous.dayKey,
                    timeZone: pair.timeZone
                ).prompt
                snapshot = WidgetSnapshot(
                    state: .revealed,
                    prompt: previousPrompt,
                    detail: friend,
                    friendName: friend,
                    updatedAt: now
                )
                imageData = images.widgetJPEG(for: previous.backFilename)
            } else {
                snapshot = WidgetSnapshot(
                    state: .upcoming,
                    prompt: schedule.prompt,
                    detail: "Opens at \(time)",
                    friendName: friend,
                    updatedAt: now
                )
            }
        }

        WidgetSnapshotStore.save(snapshot, imageData: imageData)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func latestRevealedSnap(before dayKey: String) -> Snap? {
        guard let profile else { return nil }
        let revealedDays = Set(snaps.filter { $0.authorId == profile.id }.map(\.dayKey))
        return snaps
            .filter { $0.authorId != profile.id && $0.dayKey < dayKey && revealedDays.contains($0.dayKey) }
            .sorted { $0.dayKey > $1.dayKey }
            .first
    }

    private func merge(_ exchange: SnapExchange, profile: Profile) throws {
        if var pair {
            guard pair.code == exchange.pair.code else { throw ExchangeError.differentPair }
            if exchange.pair.createdAt < pair.createdAt {
                pair.createdAt = exchange.pair.createdAt
                pair.timeZoneIdentifier = exchange.pair.timeZoneIdentifier
            }
            let incomingRealPartner = exchange.pair.members.contains { $0.id != profile.id && !$0.isSample }
            if incomingRealPartner {
                pair.members.removeAll { $0.isSample }
                settings.samplePartner = false
            }
            for member in exchange.pair.members where !member.isSample && !pair.members.contains(where: { $0.id == member.id }) {
                pair.members.append(member)
            }
            if !pair.members.contains(where: { $0.id == profile.id }) {
                pair.members.append(Member(id: profile.id, displayName: profile.displayName, isSample: false))
            }
            self.pair = pair
        } else {
            var adopted = exchange.pair
            if !adopted.members.contains(where: { $0.id == profile.id }) {
                adopted.members.append(Member(id: profile.id, displayName: profile.displayName, isSample: false))
            }
            pair = adopted
        }

        for item in exchange.snaps {
            if snaps.contains(where: { $0.id == item.snap.id }) { continue }
            if item.snap.authorId == profile.id, mySnap(on: item.snap.dayKey) != nil { continue }
            guard let back = Data(base64Encoded: item.backBase64),
                  let front = Data(base64Encoded: item.frontBase64) else { continue }
            try images.saveData(back, filename: item.snap.backFilename)
            try images.saveData(front, filename: item.snap.frontFilename)
            snaps.append(item.snap)
        }
        persist()
        banner = nil
    }

    private func makeProfile(named name: String) -> Profile? {
        let trimmed = sanitize(name)
        guard !trimmed.isEmpty else {
            banner = "Add your name first."
            return nil
        }
        return Profile(id: UUID(), displayName: trimmed, createdAt: Date())
    }

    private func sanitize(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(24))
    }

    private func persist() {
        do {
            try repository.save(
                StoreEnvelope(version: 1, profile: profile, pair: pair, snaps: snaps, settings: settings)
            )
        } catch {
            banner = "Couldn't save on this iPhone."
        }
    }

    private func rescheduleNotifications() async {
        await notifications.reschedule(
            pair: pair,
            profileID: profile?.id,
            snaps: snaps,
            enabled: settings.notificationsEnabled
        )
    }
}

enum ExchangeError: LocalizedError {
    case differentPair
    case needProfile
    case unreadable

    var errorDescription: String? {
        switch self {
        case .differentPair:
            "That file belongs to a different duo."
        case .needProfile:
            "Add your name before importing a snap."
        case .unreadable:
            "That file isn't a Daily Snap Duo exchange."
        }
    }
}
