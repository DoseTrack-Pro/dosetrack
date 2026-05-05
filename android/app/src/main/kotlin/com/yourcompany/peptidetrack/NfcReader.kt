package com.yourcompany.peptidetrack

import android.app.Activity
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Native Android NFC reader.
 *
 * Drop-in replacement for the parts of `flutter_nfc_kit` we actually use
 * (read tag UID for inventory matching). Avoids any third-party Flutter NFC
 * plugin so iOS and Android are both backed by code we control.
 *
 * Channel name MUST match `NfcReader.swift` and `lib/services/nfc_service.dart`.
 */
class NfcReader(
    private val activity: Activity
) : MethodChannel.MethodCallHandler, NfcAdapter.ReaderCallback {

    companion object {
        private const val CHANNEL_NAME = "com.adam.dosevault/nfc"

        fun register(activity: Activity, flutterEngine: FlutterEngine): NfcReader {
            val handler = NfcReader(activity)
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            channel.setMethodCallHandler(handler)
            return handler
        }
    }

    private val adapter: NfcAdapter? = NfcAdapter.getDefaultAdapter(activity)
    private var pendingResult: MethodChannel.Result? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNFCAvailability" -> handleAvailability(result)
            "poll" -> handlePoll(call, result)
            "finish" -> handleFinish(result)
            else -> result.notImplemented()
        }
    }

    private fun handleAvailability(result: MethodChannel.Result) {
        val pm = activity.packageManager
        val hasNfc = pm.hasSystemFeature(PackageManager.FEATURE_NFC)
        if (!hasNfc || adapter == null) {
            result.success("not_supported")
            return
        }
        if (!adapter.isEnabled) {
            result.success("disabled")
            return
        }
        result.success("available")
    }

    private fun handlePoll(@Suppress("UNUSED_PARAMETER") call: MethodCall, result: MethodChannel.Result) {
        val adapter = this.adapter ?: run {
            result.error("not_supported", "NFC is not supported on this device.", null)
            return
        }
        if (!adapter.isEnabled) {
            result.error("disabled", "NFC is disabled. Enable NFC in system settings.", null)
            return
        }
        if (pendingResult != null) {
            result.error("session_active", "An NFC session is already running.", null)
            return
        }

        pendingResult = result

        // Reader-mode covers the same tag types flutter_nfc_kit polled for.
        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK

        val extras = Bundle().apply {
            // Some devices ignore very short presence checks and trigger phantom tag-lost
            // events; 250ms matches flutter_nfc_kit's default and works well in practice.
            putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
        }

        try {
            adapter.enableReaderMode(activity, this, flags, extras)
        } catch (e: Throwable) {
            pendingResult = null
            result.error("session_error", e.localizedMessage ?: "Could not start reader mode.", null)
        }
    }

    private fun handleFinish(result: MethodChannel.Result) {
        try {
            adapter?.disableReaderMode(activity)
        } catch (_: Throwable) {
            // ignore: stopping a session that was never started shouldn't propagate.
        }
        pendingResult?.let {
            it.error("session_cancelled", "NFC session was cancelled.", null)
        }
        pendingResult = null
        result.success(null)
    }

    override fun onTagDiscovered(tag: Tag?) {
        val pending = pendingResult ?: return
        pendingResult = null

        val uid = tag?.id?.let(::bytesToHex).orEmpty()
        val techList = tag?.techList?.toList().orEmpty()

        // Stop reader mode + return on the main thread so the Flutter side stays single-threaded.
        mainHandler.post {
            try {
                adapter?.disableReaderMode(activity)
            } catch (_: Throwable) { /* ignore */ }

            if (uid.isEmpty()) {
                pending.error("read_failed", "Tag detected but UID was empty.", null)
            } else {
                pending.success(
                    mapOf(
                        "id" to uid,
                        "type" to inferType(techList),
                        "standard" to techList.joinToString(","),
                    )
                )
            }
        }
    }

    private fun inferType(techList: List<String>): String = when {
        techList.any { it.endsWith(".MifareClassic") } -> "mifare"
        techList.any { it.endsWith(".MifareUltralight") } -> "mifare_ultralight"
        techList.any { it.endsWith(".IsoDep") } -> "iso7816"
        techList.any { it.endsWith(".NfcA") || it.endsWith(".NfcB") } -> "iso14443"
        techList.any { it.endsWith(".NfcF") } -> "felica"
        techList.any { it.endsWith(".NfcV") } -> "iso15693"
        else -> "unknown"
    }

    private fun bytesToHex(bytes: ByteArray): String {
        val sb = StringBuilder(bytes.size * 2)
        for (b in bytes) sb.append(String.format("%02X", b))
        return sb.toString()
    }

    @Suppress("unused")
    private fun supportsReaderMode(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT
    }
}
