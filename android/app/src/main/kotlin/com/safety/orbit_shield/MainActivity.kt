package com.safety.orbit_shield

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.ComponentName
import android.content.pm.PackageManager
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.app.AppOpsManager
import android.content.Context
import android.app.usage.NetworkStatsManager
import android.net.ConnectivityManager
import android.telephony.TelephonyManager
import androidx.annotation.RequiresApi
import java.util.Calendar
import android.app.usage.NetworkStats

class MainActivity: FlutterActivity() {
    private val HIDER_CHANNEL = "com.orbitshield.app/hider"
    private val DATA_USAGE_CHANNEL = "com.orbitshield.app/datausage"
    private val NOTIFICATION_CHANNEL = "com.orbitshield.app/notifications" 

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- 1. Icon Hider Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HIDER_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "hideIcon") {
                hideAppIcon()
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        // --- 2. Notification Listener Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "requestPermission") {
                val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                startActivity(intent)
                result.success(true)
            } else if (call.method == "isPermissionGranted") {
                val enabledListeners = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
                val myPackageName = packageName
                val isGranted = enabledListeners != null && enabledListeners.contains(myPackageName)
                result.success(isGranted) // Fixed variable name here
            } else {
                result.notImplemented()
            }
        }

        // --- 3. Data Usage Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DATA_USAGE_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "getDailyDataUsage") {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (!hasUsageStatsPermission()) {
                        result.error("PERMISSION_DENIED", "Usage Access permission not granted.", null)
                        return@setMethodCallHandler
                    }
                    val startDateMillis = call.argument<Long>("startDate")
                    val endDateMillis = call.argument<Long>("endDate")

                    if (startDateMillis != null && endDateMillis != null) {
                        try {
                            val dailyUsage = getNetworkUsage(startDateMillis, endDateMillis)
                            result.success(dailyUsage)
                        } catch (e: Exception) {
                            result.error("NATIVE_ERROR", "Failed to get data usage: ${e.message}", e.toString())
                        }
                    } else {
                        result.error("INVALID_ARGS", "Start or end date missing.", null)
                    }
                } else {
                    result.error("UNSUPPORTED_OS", "Data usage requires Android 6.0+", null)
                }
            } else if (call.method == "requestUsageStatsPermission") {
                requestUsageStatsPermission()
                result.success(null)
            }
             else {
                result.notImplemented()
            }
        }
    }

    // --- Helper Methods ---

    private fun hideAppIcon() {
        val p = packageManager
        val launcherComponent = ComponentName(this, "$packageName.MainActivity")
        p.setComponentEnabledSetting(launcherComponent, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), packageName)
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun requestUsageStatsPermission() {
        try {
            val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
        } catch (e: Exception) {
             println("Error opening Usage Access Settings: ${e.message}")
        }
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun getNetworkUsage(startTime: Long, endTime: Long): Map<String, Map<String, Double>> {
        val networkStatsManager = getSystemService(Context.NETWORK_STATS_SERVICE) as NetworkStatsManager
        val dailyUsage = mutableMapOf<String, MutableMap<String, Double>>()

        val cal = Calendar.getInstance()
        cal.timeInMillis = startTime

        while (cal.timeInMillis < endTime) {
            val dayStartTime = cal.timeInMillis
            cal.add(Calendar.DAY_OF_YEAR, 1)
            val dayEndTime = cal.timeInMillis

            var wifiBytes: Long = 0
            var mobileBytes: Long = 0

            try {
                // WiFi Query
                val wifiBucket = networkStatsManager.querySummaryForDevice(ConnectivityManager.TYPE_WIFI, "", dayStartTime, dayEndTime)
                wifiBytes = (wifiBucket?.rxBytes ?: 0L) + (wifiBucket?.txBytes ?: 0L)
                // Removed wifiBucket.close() because Bucket doesn't have it.

                // Mobile Query
                val subscriberId = getSubscriberId()
                val mobileBucket = networkStatsManager.querySummaryForDevice(ConnectivityManager.TYPE_MOBILE, subscriberId, dayStartTime, dayEndTime)
                mobileBytes = (mobileBucket?.rxBytes ?: 0L) + (mobileBucket?.txBytes ?: 0L)
                // Removed mobileBucket.close() because Bucket doesn't have it.

            } catch (e: Exception) { 
                // Log error if needed
            }

            val dayKey = android.icu.text.SimpleDateFormat("yyyy-MM-dd", java.util.Locale.US).format(dayStartTime)
            val usageMap = mutableMapOf<String, Double>()
            usageMap["wifi"] = bytesToMegabytes(wifiBytes)
            usageMap["mobile"] = bytesToMegabytes(mobileBytes)

            if (usageMap["wifi"]!! > 0.0 || usageMap["mobile"]!! > 0.0) {
                 dailyUsage[dayKey] = usageMap
            }
        }
        return dailyUsage
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun getSubscriberId(): String? {
        try {
            if (checkSelfPermission(android.Manifest.permission.READ_PHONE_STATE) == PackageManager.PERMISSION_GRANTED) {
                 val tm = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
                 return tm.subscriberId
            }
        } catch (e: SecurityException){ }
        return null
    }

    private fun bytesToMegabytes(bytes: Long): Double {
        return bytes / (1024.0 * 1024.0)
    }
}