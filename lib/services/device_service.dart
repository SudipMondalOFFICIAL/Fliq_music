// ╔══════════════════════════════════════════════════════════════════╗
// ║          device_service.dart — Device Fingerprint               ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class DeviceService {
  static const _deviceIdKey = 'filq_device_id';
  static String? _cachedDeviceId;
  static Map<String, dynamic>? _cachedDeviceInfo;

  static final _plugin = DeviceInfoPlugin();

  /// Returns a stable unique device ID.
  /// Uses Android ID first, falls back to generated UUID stored in prefs.
  static Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;

    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        // Android ID is stable per device + app signing
        final aid = info.id;
        if (aid.isNotEmpty && aid != 'unknown') {
          _cachedDeviceId = 'android_$aid';
          return _cachedDeviceId!;
        }
      }
    } catch (_) {}

    // Fallback: stored UUID
    final prefs = await SharedPreferences.getInstance();
    String? stored = prefs.getString(_deviceIdKey);
    if (stored == null || stored.isEmpty) {
      stored = _generateUuid();
      await prefs.setString(_deviceIdKey, stored);
    }
    _cachedDeviceId = stored;
    return _cachedDeviceId!;
  }

  /// Returns device hardware info (brand, model, OS, etc.)
  static Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_cachedDeviceInfo != null) return _cachedDeviceInfo!;
    try {
      if (Platform.isAndroid) {
        final info = await _plugin.androidInfo;
        _cachedDeviceInfo = {
          'platform': 'android',
          'brand': info.brand,
          'model': info.model,
          'android_version': info.version.release,
          'sdk': info.version.sdkInt,
          'device': info.device,
          'hardware': info.hardware,
          'is_physical': info.isPhysicalDevice,
        };
      } else {
        _cachedDeviceInfo = {'platform': 'unknown'};
      }
    } catch (_) {
      _cachedDeviceInfo = {'platform': 'android'};
    }
    return _cachedDeviceInfo!;
  }

  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int n) => n.toRadixString(16).padLeft(2, '0');
    return '${bytes.sublist(0, 4).map(hex).join()}-'
        '${bytes.sublist(4, 6).map(hex).join()}-'
        '${bytes.sublist(6, 8).map(hex).join()}-'
        '${bytes.sublist(8, 10).map(hex).join()}-'
        '${bytes.sublist(10).map(hex).join()}';
  }
}
