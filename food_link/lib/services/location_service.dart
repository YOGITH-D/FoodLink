import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  // Determine user's current GPS coordinates
  Future<Position> determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Return a default mock position (Mumbai, India) if services are disabled (e.g. on emulator/desktop)
      return _getFallbackMockPosition();
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return _getFallbackMockPosition();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return _getFallbackMockPosition();
    }

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return _getFallbackMockPosition();
    }
  }

  // Get address text from coordinates
  Future<String> getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.name != null && place.name!.isNotEmpty ? '${place.name}, ' : ''}'
            '${place.locality != null && place.locality!.isNotEmpty ? '${place.locality}, ' : ''}'
            '${place.administrativeArea != null && place.administrativeArea!.isNotEmpty ? place.administrativeArea : ''}';
      }
      return '$lat, $lng';
    } catch (_) {
      // Return generic coordinates string if geocoding fails
      return '$lat, $lng';
    }
  }

  // Calculate distance in kilometers
  double calculateDistance(double startLat, double startLng, double endLat, double endLng) {
    double distanceInMeters = Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
    return distanceInMeters / 1000.0;
  }

  // Fallback mock position (e.g. center of Mumbai, Colaba)
  Position _getFallbackMockPosition() {
    return Position(
      latitude: 18.9217,
      longitude: 72.8330,
      timestamp: DateTime.now(),
      accuracy: 0.0,
      altitude: 0.0,
      heading: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
      altitudeAccuracy: 0.0,
      headingAccuracy: 0.0,
    );
  }
}
