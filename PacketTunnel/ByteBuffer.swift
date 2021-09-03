import Foundation

class ByteBuffer {
    let data: Data
    let littleEndian: Bool

    private var offset = 0
    var position: Int { offset }
    var availableBytes: Int { data.count - offset }

    init(_ data: Data, littleEndian: Bool = true) {
        self.data = data
        self.littleEndian = littleEndian
    }

    func read<T>(_ type: T.Type) -> T {
        let size = MemoryLayout<T>.size
        let value = data[offset..<(offset + size)].to(type: type)
        offset += size
        return value
    }

    func read<T: BinaryReadable>(_ type: T.Type) -> T {
        let size = MemoryLayout<T>.size
        let value = data[offset..<(offset + size)].to(type: type)
        offset += size
        return littleEndian ? value.littleEndian : value.bigEndian
    }

    func read(_ type: Data.Type, count: Int) -> Data {
        let value = data[offset..<(offset + count)]
        offset += count
        return Data(value)
    }
}

public protocol BinaryReadable {
    var littleEndian: Self { get }
    var bigEndian: Self { get }
}
extension UInt8: BinaryReadable {
    public var littleEndian: UInt8 { return self }
    public var bigEndian: UInt8 { return self }
}
extension UInt16: BinaryReadable {}
extension UInt32: BinaryReadable {}
extension UInt64: BinaryReadable {}
