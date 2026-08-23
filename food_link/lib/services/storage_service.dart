import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

// Uploads donation photos to Cloudinary's free tier via an unsigned upload
// preset, instead of Firebase Storage (which now requires the paid Blaze
// plan to create a new bucket). Configure both values at build time:
//   flutter build apk \
//     --dart-define=CLOUDINARY_CLOUD_NAME=your-cloud-name \
//     --dart-define=CLOUDINARY_UPLOAD_PRESET=your-unsigned-preset
// Unsigned presets are safe to reference client-side (Cloudinary's standard
// pattern for browser/mobile uploads) — no API secret is exposed.
class StorageService {
  static const String _cloudName = String.fromEnvironment('CLOUDINARY_CLOUD_NAME');
  static const String _uploadPreset = String.fromEnvironment('CLOUDINARY_UPLOAD_PRESET');

  // Upload donation food image
  Future<String> uploadDonationImage(XFile imageFile) async {
    if (_cloudName.isEmpty || _uploadPreset.isEmpty) {
      // Not configured — degrade gracefully, UI already handles an empty imageUrl.
      await Future.delayed(const Duration(seconds: 1));
      return '';
    }

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/image/upload');
      final bytes = await imageFile.readAsBytes();
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: imageFile.name));

      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['secure_url'] as String;
      } else {
        throw Exception('Cloudinary upload failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to upload image: ${e.toString()}');
    }
  }
}
