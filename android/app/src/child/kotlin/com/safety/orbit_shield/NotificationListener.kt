package com.safety.orbit_shield

import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.content.Context
import android.util.Log
import org.json.JSONObject
import org.json.JSONArray

class NotificationListener : NotificationListenerService() {

    private val TAG = "OrbitNotifListener"
    private val PREFS_NAME = "FlutterSharedPreferences"
    private val PREF_KEY = "flutter.native_notification_buffer"

    // vvv NEW: This runs when the service connects (Permission granted/App restart) vvv
    override fun onListenerConnected() {
        super.onListenerConnected()
        Log.d(TAG, "Notification Listener CONNECTED. Fetching active notifications...")
        try {
            val activeNotifs = activeNotifications
            if (activeNotifs != null) {
                for (sbn in activeNotifs) {
                    processNotification(sbn)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error fetching active notifications: ${e.message}")
        }
    }
    // ^^^ END NEW ^^^

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        processNotification(sbn)
    }

    private fun processNotification(sbn: StatusBarNotification) {
        try {
            val packageName = sbn.packageName
            val extras = sbn.notification.extras
            val title = extras.getString("android.title") ?: ""
            val text = extras.getCharSequence("android.text")?.toString() ?: ""

            // Ignore system android notifications or empty ones
            if (packageName == "android" || packageName == "com.android.systemui" || (title.isEmpty() && text.isEmpty())) return

            Log.d(TAG, "Processing Notification: $packageName - $title")

            val notifJson = JSONObject()
            notifJson.put("packageName", packageName)
            notifJson.put("title", title)
            notifJson.put("text", text)
            notifJson.put("timestamp", sbn.postTime) // Use actual notification time

            saveNotificationToPrefs(notifJson.toString())

        } catch (e: Exception) {
            Log.e(TAG, "Error processing notification: ${e.message}")
        }
    }

    private fun saveNotificationToPrefs(jsonString: String) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        
        // Get existing list
        val existingListString = prefs.getString(PREF_KEY, "[]")
        val jsonArray = try {
            JSONArray(existingListString)
        } catch (e: Exception) {
            JSONArray()
        }

        // Add new notification
        jsonArray.put(jsonString)

        // Save back
        prefs.edit().putString(PREF_KEY, jsonArray.toString()).apply()
        Log.d(TAG, "Saved to buffer. Total count: ${jsonArray.length()}")
    }

    override fun onNotificationRemoved(sbn: StatusBarNotification) {
        // Optional: Handle removal
    }
}