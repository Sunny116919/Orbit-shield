package com.safety.orbit_shield

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {

    private val TAG = "AppBlockerService"
    private var blockedApps = setOf<String>()
    private var launcherPackageName: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or
                     AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info
        
        launcherPackageName = getLauncherPackageName()
        Log.i(TAG, "Accessibility Service Connected")
        loadBlockedApps()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            val packageName = event.packageName?.toString() ?: return

            // Reload list to ensure we have the latest update from Flutter
            loadBlockedApps()

            if (blockedApps.contains(packageName) && packageName != launcherPackageName) {
                Log.d(TAG, "BLOCKED: $packageName")
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }
    }

    private fun loadBlockedApps() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        
        // FIX: Read as String ("flutter." prefix is added by the plugin)
        val blockedString = prefs.getString("flutter.native_blocked_apps", "") ?: ""
        
        if (blockedString.isNotEmpty()) {
            blockedApps = blockedString.split(",").toSet()
        } else {
            blockedApps = setOf()
        }
        
        // Uncomment this log to verify it's working in Logcat
        // Log.d(TAG, "Current Block List: $blockedApps") 
    }
    
    private fun getLauncherPackageName(): String? {
        val intent = android.content.Intent(android.content.Intent.ACTION_MAIN)
        intent.addCategory(android.content.Intent.CATEGORY_HOME)
        val resolveInfo = packageManager.resolveActivity(intent, android.content.pm.PackageManager.MATCH_DEFAULT_ONLY)
        return resolveInfo?.activityInfo?.packageName
    }

    override fun onInterrupt() {}
}