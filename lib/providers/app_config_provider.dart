// ╔══════════════════════════════════════════════════════════════════╗
// ║          app_config_provider.dart — Server Config State          ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:convert';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/app_banner.dart';

class AppConfigProvider extends ChangeNotifier {
  final ApiService _api;

  Map<String, dynamic> _raw = {};
  List<AppBanner> _banners = [];
  SplashConfig _splashConfig = const SplashConfig();
  bool _maintenance = false;
  String _maintenanceMsg = 'App is under maintenance. Please try again later.';
  String _tagline = 'Earn coins, Get rewarded!';

  // ── Force Update ──────────────────────────────────────────────
  bool _forceUpdate = false;
  String _forceUpdateVersion = '';
  String _updateUrl = '';
  String _forceUpdateMsg =
      'A new version is available. Please update to continue.';

  AppConfigProvider(this._api);

  Map<String, dynamic> get raw => _raw;
  List<AppBanner> get allBanners => _banners;
  SplashConfig get splashConfig => _splashConfig;
  bool get maintenance => _maintenance;
  String get maintenanceMsg => _maintenanceMsg;
  String get tagline => _tagline;

  bool get forceUpdate => _forceUpdate;
  String get forceUpdateVersion => _forceUpdateVersion;
  String get updateUrl => _updateUrl;
  String get forceUpdateMsg => _forceUpdateMsg;

  List<AppBanner> bannersFor(String target) =>
      _banners.where((b) => b.enabled && b.target == target).toList();

  Future<void> load() async {
    try {
      _raw = await _api.getConfig();

      // ── Banners ───────────────────────────────────────────────
      final bannersRaw = _raw['banners'];
      if (bannersRaw != null) {
        try {
          List<dynamic> list;
          if (bannersRaw is String) {
            list = jsonDecode(bannersRaw) as List<dynamic>;
          } else if (bannersRaw is List) {
            list = bannersRaw;
          } else {
            list = [];
          }
          _banners = list
              .map((e) => AppBanner.fromJson(e as Map<String, dynamic>))
              .toList();
        } catch (_) {
          _banners = [];
        }
      }

      // ── Splash animation config ────────────────────────────────
      final splashRaw = _raw['splash_animation'];
      if (splashRaw != null) {
        try {
          Map<String, dynamic> sc;
          if (splashRaw is String) {
            sc = jsonDecode(splashRaw) as Map<String, dynamic>;
          } else if (splashRaw is Map) {
            sc = Map<String, dynamic>.from(splashRaw);
          } else {
            sc = {};
          }
          _splashConfig = SplashConfig.fromJson(sc);
        } catch (_) {}
      }

      // ── Maintenance ───────────────────────────────────────────
      _maintenance = _raw['maintenance_mode'] ?? false;
      _maintenanceMsg = _raw['maintenance_message'] ?? _maintenanceMsg;
      _tagline = _splashConfig.tagline.isNotEmpty
          ? _splashConfig.tagline
          : (_raw['splash_tagline'] ?? _tagline);

      // ── Force Update ──────────────────────────────────────────
      _forceUpdate = _raw['force_update'] ?? false;
      _forceUpdateVersion = _raw['force_update_version'] ?? '';
      _updateUrl = _raw['update_url'] ?? '';
      _forceUpdateMsg = _raw['force_update_message'] ??
          'A new version is available. Please update to continue.';

      notifyListeners();
    } catch (_) {}
  }
}
