import UIKit
import AVFoundation
import AmongUsProtocol

@main
class AppDelegate: UIResponder, UIApplicationDelegate, FileWatcherDelegate, UNUserNotificationCenterDelegate {
    var fileWatcher: FileWatcher?
    var audioPlayer: AVAudioPlayer?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        try! AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        self.audioPlayer = try! AVAudioPlayer(
            contentsOf: Bundle.main.url(forResource: "silence", withExtension: "wav")!
        )
        self.audioPlayer?.numberOfLoops = -1
        self.audioPlayer?.volume = 0.00;
        self.audioPlayer?.play()

        let container = AppGroup.container
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.coordinate(writingItemAt: container, options: [], error: nil) { (directory) in
            let file = directory.appendingPathComponent("capture_state")
            let fileManager = FileManager()
            fileManager.createFile(atPath: file.path, contents: Data(), attributes: nil)

            fileWatcher = try? FileWatcher(url: file)
            fileWatcher?.delegate = self
        }

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func fileWatcherDidChange(fileWatcher: FileWatcher) {
        let container = AppGroup.container
        let file = container.appendingPathComponent("capture_state")
        let fileCoordinator = NSFileCoordinator()
        fileCoordinator.coordinate(readingItemAt: file, options: [], error: nil) { (file) in
            guard let text = try? String(contentsOf: file) else { return }
            print(text)
        }
    }
}
