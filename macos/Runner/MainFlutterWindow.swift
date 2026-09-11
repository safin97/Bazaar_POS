import Cocoa
import FlutterMacOS
import Sparkle

class MainFlutterWindow: NSWindow {
  private var updateChannel: FlutterMethodChannel?
  private var updaterController: SPUStandardUpdaterController?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    let channel = FlutterMethodChannel(
      name: "Bazaar_POS/app_updates",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    updateChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return result(FlutterMethodNotImplemented) }
      let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
      let configured = Data(base64Encoded: key)?.count == 32
      switch call.method {
      case "capabilities":
        result(configured ? "macos" : "none")
      case "installUpdate":
        guard configured else {
          return result(FlutterError(code: "updateInstallerUnavailable", message: nil, details: nil))
        }
        if self.updaterController == nil {
          self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        }
        guard let controller = self.updaterController, controller.updater.canCheckForUpdates else {
          return result(FlutterError(code: "updateBusy", message: nil, details: nil))
        }
        controller.checkForUpdates(nil)
        // Sparkle owns downloading, signature verification, installation and relaunch.
        // Opening this dialog does not mean the update has been installed.
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
