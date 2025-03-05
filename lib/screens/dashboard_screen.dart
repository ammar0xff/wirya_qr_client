import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart'; // Import the Firebase Database package
import '../utils/telegram_logger.dart'; // Import the TelegramLogger
import 'history_of_scans_screen.dart'; // Import History of Scans Screen
import 'analytics_screen.dart'; // Import Analytics Screen
import 'settings_screen.dart'; // Import Settings Screen
import 'about_screen.dart'; // Import About Screen
import 'package:geocoding/geocoding.dart'; // Import geocoding package
import 'package:geolocator/geolocator.dart'; // Import geolocator package
import 'package:audioplayers/audioplayers.dart'; // Import audioplayers package
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences package

class DashboardScreen extends StatefulWidget {
  final String user;

  DashboardScreen({required this.user});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String scannedData = "";
  bool isLoading = false;
  String errorMessage = "";
  Map<String, dynamic>? qrProfileInfo;
  bool isBeepSoundEnabled = true;
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isBeepSoundEnabled = prefs.getBool('isBeepSoundEnabled') ?? true;
    });
  }

  void _onDetect(BarcodeCapture barcodeCapture) async {
    final barcode = barcodeCapture.barcodes.first;
    if (scannedData.isEmpty) {
      setState(() {
        scannedData = barcode.rawValue!;
        isLoading = true;
        errorMessage = "";
      });
      try {
        await _processScan(scannedData);
        if (isBeepSoundEnabled) {
          await audioPlayer.play(AssetSource('beep.mp3')); // Play beep sound
        }
        // Reset scannedData after a short delay to allow scanning another QR code
        Future.delayed(Duration(seconds: 2), () {
          setState(() {
            scannedData = "";
          });
        });
      } catch (e) {
        setState(() {
          errorMessage = "خطأ في معالجة المسح: $e";
        });
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _processScan(String uniqueId) async {
    // Fetch QR profile info
    DatabaseReference profileRef = FirebaseDatabase.instance.ref("profiles/$uniqueId");
    DatabaseEvent event = await profileRef.once();
    if (event.snapshot.value != null) {
      setState(() {
        qrProfileInfo = Map<String, dynamic>.from(event.snapshot.value as Map);
      });

      // Get current location
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      String scanLocation = "موقع غير معروف";
      if (placemarks.isNotEmpty) {
        scanLocation = placemarks.first.locality ?? "موقع غير معروف";
      }

      // Send log to Telegram Bot
      await TelegramLogger.sendLog(qrProfileInfo!, widget.user, scanLocation, position.latitude, position.longitude);
    } else {
      setState(() {
        errorMessage = "لم يتم العثور على الملف الشخصي.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("لوحة التحكم")),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(
                'القائمة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.history),
              title: Text("تاريخ المسح"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistoryOfScansScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics),
              title: Text("التحليلات"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AnalyticsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.settings),
              title: Text("الإعدادات"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsScreen()),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.info),
              title: Text("حول"),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AboutScreen()),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: _onDetect,
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Center(
              child: isLoading
                  ? CircularProgressIndicator()
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: 20), // Add space above the text
                        Text(scannedData.isNotEmpty ? "تم المسح: $scannedData" : "امسح رمز QR"),
                        if (qrProfileInfo != null)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                Text(
                                  "الاسم: ${qrProfileInfo!['name']}",
                                  style: TextStyle(color: Colors.green, fontSize: 18),
                                ),
                                Text(
                                  "الفئة: ${qrProfileInfo!['category']}",
                                  style: TextStyle(color: Colors.green, fontSize: 18),
                                ),
                                Text(
                                  "الهاتف: ${qrProfileInfo!['phone']}",
                                  style: TextStyle(color: Colors.green, fontSize: 18),
                                ),
                                Text(
                                  "الموقع: ${qrProfileInfo!['location']}",
                                  style: TextStyle(color: Colors.green, fontSize: 18),
                                ),
                              ],
                            ),
                          ),
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              errorMessage,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
