import Foundation

protocol FileWatcherDelegate: AnyObject {
    func fileWatcherDidChange(fileWatcher: FileWatcher)
}

final class FileWatcher {
    let url: URL

    let fileHandle: FileHandle
    let source: DispatchSourceFileSystemObject

    weak var delegate: FileWatcherDelegate?

    init(url: URL) throws {
        self.url = url
        self.fileHandle = try FileHandle(forReadingFrom: url)

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileHandle.fileDescriptor,
            eventMask: .extend,
            queue: DispatchQueue.main
        )

        source.setEventHandler {
            let event = self.source.data
            self.process(event: event)
        }

        source.setCancelHandler {
            try? self.fileHandle.close()
        }

        _ = try? fileHandle.seekToEnd()
        source.resume()
    }

    deinit {
        source.cancel()
    }

    func process(event: DispatchSource.FileSystemEvent) {
        guard event.contains(.extend) else {
            return
        }
        delegate?.fileWatcherDidChange(fileWatcher: self)
    }
}
