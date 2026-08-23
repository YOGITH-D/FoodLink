import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PredictionService {
  // Deployed backend URL, injected at build time via:
  //   flutter build apk --dart-define=API_BASE_URL=https://your-backend.onrender.com
  static const String _configuredBaseUrl = String.fromEnvironment('API_BASE_URL');

  // Determine API base URL: prefer the build-time value, else fall back to
  // local dev defaults (emulator loopback / localhost).
  String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl;
    }
    if (kIsWeb) {
      return 'http://localhost:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  // Predict remaining shelf life from backend API
  Future<double> predictShelfLife({
    required String foodType,
    required double temperature,
    required double timeSincePrep,
    required String storageCondition,
    required String packaging,
  }) async {
    final url = Uri.parse('$baseUrl/predict');
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'food_type': foodType,
          'temperature': temperature,
          'time_since_prep_hours': timeSincePrep,
          'storage_condition': storageCondition,
          'packaging': packaging,
        }),
      ).timeout(const Duration(seconds: 60)); // Generous timeout to absorb free-tier host cold starts

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return (data['remaining_consumable_hours'] as num).toDouble();
      } else {
        final errorMsg = jsonDecode(response.body)['detail'] ?? 'Unknown API error';
        throw Exception('Prediction API Error: $errorMsg');
      }
    } on SocketException catch (_) {
      throw Exception(
        'Cannot connect to the prediction server. Please verify the FastAPI backend is running at $baseUrl.',
      );
    } on http.ClientException catch (_) {
      throw Exception('Network error while communicating with the prediction server.');
    } catch (e) {
      // Re-throw any other exceptions (like timeouts or parse errors)
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Prediction API request timed out. The server may be waking up from idle — please wait ~30s and try again.');
      }
      throw Exception('Failed to connect to the shelf-life prediction API: ${e.toString()}');
    }
  }

  // Fetch food types metadata list from backend API
  Future<List<String>> fetchFoodTypes() async {
    final url = Uri.parse('$baseUrl/metadata');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['food_types']);
      } else {
        throw Exception('Failed to fetch food metadata.');
      }
    } catch (_) {
      // Fallback to static food types list for dropdowns if metadata fails,
      // but the actual prediction will still fail and block submission if the server is offline.
      return [
        'plain_rice',
        'jeera_rice',
        'veg_pulao',
        'chicken_biryani',
        'roti',
        'naan',
        'paratha',
        'dal_tadka',
        'paneer_butter_masala',
        'chicken_curry',
        'fish_curry',
        'milk',
        'curd',
        'samosa',
        'pakora',
        'idli',
        'dosa',
        'gulab_jamun',
        'halwa'
      ];
    }
  }
}
