import Foundation
import Network

nonisolated final class MJPEGServer: @unchecked Sendable {
    private let boundary = "frameboundary"
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "mjpeg.server", qos: .userInteractive)
    private let lock = NSLock()
    private var connectionMap: [ObjectIdentifier: NWConnection] = [:]

    func start(port: UInt16 = 8080) {
        do {
            let params = NWParameters.tcp
            params.allowLocalEndpointReuse = true
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch { return }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handleConnection(conn)
        }
        listener?.start(queue: queue)
    }

    func stop() {
        listener?.cancel()
        listener = nil
        lock.withLock {
            connectionMap.values.forEach { $0.cancel() }
            connectionMap.removeAll()
        }
    }

    func pushFrame(_ jpegData: Data) {
        var header = "--\(boundary)\r\n"
        header += "Content-Type: image/jpeg\r\n"
        header += "Content-Length: \(jpegData.count)\r\n"
        header += "\r\n"

        var frameData = Data()
        frameData.append(Data(header.utf8))
        frameData.append(jpegData)
        frameData.append(Data("\r\n".utf8))

        let connections = lock.withLock { Array(connectionMap.values) }
        for conn in connections {
            conn.send(content: frameData, completion: .contentProcessed { _ in })
        }
    }

    private func handleConnection(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.lock.withLock { _ = self?.connectionMap.removeValue(forKey: id) }
            default: break
            }
        }

        connection.start(queue: queue)

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self, error == nil, let data else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""

            if request.contains("/avatar.mjpeg") || request.hasPrefix("GET / ") {
                let response = "HTTP/1.1 200 OK\r\nContent-Type: multipart/x-mixed-replace; boundary=\(self.boundary)\r\nAccess-Control-Allow-Origin: *\r\nCache-Control: no-cache\r\nConnection: keep-alive\r\n\r\n"
                connection.send(content: Data(response.utf8), completion: .contentProcessed { [weak self] _ in
                    self?.lock.withLock { self?.connectionMap[id] = connection }
                })
            } else if request.contains("OPTIONS") {
                let cors = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET\r\nContent-Length: 0\r\n\r\n"
                connection.send(content: Data(cors.utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            } else {
                let notFound = "HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\n\r\n"
                connection.send(content: Data(notFound.utf8), completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
    }
}
