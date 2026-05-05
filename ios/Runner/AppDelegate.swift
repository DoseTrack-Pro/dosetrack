import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Register our native NFC method channel alongside the standard Flutter
    // plugins. We use the same registrar mechanism so the binary messenger
    // is wired through `FlutterAppDelegate`'s plugin registry (i.e. the same
    // engine `GeneratedPluginRegistrant` just used).
    if #available(iOS 13.0, *),
       let registrar = self.registrar(forPlugin: "DoseVaultNfcReader") {
      NfcReader.register(with: registrar.messenger())
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
