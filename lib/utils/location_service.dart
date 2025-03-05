import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<void> updateLocation(String userId) async {
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    DatabaseReference ref = FirebaseDatabase.instance.ref("locations/$userId");
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
