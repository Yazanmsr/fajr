package com.example.fajr;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;
import android.widget.Toast;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;

public class AlarmBootReceiver extends BroadcastReceiver {

    @Override
    public void onReceive(Context context, Intent intent) {
        // Optional toast for testing (will not show on all Android versions)
        Toast.makeText(context, "AlarmBootReceiver triggered", Toast.LENGTH_LONG).show();

        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            // Log + optional file log already exists

            SharedPreferences prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE);
            long nextFajrMillis = prefs.getLong("flutter.next_fajr_millis", -1);
            boolean azanEnabled = prefs.getBoolean("flutter.azan_enabled", true);

            if (azanEnabled && nextFajrMillis > System.currentTimeMillis()) {
                Intent alarmIntent = new Intent(context, AlarmReceiver.class);
                PendingIntent pendingIntent = PendingIntent.getBroadcast(
                        context, 1, alarmIntent, PendingIntent.FLAG_IMMUTABLE);

                AlarmManager alarmManager = (AlarmManager) context.getSystemService(Context.ALARM_SERVICE);
                alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, nextFajrMillis, pendingIntent
                );
            }
        }

    }
}
