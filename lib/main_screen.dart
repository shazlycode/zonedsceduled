import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:location/location.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class PTime {
  final String? name;
  final DateTime? time;

  PTime({required this.name, required this.time});
}

class _MainScreenState extends State<MainScreen> {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  Location location = new Location();
  bool? _serviceEnabled;
  PermissionStatus? _permissionGranted;
  LocationData? _locationData;
  PrayerTimes? prayerTimes;
  List<PTime> todayPrayerTimes = [];

  Future<void> initNotifications() async {
    tz.initializeTimeZones();
    await FlutterTimezone.getLocalTimezone().then((currentTimeZone) {
      print("currentTimeZone: $currentTimeZone");
      return tz.setLocalLocation(tz.getLocation(currentTimeZone));
    });

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()!
        .requestNotificationsPermission();
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    final InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<LocationData> getLocationData() async {
    _serviceEnabled = await location.serviceEnabled();
    if (!_serviceEnabled!) {
      _serviceEnabled = await location.requestService();
      if (!_serviceEnabled!) {
        throw Exception("Service not enabled");
      }
    }

    _permissionGranted = await location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        throw Exception("Permission not granted");
      }
    }
    _locationData = await location.getLocation();
    debugPrint("Location data: ${_locationData!.latitude!}");
    return _locationData!;
  }

  Future<void> initAllServices() async {
    await initNotifications();
    await getLocationData();
    await getTodayPrayerTimes();
  }

  @override
  void initState() {
    initAllServices();
    super.initState();
  }

  NotificationDetails getNotificationDetails() {
    return const NotificationDetails(
      android: AndroidNotificationDetails('channel id', 'channel name',
          channelDescription: 'channel description',
          color: Colors.red,
          colorized: true,
          enableLights: true,
          subText: "Wellcome",
          visibility: NotificationVisibility.public,
          enableVibration: true,
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
          channelShowBadge: true,
          playSound: true,
          sound: RawResourceAndroidNotificationSound("s")),
    );
  }

  Future<void> notify() async {
    await flutterLocalNotificationsPlugin.show(
        1, "title", "body", getNotificationDetails());
  }

  DateTime now = DateTime.now();
  Future<void> scheduleNotification() async {
    for (var i = 0; i < todayPrayerTimes.length; i++) {
      if (todayPrayerTimes[i].time!.isAfter(DateTime.now())) {
        await flutterLocalNotificationsPlugin.zonedSchedule(
            i,
            todayPrayerTimes[i].name,
            "${todayPrayerTimes[i].name} now at ${todayPrayerTimes[i].time!.hour}:${todayPrayerTimes[i].time!.minute}",
            tz.TZDateTime.from(todayPrayerTimes[i].time!, tz.local),
            // tz.TZDateTime.now(tz.local).add(const Duration(seconds: 5)),
            getNotificationDetails(),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime);
        debugPrint(
            "🔔🔔🔔Notification for: ${todayPrayerTimes[i].name} SUCESSFULLY scheduled at: ${todayPrayerTimes[i].time}");
      }
    }
  }

  getTodayPrayerTimes() async {
    if (_locationData == null) {
      _locationData = await getLocationData();
    }

    if (_locationData != null) {
      final coordinates =
          Coordinates(_locationData!.latitude!, _locationData!.longitude!);
      final calculationParameters =
          CalculationMethod.umm_al_qura.getParameters();

      prayerTimes = PrayerTimes(coordinates,
          DateComponents.from(DateTime.now()), calculationParameters);

      todayPrayerTimes.add(PTime(name: "Fajr", time: prayerTimes!.fajr));
      todayPrayerTimes.add(PTime(name: "Dhuhr", time: prayerTimes!.dhuhr));
      todayPrayerTimes.add(PTime(name: "Asr", time: prayerTimes!.asr));
      todayPrayerTimes.add(PTime(name: "Maghrib", time: prayerTimes!.maghrib));
      todayPrayerTimes.add(PTime(name: "Isha", time: prayerTimes!.isha));
      setState(() {});
      await scheduleNotification();

      debugPrint(todayPrayerTimes.toString());
    } else {
      throw Exception("Failed to get location data");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('ZonedSceduled Notification'),
          actions: [
            IconButton(
              onPressed: () => notify(),
              icon: const Icon(Icons.notifications),
            ),
            IconButton(
              onPressed: () => scheduleNotification(),
              icon: const Icon(Icons.schedule),
            ),
          ],
        ),
        body: todayPrayerTimes.isEmpty
            ? Center(child: const CircularProgressIndicator())
            : SizedBox(
                height: 100,
                width: double.infinity,
                child: ListView.builder(
                    padding: EdgeInsets.all(10),
                    scrollDirection: Axis.horizontal,
                    itemCount: todayPrayerTimes.length,
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(todayPrayerTimes[index].name!),
                            Text(
                                "${todayPrayerTimes[index].time!.hour}:${todayPrayerTimes[index].time!.minute}"),
                          ],
                        ),
                      );
                    }),
              ));
  }
}
