import UIKit
import Combine
import NetworkExtension

final class ViewController: UITableViewController {
    private var manager: NETunnelProviderManager?
    private var cancellables = [AnyCancellable]()

    @IBOutlet private var toggle: UISwitch!
    @IBOutlet private var spinner: UIActivityIndicatorView!
    @IBOutlet private var statusLabel: UILabel!

    @IBOutlet private var launchAmongUsCell: UITableViewCell!
    @IBOutlet private var launchAmongUsLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        launchAmongUsCell.isUserInteractionEnabled = false
        launchAmongUsLabel.textColor = .systemGray3

        NotificationCenter.default.publisher(for: .NEVPNStatusDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let status = self?.manager?.connection.status else {
                    return
                }

                self?.launchAmongUsCell.isUserInteractionEnabled = false
                self?.launchAmongUsLabel.textColor = .systemGray3

                switch status {
                case .invalid:
                    self?.toggle.isEnabled = true
                    self?.toggle.isOn = false

                    self?.spinner.stopAnimating()
                    self?.statusLabel.text = "Invalid"
                case .disconnected:
                    self?.toggle.isEnabled = true
                    self?.toggle.isOn = false

                    self?.spinner.stopAnimating()
                    self?.statusLabel.text = "Disconnected"
                case .connecting:
                    self?.toggle.isEnabled = false
                    self?.toggle.isOn = true

                    self?.spinner.startAnimating()
                    self?.statusLabel.text = "Connecting..."
                case .connected:
                    self?.toggle.isEnabled = true
                    self?.toggle.isOn = true

                    self?.spinner.stopAnimating()
                    self?.statusLabel.text = "Connected"
                case .reasserting:
                    self?.toggle.isEnabled = false

                    self?.spinner.startAnimating()
                    self?.statusLabel.text = "Reasserting..."
                case .disconnecting:
                    self?.toggle.isEnabled = false

                    self?.spinner.startAnimating()
                    self?.statusLabel.text = "Disconnecting..."
                @unknown default:
                    self?.toggle.isEnabled = true
                    self?.toggle.isOn = false

                    self?.spinner.stopAnimating()
                    self?.statusLabel.text = "Unknown"
                }
            }
            .store(in: &cancellables)
    }

    private func installProfile() {
        NETunnelProviderManager.loadAllFromPreferences { [self] (managers, error) in
            if let error = error {
                presentError(error)
                return
            }

            self.manager = managers?.first ?? NETunnelProviderManager()

            self.manager?.loadFromPreferences { [self] (error) in
                if let error = error {
                    presentError(error)
                    return
                }

                let tunnelProtocol = NETunnelProviderProtocol()
                tunnelProtocol.serverAddress = "localhost"
                tunnelProtocol.providerBundleIdentifier = "com.kishikawakatsumi.AUCapture.PacketTunnel"
                tunnelProtocol.disconnectOnSleep = false

                self.manager?.protocolConfiguration = tunnelProtocol
                self.manager?.localizedDescription = "AUCapture"
                self.manager?.isEnabled = true

                if let status = self.manager?.connection.status {
                    self.toggle.isOn = status == .connected
                }

                self.manager?.saveToPreferences { (error) in
                    if let error = error {
                        presentError(error)
                        return
                    }

                    self.manager?.loadFromPreferences { (error) in
                        if let error = error {
                            presentError(error)
                            return
                        }

                        self.startVPNTunnel()
                    }
                }
            }
        }
    }

    @IBAction
    private func toggle(_ sender: UISwitch) {
        if sender.isOn {
            installProfile()
        } else {
            manager?.connection.stopVPNTunnel()
        }
    }

    private func startVPNTunnel() {
        do {
            try self.manager?.connection.startVPNTunnel()
        } catch {
            presentError(error)
        }
    }

    private func presentError(_ error: Error) {
        let alertController = UIAlertController(title: String(describing: type(of: error)), message: error.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: .default) { _ in
            alertController.dismiss(animated: true)
        })
        present(alertController, animated: true)
    }

    private func launchDiscord() {
        launchApp(with: "com.hammerandchisel.discord")
    }

    private func launchAmongUs() {
        launchApp(with: "com.innersloth.amongus")
    }

    @discardableResult
    private func launchApp(with bundleIdentifier: String) -> Bool {
        guard let obj = objc_getClass(["Workspace", "Application", "LS"].reversed().joined()) as? NSObject else { return false }
        let workspace = obj.perform(Selector((["Workspace", "default"].reversed().joined())))?.takeUnretainedValue() as? NSObject
        return workspace?.perform(Selector(([":", "ID", "Bundle", "With", "Application", "open"].reversed().joined())), with: bundleIdentifier) != nil
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath {
        case [1, 0]:
            launchAmongUs()
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
