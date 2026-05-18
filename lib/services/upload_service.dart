import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'api_service.dart';

class UploadService {
  final ApiService _api;
  UploadService(this._api);

  Future<Map<String, dynamic>> uploadSupportImage(File file) async {
    final sig = await _api.getUploadSignature(folder: 'support');
    return _upload(file, sig);
  }

  Future<Map<String, dynamic>> uploadAvatar(File file) async {
    final sig = await _api.getAvatarUploadSignature();
    return _upload(file, sig);
  }

  Future<Map<String, dynamic>> _upload(
      File file, Map<String, dynamic> sig) async {
    final cloudName = sig['cloud_name'] as String;
    final apiKey = sig['api_key'] as String;
    final timestamp = sig['timestamp'].toString();
    final signature = sig['signature'] as String;
    final folder = sig['folder'] as String? ?? 'support';
    final resourceType = sig['resource_type'] as String? ?? 'image';

    final url =
        'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload';
    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.fields['api_key'] = apiKey;
    request.fields['timestamp'] = timestamp;
    request.fields['signature'] = signature;
    request.fields['folder'] = folder;
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();
    if (response.statusCode == 200)
      return jsonDecode(body) as Map<String, dynamic>;
    throw Exception('Upload failed: $body');
  }
}
