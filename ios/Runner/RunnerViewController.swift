import Flutter
import UIKit

/// Custom FlutterViewController subclass that owns plugin registration.
///
/// We register every Flutter plugin (and our own native NFC channel) here, AFTER
/// `super.init(coder:)` has finished setting up `self.engine` and the binary
/// messenger. Doing it at this point guarantees the registrar handed to each
/// plugin's Swift `register(with:)` is non-nil — that's what was crashing the
/// app at launch on iOS 26 + iPhone 17 Pro / ProMotion (Flutter framework
/// issue #168228; manifested in builds 1.0.0 (2)–(5) inside `flutter_nfc_kit`).
///
/// The storyboard's initial view controller (`Main.storyboard`) points at this
/// class via `customClass="RunnerViewController"`.
class RunnerViewController: FlutterViewController {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    registerNativeIntegrations()
  }

  override init(
    engine: FlutterEngine,
    nibName: String?,
    bundle nibBundle: Bundle?
  ) {
    super.init(engine: engine, nibName: nibName, bundle: nibBundle)
    registerNativeIntegrations()
  }

  override init(
    project projectOrNil: FlutterDartProject?,
    nibName: String?,
    bundle nibBundle: Bundle?
  ) {
    super.init(project: projectOrNil, nibName: nibName, bundle: nibBundle)
    registerNativeIntegrations()
  }

  private func registerNativeIntegrations() {
    // 1) Standard Flutter plugins. By the time we get here `self.engine` is
    //    a fully constructed `FlutterEngine`, so every plugin's registrar is
    //    backed by a real binary messenger.
    if let engine = engine {
      GeneratedPluginRegistrant.register(with: engine)
    }

    // 2) Our native NFC method channel — replaces flutter_nfc_kit on iOS.
    if #available(iOS 13.0, *) {
      NfcReader.register(with: binaryMessenger)
    }
  }
}
