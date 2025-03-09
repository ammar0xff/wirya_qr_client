import 'package:firebase_database/firebase_database.dart';
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
import 'package:wakelock_plus/wakelock_plus.dart'; // Import Wakelock package
import 'dart:async'; // Import dart:async for Timer
import 'screens/profile_screen.dart'; // Import Profile Screen
import 'screens/tasks_screen.dart'; // Import Tasks Screen
import 'screens/qr_scanner_screen.dart'; // Import QR Scanner Screen
import 'screens/about_screen.dart'; // Import About Screen
import 'screens/lock_check_screen.dart'; // Import Lock Check Screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Initialize Firebase
    await requestLocationPermission(); // Request location permission
    await PermissionsHandler.requestPermissions(); // Request other permissions
    await disableBatteryOptimization(); // Disable battery optimization

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? username = prefs.getString('username');
    String? password = prefs.getString('password');

    bool isLocked = await checkIfLocked(); // Check if the app is locked

    runApp(QRClientApp(
      initialScreen: isLocked
          ? LockCheckScreen()
          : (username != null && password != null ? MainScreen(user: username) : LoginScreen()),
    ));

    await requestNotificationPermission(); // Request notification permission

    await initializeService(); // Initialize the background service

    if (username != null) {
      LocationService.startPeriodicLocationUpdates(username); // Start periodic location updates
    }
  } catch (e) {
    runApp(ErrorApp("Failed to initialize app: $e"));
  }
}

Future<bool> checkIfLocked() async {
  DatabaseReference lockRef = FirebaseDatabase.instance.ref("locked");
  DatabaseEvent event = await lockRef.once();
  return event.snapshot.value == true;
}

Future<void> requestLocationPermission() async {
  // Check if location permission is granted
  var status = await Permission.location.status;
  if (status.isDenied) {
    // Request location permission
    status = await Permission.location.request();
    if (status.isPermanentlyDenied) {
      // If permanently denied, open app settings
      openAppSettings();
    }
  }
}

Future<void> requestNotificationPermission() async {
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> disableBatteryOptimization() async {
  if (await Permission.ignoreBatteryOptimizations.isDenied) {
    await Permission.ignoreBatteryOptimizations.request();
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

  await service.startService();
}

Future<void> onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'my_foreground', // id
      'Foreground Service', // title
      description: 'This channel is used for the foreground service.', // description
      importance: Importance.high, // importance
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    service.setForegroundNotificationInfo(
      title: "QR Client",
      content: "App is running in the background",
    );

    // Enable wake lock to keep the CPU awake
    WakelockPlus.enable();

    // Configure location settings for continuous updates
    final LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // High accuracy
      distanceFilter: 0, // Receive updates even if the device hasn't moved
    );

    // Listen to location updates
    Geolocator.getPositionStream(locationSettings: locationSettings).listen(
      (Position position) async {
        try {
          // Get the username from SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          String? username = prefs.getString('username');

          if (username != null) {
            // Upload the location
            await LocationService.updateLocation(username, position);
          }
        } catch (e) {
          print("Failed to upload location: $e");
        }
      },
    );

    // Stop the service when requested
    service.on('stopService').listen((event) {
      WakelockPlus.disable();
      service.stopSelf();
    });
  }
}

Future<bool> onIosBackground(ServiceInstance service) async {
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

class MainScreen extends StatefulWidget {
  final String user;

  MainScreen({required this.user});

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late TabController _tabController;

  static List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(user: 'user'), // Placeholder, replace with actual user
    ProfileScreen(),
    TasksScreen(),
    QRScannerScreen(),
    AboutScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _widgetOptions.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedIndex = _tabController.index;
      });
    });
    _widgetOptions[0] = DashboardScreen(user: widget.user); // Replace placeholder with actual user
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _tabController.animateTo(index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.task), label: 'Tasks'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'QR Scanner'),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: 'About'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}