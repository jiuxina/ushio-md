package com.ushiomd

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.content.ComponentName
import android.content.pm.PackageManager
import androidx.core.content.FileProvider
import java.io.File

class MainActivity: FlutterActivity() {
    private val INSTALL_CHANNEL = "com.ushiomd/install"
    private val ICON_CHANNEL = "com.ushiomd/app_icon"

    // 包名（保持与 Manifest 一致）
    private val packageName_ = "com.ushiomd"

    // activity-alias 的完整组件名
    private val ALIAS_DEFAULT = "$packageName_.MainActivityDefault"
    private val ALIAS_ICON2   = "$packageName_.MainActivityIcon2"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── APK 安装频道 ──────────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "installApk") {
                val filePath = call.argument<String>("filePath")
                if (filePath != null) {
                    try {
                        installApk(filePath)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INSTALL_ERROR", e.message, null)
                    }
                } else {
                    result.error("INVALID_PATH", "Path is null", null)
                }
            } else {
                result.notImplemented()
            }
        }

        // ── 桌面图标切换频道 ──────────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ICON_CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "setAppIcon") {
                val iconIndex = call.argument<Int>("iconIndex") ?: 0
                try {
                    switchAppIcon(iconIndex)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("ICON_ERROR", e.message, null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    /** 通过启用/禁用 activity-alias 切换桌面图标 */
    private fun switchAppIcon(iconIndex: Int) {
        val pm = packageManager

        // 先全部禁用
        val allAliases = listOf(ALIAS_DEFAULT, ALIAS_ICON2)
        for (alias in allAliases) {
            pm.setComponentEnabledSetting(
                ComponentName(packageName_, alias),
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // 启用目标 alias
        val targetAlias = if (iconIndex == 1) ALIAS_ICON2 else ALIAS_DEFAULT
        pm.setComponentEnabledSetting(
            ComponentName(packageName_, targetAlias),
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )
    }

    private fun installApk(filePath: String) {
        val file = File(filePath)
        if (!file.exists()) throw Exception("File not found")
        
        val uri = FileProvider.getUriForFile(
            context,
            "${context.packageName}.fileProvider",
            file
        )
        
        val intent = Intent(Intent.ACTION_VIEW)
        intent.setDataAndType(uri, "application/vnd.android.package-archive")
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
