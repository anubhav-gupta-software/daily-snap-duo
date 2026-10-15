import SwiftUI

struct SprocketRow: View {
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<8, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DuoTheme.background.opacity(0.9))
                    .frame(width: 12, height: 9)
            }
        }
        .accessibilityHidden(true)
    }
}

struct PromptCard: View {
    var prompt: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SprocketRow()
            Text(prompt)
                .font(DuoTheme.serifTitle)
                .foregroundStyle(DuoTheme.paperInk)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(DuoTheme.roundedCaption)
                .foregroundStyle(DuoTheme.paperInk.opacity(0.62))
            SprocketRow()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DuoTheme.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct DuoPhotoCard: View {
    var back: UIImage
    var front: UIImage
    var caption: String
    var showsLate: Bool = false

    var body: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                Image(uiImage: back)
                    .resizable()
                    .scaledToFill()
            }
            .overlay(alignment: .bottomLeading) {
                Image(uiImage: front)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(DuoTheme.paper, lineWidth: 3)
                    }
                    .padding(10)
            }
            .overlay(alignment: .topLeading) {
                if showsLate {
                    Text("Late")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(DuoTheme.paperInk)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DuoTheme.paper, in: Capsule())
                        .padding(10)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Text(caption)
                    .font(.system(.caption2, design: .rounded).weight(.medium))
                    .foregroundStyle(DuoTheme.paper)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(caption)'s snap")
    }
}

struct SealedFrame: View {
    var title: String
    var message: String
    var systemImage: String = "lock.fill"

    var body: some View {
        Color.clear
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay {
                VStack(spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.title3)
                    Text(title)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Text(message)
                        .font(DuoTheme.roundedCaption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(DuoTheme.muted)
                }
                .foregroundStyle(DuoTheme.ink)
                .padding(12)
            }
            .background(DuoTheme.background.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(DuoTheme.line, lineWidth: 1)
            }
    }
}

struct FilledButtonStyle: ButtonStyle {
    var color: Color = DuoTheme.shutter

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(DuoTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(configuration.isPressed ? 0.82 : 1), in: Capsule())
    }
}

struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(DuoTheme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(DuoTheme.line, in: Capsule())
            .overlay {
                Capsule().stroke(DuoTheme.muted.opacity(0.35), lineWidth: 1)
            }
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}
