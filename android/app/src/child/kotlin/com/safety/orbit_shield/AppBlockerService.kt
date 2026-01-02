package com.safety.orbit_shield

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.SharedPreferences
import android.os.Build
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppBlockerService : AccessibilityService() {

    private val TAG = "AppBlockerService"
    
    private lateinit var appBlockerManager: AppBlockerManager
    private lateinit var webHistoryManager: WebHistoryManager

    private val PREFS_NAME = "FlutterSharedPreferences"
    private val LOCK_TRIGGER_KEY = "flutter.native_trigger_lock"

    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { prefs, key ->
        if (key == LOCK_TRIGGER_KEY) {
            val shouldLock = prefs.getBoolean(key, false)
            if (shouldLock) {
                Log.d(TAG, "🔒 TRIGGER DETECTED: Locking Device Now!")
                performLockAction()
                
                prefs.edit().putBoolean(key, false).apply()
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        
        appBlockerManager = AppBlockerManager(this)
        webHistoryManager = WebHistoryManager(this)

        val info = AccessibilityServiceInfo()
        
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or 
                          AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED or
                          AccessibilityEvent.TYPE_VIEW_CLICKED or 
                          AccessibilityEvent.TYPE_VIEW_TEXT_SELECTION_CHANGED
        
        info.flags = AccessibilityServiceInfo.FLAG_INCLUDE_NOT_IMPORTANT_VIEWS or 
                     AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info
        
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)

        Log.i(TAG, "Orbit Shield Accessibility Service Connected & Lock Listener Ready")
    }

    private fun performLockAction() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val result = performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
            Log.d(TAG, "Lock Action Performed: $result")
        } else {
            Log.w(TAG, "Lock Screen not supported on this Android version (Needs Android 9+). Going Home instead.")
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        val packageName = event.packageName?.toString() ?: return
        val rootInActiveWindow = rootInActiveWindow
        
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            appBlockerManager.updateBlockedList()
            
            if (appBlockerManager.shouldBlockApp(packageName)) {
                Log.d(TAG, "BLOCKED: $packageName")
                performGlobalAction(GLOBAL_ACTION_HOME)
                return 
            }
        }

        try {
            webHistoryManager.processEvent(packageName, rootInActiveWindow)
        } catch (e: Exception) {
        }
    }

    override fun onInterrupt() {
        Log.e(TAG, "Service Interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        try {            
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)

        } catch (e: Exception) {
             Log.e(TAG, "Cleanup Error: ${e.message}")
        }
    }
}