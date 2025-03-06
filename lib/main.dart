import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // Import Firebase options
import 'screens/dashboard_screen.dart'; // Import Dashboard Screen
import 'screens/login_screen.dart'; // Import Login Screen
import 'utils/permissions_handler.dart'; // Import Permissions Handler
import 'utils/location_service.dart'; // Import Location Service
import 'package:flutter_background_service/flutter_background_service.dart'; // Import Flutter Background Service

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Initialize Firebase
    await PermissionsHandler.requestPermissions();

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');

    runApp(QRClientApp(initialScreen: username != null && password != null ? DashboardScreen(user: username) : LoginScreen()));

    if (username != null) {
      LocationService.startLocationUpdates(username);
    }

    await initializeService();
  } catch (e) {
    runApp(ErrorApp("Failed to initialize app: $e"));
  }
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true, // Set to true to ensure the service runs continuously
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

void onStart(ServiceInstance service) {
  if (service is AndroidServiceInstance) {
    service.setForegroundNotificationInfo(
      title: "QR Client",
      content: "App is running in the background",
    );
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  SharedPreferences.getInstance().then((prefs) {
    String? username = prefs.getString('username');
    if (username != null) {
      LocationService.startLocationUpdates(username);
    }
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
