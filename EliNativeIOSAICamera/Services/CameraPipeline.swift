import Foundation
import UIKit

@Observable
class CameraPipeline {
    var isRunning: Bool = false
    var serverURL: String = ""
    var currentFPS: Double = 0
    var currentLatency: Double = 0
    var latestPreviewImage: UIImage?
    var onFrameForWebView: ((Data) -> Void)?

    private let capture = CameraCaptureService()
    private let mjpegServer = MJPEGServer()
    private let processor = FrameProcessorService()
    private var frameCount: Int = 0
    private var lastFPSUpdate: CFAbsoluteTime = 0

    func start() {
        guard !isRunning else { return }

        let saved = UserDefaults.standard.string(forKey: "transformServerURL") ?? ""
        if !saved.isEmpty { serverURL = saved }
        if !serverURL.isEmpty { processor.serverURL = URL(string: serverURL) }

        if let refURL = UserDefaults.standard.string(forKey: "referenceImageURL"),
           let url = URL(string: refURL) {
            let proc = processor
            Task.detached {
                if let data = try? Data(contentsOf: url) {
                    proc.referenceImageData = data
                }
            }
        }

        mjpegServer.start(port: 8080)

        let proc = processor
        let mjpeg = mjpegServer

        capture.onJPEGFrame = { [weak self] jpegData in
            Task.detached { [weak self] in
                let start = CFAbsoluteTimeGetCurrent()
                let processed = await proc.processFrame(jpegData)
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0

                mjpeg.pushFrame(processed)

                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.currentLatency = elapsed
                    self.frameCount += 1
                    let now = CFAbsoluteTimeGetCurrent()
                    if now - self.lastFPSUpdate >= 1.0 {
                        self.currentFPS = Double(self.frameCount) / (now - self.lastFPSUpdate)
                        self.frameCount = 0
                        self.lastFPSUpdate = now
                    }
                    self.latestPreviewImage = UIImage(data: processed)
                    self.onFrameForWebView?(processed)
                }
            }
        }

        capture.requestPermissionAndStart()
        isRunning = true
        lastFPSUpdate = CFAbsoluteTimeGetCurrent()
    }

    func stop() {
        capture.stop()
        mjpegServer.stop()
        isRunning = false
        currentFPS = 0
        currentLatency = 0
    }

    func updateServerURL(_ url: String) {
        serverURL = url
        UserDefaults.standard.set(url, forKey: "transformServerURL")
        processor.serverURL = url.isEmpty ? nil : URL(string: url)
    }

    func updateReferenceURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "referenceImageURL")
        guard let refURL = URL(string: url), !url.isEmpty else {
            processor.referenceImageData = nil
            return
        }
        let proc = processor
        Task.detached {
            if let data = try? Data(contentsOf: refURL) {
                proc.referenceImageData = data
            }
        }
    }
}
