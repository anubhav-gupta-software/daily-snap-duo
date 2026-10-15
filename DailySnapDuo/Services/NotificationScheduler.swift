import Foundation
import UserNotifications

/// Local notifications only. Remote push needs a paid developer account, and
/// the daily prompt is already known on the phone, so a local schedule is enough.
@MainActor
final class NotificationScheduler {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func status() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func request() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func clearBadge() async {
        try? await center.setBadgeCount(0)
    }

    func reschedule(pair: Duo?, profileID: UUID?, snaps: [Snap], enabled: Bool, now: Date = Date()) async {
        let pending = await center.pendingNotificationRequests()
        let ours = pending.map(\.identifier).filter { $0.hasPrefix("snap-") }
        center.removePendingNotificationRequests(withIdentifiers: ours)

        guard enabled, let pair, let profileID else { return }
        let authorization = await status()
        guard authorization == .authorized || authorization == .provisional || authorization == .ephemeral else {
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pair.timeZone
        var day = calendar.startOfDay(for: now)

        for _ in 0..<8 {
            let dayKey = PromptCalendar.dayKey(for: day, timeZone: pair.timeZone)
            let schedule = PromptCalendar.schedule(code: pair.code, dayKey: dayKey, timeZone: pair.timeZone)
            let posted = snaps.contains { $0.dayKey == dayKey && $0.authorId == profileID && $0.pairCode == pair.code }
            if !posted {
                await schedulePrompt(schedule)
                await scheduleReminder(schedule)
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
    }

    private func schedulePrompt(_ schedule: PromptCalendar.Schedule) async {
        guard schedule.opensAt > Date().addingTimeInterval(5) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Time to snap"
        content.body = schedule.prompt
        content.sound = .default
        content.badge = 1
        await add(content, at: schedule.opensAt, id: "snap-prompt-\(schedule.dayKey)")
    }

    private func scheduleReminder(_ schedule: PromptCalendar.Schedule) async {
        let reminder = schedule.opensAt.addingTimeInterval(45 * 60)
        guard reminder > Date().addingTimeInterval(5), reminder < schedule.closesAt else { return }
        let content = UNMutableNotificationContent()
        content.title = "Still time today"
        content.body = "Post your snap if you want to see your friend's."
        content.sound = .default
        await add(content, at: reminder, id: "snap-reminder-\(schedule.dayKey)")
    }

    private func add(_ content: UNNotificationContent, at date: Date, id: String) async {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }
}
