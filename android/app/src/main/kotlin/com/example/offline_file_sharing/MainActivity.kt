package com.example.offline_file_sharing

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.net.wifi.WifiConfiguration
import android.net.wifi.WifiManager
import android.os.Build
import android.provider.DocumentsContract
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.lang.reflect.Method

class MainActivity : FlutterActivity() {
    private val FILE_CHANNEL = "com.example.offline_file_sharing/file_operations"
    private val HOTSPOT_CHANNEL = "com.example.offline_file_sharing/hotspot"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // File operations channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FILE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openFolder" -> {
                    val folderPath = call.argument<String>("folderPath")
                    if (folderPath != null) {
                        val success = openFolder(folderPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Folder path is required", null)
                    }
                }
                "openFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = openFile(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                "shareFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = shareFile(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "File path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        // Hotspot operations channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, HOTSPOT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "canCreateHotspot" -> {
                    val canCreate = canCreateHotspot()
                    result.success(canCreate)
                }
                "createHotspot" -> {
                    val networkName = call.argument<String>("networkName")
                    val password = call.argument<String>("password")
                    if (networkName != null && password != null) {
                        val success = createHotspot(networkName, password)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Network name and password are required", null)
                    }
                }
                "stopHotspot" -> {
                    val success = stopHotspot()
                    result.success(success)
                }
                "isHotspotActive" -> {
                    val isActive = isHotspotActive()
                    result.success(isActive)
                }
                "getHotspotInfo" -> {
                    val info = getHotspotInfo()
                    result.success(info)
                }
                "openWiFiSettings" -> {
                    val success = openWiFiSettings()
                    result.success(success)
                }
                "openHotspotSettings" -> {
                    val success = openHotspotSettings()
                    result.success(success)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openFolder(folderPath: String): Boolean {
        return try {
            val folder = File(folderPath)
            val parentFolder = if (folder.isFile) folder.parentFile else folder
            
            if (parentFolder == null || !parentFolder.exists()) {
                return false
            }

            // Try to open with file manager
            val intent = Intent(Intent.ACTION_VIEW).apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // Use FileProvider for Android 7+
                    val uri = FileProvider.getUriForFile(
                        this@MainActivity,
                        "${applicationContext.packageName}.fileprovider",
                        parentFolder
                    )
                    setDataAndType(uri, DocumentsContract.Document.MIME_TYPE_DIR)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    // Direct file URI for older versions
                    setDataAndType(Uri.fromFile(parentFolder), DocumentsContract.Document.MIME_TYPE_DIR)
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            // Try to start the intent
            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }

            // Fallback: Open Downloads folder or file manager
            return openDownloadsFolder()
        } catch (e: Exception) {
            e.printStackTrace()
            // Fallback to opening Downloads folder
            openDownloadsFolder()
        }
    }

    private fun openDownloadsFolder(): Boolean {
        return try {
            // Try to open Downloads folder specifically
            val intent = Intent(Intent.ACTION_VIEW).apply {
                type = DocumentsContract.Document.MIME_TYPE_DIR
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }

            // Final fallback: Open any file manager
            val fileManagerIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "*/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (fileManagerIntent.resolveActivity(packageManager) != null) {
                startActivity(fileManagerIntent)
                return true
            }

            false
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun openFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                return false
            }

            val intent = Intent(Intent.ACTION_VIEW).apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val uri = FileProvider.getUriForFile(
                        this@MainActivity,
                        "${applicationContext.packageName}.fileprovider",
                        file
                    )
                    setDataAndType(uri, getMimeType(file))
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    setDataAndType(Uri.fromFile(file), getMimeType(file))
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                return true
            }

            false
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun shareFile(filePath: String): Boolean {
        return try {
            val file = File(filePath)
            if (!file.exists()) {
                return false
            }

            val intent = Intent(Intent.ACTION_SEND).apply {
                type = getMimeType(file)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    val uri = FileProvider.getUriForFile(
                        this@MainActivity,
                        "${applicationContext.packageName}.fileprovider",
                        file
                    )
                    putExtra(Intent.EXTRA_STREAM, uri)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } else {
                    putExtra(Intent.EXTRA_STREAM, Uri.fromFile(file))
                }
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            val chooser = Intent.createChooser(intent, "Share file")
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(chooser)
            return true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun getMimeType(file: File): String {
        val extension = file.extension.lowercase()
        return when (extension) {
            "pdf" -> "application/pdf"
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "gif" -> "image/gif"
            "mp4" -> "video/mp4"
            "mp3" -> "audio/mpeg"
            "txt" -> "text/plain"
            "json" -> "application/json"
            "zip" -> "application/zip"
            else -> "*/*"
        }
    }

    // Hotspot functionality methods
    private fun canCreateHotspot(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // Android 8+ requires special permissions and is more restricted
                false
            } else {
                // Check if we can access WifiManager
                val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
                wifiManager != null
            }
        } catch (e: Exception) {
            false
        }
    }

    private fun createHotspot(networkName: String, password: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // For Android 8+, always redirect to system settings
                openHotspotSettings()
                false
            } else {
                // For older Android versions, try programmatic approach first
                val success = createHotspotLegacy(networkName, password)
                if (!success) {
                    openHotspotSettings()
                }
                success
            }
        } catch (e: Exception) {
            // Always fallback to opening settings
            openHotspotSettings()
            false
        }
    }

    private fun createHotspotLegacy(networkName: String, password: String): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            
            // Create WifiConfiguration
            val wifiConfig = WifiConfiguration().apply {
                SSID = networkName
                preSharedKey = password
                allowedKeyManagement.set(WifiConfiguration.KeyMgmt.WPA_PSK)
                allowedAuthAlgorithms.set(WifiConfiguration.AuthAlgorithm.OPEN)
            }

            // Use reflection to access hidden methods
            val method: Method = wifiManager.javaClass.getMethod("setWifiApEnabled", WifiConfiguration::class.java, Boolean::class.javaPrimitiveType)
            method.invoke(wifiManager, wifiConfig, true) as Boolean
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun stopHotspot(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                // For Android 8+, always redirect to system settings
                openHotspotSettings()
                false
            } else {
                // For older Android versions, try programmatic approach first
                val success = stopHotspotLegacy()
                if (!success) {
                    openHotspotSettings()
                }
                success
            }
        } catch (e: Exception) {
            openHotspotSettings()
            false
        }
    }

    private fun stopHotspotLegacy(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method: Method = wifiManager.javaClass.getMethod("setWifiApEnabled", WifiConfiguration::class.java, Boolean::class.javaPrimitiveType)
            method.invoke(wifiManager, null, false) as Boolean
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isHotspotActive(): Boolean {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method: Method = wifiManager.javaClass.getMethod("isWifiApEnabled")
            method.invoke(wifiManager) as Boolean
        } catch (e: Exception) {
            false
        }
    }

    private fun getHotspotInfo(): Map<String, String>? {
        return try {
            val wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
            val method: Method = wifiManager.javaClass.getMethod("getWifiApConfiguration")
            val config = method.invoke(wifiManager) as? WifiConfiguration
            
            config?.let {
                mapOf(
                    "networkName" to (it.SSID ?: ""),
                    "password" to (it.preSharedKey ?: ""),
                    "ip" to "192.168.43.1"
                )
            }
        } catch (e: Exception) {
            null
        }
    }

    private fun openWiFiSettings(): Boolean {
        return try {
            val intent = Intent(Settings.ACTION_WIFI_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                // Fallback to wireless settings
                val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } catch (e2: Exception) {
                false
            }
        }
    }

    private fun openHotspotSettings(): Boolean {
        return try {
            // Try to open tethering settings directly
            val intent = Intent().apply {
                setClassName("com.android.settings", "com.android.settings.TetherSettings")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            try {
                // Fallback to wireless settings
                val intent = Intent(Settings.ACTION_WIRELESS_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(intent)
                true
            } catch (e2: Exception) {
                try {
                    // Final fallback to general settings
                    val intent = Intent(Settings.ACTION_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    true
                } catch (e3: Exception) {
                    false
                }
            }
        }
    }
}
