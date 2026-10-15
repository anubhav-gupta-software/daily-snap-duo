import Foundation

/// Whether a friend's snap can be shown.
///
/// You only see theirs after you have posted your own for that day. Missing
/// the day seals it. This is a product rule in the app, not a lock on the file.
enum DuoDayPhase: String, Equatable {
    case upcoming
    case yourTurn
    case locked
    case waitingForFriend
    case revealed
    case sealed
}

struct DayStatus: Equatable {
    var phase: DuoDayPhase
    var canSeePartner: Bool
}

enum RevealRule {
    static func status(
        now: Date,
        schedule: PromptCalendar.Schedule,
        youPosted: Bool,
        friendPosted: Bool
    ) -> DayStatus {
        if youPosted && friendPosted {
            return DayStatus(phase: .revealed, canSeePartner: true)
        }
        if youPosted {
            return DayStatus(phase: .waitingForFriend, canSeePartner: false)
        }
        if now < schedule.opensAt {
            return DayStatus(phase: .upcoming, canSeePartner: false)
        }
        if now > schedule.closesAt {
            return DayStatus(phase: .sealed, canSeePartner: false)
        }
        if friendPosted {
            return DayStatus(phase: .locked, canSeePartner: false)
        }
        return DayStatus(phase: .yourTurn, canSeePartner: false)
    }
}
