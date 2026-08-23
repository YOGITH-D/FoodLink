import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class AddressSuggestion {
  final String displayName;
  final double latitude;
  final double longitude;

  const AddressSuggestion({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

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

  // Search for address suggestions as the user types, using OpenStreetMap's
  // free Nominatim geocoding search (no API key required). Per Nominatim's
  // usage policy, requests are capped to light/interactive use and must
  // identify the app via User-Agent — callers should debounce keystrokes
  // rather than calling this on every character.
  Future<List<AddressSuggestion>> searchAddress(String query) async {
    if (query.trim().length < 3) return [];

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search'
      '?q=${Uri.encodeQueryComponent(query)}&format=json&limit=5',
    );

    try {
      final response = await http
          .get(url, headers: {'User-Agent': 'FoodLink-App/1.0 (college project)'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final List<dynamic> results = jsonDecode(response.body);
      return results
          .map((r) => AddressSuggestion(
                displayName: r['display_name'] as String,
                latitude: double.parse(r['lat'] as String),
                longitude: double.parse(r['lon'] as String),
              ))
          .toList();
    } catch (_) {
      return [];
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
