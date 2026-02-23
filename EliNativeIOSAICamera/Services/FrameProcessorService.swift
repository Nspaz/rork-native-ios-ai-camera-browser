import Foundation

nonisolated final class FrameProcessorService: @unchecked Sendable {
    private let lock = NSLock()
    private var _serverURL: URL?
    private var _referenceImageData: Data?
    private var _isProcessing = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 1.5
        config.timeoutIntervalForResource = 3.0
        return URLSession(configuration: config)
    }()

    var serverURL: URL? {
        get { lock.withLock { _serverURL } }
        set { lock.withLock { _serverURL = newValue } }
    }

    var referenceImageData: Data? {
        get { lock.withLock { _referenceImageData } }
        set { lock.withLock { _referenceImageData = newValue } }
    }

    func processFrame(_ jpegData: Data) async -> Data {
        guard let url = serverURL else { return jpegData }

        let shouldProcess = lock.withLock {
            if _isProcessing { return false }
            _isProcessing = true
            return true
        }
        guard shouldProcess else { return jpegData }
        defer { lock.withLock { _isProcessing = false } }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"frame\"; filename=\"frame.jpg\"\r\n".utf8))
        body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
        body.append(jpegData)
        body.append(Data("\r\n".utf8))

        if let ref = referenceImageData {
            body.append(Data("--\(boundary)\r\n".utf8))
            body.append(Data("Content-Disposition: form-data; name=\"reference\"; filename=\"ref.jpg\"\r\n".utf8))
            body.append(Data("Content-Type: image/jpeg\r\n\r\n".utf8))
            body.append(ref)
            body.append(Data("\r\n".utf8))
        }

        body.append(Data("--\(boundary)--\r\n".utf8))
        request.httpBody = body

        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty {
                return data
            }
            return jpegData
        } catch {
            return jpegData
        }
    }
}
