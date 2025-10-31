import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adhan/adhan.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fajr/android_alarm_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tahajjud Azan App',
      home: HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  String? selectedCountry;
  DateTime? nextFajr;
  String? azanFilePath;
  bool azanEnabled = true;
  Map<String, Coordinates> countryCoords = {};
  final AudioPlayer audioPlayer = AudioPlayer();
  Future<void> stopAzan() async {
    try {
      await audioPlayer.stop();
      debugPrint("Azan stopped.");
    } catch (e) {
      debugPrint("Error stopping azan: $e");
    }
  }


  @override
  void initState() {
    super.initState();
    requestBatteryOptimizationExemption(); // ✅ here
    prepareAzanFile();
    loadCountryCoordinates().then((_) {
      loadSettingsAndSchedule();
    });
  }


  Future<void> loadSettingsAndSchedule() async {
    final prefs = await SharedPreferences.getInstance();

    final country = prefs.getString('country');
    final enabled = prefs.getBool('azan_enabled') ?? true;

    setState(() {
      selectedCountry = country;
      azanEnabled = enabled;
    });

    if (country != null && enabled) {
      await calculateAndScheduleFajr();
    }
  }



  @override
  void dispose() {
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> prepareAzanFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/azan.mp3';

    final file = File(filePath);
    if (!await file.exists()) {
      final assetBytes = await rootBundle.load("assets/azan.mp3");
      final bytes = assetBytes.buffer.asUint8List();
      await file.writeAsBytes(bytes);
      debugPrint("Azan copied to local storage: $filePath");
    } else {
      debugPrint("Azan file already exists: $filePath");
    }

    setState(() {
      azanFilePath = filePath;
    });
  }

  Future<void> loadCountryCoordinates() async {
    final jsonStr = await rootBundle.loadString('assets/country_coords.json');
    final List<dynamic> data = jsonDecode(jsonStr);
    countryCoords = {
      for (var item in data)
        item['name']: Coordinates(item['lat'].toDouble(), item['lng'].toDouble())
    };
  }

  Future<void> loadCountry() async {
    final prefs = await SharedPreferences.getInstance();
    final country = prefs.getString('country');
    if (country != null) {
      setState(() {
        selectedCountry = country;
      });
      await calculateAndScheduleFajr();
    }
  }

  Future<void> saveCountry(String country) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('country', country);
    setState(() {
      selectedCountry = country;
    });
    await calculateAndScheduleFajr();
  }

  Future<void> calculateAndScheduleFajr({bool fakeTime = false}) async {
    if (selectedCountry == null) return;

    final coordinates = countryCoords[selectedCountry!];
    if (coordinates == null) {
      debugPrint("Coordinates not found for $selectedCountry");
      return;
    }

    final params = CalculationMethod.muslim_world_league.getParameters();
    params.madhab = Madhab.hanafi;

    final prayerTimes = PrayerTimes.today(coordinates, params);

    DateTime fajrTime = prayerTimes.fajr.toLocal().subtract(const Duration(minutes: 30));

    if (fakeTime) {
      fajrTime = DateTime.now().add(Duration(seconds: 20));
    }

    setState(() {
      nextFajr = fajrTime;
    });

    await scheduleAzan(fajrTime);
  }

  Future<void> scheduleAzan(DateTime fajrTime) async {
    final platform = MethodChannel('android_alarm_manager_plus');
    try {
      await platform.invokeMethod('setClockAlarm', {
        'time': fajrTime.millisecondsSinceEpoch,
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('flutter.next_fajr_millis', fajrTime.millisecondsSinceEpoch);
      await prefs.setBool('flutter.azan_enabled', true);

      debugPrint("System alarm set for: $fajrTime");
    } catch (e) {
      debugPrint("Failed to set Clock alarm: $e");
    }
  }




  Future<void> requestBatteryOptimizationExemption() async {
    const platform = MethodChannel('android_alarm_manager_plus');
    try {
      await platform.invokeMethod('requestBatteryPermission');
      debugPrint("Requested battery optimization exemption.");
    } catch (e) {
      debugPrint("Error requesting battery permission: $e");
    }
  }


  static Future<void> playAzanStatic() async {
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/azan.mp3';

    final player = AudioPlayer();
    await player.play(DeviceFileSource(filePath));
    debugPrint("Azan played from Alarm Manager!");
  }

  Future<void> playAzan() async {
    try {
      if (azanFilePath != null) {
        await audioPlayer.play(DeviceFileSource(azanFilePath!));
        debugPrint("Azan is playing from local file.");
      } else {
        await audioPlayer.play(AssetSource('assets/azan.mp3'));
        debugPrint("Azan is playing from assets.");
      }
    } catch (e) {
      debugPrint("Error playing azan: $e");
    }
  }

  void showCountryPickerDialog() {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country country) {
        saveCountry(country.name);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Tahajjud App')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: selectedCountry == null
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select your country:",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: showCountryPickerDialog,
              child: Text("Choose Country"),
            )
          ],
        )
            : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Country: $selectedCountry",
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 16),
            if (nextFajr != null)
              Text(
                "${azanEnabled ? 'Next Tahajjud' : 'Azan Paused Until Resume'}: ${DateFormat.jm().format(nextFajr!)}",
                style: TextStyle(fontSize: 18, color: azanEnabled ? Colors.black : Colors.grey),
              ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => calculateAndScheduleFajr(fakeTime: true),
              child: Text("Run Tahajjud logic after 20 seconds (TEST)"),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => playAzan(),
              child: Text("Play Azan Immediately (TEST)"),
            ),

            SizedBox(height: 16),
            ElevatedButton(
              onPressed: showCountryPickerDialog,
              child: Text("Change Country"),
            ),
            SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => stopAzan(),
              child: Text("Stop Azan"),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await AndroidAlarmManager.cancel(0);
                await prefs.setBool('azan_enabled', false);
                setState(() {
                  azanEnabled = false;
                  nextFajr = nextFajr; // trigger rebuild
                });
                debugPrint("Azan scheduling paused.");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text("Pause Azan Schedule"),
            ),
            SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('azan_enabled', true);
                setState(() => azanEnabled = true);
                await calculateAndScheduleFajr();
                debugPrint("Azan scheduling resumed.");
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Resume Azan Schedule"),
            ),


          ],
        ),
      ),
    );
  }
}
