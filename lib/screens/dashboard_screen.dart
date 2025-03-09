import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_database/firebase_database.dart'; // Import the Firebase Database package
import '../utils/telegram_logger.dart'; // Import the TelegramLogger
import 'package:geocoding/geocoding.dart'; // Import geocoding package
import 'package:geolocator/geolocator.dart'; // Import geolocator package
import 'package:audioplayers/audioplayers.dart'; // Import audioplayers package
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences package
import 'package:pull_to_refresh/pull_to_refresh.dart'; // Import pull_to_refresh package

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
  final RefreshController _refreshController = RefreshController(initialRefresh: false);
  List<Map<String, dynamic>> undoneTasks = [];
  List<Map<String, dynamic>> doneTasks = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _fetchTasks();
  }

  Future<void> _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      isBeepSoundEnabled = prefs.getBool('isBeepSoundEnabled') ?? true;
    });
  }

  Future<void> _fetchTasks() async {
    DatabaseReference tasksRef = FirebaseDatabase.instance.ref("users/${widget.user}/tasks");
    DatabaseEvent event = await tasksRef.once();
    if (event.snapshot.value != null) {
      Map<String, dynamic> tasks = Map<String, dynamic>.from(event.snapshot.value as Map);
      setState(() {
        undoneTasks = tasks.entries.where((entry) => !entry.value['done']).map((entry) => entry.value as Map<String, dynamic>).toList();
        doneTasks = tasks.entries.where((entry) => entry.value['done']).map((entry) => entry.value as Map<String, dynamic>).toList();
      });
    }
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

  void _onRefresh() async {
    await _fetchTasks();
    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard"),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: SmartRefresher(
        controller: _refreshController,
        onRefresh: _onRefresh,
        child: ListView(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Undone Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...undoneTasks.map((task) => Card(
                    child: ListTile(
                      title: Text(task['name']),
                      subtitle: Text(task['data']),
                      trailing: Icon(Icons.check_box_outline_blank),
                    ),
                  )),
                  Text("Done Tasks", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...doneTasks.map((task) => Card(
                    child: ListTile(
                      title: Text(task['name']),
                      subtitle: Text(task['data']),
                      trailing: Icon(Icons.check_box),
                    ),
                  )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Total Tasks: ${undoneTasks.length + doneTasks.length}"),
                  Text("Undone Tasks: ${undoneTasks.length}"),
                ],
              ),
            ),
            Column(
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
                              SizedBox(height: 20),
                              Text(scannedData.isNotEmpty ? "Scanned: $scannedData" : "Scan a QR code"),
                              if (qrProfileInfo != null)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        "Name: ${qrProfileInfo!['name']}",
                                        style: TextStyle(color: Colors.green, fontSize: 18),
                                      ),
                                      Text(
                                        "Category: ${qrProfileInfo!['category']}",
                                        style: TextStyle(color: Colors.green, fontSize: 18),
                                      ),
                                      Text(
                                        "Phone: ${qrProfileInfo!['phone']}",
                                        style: TextStyle(color: Colors.green, fontSize: 18),
                                      ),
                                      Text(
                                        "Location: ${qrProfileInfo!['location']}",
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
          ],
        ),
      ),
    );
  }
}
