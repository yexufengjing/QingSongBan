package com.yexufengjing.qingsongban

import android.content.ContentValues
import android.content.Intent
import android.Manifest
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "qingsongban/file_exports"
    private val lifecycleChannelName = "qingsongban/app_lifecycle"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val galleryPermissionRequest = 4101
    private var pendingGallerySave: Triple<String, ByteArray, MethodChannel.Result>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveImageToGallery") {
                    val fileName = call.argument<String>("fileName")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (fileName.isNullOrBlank() || bytes == null || bytes.isEmpty() ||
                        File(fileName).name != fileName) {
                        result.error("INVALID_EXPORT", "考勤图片参数无效", null)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
                        checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) !=
                        PackageManager.PERMISSION_GRANTED) {
                        if (pendingGallerySave != null) {
                            result.error("EXPORT_BUSY", "正在等待相册保存授权", null)
                            return@setMethodCallHandler
                        }
                        pendingGallerySave = Triple(fileName, bytes, result)
                        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            galleryPermissionRequest)
                    } else {
                        saveImageToGallery(fileName, bytes, result)
                    }
                    return@setMethodCallHandler
                }
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

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != galleryPermissionRequest) return
        val pending = pendingGallerySave ?: return
        pendingGallerySave = null
        if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) {
            saveImageToGallery(pending.first, pending.second, pending.third)
        } else {
            pending.third.error("GALLERY_PERMISSION_DENIED",
                "保存到相册需要允许存储权限，请在应用设置中允许后重试", null)
        }
    }

    private fun saveImageToGallery(
        fileName: String,
        bytes: ByteArray,
        result: MethodChannel.Result,
    ) {
        Thread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val resolver = contentResolver
                var uri: android.net.Uri? = null
                try {
                    val values = ContentValues().apply {
                        put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                        put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                        put(MediaStore.Images.Media.RELATIVE_PATH,
                            "${Environment.DIRECTORY_PICTURES}/轻松办")
                        put(MediaStore.Images.Media.IS_PENDING, 1)
                    }
                    val inserted = resolver.insert(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values,
                    ) ?: throw IllegalStateException("无法创建相册图片")
                    uri = inserted
                    resolver.openOutputStream(inserted)?.use { it.write(bytes) }
                        ?: throw IllegalStateException("无法写入相册图片")
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    if (resolver.update(inserted, values, null, null) != 1) {
                        throw IllegalStateException("无法完成相册图片保存")
                    }
                    mainHandler.post { result.success(inserted.toString()) }
                } catch (error: Exception) {
                    uri?.let { runCatching { resolver.delete(it, null, null) } }
                    mainHandler.post { result.error("GALLERY_SAVE_FAILED",
                        "保存到相册失败，请检查可用空间后重试", null) }
                }
            } else {
                val directory = File(Environment.getExternalStoragePublicDirectory(
                    Environment.DIRECTORY_PICTURES), "轻松办")
                val file = File(directory, fileName)
                var created = false
                try {
                    if (!directory.exists() && !directory.mkdirs()) {
                        throw IllegalStateException("无法创建相册目录")
                    }
                    created = file.createNewFile()
                    if (!created) throw IllegalStateException("图片文件已存在")
                    file.outputStream().use { it.write(bytes) }
                    MediaScannerConnection.scanFile(this,
                        arrayOf(file.absolutePath), arrayOf("image/png")) { _, uri ->
                        if (uri == null) file.delete()
                        mainHandler.post {
                            if (uri != null) result.success(uri.toString())
                            else result.error("GALLERY_SAVE_FAILED",
                                "图片未能加入相册，请重试", null)
                        }
                    }
                } catch (error: Exception) {
                    if (created) file.delete()
                    mainHandler.post { result.error("GALLERY_SAVE_FAILED",
                        "保存到相册失败，请检查可用空间后重试", null) }
                }
            }
        }.start()
    }
}
