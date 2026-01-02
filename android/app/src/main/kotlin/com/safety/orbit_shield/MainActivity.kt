package com.safety.orbit_shield

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings

class MainActivity: FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.orbitshield.app/notifications" 

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestPermission") {
                try {
                    val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                    startActivity(intent)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ERROR", "Could not open settings: ${e.message}", null)
                }
            } else if (call.method == "isPermissionGranted") {
                val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                val myPackageName = packageName
                val isGranted = enabledListeners != null && enabledListeners.contains(myPackageName)
                result.success(isGranted)
            } else {
                result.notImplemented()
            }
        }
    }
}