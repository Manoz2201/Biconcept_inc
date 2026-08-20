package com.example.biconcept

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val exportChannel = "com.example.biconcept/export"
    private val saveBackup = 4101
    private val pickBackup = 4102
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBackupFile: File? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, exportChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareFile" -> {
                        val path = call.argument<String>("path")
                        val mime = call.argument<String>("mime") ?: "*/*"
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "Missing path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            shareFile(path, mime)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("share_failed", error.message, null)
                        }
                    }
                    "dialPhone" -> {
                        val number = call.argument<String>("number")
                        if (number.isNullOrBlank()) {
                            result.error("bad_args", "Missing number", null)
                            return@setMethodCallHandler
                        }
                        try {
                            dialPhone(number)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("dial_failed", error.message, null)
                        }
                    }
                    "saveBackupCsv" -> {
                        val path = call.argument<String>("path")
                        val fileName = call.argument<String>("fileName") ?: "biconcept-backup.csv"
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "Missing path", null)
                            return@setMethodCallHandler
                        }
                        saveBackupCsv(path, fileName, result)
                    }
                    "pickBackupCsv" -> pickBackupCsv(result)
                    "openUrl" -> {
                        val url = call.argument<String>("url")
                        if (url.isNullOrBlank()) {
                            result.error("bad_args", "Missing url", null)
                            return@setMethodCallHandler
                        }
                        try {
                            openUrl(url)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("open_failed", error.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("bad_args", "Missing path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            installApk(path, result)
                        } catch (error: Exception) {
                            result.error("install_failed", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val result = pendingResult ?: return
        pendingResult = null
        if (resultCode != RESULT_OK) {
            pendingBackupFile = null
            result.success(null)
            return
        }
        try {
            when (requestCode) {
                saveBackup -> {
                    val uri = data?.data
                    val source = pendingBackupFile
                    pendingBackupFile = null
                    if (uri != null && source != null) {
                        contentResolver.openOutputStream(uri)?.use { output ->
                            source.inputStream().use { input -> input.copyTo(output) }
                        }
                    }
                    result.success(source?.absolutePath)
                }
                pickBackup -> {
                    val uri = data?.data ?: throw IllegalArgumentException("No file selected")
                    val dest = File(cacheDir, "biconcept-restore.csv")
                    contentResolver.openInputStream(uri)?.use { input ->
                        dest.outputStream().use { output -> input.copyTo(output) }
                    } ?: throw IllegalArgumentException("Could not read backup file")
                    result.success(dest.absolutePath)
                }
                else -> result.success(null)
            }
        } catch (error: Exception) {
            pendingBackupFile = null
            result.error("backup_failed", error.message, null)
        }
    }

    private fun saveBackupCsv(path: String, fileName: String, result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another file picker is open", null)
            return
        }
        pendingBackupFile = File(path)
        pendingResult = result
        try {
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "text/csv"
                putExtra(Intent.EXTRA_TITLE, fileName)
            }
            startActivityForResult(intent, saveBackup)
        } catch (error: Exception) {
            pendingResult = null
            pendingBackupFile = null
            result.success(File(path).absolutePath)
        }
    }

    private fun pickBackupCsv(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "Another file picker is open", null)
            return
        }
        pendingResult = result
        try {
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf("text/csv", "text/comma-separated-values", "text/plain", "application/csv")
                )
            }
            startActivityForResult(intent, pickBackup)
        } catch (error: Exception) {
            pendingResult = null
            result.error("picker_failed", error.message, null)
        }
    }

    private fun openUrl(url: String) {
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
    }

    private fun installApk(path: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && !packageManager.canRequestPackageInstalls()) {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName"),
                ),
            )
            result.error(
                "need_install_permission",
                "Allow BiConcept to install updates, then tap Download and install again.",
                null,
            )
            return
        }
        val source = File(path)
        if (!source.exists()) {
            result.error("missing_file", "Update file was not found", null)
            return
        }
        val shared = File(cacheDir, source.name)
        source.copyTo(shared, overwrite = true)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", shared)
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
        result.success(true)
    }

    private fun dialPhone(number: String) {
        val intent = Intent(Intent.ACTION_DIAL).apply {
            data = Uri.parse("tel:$number")
        }
        startActivity(intent)
    }

    private fun shareFile(path: String, mime: String) {
        val source = File(path)
        if (!source.exists()) {
            throw IllegalArgumentException("File not found")
        }
        val shared = File(cacheDir, source.name)
        source.copyTo(shared, overwrite = true)
        val uri = FileProvider.getUriForFile(this, "$packageName.fileprovider", shared)
        val send = Intent(Intent.ACTION_SEND).apply {
            type = mime
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(send, "Share estimate"))
    }
}
