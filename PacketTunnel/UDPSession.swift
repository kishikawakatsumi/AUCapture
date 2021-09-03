import Foundation
import Network

class UDPSession {
    let host: String
    let port: UInt16
    let payload: Data
    
    var onReceive: (Data) -> Void = { _ in }
    var onError: (Error) -> Void = { _ in }

    private let connection: NWConnection
    private let queue = DispatchQueue(label: "")

    init(host: String, port: UInt16, payload: Data) {
        self.host = host
        self.port = port
        self.payload = payload
        connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port)!, using: .udp)
        connect()
    }

    func send(_ payload: Data) {
        connection.send(content: payload, completion: .contentProcessed({ [weak self] (error) in
            if let error = error {
                self?.onError(error)
            }
        }))
    }

    private func connect() {
        let payload = self.payload
        connection.stateUpdateHandler = { [weak self] (state) in
            switch (state) {
            case .setup, .waiting, .preparing:
                break
            case .ready:
                self?.send(payload)
            case .failed(let error):
                self?.onError(error)
            case .cancelled:
                break
            @unknown default:
                break
            }
        }

        connection.start(queue: queue)
        receive()
    }

    private func receive() {
        connection.receiveMessage(completion: { [weak self] (data, context, isComplete, error) in
            if let data = data {
                self?.onReceive(data)
            }
            if let error = error {
                self?.onError(error)
            }
            self?.receive()
        })
    }
}
