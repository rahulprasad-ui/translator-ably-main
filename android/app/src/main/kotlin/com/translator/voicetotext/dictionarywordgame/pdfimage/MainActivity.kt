package com.translator.voicetotext.dictionarywordgame.pdfimage

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.translator/storage_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasStoragePermission" -> {
                    val hasPerm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        Environment.isExternalStorageManager()
                    } else {
                        ContextCompat.checkSelfPermission(this, Manifest.permission.READ_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                    }
                    result.success(hasPerm)
                }
                "requestStoragePermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                        try {
                            val intent = Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                                data = Uri.parse("package:$packageName")
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION)
                            startActivity(intent)
                        }
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE, Manifest.permission.WRITE_EXTERNAL_STORAGE),
                            1001
                        )
                    }
                    result.success(true)
                }
                "queryAllDocuments" -> {
                    val docsList = mutableListOf<Map<String, Any>>()
                    try {
                        val projection = arrayOf(
                            MediaStore.Files.FileColumns.DATA,
                            MediaStore.Files.FileColumns.DISPLAY_NAME,
                            MediaStore.Files.FileColumns.SIZE,
                            MediaStore.Files.FileColumns.DATE_MODIFIED
                        )
                        val selection = "(${MediaStore.Files.FileColumns.DATA} LIKE '%.pdf' OR " +
                                "${MediaStore.Files.FileColumns.DATA} LIKE '%.doc' OR " +
                                "${MediaStore.Files.FileColumns.DATA} LIKE '%.docx' OR " +
                                "${MediaStore.Files.FileColumns.DATA} LIKE '%.xls' OR " +
                                "${MediaStore.Files.FileColumns.DATA} LIKE '%.xlsx' OR " +
                                "${MediaStore.Files.FileColumns.DATA} LIKE '%.ppt' OR " +
                                "${MediaStore.Files.FileColumns.DATA} LIKE '%.pptx')"

                        val cursor = contentResolver.query(
                            MediaStore.Files.getContentUri("external"),
                            projection,
                            selection,
                            null,
                            "${MediaStore.Files.FileColumns.DATE_MODIFIED} DESC"
                        )

                        cursor?.use {
                            val dataCol = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATA)
                            val nameCol = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DISPLAY_NAME)
                            val sizeCol = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.SIZE)
                            val dateCol = it.getColumnIndexOrThrow(MediaStore.Files.FileColumns.DATE_MODIFIED)

                            while (it.moveToNext()) {
                                val path = it.getString(dataCol) ?: continue
                                val name = it.getString(nameCol) ?: path.substringAfterLast('/')
                                val size = it.getLong(sizeCol)
                                val modifiedSeconds = it.getLong(dateCol)

                                docsList.add(mapOf(
                                    "path" to path,
                                    "name" to name,
                                    "size" to size,
                                    "modified" to (modifiedSeconds * 1000)
                                ))
                            }
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(docsList)
                }
                else -> result.notImplemented()
            }
        }
    }
}
