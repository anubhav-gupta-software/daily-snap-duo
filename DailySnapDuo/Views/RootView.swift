import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.profile == nil || model.pair == nil {
                OnboardingView()
            } else {
                HomeView()
            }
        }
        .preferredColorScheme(.dark)
        .tint(DuoTheme.shutter)
        .overlay(alignment: .top) {
            banner
        }
        .task {
            await model.onForeground()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await model.onForeground() }
            }
        }
        .onOpenURL { url in
            open(url)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let message = model.banner {
            Button {
                model.dismissBanner()
            } label: {
                Text(message)
                    .font(DuoTheme.roundedCaption)
                    .foregroundStyle(DuoTheme.paperInk)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(DuoTheme.paper, in: Capsule())
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
        }
    }

    private func open(_ url: URL) {
        if url.pathExtension.lowercased() == "snapduo" {
            guard model.profile != nil else {
                model.banner = "Add your name, then open that file again."
                return
            }
            do {
                try model.importExchange(from: url)
            } catch {
                model.banner = (error as? LocalizedError)?.errorDescription ?? "Couldn't open that snap."
            }
            return
        }

        guard url.scheme == "dailysnapduo" else { return }
        let code = InviteCode.normalize(url.pathComponents.last ?? "")
        guard InviteCode.isValid(code) else { return }
        if model.profile == nil {
            model.pendingInviteCode = code
            return
        }
        if model.pair == nil {
            _ = model.joinDuo(name: model.profile?.displayName ?? "", code: code)
            return
        }
        if model.pair?.code != code {
            model.banner = "Leave your current duo before joining \(code)."
        }
    }
}
