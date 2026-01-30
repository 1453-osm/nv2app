package com.osm.NamazVaktim

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StopAlarmReceiver : BroadcastReceiver() {
	override fun onReceive(context: Context, intent: Intent) {
		// Servisi durdur
		try { context.stopService(Intent(context, MediaPlaybackService::class.java)) } catch (_: Exception) {}
		// Heads-up bildirimi varsa iptal et
		try {
			val req = intent.getIntExtra("requestCode", 0x900)
			val mgr = context.getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
			mgr.cancel(req)
		} catch (_: Exception) {}
	}
}


