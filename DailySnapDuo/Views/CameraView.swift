import SwiftUI

struct CameraView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @StateObject private var camera = CameraController()
    @State private var isSending = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch camera.phase {
            case .review:
                review
            case .failed(let message):
                failed(message)
            default:
                finder
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            camera.start()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            camera.stop()
        }
    }

    private var finder: some View {
        ZStack {
            CameraPreview(session: camera.session, mirrored: camera.capturingFront)
                .ignoresSafeArea()
            VStack {
                HStack {
                    closeButton
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Text(camera.capturingFront ? "Now the front camera" : (model.todaySchedule()?.prompt ?? "Today's snap"))
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.4), in: Capsule())
                    .padding(.top, 8)

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    camera.shutter()
                } label: {
                    ZStack {
                        Circle()
                            .stroke(.white, lineWidth: 4)
                            .frame(width: 78, height: 78)
                        Circle()
                            .fill(DuoTheme.shutter)
                            .frame(width: 62, height: 62)
                    }
                }
                .disabled(camera.phase != .ready)
                .opacity(camera.phase == .ready ? 1 : 0.45)
                .accessibilityLabel("Take back and front photos")
                .padding(.bottom, 28)
            }
        }
    }

    private var review: some View {
        VStack(spacing: 18) {
            HStack {
                closeButton
                Spacer()
                Text("Look right?")
                    .font(DuoTheme.serifTitle)
                    .foregroundStyle(DuoTheme.ink)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)

            if let back = camera.backImage, let front = camera.frontImage {
                DuoPhotoCard(back: back, front: front, caption: "You")
                    .padding(.horizontal, 28)
            }

            VStack(spacing: 10) {
                Button {
                    send()
                } label: {
                    Text(isSending ? "Sending…" : "Send today's snap")
                }
                .buttonStyle(FilledButtonStyle())
                .disabled(isSending)

                Button("Retake") {
                    camera.retake()
                }
                .buttonStyle(QuietButtonStyle())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
    }

    private func failed(_ message: String) -> some View {
        VStack(spacing: 16) {
            HStack {
                closeButton
                Spacer()
            }
            Spacer()
            Image(systemName: "camera.fill")
                .font(.largeTitle)
                .foregroundStyle(DuoTheme.muted)
            Text(message)
                .font(DuoTheme.roundedBody)
                .foregroundStyle(DuoTheme.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Use a stand-in photo") {
                let seed = PromptCalendar.stableHash(model.pair?.code ?? "stand-in")
                camera.useStandIn(seed: seed)
            }
            .buttonStyle(FilledButtonStyle())
            .padding(.horizontal, 24)
            Button("Open Settings") {
                model.openSystemSettings()
            }
            .font(DuoTheme.roundedCaption)
            .foregroundStyle(DuoTheme.muted)
            Spacer()
        }
        .padding(.top, 12)
    }

    private var closeButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.black.opacity(0.4), in: Circle())
        }
        .accessibilityLabel("Close camera")
    }

    private func send() {
        guard let back = camera.backImage, let front = camera.frontImage else { return }
        isSending = true
        Task {
            let posted = await model.post(back: back, front: front)
            isSending = false
            if posted {
                dismiss()
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var mirrored: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.mirrored = mirrored
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    var mirrored = false {
        didSet { applyConnection() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyConnection()
    }

    private func applyConnection() {
        guard let connection = previewLayer.connection else { return }
        if connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = mirrored
        }
    }
}
