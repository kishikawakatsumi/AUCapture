import NetworkExtension
import AmongUsProtocol

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
        packetFlow.readPackets { [weak self] (packets, _) in
            defer { self?.localPacketsToServer() }
            guard let self = self else { return }

            packets.forEach { (data) in
                if let ipPacket = IPPacket(data) {
                    switch ipPacket.proto {
                    case .tcp:
                        self.sendTCPPacket(ipPacket)
                    case .udp:
                        self.sendUDPPacket(ipPacket)
                    case .icmp:
                        break
                    }
                }
            }
        }
    }

    private func remotePacketToLocal() {

    }

    private func sendTCPPacket(_ packet: IPPacket) {

    }

    private func sendUDPPacket(_ packet: IPPacket) {
        let key = "\(packet.source):\(packet.sourcePort) => \(packet.destination):\(packet.destinationPort)"
        NSLog("SEND: \(key) \(packet.proto) \(packet.payload.hex)")

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

//                NSLog("RECV: \(packet.source):\(packet.sourcePort) => \(packet.destination):\(packet.destinationPort) \(packet.packetData.hex)")

                if let auPacket = PacketParser.parse(packet: data) {
//                    NSLog("AUPK: \(auPacket)")
                    switch auPacket {
                    case .normal(let nomal):
                        break
                    case .reliable(let reliable):
                        NSLog("AUPK: RECV: \(auPacket) \(data.hex)")
                        for message in reliable.messages {
                            switch message.payload {
                            case .hostGame(let hostGame):
                                NSLog("AUPK: hostGame: \(hostGame)")
                            case .joinGame(let joinGame):
                                NSLog("AUPK: joinGame: \(joinGame)")
                            case .startGame(let startGame):
                                NSLog("AUPK: startGame: \(startGame)")
                            case .gameData(let gameData):
                                for message in gameData.messages {
                                    switch message.payload {
                                    case .data(let data):
                                        break
                                    case .rpc(let rpc):
                                        switch rpc.payload {
                                        case .syncSettings(_):
                                            break
                                        case .setInfected(let setInfected):
                                            NSLog("AUPK: setInfected: \(setInfected)")
                                        case .setName(let setName):
                                            break
                                        case .setColor(let setColor):
                                            break
                                        case .setHat(let setHat):
                                            break
                                        case .setSkin(_):
                                            break
                                        case .murderPlayer(let murderPlayer):
                                            NSLog("AUPK: murderPlayer: [\(rpc.senderNetId)] \(rpc.rpcCallId) killed \(murderPlayer)")
                                        case .startMeeting(_):
                                            break
                                        case .sendChatNote(_):
                                            break
                                        case .setPet(_):
                                            break
                                        case .setStartCounter(_):
                                            break
                                        case .close:
                                            break
                                        case .votingComplete(_):
                                            break
                                        case .castVote(_):
                                            break
                                        case .setTasks(_):
                                            break
                                        case .updateGameData(_):
                                            break
                                        }
                                    case .spawn(let spawn):
                                        break
                                    case .despawn(let despawn):
                                        break
                                    }
                                }
                            case .endGame(let endGame):
                                NSLog("AUPK: endGame: \(endGame)")
                            case .redirect(let redirect):
                                NSLog("AUPK: redirect: \(redirect)")
                            case .reselectServer(let reselectServer):
                                NSLog("AUPK: reselectServer: \(reselectServer)")
                            }
                        }
                    case .hello(let hello):
                        break
                    case .disconnect:
                        NSLog("AUPK: disconnect")
                    case .acknowledgement(let acknowledgement):
                        break
                    case .fragment:
                        break
                    case .ping(let ping):
                        break
                    }
                }

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
