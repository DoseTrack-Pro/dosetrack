import CoreNFC
import Flutter
import UIKit

/// Native iOS NFC reader.
///
/// Replaces `flutter_nfc_kit` on iOS so we own the entire NFC pipeline.
/// Channel name MUST match `lib/services/nfc_service.dart` and `NfcReader.kt`.
///
/// Error contract (for the Flutter side to switch on):
///   * `session_cancelled`   — user tapped Cancel on the system NFC sheet
///   * `session_timeout`     — iOS' 60s session timer expired
///   * `session_terminated`  — iOS reported `terminatedUnexpectedly` (202)
///   * `system_busy`         — iOS reported `systemIsBusy` (203)
///   * `radio_disabled`      — NFC radio is turned off
///   * `unsupported_feature` — device doesn't support tag reading
///   * `security_violation`  — entitlement / signing problem
///   * `connect_failed`      — detected tag but couldn't connect to it
///   * `session_error`       — anything else
///
/// `details` is always a `[String: Any]` map with the underlying NSError code,
/// domain, and `localizedDescription` so we can diagnose new failure modes
/// from the Flutter `debugPrint` logs.
@available(iOS 13.0, *)
final class NfcReader: NSObject, NFCTagReaderSessionDelegate {
  static let channelName = "com.adam.dosevault/nfc"

  private static var sharedInstance: NfcReader?

  private var channel: FlutterMethodChannel?
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
    // Strong reference: the channel keeps the call handler alive, but we also
    // need a strong link from the instance back to the channel so it survives
    // for the lifetime of the app.
    instance.channel = channel
    sharedInstance = instance
    NSLog("[NfcReader] Registered on channel \(channelName)")
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
      // The previous session is still alive — likely the dashboard scan modal
      // was just closed and we beat its cleanup. Report as "busy" so the Dart
      // side can show a retry hint.
      NSLog("[NfcReader] poll() rejected: a session is already active.")
      result(FlutterError(code: "system_busy",
                          message: "An NFC session is already running.",
                          details: nil))
      return
    }

    pendingResult = result

    // Polling options.
    //
    // We deliberately exclude `.iso18092` (FeliCa). Adding that option requires
    // the `com.apple.developer.nfc.readersession.felica.systemcodes` entitlement
    // — which we don't have, don't need (FeliCa is Japan-only Suica/Pasmo/etc.),
    // and which our App Store provisioning profile isn't authorised for.
    //
    // With `.iso18092` present, iOS rejected `session.begin()` with
    // NFCError code=2 "Missing required entitlement" within ~1s of opening
    // the sheet on iOS 26 (builds 1.0.0 (7)–(10)).
    //
    // `.iso14443` covers NTAG / MIFARE / ISO 7816 smart cards (the vast majority
    // of NFC stickers / cards). `.iso15693` covers vicinity tags (ICODE etc).
    // Together that's every tag the peptide-tracker workflow realistically uses.
    let pollingOption: NFCTagReaderSession.PollingOption = [.iso14443, .iso15693]
    guard let newSession = NFCTagReaderSession(pollingOption: pollingOption,
                                               delegate: self,
                                               queue: nil) else {
      NSLog("[NfcReader] NFCTagReaderSession init returned nil.")
      pendingResult = nil
      result(FlutterError(code: "session_error",
                          message: "Could not start an NFC session.",
                          details: nil))
      return
    }

    if let alertMessage = args["iosAlertMessage"] as? String, !alertMessage.isEmpty {
      newSession.alertMessage = alertMessage
    }
    self.session = newSession
    NSLog("[NfcReader] poll() — beginning session.")
    newSession.begin()
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

  func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) {
    NSLog("[NfcReader] Session became active.")
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
    let nsError = error as NSError
    NSLog("[NfcReader] Session invalidated: domain=\(nsError.domain) " +
          "code=\(nsError.code) localized=\(error.localizedDescription)")

    defer {
      self.session = nil
      self.pendingResult = nil
    }
    guard let pending = pendingResult else { return }

    let (code, message) = Self.mapError(error)
    let details: [String: Any] = [
      "errorCode": nsError.code,
      "errorDomain": nsError.domain,
      "localizedDescription": error.localizedDescription,
    ]
    pending(FlutterError(code: code, message: message, details: details))
  }

  func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {
    guard let firstTag = tags.first else {
      session.restartPolling()
      return
    }
    session.connect(to: firstTag) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        let nsError = error as NSError
        NSLog("[NfcReader] connect() failed: code=\(nsError.code) " +
              "localized=\(error.localizedDescription)")
        let details: [String: Any] = [
          "errorCode": nsError.code,
          "errorDomain": nsError.domain,
          "localizedDescription": error.localizedDescription,
        ]
        self.pendingResult?(FlutterError(code: "connect_failed",
                                         message: "Could not connect to tag.",
                                         details: details))
        self.pendingResult = nil
        session.invalidate(errorMessage: "Could not connect to tag.")
        self.session = nil
        return
      }

      let uid = Self.uidString(for: firstTag)
      NSLog("[NfcReader] Tag detected — uid=\(uid) type=\(Self.typeString(for: firstTag))")
      let payload: [String: Any] = [
        "id": uid,
        "type": Self.typeString(for: firstTag),
        "standard": Self.standardString(for: firstTag),
      ]
      self.pendingResult?(payload)
      self.pendingResult = nil
    }
  }

  // MARK: - Helpers

  /// Map an iOS `NFCReaderError` to a stable `(code, message)` pair shared
  /// with the Dart side. Keep these strings in sync with `_exceptionFor` in
  /// `lib/services/nfc_service.dart` and `NfcReader.kt`.
  private static func mapError(_ error: Error) -> (String, String) {
    guard let nfcError = error as? NFCReaderError else {
      return ("session_error", "NFC error.")
    }
    switch nfcError.code {
    case .readerSessionInvalidationErrorUserCanceled:
      return ("session_cancelled", "User cancelled the NFC session.")
    case .readerSessionInvalidationErrorSessionTimeout:
      return ("session_timeout", "NFC session timed out.")
    case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
      return ("session_terminated",
              "NFC session ended unexpectedly. Try again in a moment.")
    case .readerSessionInvalidationErrorSystemIsBusy:
      return ("system_busy",
              "iOS NFC reader is busy. Wait a moment and try again.")
    case .readerErrorRadioDisabled:
      return ("radio_disabled", "NFC radio is turned off.")
    case .readerErrorUnsupportedFeature:
      return ("unsupported_feature", "This device does not support NFC tag reading.")
    case .readerErrorSecurityViolation:
      return ("security_violation",
              "NFC entitlement / signing issue. Reinstall the app.")
    case .readerErrorInvalidParameter,
         .readerErrorInvalidParameterLength,
         .readerErrorParameterOutOfBound:
      return ("session_error", "Invalid NFC parameter.")
    default:
      return ("session_error", "NFC error.")
    }
  }

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
