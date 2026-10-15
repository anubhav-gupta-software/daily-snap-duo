import Photos
import SwiftUI

struct HistoryView: View {
    @Environment(AppModel.self) private var model
    @State private var saveMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                DuoTheme.background.ignoresSafeArea()
                if model.historyDayKeys().isEmpty {
                    Text("Your snaps will stack up here.")
                        .font(DuoTheme.roundedBody)
                        .foregroundStyle(DuoTheme.muted)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 28) {
                            ForEach(model.historyDayKeys(), id: \.self) { dayKey in
                                daySection(dayKey)
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await model.refresh() }
            .alert("Photos", isPresented: Binding(
                get: { saveMessage != nil },
                set: { if !$0 { saveMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage ?? "")
            }
        }
    }

    private func daySection(_ dayKey: String) -> some View {
        let schedule = model.pair.map {
            PromptCalendar.schedule(code: $0.code, dayKey: dayKey, timeZone: $0.timeZone)
        }
        let status = model.status(for: dayKey)
        return VStack(alignment: .leading, spacing: 10) {
            Text(title(for: dayKey))
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.muted)
            Text(schedule?.prompt ?? "")
                .font(.system(.title3, design: .serif))
                .foregroundStyle(DuoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .top, spacing: 12) {
                column(title: "You", snap: model.mySnap(on: dayKey), revealed: true)
                column(
                    title: model.partnerName,
                    snap: model.partnerSnap(on: dayKey),
                    revealed: status?.canSeePartner == true,
                    sealed: status?.phase == .sealed
                )
            }
        }
    }

    @ViewBuilder
    private func column(title: String, snap: Snap?, revealed: Bool, sealed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.muted)
                .lineLimit(1)
            if revealed, let snap,
               let back = model.image(named: snap.backFilename),
               let front = model.image(named: snap.frontFilename) {
                DuoPhotoCard(back: back, front: front, caption: title, showsLate: !snap.onTime)
                Button("Save") {
                    Task { await save(back) }
                }
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.muted)
            } else if sealed {
                SealedFrame(title: "Sealed", message: "No post, so this stayed closed.")
            } else if snap != nil && !revealed {
                SealedFrame(title: "Hidden", message: "Post yours to open this one.")
            } else {
                SealedFrame(title: "Empty", message: "Nothing from \(title) this day.", systemImage: "photo")
            }
        }
    }

    private func title(for dayKey: String) -> String {
        guard let zone = model.pair?.timeZone, let date = PromptCalendar.date(for: dayKey, timeZone: zone) else {
            return dayKey
        }
        return date.formatted(
            Date.FormatStyle()
                .weekday(.abbreviated)
                .month(.abbreviated)
                .day()
                .timeZone(zone)
        )
    }

    private func save(_ image: UIImage) async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            saveMessage = "Photos access is off, so I couldn't save a copy."
            return
        }
        let saved = await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                continuation.resume(returning: success)
            }
        }
        saveMessage = saved ? "Saved a copy to Photos." : "Couldn't save that photo."
    }
}
