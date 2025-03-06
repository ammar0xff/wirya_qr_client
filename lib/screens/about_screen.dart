import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/location_service.dart';

class AboutScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("About")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Developer's Contact Information",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text("Email: ammar0xf@gmail.com"),
            Text("Phone: 01558695202"),
            Text("Location: Suez, Egypt"),
            SizedBox(height: 16),
            Text(
              "About the App",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              "This app is a QR code scanner with the following features:",
            ),
            SizedBox(height: 8),
            Text(
              "1. Scan QR codes: Quickly and easily scan QR codes using your device's camera.\n"
              "2. View scan history: Keep track of all the QR codes you have scanned with a detailed history.\n"
              "3. View analytics: Analyze your scanning activity with comprehensive analytics.\n"
              "4. Enable/disable beep sound: Customize your scanning experience by enabling or disabling the beep sound.\n"
              "5. Share scanned data via Telegram bot: Share the scanned QR code data with others using a Telegram bot.",
            ),
            SizedBox(height: 16),
            Center(
              child: ElevatedButton(
                onPressed: () async {
                  Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
                  SharedPreferences prefs = await SharedPreferences.getInstance();
                  String? username = prefs.getString('username');
                  if (username != null) {
                    await LocationService.updateLocation(username, position);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Location uploaded successfully")));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("User not logged in")));
                  }
                },
                child: Text("Upload Location"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
