import SwiftUI

struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showCamera = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                DuoTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        if let schedule = model.todaySchedule() {
                            PromptCard(prompt: schedule.prompt, detail: detail(for: schedule))
                            slots(schedule)
                        }
                        notificationCard
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.isSyncing {
                        ProgressView()
                            .accessibilityLabel("Syncing")
                    }
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .background(DuoTheme.background.opacity(0.92))
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .refreshable {
                await model.refresh()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(todayTitle)
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.muted)
            HStack {
                Text("Daily Snap Duo")
                    .font(DuoTheme.serifTitle)
                    .foregroundStyle(DuoTheme.ink)
                Spacer()
                if model.streak() > 1 {
                    Text("\(model.streak())-day streak")
                        .font(DuoTheme.roundedCaption)
                        .foregroundStyle(DuoTheme.olive)
                }
            }
        }
        .padding(.top, 8)
    }

    private func slots(_ schedule: PromptCalendar.Schedule) -> some View {
        let status = model.status(for: schedule.dayKey)
        return HStack(alignment: .top, spacing: 12) {
            youColumn(schedule)
            friendColumn(schedule, status: status)
        }
    }

    private func youColumn(_ schedule: PromptCalendar.Schedule) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("You")
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.muted)
            if let snap = model.mySnap(on: schedule.dayKey),
               let back = model.image(named: snap.backFilename),
               let front = model.image(named: snap.frontFilename) {
                DuoPhotoCard(back: back, front: front, caption: "You", showsLate: !snap.onTime)
            } else {
                SealedFrame(title: "Not yet", message: "Your two frames land here.", systemImage: "camera")
            }
        }
    }

    private func friendColumn(_ schedule: PromptCalendar.Schedule, status: DayStatus?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(model.partnerName)
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.muted)
                .lineLimit(1)
            friendBody(schedule, status: status)
        }
    }

    @ViewBuilder
    private func friendBody(_ schedule: PromptCalendar.Schedule, status: DayStatus?) -> some View {
        if status?.canSeePartner == true,
           let snap = model.partnerSnap(on: schedule.dayKey),
           let back = model.image(named: snap.backFilename),
           let front = model.image(named: snap.frontFilename) {
            DuoPhotoCard(back: back, front: front, caption: model.partnerName, showsLate: !snap.onTime)
        } else if status?.phase == .waitingForFriend {
            SealedFrame(title: "Waiting", message: "\(model.partnerName) hasn't posted.", systemImage: "hourglass")
        } else if status?.phase == .upcoming {
            SealedFrame(title: "Later", message: "Their snap stays hidden until the prompt opens.", systemImage: "clock")
        } else if status?.phase == .sealed {
            SealedFrame(title: "Sealed", message: "You missed the window, so this one stays closed.")
        } else if status?.phase == .locked {
            SealedFrame(title: "Posted", message: "Send yours to see \(model.partnerName).")
        } else {
            SealedFrame(title: "Hidden", message: "Post yours to reveal \(model.partnerName).")
        }
    }

    @ViewBuilder
    private var notificationCard: some View {
        if model.notificationAuthorization == .notDetermined && !model.settings.dismissedNotificationPrompt {
            VStack(alignment: .leading, spacing: 10) {
                Text("A nudge when it opens")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(DuoTheme.ink)
                Text("It's a reminder on this iPhone. No server has to ping you.")
                    .font(DuoTheme.roundedCaption)
                    .foregroundStyle(DuoTheme.muted)
                HStack {
                    Button("Turn on") {
                        Task { await model.enableNotifications() }
                    }
                    .buttonStyle(FilledButtonStyle())
                    Button("Not now") {
                        model.dismissNotificationPrompt()
                    }
                    .buttonStyle(QuietButtonStyle())
                }
            }
            .padding(16)
            .background(DuoTheme.line, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var actionButton: some View {
        let schedule = model.todaySchedule()
        let posted = schedule.flatMap { model.mySnap(on: $0.dayKey) } != nil
        let phase = schedule.flatMap { model.status(for: $0.dayKey)?.phase }
        let title: String
        let enabled: Bool
        switch phase {
        case .upcoming:
            let time = schedule?.opensAt.formatted(date: .omitted, time: .shortened) ?? ""
            title = "Opens at \(time)"
            enabled = false
        case .sealed:
            title = "Today's window has closed"
            enabled = false
        case .waitingForFriend, .revealed:
            title = posted ? "Sent for today" : "Take today's snap"
            enabled = !posted
        default:
            title = "Take today's snap"
            enabled = schedule != nil && !posted
        }
        return Button(title) {
            showCamera = true
        }
        .buttonStyle(FilledButtonStyle(color: enabled ? DuoTheme.shutter : DuoTheme.muted.opacity(0.4)))
        .disabled(!enabled)
    }

    private var todayTitle: String {
        guard let pair = model.pair else {
            return Date.now.formatted(date: .complete, time: .omitted)
        }
        return Date.now.formatted(
            Date.FormatStyle()
                .weekday(.wide)
                .month(.wide)
                .day()
                .timeZone(pair.timeZone)
        )
    }

    private func detail(for schedule: PromptCalendar.Schedule) -> String {
        let time = schedule.opensAt.formatted(date: .omitted, time: .shortened)
        let phase = model.status(for: schedule.dayKey)?.phase
        switch phase {
        case .upcoming:
            return "Opens at \(time) · on time for \(PromptCalendar.onTimeLengthMinutes) min"
        case .yourTurn, .locked:
            if Date.now <= schedule.onTimeUntil {
                return "Open now · on time until \(schedule.onTimeUntil.formatted(date: .omitted, time: .shortened))"
            }
            return "Open now · late is fine until midnight"
        case .waitingForFriend, .revealed:
            return "Posted · \(time)"
        case .sealed:
            return "Closed at midnight"
        case .none:
            return "Opens at \(time)"
        }
    }
}
