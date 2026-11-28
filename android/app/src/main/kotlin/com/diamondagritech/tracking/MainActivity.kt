package com.diamondagritech.tracking

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PHONE_SETUP)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "maker" -> result.success(
                        mapOf("manufacturer" to Build.MANUFACTURER, "brand" to Build.BRAND),
                    )
                    "open" -> result.success(open(call.argument<String>("page") ?: ""))
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Opens a phone settings page. The phone makers' own pages are not an
     * official API and differ between models, so each is tried in turn; when
     * none opens, the app's own info page opens instead.
     * Returns "page" (the asked page opened) or "appInfo" (the fallback).
     */
    private fun open(page: String): String {
        val tries: List<Intent> = when (page) {
            "battery" -> listOf(Intent(Intent.ACTION_POWER_USAGE_SUMMARY))
            "xiaomiAutostart" -> components(
                "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            )
            "vivoAutostart" -> components(
                "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
                "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            )
            "samsungSleeping" -> components(
                "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
                "com.samsung.android.lool" to "com.samsung.android.sm.ui.battery.BatteryActivity",
            )
            "tecnoAutostart" -> components(
                "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
            )
            else -> emptyList()
        }
        for (intent in tries) {
            if (start(intent)) return "page"
        }
        start(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)),
        )
        return "appInfo"
    }

    private fun components(vararg names: Pair<String, String>): List<Intent> =
        names.map { (pkg, cls) -> Intent().setComponent(ComponentName(pkg, cls)) }

    /** False when this phone has no such page or does not let us open it. */
    private fun start(intent: Intent): Boolean = try {
        // Started from the app's own screen, so Back returns to the app.
        startActivity(intent)
        true
    } catch (e: Exception) {
        // ActivityNotFoundException or SecurityException: try the next one.
        false
    }

    private companion object {
        const val PHONE_SETUP = "com.diamondagritech.tracking/phone_setup"
    }
}
