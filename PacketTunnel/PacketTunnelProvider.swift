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
        packetFlow.readPacketObjects { [weak self] (packets) in
            defer { self?.localPacketsToServer() }
            guard let self = self else { return }

            packets.forEach { (packet) in
                if let ipPacket = IPPacket(packet.data) {
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
        NSLog("SEND: \(key) \(packet.payload.hex)")

        let port = packet.destinationPort
        if port == 22023 || port == 22123 || port == 22223 || port == 22323 ||
            port == 22423 || port == 22523 || port == 22623 || port == 22723 ||
            port == 22823 || port == 22923 {
            if packet.payload.hex.hasPrefix("01") {
                NSLog("handleEvent: => \(packet.payload.hex)")
            }
        }

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

                if let auPacket = PacketParser.parse(packet: data) {
                    handleEvent(packet: auPacket, data: data)
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

private func handleEvent(packet: Packet, data: Data) {
    switch packet {
    case .reliable(let reliable):
        NSLog("handleEvent: \(packet) \(data.hex)")
        for message in reliable.messages {
            switch message.payload {
            case .hostGame(let hostGame):
                NSLog("Host Game: \(hostGame)")
            case .joinGame(let joinGame):
                NSLog("Join Game: \(joinGame.gameCode)")
            case .startGame:
                NSLog("Start Game")
            case .gameData(let gameData):
                handleGameData(gameData: gameData)
            case .endGame(let endGame):
                NSLog("End Game: \(endGame)")
            case .redirect(_):
                break
            case .reselectServer(_):
                break
            }
        }
        break
    case .disconnect:
        break
    case .normal, .hello, .acknowledgement, .fragment, .ping:
        break
    }
}

private func handleGameData(gameData: GameData) {
    var despawning = false

    for message in gameData.messages {
        switch message.payload {
        case .data:
            break
        case .rpc(let rpc):
            switch rpc.payload {
            case .syncSettings:
                break
            case .setInfected(let infected):
//                var playerInfos = [ImmutablePlayer]()
//                for player in GameStateCapture.shared.players {
//                    playerInfos.append(ImmutablePlayer(name: player.name, isImpostor: infected.impostors.contains(player.id)))
//                }
//                GameStateCapture.shared.playerInfos = playerInfos
                break
            case .setName:
                break
            case .setColor, .setHat, .setSkin:
                break
            case .startMeeting:
                break
            case .sendChatNote, .setPet, .setStartCounter:
                break
            case .close:
                break
            case .votingComplete:
                break
            case .castVote, .setTasks:
                break
            case .updateGameData(let gameData):
                let players = gameData.map { (playerData) in
                    let flags = playerData.flags
                    let isDisconnected = (flags & 1) != 0
                    let isDead = (flags & 4) != 0

                    NSLog("Player Data: \(playerData)")
                }

//                if despawning {
//                    for player in GameStateCapture.shared.players {
//                        if !players.contains(player) {
//                            GameEventManager.shared.changeState(
//                                event: PlayerChangedEvent(
//                                    action: .left,
//                                    name: player.name,
//                                    isDead: player.isDead,
//                                    isDisconnected: player.isDisconnected,
//                                    color: player.color
//                                )
//                            )
//                        }
//                    }
//                } else {
//                    for player in players {
//                        if GameStateCapture.shared.players.contains(player) {
//                            GameEventManager.shared.changeState(
//                                event: PlayerChangedEvent(
//                                    action: .changedColor,
//                                    name: player.name,
//                                    isDead: player.isDead,
//                                    isDisconnected: player.isDisconnected,
//                                    color: player.color
//                                )
//                            )
//                        } else {
//                            GameEventManager.shared.changeState(
//                                event: PlayerChangedEvent(
//                                    action: .joined,
//                                    name: player.name,
//                                    isDead: player.isDead,
//                                    isDisconnected: player.isDisconnected,
//                                    color: player.color
//                                )
//                            )
//                        }
//                    }
//                }
//
//                GameStateCapture.shared.players = players
            case .murderPlayer(let murderPlayer):
                NSLog("Murder Player: \(murderPlayer)")
            }
        case .spawn(let spawn):
            switch spawn.spawnType {
            case .shipStatus:
                break
            case .meetingHud:
                break
            case .lobbyBehaviour:
                break
            case .gameData:
                break
            case .playerControl:
                break
            case .headquarters:
                break
            case .planetMap:
                break
            case .aprilShipStatus:
                break
            }
        case .despawn:
            despawning = true
        }
    }
}
