package com.example.reel_reminder

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.os.Bundle
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val inbox by lazy { getSharedPreferences("share_inbox", MODE_PRIVATE) }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState?.getBoolean("shareConsumed") == true) {
            intent.action = Intent.ACTION_MAIN
        } else {
            receive(intent)
        }
    }
    override fun onSaveInstanceState(outState: Bundle) {
        outState.putBoolean("shareConsumed", intent.action != Intent.ACTION_SEND)
        super.onSaveInstanceState(outState)
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "reel_reminder/share")
        channel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "pending" -> {
                        val uid = call.argument<String>("uid") ?: error("Missing account")
                        val rows = readInbox()
                        val output = mutableListOf<Map<String, Any>>()
                        for (i in 0 until rows.length()) {
                            val row = rows.getJSONObject(i)
                            if (!row.has("uid")) row.put("uid", uid)
                            if (row.getString("uid") == uid) output.add(mapOf(
                                "id" to row.getString("id"), "text" to row.getString("text"), "time" to row.getLong("time")))
                        }
                        check(inbox.edit().putString("items", rows.toString()).commit())
                        result.success(output)
                    }
                    "ack" -> {
                        val rows = readInbox()
                        val remaining = JSONArray()
                        for (i in 0 until rows.length()) {
                            val row = rows.getJSONObject(i)
                            if (row.getString("id") != call.argument<String>("id")) remaining.put(row)
                        }
                        check(inbox.edit().putString("items", remaining.toString()).commit())
                        result.success(null)
                    }
                    "share" -> {
                        startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                        }, "Share link"))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("share_storage", "Could not access shared content", null)
            }
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        receive(intent)
    }
    private fun readInbox() = JSONArray(inbox.getString("items", "[]"))
    private fun receive(incoming: Intent?) {
        if (incoming?.action != Intent.ACTION_SEND) return
        // Android may restore the original SEND intent when opened from Recents.
        if (incoming.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            incoming.action = Intent.ACTION_MAIN
            return
        }
        try {
            if (incoming.type?.substringBefore(';') != "text/plain") {
                incoming.action = Intent.ACTION_MAIN
                android.widget.Toast.makeText(this, "Share text containing a web link.", android.widget.Toast.LENGTH_LONG).show()
                return
            }
            val text = incoming.getCharSequenceExtra(Intent.EXTRA_TEXT)?.toString()
                ?: incoming.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.text?.toString()
            if (text.isNullOrBlank() || text.length > 20000) {
                incoming.action = Intent.ACTION_MAIN
                android.widget.Toast.makeText(this,
                    if (text.isNullOrBlank()) "Share text containing a web link." else "Shared text is too long. Share just the link.",
                    android.widget.Toast.LENGTH_LONG).show()
                return
            }
            val rows = readInbox()
            rows.put(JSONObject().put("id", UUID.randomUUID().toString()).put("text", text).put("time", System.currentTimeMillis()))
            check(inbox.edit().putString("items", rows.toString()).commit())
            incoming.action = Intent.ACTION_MAIN
            incoming.removeExtra(Intent.EXTRA_TEXT)
            incoming.clipData = null
            channel?.invokeMethod("incoming", null)
        } catch (e: Exception) {
            android.widget.Toast.makeText(this, "Could not keep this share. Please share it again.", android.widget.Toast.LENGTH_LONG).show()
        }
    }
}
