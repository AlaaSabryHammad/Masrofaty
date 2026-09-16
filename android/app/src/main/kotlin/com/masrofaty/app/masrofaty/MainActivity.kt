package com.masrofaty.app.masrofaty

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {

    private val METHOD_CHANNEL = "com.masrofaty.app/bank_sms"
    private val EVENT_CHANNEL = "com.masrofaty.app/bank_sms_stream"
    private val SMS_PERMISSION_REQ_CODE = 8821

    private var pendingPermissionResult: MethodChannel.Result? = null
    private var smsEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Event Channel for real-time incoming SMS
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEventSink = events
                    SmsReceiver.smsListener = { sender, body, timestamp ->
                        runOnUiThread {
                            smsEventSink?.success(
                                mapOf(
                                    "sender" to sender,
                                    "body" to body,
                                    "timestamp" to timestamp
                                )
                            )
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    smsEventSink = null
                    SmsReceiver.smsListener = null
                }
            })

        // Method Channel for permissions, pending SMS retrieval, and inbox scanning
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkPermissions" -> {
                        val receiveGranted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECEIVE_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        val readGranted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        result.success(receiveGranted && readGranted)
                    }

                    "requestPermissions" -> {
                        val receiveGranted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.RECEIVE_SMS
                        ) == PackageManager.PERMISSION_GRANTED
                        val readGranted = ContextCompat.checkSelfPermission(
                            this,
                            Manifest.permission.READ_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (receiveGranted && readGranted) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.RECEIVE_SMS,
                                    Manifest.permission.READ_SMS
                                ),
                                SMS_PERMISSION_REQ_CODE
                            )
                        }
                    }

                    "getPendingSms" -> {
                        try {
                            val prefs = getSharedPreferences("masrofaty_sms_prefs", Context.MODE_PRIVATE)
                            val jsonString = prefs.getString("pending_sms", "[]") ?: "[]"
                            val jsonArray = JSONArray(jsonString)
                            val list = mutableListOf<Map<String, Any>>()

                            for (i in 0 until jsonArray.length()) {
                                val obj = jsonArray.getJSONObject(i)
                                list.add(
                                    mapOf(
                                        "sender" to obj.optString("sender"),
                                        "body" to obj.optString("body"),
                                        "timestamp" to obj.optLong("timestamp")
                                    )
                                )
                            }
                            // Clear after retrieving
                            prefs.edit().remove("pending_sms").apply()
                            result.success(list)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }

                    "readRecentBankSms" -> {
                        val days = (call.argument<Int>("days") ?: 14)
                        val limit = (call.argument<Int>("limit") ?: 50)
                        try {
                            val recentSmsList = scanRecentBankSms(days, limit)
                            result.success(recentSmsList)
                        } catch (e: Exception) {
                            result.error("SMS_SCAN_ERROR", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun scanRecentBankSms(days: Int, limit: Int): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val readGranted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED

        if (!readGranted) return list

        val uri = Uri.parse("content://sms/inbox")
        val cutoffTime = System.currentTimeMillis() - (days * 24L * 60L * 60L * 1000L)
        val projection = arrayOf("address", "body", "date")
        val selection = "date >= ?"
        val selectionArgs = arrayOf(cutoffTime.toString())
        val sortOrder = "date DESC LIMIT $limit"

        var cursor: Cursor? = null
        try {
            cursor = contentResolver.query(uri, projection, selection, selectionArgs, sortOrder)
            if (cursor != null && cursor.moveToFirst()) {
                val addressIdx = cursor.getColumnIndex("address")
                val bodyIdx = cursor.getColumnIndex("body")
                val dateIdx = cursor.getColumnIndex("date")

                do {
                    val address = if (addressIdx != -1) cursor.getString(addressIdx) ?: "" else ""
                    val body = if (bodyIdx != -1) cursor.getString(bodyIdx) ?: "" else ""
                    val date = if (dateIdx != -1) cursor.getLong(dateIdx) else 0L

                    if (SmsReceiver.isBankRelated(address, body)) {
                        list.add(
                            mapOf(
                                "sender" to address,
                                "body" to body,
                                "timestamp" to date
                            )
                        )
                    }
                } while (cursor.moveToNext())
            }
        } catch (e: Exception) {
            e.printStackTrace()
        } finally {
            cursor?.close()
        }

        return list
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == SMS_PERMISSION_REQ_CODE) {
            val allGranted = grantResults.isNotEmpty() &&
                    grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(allGranted)
            pendingPermissionResult = null
        }
    }
}
