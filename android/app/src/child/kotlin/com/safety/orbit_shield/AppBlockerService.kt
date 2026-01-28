package com.safety.orbit_shield

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.os.Build
import android.util.Log
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.widget.FrameLayout
import android.widget.TextView

class AppBlockerService : AccessibilityService() {

    private val TAG = "AppBlockerService"
    private lateinit var appBlockerManager: AppBlockerManager
    private lateinit var webHistoryManager: WebHistoryManager

    private val PREFS_NAME = "FlutterSharedPreferences"
    private val LOCK_TRIGGER_KEY = "flutter.native_trigger_lock"

    private var windowManager: WindowManager? = null
    private var lockView: ViewGroup? = null
    private var isLockedViewShowing = false

    private val prefsListener = SharedPreferences.OnSharedPreferenceChangeListener { prefs, key ->
        if (key == LOCK_TRIGGER_KEY) {
            val shouldLock = prefs.getBoolean(key, false)
            if (shouldLock) {
                showLockScreen()
            } else {
                hideLockScreen()
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()

        appBlockerManager = AppBlockerManager(this)
        webHistoryManager = WebHistoryManager(this)
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager

        // Accessibility Config
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        this.serviceInfo = info

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.registerOnSharedPreferenceChangeListener(prefsListener)

        // Check initial state
        val shouldLockInitially = prefs.getBoolean(LOCK_TRIGGER_KEY, false)
        if (shouldLockInitially) {
            showLockScreen()
        }
    }

    // -------------------------------------------------------------
    // NEW: CUSTOM OVERLAY LOCK LOGIC
    // -------------------------------------------------------------

    private fun createLockView(): ViewGroup {
        // 1. Create a FrameLayout to cover the screen
        val layout = object : FrameLayout(this) {
            // Intercept Key Events (Block Back Button)
            override fun dispatchKeyEvent(event: KeyEvent): Boolean {
                if (event.keyCode == KeyEvent.KEYCODE_BACK || 
                    event.keyCode == KeyEvent.KEYCODE_HOME) {
                    return true // Consume the event (do nothing)
                }
                return super.dispatchKeyEvent(event)
            }
        }
        
        layout.setBackgroundColor(Color.BLACK) // Completely Black Screen

        // 2. Add a Message
        val textView = TextView(this)
        textView.text = "🔒\nDevice Locked by Parent\nContact parent to unlock"
        textView.setTextColor(Color.WHITE)
        textView.textSize = 24f
        textView.gravity = Gravity.CENTER
        textView.textAlignment = View.TEXT_ALIGNMENT_CENTER

        val params = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.WRAP_CONTENT,
            FrameLayout.LayoutParams.WRAP_CONTENT
        )
        params.gravity = Gravity.CENTER
        layout.addView(textView, params)

        return layout
    }

    private fun showLockScreen() {
        if (isLockedViewShowing) return
        
        try {
            if (lockView == null) {
                lockView = createLockView()
            }

            val layoutParams = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or // Allow system to sleep
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_FULLSCREEN, 
                PixelFormat.TRANSLUCENT
            )

            // Make it focusable so it catches the Back Button
            layoutParams.flags = 0 // Reset flags
            layoutParams.flags = WindowManager.LayoutParams.FLAG_FULLSCREEN or
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON 

            // High priority view
            layoutParams.gravity = Gravity.CENTER

            windowManager?.addView(lockView, layoutParams)
            isLockedViewShowing = true
            Log.d(TAG, "🔒 OVERLAY ADDED")

        } catch (e: Exception) {
            Log.e(TAG, "Error showing lock screen: ${e.message}")
            // Fallback to old method if permission missing
            performGlobalAction(GLOBAL_ACTION_HOME)
        }
    }

    private fun hideLockScreen() {
        if (!isLockedViewShowing || lockView == null) return

        try {
            windowManager?.removeView(lockView)
            isLockedViewShowing = false
            Log.d(TAG, "🔓 OVERLAY REMOVED")
        } catch (e: Exception) {
            Log.e(TAG, "Error removing lock screen: ${e.message}")
        }
    }

    // -------------------------------------------------------------
    // EXISTING LOGIC (App Block & History)
    // -------------------------------------------------------------

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // If our custom lock overlay is showing, we don't need to check blocking logic
        // The view is already physically blocking the screen.
        if (isLockedViewShowing) return

        val packageName = event.packageName?.toString() ?: return

        // 1. App Blocking
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            appBlockerManager.updateBlockedList()
            if (appBlockerManager.shouldBlockApp(packageName)) {
                performGlobalAction(GLOBAL_ACTION_HOME)
            }
        }

        // 2. Web History
        try {
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                webHistoryManager.processEvent(packageName, rootNode)
            }
        } catch (e: Exception) {
            Log.e(TAG, "History Error: ${e.message}")
        }
    }

    override fun onInterrupt() {}

    override fun onDestroy() {
        super.onDestroy()
        hideLockScreen() // Clean up view if service dies
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.unregisterOnSharedPreferenceChangeListener(prefsListener)
        } catch (e: Exception) {}
    }
}