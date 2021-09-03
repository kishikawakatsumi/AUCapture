import Foundation

struct IPPacket {
    var version: IPVersion = .ipv4
    var headerLength: UInt8 = 20
    var typeOfService: UInt8 = 0
    var length: UInt16
    var id: UInt16
    var offset: UInt16 = 0
    var timeToLive: UInt8 = 64
    var proto: Protocol
    var checksum: UInt16

    var source: String { sourceAddr.asString }
    private var sourceAddr: in_addr
    var destination: String { destAddr.asString }
    private var destAddr: in_addr

    var sourcePort: UInt16
    var destinationPort: UInt16

    var packetData: Data
    var payload: Data

    init(proto: Protocol, source: String, destination: String, sourcePort: UInt16, destinationPort: UInt16, payload: Data) {
        self.proto = proto

        sourceAddr = in_addr(string: source)
        destAddr = in_addr(string: destination)

        self.sourcePort = sourcePort
        self.destinationPort = destinationPort

        id = 0
        checksum = 0

        let bytesLength = payload.count + 8
        packetData = Data(count: Int(headerLength) + bytesLength)
        self.payload = payload

        length = UInt16(packetData.count)

        // set header
        setPayloadWithUInt8(headerLength / 4 + version.rawValue << 4, at: 0)
        setPayloadWithUInt8(typeOfService, at: 1)
        setPayloadWithUInt16(length, at: 2)
        setPayloadWithUInt16(id, at: 4)
        setPayloadWithUInt16(offset, at: 6)
        setPayloadWithUInt8(timeToLive, at: 8)
        setPayloadWithUInt8(proto.rawValue, at: 9)

        // clear checksum bytes
        resetPayloadAt(10, length: 2)

        setPayloadWithUInt32(sourceAddr.s_addr, at: 12, swap: false)
        setPayloadWithUInt32(destAddr.s_addr, at: 16, swap: false)

        // let TCP or UDP packet build
        buildSegment(computePseudoHeaderChecksum())

        setPayloadWithUInt16(Checksum.computeChecksum(packetData, from: 0, to: Int(headerLength)), at: 10, swap: false)
    }

    init?(_ packet: Data) {
        packetData = packet
        let buffer = ByteBuffer(packet, littleEndian: false)

        let vhl = buffer.read(UInt8.self)
        guard let version = IPVersion(rawValue: vhl >> 4) else { return nil }
        self.version = version

        headerLength = vhl & 0x0F * 4
        guard buffer.availableBytes >= headerLength else { return nil }

        typeOfService = buffer.read(UInt8.self)

        length = buffer.read(UInt16.self)
        guard buffer.data.count == length else { return nil }

        id = buffer.read(UInt16.self)
        offset = buffer.read(UInt16.self)
        timeToLive = buffer.read(UInt8.self)

        guard let proto = Protocol(rawValue: buffer.read(UInt8.self)) else { return nil }
        self.proto = proto

        checksum = buffer.read(UInt16.self)

        sourceAddr = buffer.read(in_addr.self)
        destAddr = buffer.read(in_addr.self)

        switch proto {
        case .tcp:
            payload = buffer.data[Int(headerLength)..<packetData.count]
        case .udp:
            payload = buffer.data[Int(headerLength) + 8..<packetData.count]
        case .icmp:
            payload = buffer.data[Int(headerLength)..<packetData.count]
        }

        sourcePort = buffer.read(UInt16.self)
        destinationPort = buffer.read(UInt16.self)
    }

    private mutating func setPayloadWithUInt8(_ value: UInt8, at: Int) {
        var v = value
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at + 1, with: $0)
        }
    }

    private mutating func setPayloadWithUInt16(_ value: UInt16, at: Int, swap: Bool = true) {
        var v: UInt16
        if swap {
            v = CFSwapInt16HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at + 2, with: $0)
        }
    }

    private mutating func setPayloadWithUInt32(_ value: UInt32, at: Int, swap: Bool = true) {
        var v: UInt32
        if swap {
            v = CFSwapInt32HostToBig(value)
        } else {
            v = value
        }
        withUnsafeBytes(of: &v) {
            packetData.replaceSubrange(at..<at+4, with: $0)
        }
    }

    private mutating func setPayloadWithData(_ data: Data, at: Int, length: Int? = nil, from: Int = 0) {
        var length = length
        if length == nil {
            length = data.count - from
        }
        packetData.replaceSubrange(at..<at+length!, with: data)
    }

    private mutating func resetPayloadAt(_ at: Int, length: Int) {
        packetData.resetBytes(in: at..<at+length)
    }

    private func computePseudoHeaderChecksum() -> UInt32 {
        var result: UInt32 = 0
        result += sourceAddr.s_addr >> 16 + sourceAddr.s_addr & 0xffff
        result += destAddr.s_addr >> 16 + destAddr.s_addr & 0xffff
        result += UInt32(proto.rawValue) << 8
        switch proto {
        case .udp:
            result += CFSwapInt32(UInt32(payload.count + 8))
        default:
            break
        }
        return result
    }

    private mutating func buildSegment(_ pseudoHeaderChecksum: UInt32) {
        let offset = Int(headerLength)

        var sourcePort = sourcePort.bigEndian
        withUnsafeBytes(of: &sourcePort) {
            packetData.replaceSubrange(offset..<(offset + 2), with: $0)
        }
        var destinationPort = destinationPort.bigEndian
        withUnsafeBytes(of: &destinationPort) {
            packetData.replaceSubrange(offset + 2..<(offset + 4), with: $0)
        }

        var length = NSSwapHostShortToBig(UInt16(payload.count + 8))
        withUnsafeBytes(of: &length) {
            packetData.replaceSubrange(offset + 4..<offset + 6, with: $0)
        }

        packetData.replaceSubrange(offset + 8..<offset + 8 + payload.count, with: payload)

        packetData.resetBytes(in: offset + 6..<offset + 8)
        var checksum = Checksum.computeChecksum(packetData, from: offset, to: nil, withPseudoHeaderChecksum: pseudoHeaderChecksum)
        withUnsafeBytes(of: &checksum) {
            packetData.replaceSubrange(offset + 6..<offset + 8, with: $0)
        }
    }
}

extension IPPacket: CustomStringConvertible {
    var description: String {
        "Version: \(version.rawValue), Length: \(length), TTL: \(timeToLive), Protocol: \(proto), Source: \(source):\(sourcePort), Dest: \(destination):\(destinationPort), Payload: \(payload.hex)"
    }
}

public enum IPVersion: UInt8, CustomStringConvertible {
    case ipv4 = 4, ipv6 = 6
    public var description: String { "\(rawValue)" }
}

enum Protocol: UInt8, CustomStringConvertible {
    case tcp = 6, udp = 17, icmp = 1

    var description: String {
        switch self {
        case .tcp:
            return "TCP"
        case .udp:
            return "UDP"
        case .icmp:
            return "ICMP"
        }
    }
}

extension in_addr {
    init(string: String) {
        self.init()
        var buf = in_addr(s_addr: 0)
        inet_pton(AF_INET, string, &buf)
        s_addr = buf.s_addr
    }

    var asString: String {
        let len = Int(INET_ADDRSTRLEN) + 2
        var buf = [CChar](repeating: 0, count: len)
        var selfCopy = self
        let cs = inet_ntop(AF_INET, &selfCopy, &buf, socklen_t(len))
        return String(validatingUTF8: cs!)!
    }
}

protocol BinaryConvertible {
    static func +(lhs: Data, rhs: Self) -> Data
    static func +=(lhs: inout Data, rhs: Self)
}

extension BinaryConvertible {
    static func +(lhs: Data, rhs: Self) -> Data {
        var value = rhs
        let data = withUnsafePointer(to: &value) {
            Data(buffer: UnsafeBufferPointer(start: $0, count: 1))
        }
        return lhs + data
    }

    static func +=(lhs: inout Data, rhs: Self) {
        lhs = lhs + rhs
    }
}

extension UInt8: BinaryConvertible {}
extension UInt16: BinaryConvertible {}
extension UInt32: BinaryConvertible {}
extension UInt64: BinaryConvertible {}
extension Int8: BinaryConvertible {}
extension Int16: BinaryConvertible {}
extension Int32: BinaryConvertible {}
extension Int64: BinaryConvertible {}
extension Int: BinaryConvertible {}
