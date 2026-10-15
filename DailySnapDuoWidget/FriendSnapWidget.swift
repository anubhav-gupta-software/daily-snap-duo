import SwiftUI
import WidgetKit

@main
struct DailySnapDuoWidgetBundle: WidgetBundle {
    var body: some Widget {
        FriendSnapWidget()
    }
}

struct FriendSnapWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FriendSnap", provider: PlaceholderProvider()) { entry in
            Text(entry.label)
                .font(.system(.headline, design: .serif))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .containerBackground(for: .widget) {
                    Color(red: 0.11, green: 0.09, blue: 0.08)
                }
        }
        .configurationDisplayName("Friend's snap")
        .description("The latest snap you're allowed to see.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PlaceholderEntry: TimelineEntry {
    var date: Date
    var label: String
}

struct PlaceholderProvider: TimelineProvider {
    func placeholder(in context: Context) -> PlaceholderEntry {
        PlaceholderEntry(date: Date(), label: "Daily Snap Duo")
    }

    func getSnapshot(in context: Context, completion: @escaping (PlaceholderEntry) -> Void) {
        completion(PlaceholderEntry(date: Date(), label: "Daily Snap Duo"))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PlaceholderEntry>) -> Void) {
        let entry = PlaceholderEntry(date: Date(), label: "Daily Snap Duo")
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600))))
    }
}
