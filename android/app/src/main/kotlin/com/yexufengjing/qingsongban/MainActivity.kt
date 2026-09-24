package com.yexufengjing.qingsongban

import android.content.ContentValues
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "qingsongban/file_exports"
    private val lifecycleChannelName = "qingsongban/app_lifecycle"
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "saveToDownloads") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    result.success(null)
                    return@setMethodCallHandler
                }

                val fileName = call.argument<String>("fileName")
                val bytes = call.argument<ByteArray>("bytes")
                if (fileName.isNullOrBlank() || bytes == null) {
                    result.error("INVALID_EXPORT", "导出文件参数无效", null)
                    return@setMethodCallHandler
                }

                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, fileName)
                    put(
                        MediaStore.Downloads.MIME_TYPE,
                        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                    )
                    put(MediaStore.Downloads.IS_PENDING, 1)
                }
                val resolver = contentResolver
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI,
                    values,
                )
                if (uri == null) {
                    result.error("EXPORT_FAILED", "无法创建下载文件", null)
                    return@setMethodCallHandler
                }

                try {
                    resolver.openOutputStream(uri)?.use { output ->
                        output.write(bytes)
                    } ?: throw IllegalStateException("无法写入下载文件")
                    values.clear()
                    values.put(MediaStore.Downloads.IS_PENDING, 0)
                    resolver.update(uri, values, null, null)
                    result.success(uri.toString())
                } catch (error: Exception) {
                    resolver.delete(uri, null, null)
                    result.error("EXPORT_FAILED", error.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, lifecycleChannelName)
            .setMethodCallHandler { call, result ->
                if (call.method != "restartApp") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                if (launchIntent == null) {
                    result.error("RESTART_FAILED", "无法找到应用启动入口", null)
                    return@setMethodCallHandler
                }
                launchIntent.addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP,
                )
                result.success(null)
                mainHandler.postDelayed({
                    startActivity(launchIntent)
                    finishAffinity()
                }, 250L)
            }
    }
}
