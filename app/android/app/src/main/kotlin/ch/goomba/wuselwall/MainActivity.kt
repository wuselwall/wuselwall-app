package ch.goomba.wuselwall

import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    // The wall display keeps its screen on while the week board is shown (specs/09 "The
    // wall display"); every other register lets the device sleep as usual.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wuselwall/kiosk")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "keepScreenOn" -> {
                        if (call.arguments == true) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        // A calendar file the app was opened with (specs/05 "Sharing one event"): only this
        // activity holds the permission to read its content:// address. Answers the bytes,
        // or null when the file cannot be read or is larger than the caller takes.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "wuselwall/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "read" -> {
                        val uri = call.argument<String>("uri")?.let(Uri::parse)
                        val maxBytes = call.argument<Int>("maxBytes") ?: 0
                        if (uri == null || uri.scheme != "content" || maxBytes <= 0) {
                            result.success(null)
                        } else {
                            val main = Handler(Looper.getMainLooper())
                            // A content provider may be slow: never on the UI thread.
                            Thread {
                                val bytes = readCapped(uri, maxBytes)
                                main.post { result.success(bytes) }
                            }.start()
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** The content of [uri], or null when it cannot be read or holds more than [maxBytes]. */
    private fun readCapped(uri: Uri, maxBytes: Int): ByteArray? =
        try {
            contentResolver.openInputStream(uri)?.use { input ->
                val out = ByteArrayOutputStream()
                val buffer = ByteArray(8192)
                var total = 0
                while (true) {
                    val n = input.read(buffer)
                    if (n < 0) break
                    total += n
                    if (total > maxBytes) return null
                    out.write(buffer, 0, n)
                }
                out.toByteArray()
            }
        } catch (e: Exception) {
            null
        }
}
