import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class LocationService {
  static void startLocationUpdates(String userId) {
    getPositionStream().listen((Position position) async {
      await updateLocation(userId, position);
    });
  }

  static Future<void> updateLocation(String userId, Position position) async {
    DatabaseReference ref = FirebaseDatabase.instance.ref("users/$userId/current_location");
    await ref.set({
      "latitude": position.latitude,
      "longitude": position.longitude,
      "timestamp": DateTime.now().millisecondsSinceEpoch,
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
}
