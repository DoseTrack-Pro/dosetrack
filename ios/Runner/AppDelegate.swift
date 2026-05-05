import Flutter
import UIKit

/// Minimal AppDelegate.
///
/// We deliberately do NOT call `GeneratedPluginRegistrant.register(with: self)` here.
/// Plugin registration is owned by `RunnerViewController.init(coder:)` in
/// `RunnerViewController.swift`, which runs AFTER the implicit `FlutterEngine`
/// is constructed. That guarantees every Swift plugin's `register(with:)` gets
/// a non-nil registrar and avoids Flutter framework issue #168228 (the
/// `swift_getObjectType` crash that took down builds 1.0.0 (2)–(5) inside
/// `flutter_nfc_kit` on iOS 26 + iPhone 17 Pro).
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
