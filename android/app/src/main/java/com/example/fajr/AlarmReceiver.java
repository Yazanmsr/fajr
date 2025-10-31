package com.example.fajr;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.SharedPreferences;
import android.util.Log;
import android.media.MediaPlayer;

import java.io.File;


public class AlarmReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        Log.d("AlarmReceiver", "Alarm triggered!");

        try {
            // ✅ Optionally play audio or show notification here
            // You already have audio code — keep or remove as needed

            // ✅ Launch the app
            Intent launchIntent = new Intent(context, MainActivity.class);
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(launchIntent);

            // ✅ Schedule next day's alarm
            SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            boolean enabled = prefs.getBoolean("flutter.azan_enabled", true);

            if (enabled) {
                long nextMillis = prefs.getLong("flutter.next_fajr_millis", -1);
                if (nextMillis > 0) {
                    // Add 24 hours
                    long nextDayMillis = nextMillis + 24 * 60 * 60 * 1000;
                    prefs.edit().putLong("flutter.next_fajr_millis", nextDayMillis).apply();

                    Intent nextIntent = new Intent(context, AlarmReceiver.class);
                    PendingIntent pendingIntent = PendingIntent.getBroadcast(
                            context, 0, nextIntent, PendingIntent.FLAG_IMMUTABLE
                    );

                    AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
                    alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            nextDayMillis,
                            pendingIntent
                    );

                    Log.d("AlarmReceiver", "Next day's alarm set for: " + nextDayMillis);
                }
            }
        } catch (Exception e) {
            Log.e("AlarmReceiver", "Failed in onReceive: " + e.getMessage());
        }
    }

}
