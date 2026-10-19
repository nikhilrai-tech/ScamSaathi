package io.github.nikhilrai_tech.scamsaathi

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands text shared from another app (WhatsApp, SMS, a browser) to Flutter. The text is only passed on to the
 * on-device checker; it is never logged or sent anywhere from here.
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var pending: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pending = sharedText(intent)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "scamsaathi/share")
        ch.setMethodCallHandler { call, result ->
            if (call.method == "takeSharedText") {
                result.success(pending)
                pending = null
            } else {
                result.notImplemented()
            }
        }
        channel = ch
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedText(intent)?.let { channel?.invokeMethod("sharedText", it) }
    }

    private fun sharedText(i: Intent?): String? {
        if (i?.action != Intent.ACTION_SEND || i.type?.startsWith("text/") != true) return null
        return i.getStringExtra(Intent.EXTRA_TEXT)?.take(5000)
    }
}
