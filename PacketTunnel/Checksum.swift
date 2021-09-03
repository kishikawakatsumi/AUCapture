import Foundation

class Checksum {
    static func computeChecksum(_ data: Data, from start: Int = 0, to end: Int? = nil, withPseudoHeaderChecksum initChecksum: UInt32 = 0) -> UInt16 {
        return toChecksum(computeChecksumUnfold(data, from: start, to: end, withPseudoHeaderChecksum: initChecksum))
    }

    static func validateChecksum(_ payload: Data, from start: Int = 0, to end: Int? = nil) -> Bool {
        let cs = computeChecksumUnfold(payload, from: start, to: end)
        return toChecksum(cs) == 0
    }

    static func computeChecksumUnfold(_ data: Data, from start: Int = 0, to end: Int? = nil, withPseudoHeaderChecksum initChecksum: UInt32 = 0) -> UInt32 {
        let buffer = ByteBuffer(data)
        _ = buffer.read(Data.self, count: start)
        var result: UInt32 = initChecksum
        var end = end
        if end == nil {
            end = data.count
        }
        var counter = 0
        while buffer.position + 2 <= end! {
            let value = buffer.read(UInt16.self)
            result += UInt32(value)
            counter += 1
        }
        print(counter)

        if buffer.position != end! {
            // data is of odd size
            // Intel and ARM are both litten endian
            // so just add it
            let value = buffer.read(UInt8.self)
            result += UInt32(value)
        }
        return result
    }

    static func toChecksum(_ checksum: UInt32) -> UInt16 {
        var result = checksum
        while (result) >> 16 != 0 {
            result = result >> 16 + result & 0xFFFF
        }
        return ~UInt16(result)
    }
}
