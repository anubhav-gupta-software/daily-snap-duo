import SwiftUI

struct OnboardingView: View {
    @Environment(AppModel.self) private var model
    @State private var name = ""
    @State private var code = ""
    @State private var joining = false

    var body: some View {
        ZStack {
            DuoTheme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Daily Snap Duo")
                        .font(DuoTheme.serifLarge)
                        .foregroundStyle(DuoTheme.ink)
                    Text("One prompt a day, at a time neither of you picks. Two photos. Theirs stays hidden until you post yours.")
                        .font(DuoTheme.roundedBody)
                        .foregroundStyle(DuoTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 14) {
                        rule(icon: "clock", text: "It opens sometime between 8:00 and 9:30.")
                        rule(icon: "camera.fill", text: "One shutter takes the back, then the front.")
                        rule(icon: "lock.fill", text: "You can't see their snap until you send yours.")
                    }
                    .padding(.vertical, 6)

                    TextField("Your name", text: $name)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .rounded))
                        .padding(16)
                        .background(DuoTheme.line, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(DuoTheme.ink)

                    if joining {
                        TextField("Invite code", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .padding(16)
                            .background(DuoTheme.line, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(DuoTheme.ink)
                            .onChange(of: code) { _, newValue in
                                let normalized = InviteCode.normalize(newValue)
                                if normalized != newValue { code = normalized }
                            }

                        Button("Join this duo") {
                            _ = model.joinDuo(name: name, code: code)
                        }
                        .buttonStyle(FilledButtonStyle())

                        Button("I want to start one instead") {
                            joining = false
                        }
                        .font(DuoTheme.roundedCaption)
                        .foregroundStyle(DuoTheme.muted)
                        .frame(maxWidth: .infinity)
                    } else {
                        Button("Start a duo") {
                            _ = model.startDuo(name: name)
                        }
                        .buttonStyle(FilledButtonStyle())

                        Button("I have a code") {
                            joining = true
                        }
                        .buttonStyle(QuietButtonStyle())
                    }
                }
                .padding(24)
            }
        }
        .onAppear {
            if name.isEmpty, let existing = model.profile?.displayName {
                name = existing
            }
            if let pending = model.pendingInviteCode {
                code = pending
                joining = true
            }
        }
    }

    private func rule(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(DuoTheme.shutter)
            Text(text)
                .font(DuoTheme.roundedBody)
                .foregroundStyle(DuoTheme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
