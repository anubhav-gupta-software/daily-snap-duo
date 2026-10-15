import SwiftUI
import UIKit
import WidgetKit

@main
struct DailySnapDuoWidgetBundle: WidgetBundle {
    var body: some Widget {
        FriendSnapWidget()
    }
}

struct FriendSnapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FriendSnap", provider: FriendProvider()) { entry in
            FriendSnapView(entry: entry)
                .containerBackground(for: .widget) {
                    DuoTheme.background
                }
        }
        .configurationDisplayName("Friend's snap")
        .description("The latest snap you're allowed to see.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct FriendEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    var image: UIImage?
}

struct FriendProvider: TimelineProvider {
    func placeholder(in context: Context) -> FriendEntry {
        FriendEntry(date: Date(), snapshot: .gallery, image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (FriendEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FriendEntry>) -> Void) {
        let entry = load()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func load() -> FriendEntry {
        guard let (snapshot, data) = WidgetSnapshotStore.load() else {
            return FriendEntry(date: Date(), snapshot: .unavailable, image: nil)
        }
        let image = snapshot.state == .revealed ? data.flatMap(UIImage.init(data:)) : nil
        return FriendEntry(date: Date(), snapshot: snapshot, image: image)
    }
}

struct FriendSnapView: View {
    @Environment(\.widgetFamily) private var family
    var entry: FriendEntry

    var body: some View {
        Group {
            if family == .systemMedium {
                medium
            } else {
                small
            }
        }
        .widgetURL(URL(string: "dailysnapduo://today"))
    }

    @ViewBuilder
    private var small: some View {
        if entry.snapshot.state == .revealed, let image = entry.image {
            photo(image, name: entry.snapshot.friendName)
        } else {
            status(compact: true)
        }
    }

    private var medium: some View {
        HStack(spacing: 12) {
            if entry.snapshot.state == .revealed, let image = entry.image {
                photo(image, name: entry.snapshot.friendName)
                    .frame(maxWidth: 140)
            } else {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(DuoTheme.shutter)
                    .frame(width: 72)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.snapshot.friendName.isEmpty ? "Daily Snap Duo" : entry.snapshot.friendName)
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(DuoTheme.muted)
                Text(entry.snapshot.prompt)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(DuoTheme.ink)
                    .lineLimit(3)
                Text(entry.snapshot.detail)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(DuoTheme.muted)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func photo(_ image: UIImage, name: String) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .bottomLeading) {
                Text(name)
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(8)
            }
            .clipped()
    }

    private func status(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(DuoTheme.shutter)
            Text(entry.snapshot.prompt)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(DuoTheme.ink)
                .lineLimit(compact ? 3 : 2)
            Text(entry.snapshot.detail)
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(DuoTheme.muted)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var symbol: String {
        switch entry.snapshot.state {
        case .needsPairing:
            "person.2"
        case .upcoming:
            "clock"
        case .yourTurn:
            "camera"
        case .locked, .sealed:
            "lock.fill"
        case .waitingForFriend:
            "hourglass"
        case .revealed:
            "photo"
        case .unavailable:
            "app"
        }
    }
}

extension WidgetSnapshot {
    static let gallery = WidgetSnapshot(
        state: .locked,
        prompt: "Show the view from where you are.",
        detail: "Post yours to see them",
        friendName: "Friend",
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}
