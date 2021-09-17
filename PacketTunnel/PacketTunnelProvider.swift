import NetworkExtension

class PacketTunnelProvider: NEPacketTunnelProvider {
    private var tcpSessions = [String: TCPSession]()
    private var udpSessions = [String: UDPSession]()

    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let ip = "10.10.10.10"
        let subnetMask = "255.255.255.0"

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4Settings = NEIPv4Settings(addresses: [ip], subnetMasks: [subnetMask])

        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        ipv4Settings.excludedRoutes = [
            NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
            NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
        ]
        settings.ipv4Settings = ipv4Settings

        let dnsSettings = NEDNSSettings(servers: ["8.8.8.8", "8.8.4.4"])
        dnsSettings.matchDomains = [""]
        settings.dnsSettings = dnsSettings

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }

            completionHandler(error)
            if let error = error {
                NSLog("Tunnel network settings error: \(error)")
            } else {
                self.localPacketsToServer()
            }
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        completionHandler()
    }

    private func localPacketsToServer() {
        packetFlow.readPacketObjects { [weak self] (packets) in
            defer { self?.localPacketsToServer() }
            guard let self = self else { return }

            packets.forEach { (packet) in
                if let ipPacket = IPPacket(packet.data) {
                    switch ipPacket.proto {
                    case .tcp:
                        self.handleTCPPacket(ipPacket)
                    case .udp:
                        self.sendUDPPacket(ipPacket)
                    case .icmp:
                        break
                    }
                }
            }
        }
    }

    private func handleTCPPacket(_ packet: IPPacket) {
        // For now, for the sake of simplicity, TCP packets are not handled.
    }

    private func sendUDPPacket(_ packet: IPPacket) {
        let key = "\(packet.source):\(packet.sourcePort) => \(packet.destination):\(packet.destinationPort)"
        NSLog("SEND: \(key) \(packet.payload.hex)")
        sendPacketDump(packet.payload)

        if let session = self.udpSessions[key] {
            session.send(packet.payload)
        } else {
            let session = UDPSession(
                host: packet.destination,
                port: packet.destinationPort,
                payload: packet.payload
            )
            session.onReceive = { [weak self] (data) in
                guard let self = self else { return }

                let packet = IPPacket(
                    proto: packet.proto,
                    source: packet.destination,
                    destination: packet.source,
                    sourcePort: packet.destinationPort,
                    destinationPort: packet.sourcePort,
                    payload: data
                )

                NSLog("RECV: \(packet.source):\(packet.sourcePort) => \(packet.destination):\(packet.destinationPort) \(data.hex)")
                sendPacketDump(data)

                self.packetFlow.writePacketObjects([
                    NEPacket(
                        data: packet.packetData,
                        protocolFamily: sa_family_t(AF_INET)
                    )
                ])
            }
            session.onError = { (error) in
                NSLog("UDP Error: \(error)")
            }

            self.udpSessions[key] = session
        }
    }
}

private func sendPacketDump(_ data: Data) {
    let container = AppGroup.container
    let file = container.appendingPathComponent("capture_state")
    let fileCoordinator = NSFileCoordinator()
    fileCoordinator.coordinate(writingItemAt: file, options: [], error: nil) { (file) in
        try? data.hex.write(to: file, atomically: false, encoding: .utf8)
    }
}
