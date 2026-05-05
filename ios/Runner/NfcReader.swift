import CoreNFC
import Flutter
import UIKit

/// Native iOS NFC reader.
///
/// Replaces `flutter_nfc_kit` on iOS to avoid Flutter framework issue #168228
/// (`registrar` is nil when Swift plugins register on iOS 26 + ProMotion).
/// We register this object ourselves from `AppDelegate.application(_:didFinishLaunchingWithOptions:)`,
/// AFTER `super.application(...)` returns and the engine is fully initialised, so the
/// `FlutterBinaryMessenger` we pass in is always non-nil.
///
/// Channel name MUST match the one in `lib/services/nfc_service.dart`.
@available(iOS 13.0, *)
final class NfcReader: NSObject, NFCTagReaderSessionDelegate {
  static let channelName = "com.adam.dosevault/nfc"

  private static var sharedInstance: NfcReader?

  private weak var channel: FlutterMethodChannel?
  private var session: NFCTagReaderSession?
  private var pendingResult: FlutterResult?

  /// Register the channel with the given messenger. Idempotent.
  static func register(with messenger: FlutterBinaryMessenger) {
    if sharedInstance != nil { return }
    let instance = NfcReader()
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak instance] call, result in
      instance?.handle(call, result: result)
    }
    instance.channel = channel
    sharedInstance = instance
  }

  // MARK: - Method handling

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getNFCAvailability":
      handleAvailability(result: result)
    case "poll":
      handlePoll(args: call.arguments as? [String: Any] ?? [:], result: result)
    case "finish":
      handleFinish(args: call.arguments as? [String: Any] ?? [:], result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleAvailability(result: @escaping FlutterResult) {
    if NFCTagReaderSession.readingAvailable {
      result("available")
    } else {
      result("not_supported")
    }
  }

  private func handlePoll(args: [String: Any], result: @escaping FlutterResult) {
    guard NFCTagReaderSession.readingAvailable else {
      result(FlutterError(code: "not_supported",
                          message: "NFC is not supported on this device.",
                          details: nil))
      return
    }
    if session != nil {
      result(FlutterError(code: "session_active",
                          message: "An NFC session is already running.",
                          details: nil))
      return
    }

    pendingResult = result

    // Match flutter_nfc_kit's default polling so we read every tag UID.
    let pollingOption: NFCTagReaderSession.PollingOption = [.iso14443, .iso15693, .iso18092]
    let session = NFCTagReaderSession(pollingOption: pollingOption,
                                      delegate: self,
                                      queue: nil)
    if let alertMessage = args["iosAlertMessage"] as? String, !alertMessage.isEmpty {
      session?.alertMessage = alertMessage
    }
    self.session = session
    session?.begin()
  }

  private func handleFinish(args: [String: Any], result: @escaping FlutterResult) {
    if let session = session {
      let alertMessage = args["iosAlertMessage"] as? String
      let errorMessage = args["iosErrorMessage"] as? String
      if let errorMessage = errorMessage, !errorMessage.isEmpty {
        session.invalidate(errorMessage: errorMessage)
      } else {
        if let alertMessage = alertMessage, !alertMessage.isEmpty {
          session.alertMessage = alertMessage
        }
        session.invalidate()
      }
      self.session = nil
    }

    if let pending = pendingResult {
      pending(FlutterError(code: "session_cancelled",
                           message: "NFC session was cancelled.",
                           details: nil))
      pendingResult = nil
    }
    result(nil)
  }

  // MARK: - NFCTagReaderSessionDelegate

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {}

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    defer {
      self.session = nil
      self.pendingResult = nil
    }
    guard let pending = pendingResult else { return }

    if let nfcError = error as? NFCReaderError {
      switch nfcError.errorCode {
      case NFCReaderError.Code.readerSessionInvalidationErrorUserCanceled.rawValue:
        pending(FlutterError(code: "session_cancelled",
                             message: "User cancelled the NFC session.",
                             details: nfcError.localizedDescription))
      case NFCReaderError.Code.readerSessionInvalidationErrorSessionTimeout.rawValue:
        pending(FlutterError(code: "session_timeout",
                             message: "NFC session timed out.",
                             details: nfcError.localizedDescription))
      default:
        pending(FlutterError(code: "session_error",
                             message: "NFC error.",
                             details: nfcError.localizedDescription))
      }
    } else {
      pending(FlutterError(code: "session_error",
                           message: "NFC error.",
                           details: error.localizedDescription))
    }
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let firstTag = tags.first else {
      session.restartPolling()
      return
    }
    session.connect(to: firstTag) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        self.pendingResult?(FlutterError(code: "connect_failed",
                                         message: "Could not connect to tag.",
                                         details: error.localizedDescription))
        self.pendingResult = nil
        session.invalidate(errorMessage: "Could not connect to tag.")
        self.session = nil
        return
      }

      let payload: [String: Any] = [
        "id": NfcReader.uidString(for: firstTag),
        "type": NfcReader.typeString(for: firstTag),
        "standard": NfcReader.standardString(for: firstTag),
      ]
      self.pendingResult?(payload)
      self.pendingResult = nil
    }
  }

  // MARK: - Helpers

  private static func uidString(for tag: NFCTag) -> String {
    let bytes: Data
    switch tag {
    case let .iso7816(t): bytes = t.identifier
    case let .miFare(t): bytes = t.identifier
    case let .iso15693(t): bytes = t.identifier
    case let .feliCa(t): bytes = t.currentIDm
    @unknown default: return ""
    }
    return bytes.map { String(format: "%02hhX", $0) }.joined()
  }

  private static func typeString(for tag: NFCTag) -> String {
    switch tag {
    case .iso7816: return "iso7816"
    case .miFare: return "mifare"
    case .iso15693: return "iso15693"
    case .feliCa: return "felica"
    @unknown default: return "unknown"
    }
  }

  private static func standardString(for tag: NFCTag) -> String {
    switch tag {
    case .iso7816: return "ISO 14443"
    case .miFare: return "ISO 14443 (Type A)"
    case .iso15693: return "ISO 15693"
    case .feliCa: return "ISO 18092 (FeliCa)"
    @unknown default: return "unknown"
    }
  }
}
