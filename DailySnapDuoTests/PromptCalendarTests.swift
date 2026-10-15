import XCTest
@testable import DailySnapDuo

final class PromptCalendarTests: XCTestCase {
    private let zone = TimeZone(identifier: "America/New_York")!

    func testHashIsStable() {
        XCTAssertEqual(PromptCalendar.stableHash("prompt|K7MQ2P|2026-10-15"), 17_488_028_170_258_340_024)
        XCTAssertEqual(PromptCalendar.stableHash("time|K7MQ2P|2026-10-15"), 6_120_781_827_179_909_315)
    }

    func testSameCodeProducesTheSameSchedule() {
        let first = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        let second = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        XCTAssertEqual(first, second)
        XCTAssertEqual(first.dayKey, "2026-10-15")
    }

    func testPromptOpensInsideTheAfternoonWindow() {
        let schedule = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: schedule.opensAt)
        XCTAssertEqual(parts.year, 2026)
        XCTAssertEqual(parts.month, 10)
        XCTAssertEqual(parts.day, 15)
        let minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
        XCTAssertGreaterThanOrEqual(minutes, 8 * 60)
        XCTAssertLessThan(minutes, 21 * 60 + 30)
        XCTAssertEqual(
            schedule.onTimeUntil.timeIntervalSince(schedule.opensAt),
            TimeInterval(PromptCalendar.onTimeLengthMinutes * 60)
        )
        XCTAssertGreaterThan(schedule.closesAt, schedule.onTimeUntil)
    }

    func testDifferentCodesUsuallyDiffer() {
        let left = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        let right = PromptCalendar.schedule(code: "H4NP8R", dayKey: "2026-10-15", timeZone: zone)
        XCTAssertNotEqual(left.opensAt, right.opensAt)
    }

    func testInviteCodeRejectsAmbiguousCharacters() {
        XCTAssertEqual(InviteCode.normalize("k7m-q2p"), "K7MQ2P")
        XCTAssertTrue(InviteCode.isValid("K7MQ2P"))
        XCTAssertFalse(InviteCode.isValid("K7MQ2"))
        XCTAssertFalse(InviteCode.isValid("O0IL1A"))
        XCTAssertFalse(InviteCode.alphabet.contains("O"))
        XCTAssertFalse(InviteCode.alphabet.contains("0"))
        XCTAssertFalse(InviteCode.alphabet.contains("I"))
        XCTAssertFalse(InviteCode.alphabet.contains("1"))
    }

    func testYouCannotSeeAFriendUntilYouPost() {
        let schedule = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        let during = schedule.opensAt.addingTimeInterval(60)
        let locked = RevealRule.status(now: during, schedule: schedule, youPosted: false, friendPosted: true)
        XCTAssertEqual(locked.phase, .locked)
        XCTAssertFalse(locked.canSeePartner)

        let revealed = RevealRule.status(now: during, schedule: schedule, youPosted: true, friendPosted: true)
        XCTAssertEqual(revealed.phase, .revealed)
        XCTAssertTrue(revealed.canSeePartner)

        let waiting = RevealRule.status(now: during, schedule: schedule, youPosted: true, friendPosted: false)
        XCTAssertEqual(waiting.phase, .waitingForFriend)
        XCTAssertFalse(waiting.canSeePartner)
    }

    func testMissingTheDaySealsTheSnap() {
        let schedule = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        let after = schedule.closesAt.addingTimeInterval(60)
        let status = RevealRule.status(now: after, schedule: schedule, youPosted: false, friendPosted: true)
        XCTAssertEqual(status.phase, .sealed)
        XCTAssertFalse(status.canSeePartner)
    }

    func testUpcomingHidesTheCamera() {
        let schedule = PromptCalendar.schedule(code: "K7MQ2P", dayKey: "2026-10-15", timeZone: zone)
        let before = schedule.opensAt.addingTimeInterval(-60)
        let status = RevealRule.status(now: before, schedule: schedule, youPosted: false, friendPosted: false)
        XCTAssertEqual(status.phase, .upcoming)
    }
}
