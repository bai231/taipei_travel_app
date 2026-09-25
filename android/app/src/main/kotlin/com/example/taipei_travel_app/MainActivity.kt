package com.example.taipei_travel_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "travel_app/routes_config")
            .setMethodCallHandler { call, result ->
                if (call.method != "getConfig") {
                    result.notImplemented()
                } else {
                    try {
                        val app = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
                                .signingInfo?.apkContentsSigners
                        } else {
                            @Suppress("DEPRECATION")
                            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
                        }
                        val certificate = signatures?.firstOrNull()
                            ?: throw IllegalStateException("Missing signing certificate")
                        val sha1 = MessageDigest.getInstance("SHA-1").digest(certificate.toByteArray())
                            .joinToString("") { "%02X".format(it.toInt() and 0xff) }
                        result.success(mapOf(
                            "apiKey" to (app.metaData?.getString("app.google.ROUTES_API_KEY") ?: ""),
                            "packageName" to packageName,
                            "certificate" to sha1
                        ))
                    } catch (_: Exception) {
                        result.error("ROUTES_CONFIG", "Unable to read Android route configuration", null)
                    }
                }
            }
    }
}
