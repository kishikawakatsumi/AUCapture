import Foundation

enum AppGroup {
    static let identifier = "group.com.kishikawakatsumi.AUCapture"
    static let container: URL = {
        guard let container = FileManager().containerURL(forSecurityApplicationGroupIdentifier: identifier) else {
            preconditionFailure()
        }
        return container
    }()
}
