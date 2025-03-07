import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async'; // Import dart:async for Timer

class LocationService {
  static Future<void> updateLocation(String username, Position position) async {
    final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref("users/$username/location");
    await _databaseRef.set({
      "latitude": position.latitude,
      "longitude": position.longitude,
      "timestamp": DateTime.now().toIso8601String(),
    });
  }

  static void startLocationUpdates(String userId) {
    getPositionStream().listen((Position position) async {
      await updateLocation(userId, position);
    });
  }

  static Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update location every 10 meters
      ),
    );
  }

  static void startPeriodicLocationUpdates(String userId) {
    Timer.periodic(Duration(seconds: 1), (timer) async {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await updateLocation(userId, position);
    });
  }
}
