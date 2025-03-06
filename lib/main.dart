import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // Import Firebase options
import 'screens/dashboard_screen.dart'; // Import Dashboard Screen
import 'screens/login_screen.dart'; // Import Login Screen
import 'utils/permissions_handler.dart'; // Import Permissions Handler
import 'utils/location_service.dart'; // Import Location Service
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart'; // Import AndroidServiceInstance
import 'package:geolocator/geolocator.dart'; // Import Geolocator package
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import Flutter Local Notifications
import 'package:permission_handler/permission_handler.dart'; // Import Permission Handler

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Initialize Firebase
    await PermissionsHandler.requestPermissions();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');

    runApp(QRClientApp(initialScreen: username != null && password != null ? DashboardScreen(user: username) : LoginScreen()));

    await requestNotificationPermission(); // Request notification permission

    await initializeService();
  } catch (e) {
    runApp(ErrorApp("Failed to initialize app: $e"));
  }
}

Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'my_foreground', // id
    'Foreground Service', // title
    description: 'This channel is used for the foreground service.',
    importance: Importance.high, // Set importance to High
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  var initializationSettingsAndroid =
      const AndroidInitializationSettings('@mipmap/ic_launcher');
  var initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: 'QR Client',
      initialNotificationContent: 'App is running in the background',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

void onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails notificationDetails =
        AndroidNotificationDetails(
      'my_foreground',
      'Foreground Service',
      channelDescription: 'This channel is used for foreground services',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
    );

    const NotificationDetails notificationSettings =
        NotificationDetails(android: notificationDetails);

    await flutterLocalNotificationsPlugin.show(
      888, // Notification ID
      'QR Client',
      'App is running in the background',
      notificationSettings,
    );

    service.setForegroundNotificationInfo(
      title: "QR Client",
      content: "App is running in the background",
    );
  }

  service.on('setAsForeground').listen((event) {
    service.setAsForegroundService();
  });

  service.on('setAsBackground').listen((event) {
    service.setAsBackgroundService();
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  LocationService.getPositionStream().listen((Position position) {
    SharedPreferences.getInstance().then((prefs) {
      String? username = prefs.getString('username');
      if (username != null) {
        LocationService.updateLocation(username, position);
      }
    });
  });
}

bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  return true;
}

class QRClientApp extends StatelessWidget {
  final Widget initialScreen;

  QRClientApp({required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: initialScreen,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String errorMessage;

  ErrorApp(this.errorMessage);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: Text("Error")),
        body: Center(
          child: Text("Error initializing app: $errorMessage"),
        ),
      ),
    );
  }
}
