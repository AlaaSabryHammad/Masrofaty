package com.masrofaty.app.masrofaty

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony
import org.json.JSONArray
import org.json.JSONObject

class SmsReceiver : BroadcastReceiver() {

    companion object {
        var smsListener: ((sender: String, body: String, timestamp: Long) -> Unit)? = null

        private val BANK_KEYWORDS = listOf(
            "شراء", "خصم", "سحب", "إيداع", "ايداع", "مدى", "mada",
            "حوالة", "راتب", "بطاقة", "صراف", "pos", "atm",
            "alrajhi", "rajhi", "snb", "alahli", "alinma", "riyad",
            "bilad", "jazira", "stcpay", "urpay", "tiqmo", "cib", "misr"
        )

        fun isBankRelated(sender: String, body: String): Boolean {
            val text = (sender + " " + body).lowercase()
            return BANK_KEYWORDS.any { text.contains(it) }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent)
            if (messages.isNullOrEmpty()) return

            val sender = messages[0].displayOriginatingAddress ?: ""
            val fullBody = messages.joinToString("") { it.displayMessageBody ?: "" }
            val timestamp = messages[0].timestampMillis

            if (!isBankRelated(sender, fullBody)) {
                return
            }

            // Deliver immediately if app is in foreground
            smsListener?.invoke(sender, fullBody, timestamp)

            // Also persist to pending_sms in SharedPreferences so it won't be missed
            try {
                val prefs = context.getSharedPreferences("masrofaty_sms_prefs", Context.MODE_PRIVATE)
                val existingJson = prefs.getString("pending_sms", "[]") ?: "[]"
                val jsonArray = JSONArray(existingJson)

                val smsObj = JSONObject().apply {
                    put("sender", sender)
                    put("body", fullBody)
                    put("timestamp", timestamp)
                }
                jsonArray.put(smsObj)

                prefs.edit().putString("pending_sms", jsonArray.toString()).apply()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }
}
