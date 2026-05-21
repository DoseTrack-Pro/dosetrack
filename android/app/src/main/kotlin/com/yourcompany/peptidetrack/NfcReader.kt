package com.yourcompany.peptidetrack

import android.app.Activity
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.TagLostException
import android.nfc.tech.IsoDep
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import net.cacheux.nvplib.NvpController
import net.cacheux.nvplib.data.PenResult
import net.cacheux.nvplib.nfc.NfcDataReader

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

    private class IncompleteScanException(message: String) : RuntimeException(message)

    private enum class PendingOperation { TAG_UID, NOVOPEN_DATA, ENROLLMENT_AUTO_DETECT }

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
    private var pendingOperation: PendingOperation? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getNFCAvailability" -> handleAvailability(result)
            "poll" -> handlePoll(call, result)
            "readNovoPenData" -> handleNovoPenRead(result)
            "scanForEnrollment" -> handleEnrollmentScan(result)
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
        pendingOperation = PendingOperation.TAG_UID

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
            pendingOperation = null
            result.error("session_error", e.localizedMessage ?: "Could not start reader mode.", null)
        }
    }

    private fun handleNovoPenRead(result: MethodChannel.Result) {
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
        pendingOperation = PendingOperation.NOVOPEN_DATA

        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK

        val extras = Bundle().apply {
            putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
        }

        try {
            adapter.enableReaderMode(activity, this, flags, extras)
        } catch (e: Throwable) {
            pendingResult = null
            pendingOperation = null
            result.error("session_error", e.localizedMessage ?: "Could not start reader mode.", null)
        }
    }

    private fun handleEnrollmentScan(result: MethodChannel.Result) {
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
        pendingOperation = PendingOperation.ENROLLMENT_AUTO_DETECT

        val flags = NfcAdapter.FLAG_READER_NFC_A or
            NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or
            NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK

        val extras = Bundle().apply {
            putInt(NfcAdapter.EXTRA_READER_PRESENCE_CHECK_DELAY, 250)
        }

        try {
            adapter.enableReaderMode(activity, this, flags, extras)
        } catch (e: Throwable) {
            pendingResult = null
            pendingOperation = null
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
        pendingOperation = null
        result.success(null)
    }

    override fun onTagDiscovered(tag: Tag?) {
        val pending = pendingResult ?: return
        val op = pendingOperation ?: return
        pendingResult = null
        pendingOperation = null

        var successPayload: Any?
        var errorCode: String?
        var errorMessage: String?
        try {
            when (op) {
                PendingOperation.TAG_UID -> {
                    val uid = tag?.id?.let(::bytesToHex).orEmpty()
                    val techList = tag?.techList?.toList().orEmpty()
                    if (uid.isEmpty()) {
                        successPayload = null
                        errorCode = "read_failed"
                        errorMessage = "Tag detected but UID was empty."
                    } else {
                        successPayload = mapOf(
                            "id" to uid,
                            "type" to inferType(techList),
                            "standard" to techList.joinToString(","),
                        )
                        errorCode = null
                        errorMessage = null
                    }
                }
                PendingOperation.NOVOPEN_DATA -> {
                    successPayload = readNovoPenPayload(tag)
                    errorCode = null
                    errorMessage = null
                }
                PendingOperation.ENROLLMENT_AUTO_DETECT -> {
                    successPayload = readEnrollmentPayload(tag)
                    errorCode = null
                    errorMessage = null
                }
            }
        } catch (e: Throwable) {
            successPayload = null
            if (e is IncompleteScanException) {
                errorCode = "incomplete_scan"
                errorMessage = e.localizedMessage ?: "Scan was too short."
            } else {
                errorCode = "read_failed"
                errorMessage = e.localizedMessage ?: "NFC read failed."
            }
        }

        // Stop reader mode + return on the main thread so Flutter stays single-threaded.
        mainHandler.post {
            try {
                adapter?.disableReaderMode(activity)
            } catch (_: Throwable) { /* ignore */ }

            if (errorCode != null) {
                pending.error(errorCode, errorMessage, null)
            } else {
                pending.success(successPayload)
            }
        }
    }

    private fun readNovoPenPayload(tag: Tag?): Map<String, Any> {
        val isoDep = IsoDep.get(tag) ?: throw IllegalStateException("Incorrect tag detected.")
        isoDep.timeout = 1000

        return try {
            isoDep.connect()
            val reader = object : NfcDataReader(isoDep) {}
            val controller = NvpController(reader)
            when (val result = controller.dataRead()) {
                is PenResult.Success -> {
                    val data = result.data
                    val startTime = data.startTime.toInt()
                    val now = System.currentTimeMillis()
                    val doses = data.doseList.mapIndexed { index, dose ->
                        val utc = dose.withUtcTime(startTime, now)
                        mapOf(
                            "index" to index,
                            "timeMs" to utc.time,
                            "units" to utc.units,
                            "flags" to utc.flags,
                        )
                    }
                    mapOf(
                        "model" to data.model,
                        "serial" to data.serial,
                        "startTime" to data.startTime,
                        "doses" to doses,
                    )
                }
                is PenResult.Failure ->
                    throw IllegalStateException(result.message.ifBlank { "NovoPen protocol read failed." })
            }
        } finally {
            try {
                isoDep.close()
            } catch (_: Throwable) { /* ignore */ }
        }
    }

    private fun readEnrollmentPayload(tag: Tag?): Map<String, Any> {
        val uid = tag?.id?.let(::bytesToHex).orEmpty()
        val techList = tag?.techList?.toList().orEmpty()

        val isoDep = IsoDep.get(tag)
        if (isoDep != null) {
            try {
                val novo = readNovoPenPayload(tag)
                val serial = (novo["serial"] as? String).orEmpty().trim()
                if (serial.isNotEmpty()) {
                    val doseCount = (novo["doses"] as? List<*>)?.size ?: 0
                    return mapOf(
                        "mode" to "novo_pen",
                        "id" to serial,
                        "model" to ((novo["model"] as? String) ?: "NovoPen"),
                        "doseCount" to doseCount,
                    )
                }
            } catch (e: Throwable) {
                // If pen communication fails very early, this is likely a short
                // dwell ("quick tap") and should force a rescan rather than
                // silently downgrading to a standard UID registration.
                val msg = e.localizedMessage?.lowercase().orEmpty()
                val likelyIncomplete = e is TagLostException ||
                    msg.contains("transceive failed") ||
                    msg.contains("tag was lost")
                if (likelyIncomplete) {
                    throw IncompleteScanException("Scan was too short. Hold the pen steady for 1-2 seconds and rescan.")
                }
                // Otherwise, treat as non-Novo and fall through to UID mode.
            }
        }

        if (uid.isEmpty()) {
            throw IllegalStateException("Tag detected but UID was empty.")
        }
        return mapOf(
            "mode" to "tag",
            "id" to uid,
            "type" to inferType(techList),
            "standard" to techList.joinToString(","),
        )
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
