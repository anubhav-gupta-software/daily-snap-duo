import Foundation

/// Locates the container shared by the app and the widget.
///
/// The identifier is written into each target's Info.plist from
/// `APP_GROUP_IDENTIFIER` so a bundle-id change in the xcconfig stays in sync.
/// If the App Group entitlement isn't on the provisioning profile, `containerURL`
/// is nil and the widget falls back to an empty state.
enum AppGroupLocator {
    static let fallbackIdentifier = "group.com.anubhavgupta.dailysnapduo"

    static func identifier(bundle: Bundle = .main) -> String {
        if let value = bundle.object(forInfoDictionaryKey: "AppGroupIdentifier") as? String,
           !value.isEmpty,
           !value.contains("$(") {
            return value
        }
        return fallbackIdentifier
    }

    static func containerURL(bundle: Bundle = .main) -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: identifier(bundle: bundle)
        )
    }
}
