import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart'; // Import Firebase options
import 'screens/dashboard_screen.dart'; // Import Dashboard Screen
import 'screens/login_screen.dart'; // Import Login Screen
import 'utils/permissions_handler.dart'; // Import Permissions Handler
import 'utils/location_service.dart'; // Import Location Service
import 'utils/battery_optimization_handler.dart'; // Import Battery Optimization Handler
import 'package:geolocator/geolocator.dart'; // Import Geolocator package
import 'package:workmanager/workmanager.dart'; // Import WorkManager

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

    await initializeWorkManager();
  } catch (e) {
    runApp(ErrorApp("Failed to initialize app: $e"));
  }
}

void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // Perform background task
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    if (username != null) {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      LocationService.updateLocation(username, position);
    }
    return Future.value(true);
  });
}

Future<void> initializeWorkManager() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: true, // Set to false in production
  );

  await Workmanager().registerPeriodicTask(
    "1",
    "simplePeriodicTask",
    frequency: Duration(minutes: 15), // Run every 15 minutes
  );
}

class QRClientApp extends StatelessWidget {
  final Widget initialScreen;

  QRClientApp({required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    BatteryOptimizationHandler.requestDisableBatteryOptimizations(context); // Request to disable battery optimizations

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
