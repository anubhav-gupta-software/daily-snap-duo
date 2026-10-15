import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct PairView: View {
    @Environment(AppModel.self) private var model
    @State private var exchangeURL: URL?
    @State private var importing = false
    @State private var confirmLeave = false
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ZStack {
                DuoTheme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("Your code")
                            .font(DuoTheme.roundedCaption)
                            .foregroundStyle(DuoTheme.muted)
                        Text(model.pair?.code ?? "------")
                            .font(.system(size: 42, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DuoTheme.ink)
                            .tracking(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("Invite code \(model.pair?.code ?? "")")

                        Text(partnerLine)
                            .font(DuoTheme.roundedBody)
                            .foregroundStyle(DuoTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        Button(copied ? "Copied" : "Copy code") {
                            UIPasteboard.general.string = model.pair?.code
                            copied = true
                        }
                        .buttonStyle(FilledButtonStyle())

                        if let code = model.pair?.code {
                            ShareLink(item: inviteMessage(code)) {
                                Text("Share invite")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(QuietButtonStyle())
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Pass snaps")
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(DuoTheme.ink)
                            Text("AirDrop a .snapduo file when you don't want to run a relay. The reveal rule still applies on the other phone.")
                                .font(DuoTheme.roundedCaption)
                                .foregroundStyle(DuoTheme.muted)
                        }
                        .padding(.top, 8)

                        if let exchangeURL {
                            ShareLink(item: exchangeURL, preview: SharePreview("Daily Snap Duo", icon: Image(systemName: "photo.on.rectangle"))) {
                                Text("Send snap file")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(FilledButtonStyle(color: DuoTheme.olive))
                        }

                        Button("Open a snap file") {
                            importing = true
                        }
                        .buttonStyle(QuietButtonStyle())

                        Button("Leave this duo", role: .destructive) {
                            confirmLeave = true
                        }
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(DuoTheme.shutter)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Duo")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { refreshFile() }
            .fileImporter(
                isPresented: $importing,
                allowedContentTypes: [snapType],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        try model.importExchange(from: url)
                        refreshFile()
                    } catch {
                        model.banner = (error as? LocalizedError)?.errorDescription ?? "Couldn't open that file."
                    }
                case .failure:
                    model.banner = "Couldn't open that file."
                }
            }
            .confirmationDialog("Leave this duo?", isPresented: $confirmLeave, titleVisibility: .visible) {
                Button("Leave duo", role: .destructive) {
                    model.leavePair()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Snaps on this iPhone for this duo will be deleted.")
            }
        }
    }

    private var partnerLine: String {
        guard let profile = model.profile, let pair = model.pair else {
            return "Share the code with one friend."
        }
        if let partner = pair.partner(for: profile.id) {
            if partner.isSample {
                return "Riley is a practice partner on this phone. Turn them off in Settings when a real friend joins."
            }
            return "You're paired with \(partner.displayName)."
        }
        return "Share the code. When they join, their name shows up here."
    }

    private func inviteMessage(_ code: String) -> String {
        "Join me on Daily Snap Duo. Code: \(code). Open the app and enter it — dailysnapduo://join/\(code)"
    }

    private var snapType: UTType {
        UTType(filenameExtension: "snapduo") ?? .json
    }

    private func refreshFile() {
        exchangeURL = try? model.makeExchangeFile()
    }
}
