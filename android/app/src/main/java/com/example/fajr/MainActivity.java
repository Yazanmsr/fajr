package com.example.fajr;

import android.content.Intent;
import android.content.Context;
import android.os.PowerManager;
import android.provider.Settings;
import android.net.Uri;
import android.provider.AlarmClock;

import java.util.Calendar;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "android_alarm_manager_plus";

    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    Context context = MainActivity.this;

                    if (call.method.equals("setClockAlarm")) {
                        long timeMillis = call.argument("time");

                        Calendar calendar = Calendar.getInstance();
                        calendar.setTimeInMillis(timeMillis);
                        int hour = calendar.get(Calendar.HOUR_OF_DAY);
                        int minute = calendar.get(Calendar.MINUTE);

                        Intent intent = new Intent(AlarmClock.ACTION_SET_ALARM);
                        intent.putExtra(AlarmClock.EXTRA_HOUR, hour);
                        intent.putExtra(AlarmClock.EXTRA_MINUTES, minute);
                        intent.putExtra(AlarmClock.EXTRA_MESSAGE, "Tahajjud Alarm");
                        intent.putExtra(AlarmClock.EXTRA_SKIP_UI, false); // let user confirm (skip not reliable)
                        intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);

                        if (intent.resolveActivity(context.getPackageManager()) != null) {
                            context.startActivity(intent);
                            result.success("Alarm set for " + hour + ":" + minute);
                        } else {
                            result.error("UNAVAILABLE", "No Clock app found", null);
                        }

                    } else if (call.method.equals("requestBatteryPermission")) {
                        String packageName = context.getPackageName();
                        PowerManager pm = (PowerManager) context.getSystemService(Context.POWER_SERVICE);

                        if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                            Intent intent = new Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS);
                            intent.setData(Uri.parse("package:" + packageName));
                            intent.setFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                            context.startActivity(intent);
                        }

                        result.success(null);

                    } else {
                        result.notImplemented();
                    }
                });
    }
}
