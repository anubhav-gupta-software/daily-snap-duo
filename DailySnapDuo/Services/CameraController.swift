import AVFoundation
import UIKit

final class CameraController: NSObject, ObservableObject {
    enum Phase: Equatable {
        case starting
        case ready
        case capturing
        case review
        case failed(String)
    }

    @Published var phase: Phase = .starting
    @Published var capturingFront = false
    @Published var backImage: UIImage?
    @Published var frontImage: UIImage?

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "app.dailysnapduo.camera")
    private var nextShot: Shot = .back

    private enum Shot {
        case back
        case front
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStart(position: .back)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndStart(position: .back)
                    } else {
                        self?.phase = .failed("Camera access is off. You can allow it in Settings.")
                    }
                }
            }
        default:
            phase = .failed("Camera access is off. You can allow it in Settings.")
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func shutter() {
        guard phase == .ready else { return }
        phase = .capturing
        nextShot = .back
        capturingFront = false
        capture()
    }

    func retake() {
        backImage = nil
        frontImage = nil
        capturingFront = false
        nextShot = .back
        phase = .starting
        configureAndStart(position: .back)
    }

    func useStandIn(seed: UInt64) {
        let artwork = SampleArtwork.standInPair(seed: seed)
        backImage = artwork.back
        frontImage = artwork.front
        capturingFront = false
        phase = .review
        stop()
    }

    private func configureAndStart(position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configure(position: position)
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                DispatchQueue.main.async {
                    if case .failed = self.phase { return }
                    if self.phase != .review {
                        self.phase = .ready
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.phase = .failed("No camera is available on this device.")
                }
            }
        }
    }

    private func configure(position: AVCaptureDevice.Position) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo

        for input in session.inputs {
            session.removeInput(input)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw CameraError.unavailable
        }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)

        if !session.outputs.contains(where: { $0 === photoOutput }) {
            guard session.canAddOutput(photoOutput) else { throw CameraError.unavailable }
            session.addOutput(photoOutput)
        }
        photoOutput.maxPhotoQualityPrioritization = .balanced

        if let connection = photoOutput.connection(with: .video) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = position == .front
            }
        }
    }

    private func capture() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(.off) {
                settings.flashMode = .off
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func switchToFrontAndCapture() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            do {
                try self.configure(position: .front)
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            } catch {
                DispatchQueue.main.async {
                    self.phase = .failed("The front camera didn't start.")
                }
                return
            }
            DispatchQueue.main.async {
                self.capturingFront = true
                self.phase = .capturing
            }
            self.sessionQueue.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.capture()
            }
        }
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap(UIImage.init(data:))
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if error != nil || image == nil {
                self.phase = .failed("That photo didn't come through. Try again.")
                return
            }
            guard let image else { return }
            switch self.nextShot {
            case .back:
                self.backImage = image
                self.nextShot = .front
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                self.switchToFrontAndCapture()
            case .front:
                self.frontImage = image
                self.capturingFront = false
                self.phase = .review
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                self.stop()
            }
        }
    }
}

enum CameraError: Error {
    case unavailable
}
