import AVFoundation
import UIKit
import VideoToolbox

nonisolated final class CameraCaptureService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let sessionQueue = DispatchQueue(label: "cam.session", qos: .userInteractive)
    private var testPatternTimer: DispatchSourceTimer?

    var onJPEGFrame: (@Sendable (Data) -> Void)?

    func requestPermissionAndStart() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            guard let self else { return }
            self.sessionQueue.async {
                if granted {
                    self.configureSession()
                } else {
                    self.startTestPattern()
                }
            }
        }
    }

    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            session.commitConfiguration()
            startTestPattern()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }

        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: sessionQueue)

        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        if let connection = videoOutput.connection(with: .video) {
            connection.isVideoMirrored = true
        }

        do {
            try camera.lockForConfiguration()
            camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            camera.unlockForConfiguration()
        } catch {}

        session.commitConfiguration()
        session.startRunning()
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        var cgImage: CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        guard let cgImage else { return }

        let uiImage = UIImage(cgImage: cgImage)
        guard let jpegData = uiImage.jpegData(compressionQuality: 0.6) else { return }

        onJPEGFrame?(jpegData)
    }

    private func startTestPattern() {
        let size = CGSize(width: 1280, height: 720)
        let renderer = UIGraphicsImageRenderer(size: size)
        let frameData = renderer.jpegData(withCompressionQuality: 0.5) { ctx in
            UIColor(white: 0.1, alpha: 1).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let text = "Virtual Camera"
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: UIColor.white.withAlphaComponent(0.35),
                .font: UIFont.systemFont(ofSize: 36, weight: .light)
            ]
            let ts = (text as NSString).size(withAttributes: attrs)
            (text as NSString).draw(
                at: CGPoint(x: (size.width - ts.width) / 2, y: (size.height - ts.height) / 2),
                withAttributes: attrs
            )
        }

        let timer = DispatchSource.makeTimerSource(queue: sessionQueue)
        timer.schedule(deadline: .now(), repeating: 1.0 / 30.0)
        timer.setEventHandler { [weak self] in
            self?.onJPEGFrame?(frameData)
        }
        timer.resume()
        testPatternTimer = timer
    }

    func stop() {
        sessionQueue.async { [weak self] in
            self?.session.stopRunning()
            self?.testPatternTimer?.cancel()
            self?.testPatternTimer = nil
        }
    }
}
