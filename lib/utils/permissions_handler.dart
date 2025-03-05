import 'package:geolocator/geolocator.dart';

class PermissionsHandler {
  static Future<void> requestPermissions() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        throw Exception("Location permissions are permanently denied.");
      }
      if (permission == LocationPermission.denied) {
        // Permissions are denied, handle appropriately.
        throw Exception("Location permissions are denied.");
      }
    } catch (e) {
      print("Error requesting permissions: $e");
      throw e;
    }
  }
}
