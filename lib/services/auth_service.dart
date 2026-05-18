// auth_service.dart
// Fix v3: googleSignIn এ referral_code optional parameter added

import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'api_service.dart';
import 'device_service.dart';
import '../models/user.dart';

class AuthService {
  static const _tokenKey = 'auth_token';

  // ─────────────────────────────────────────────────────────────────
  // ⚠️  এখানে তোমার Firebase Console → Project Settings →
  //     General → Web app → OAuth 2.0 Client ID বসাও।
  //     google-services.json এ oauth_client[client_type=3].client_id
  // ─────────────────────────────────────────────────────────────────
  static const _webClientId =
      '630847282007-ivvsvmbtejafq0ftr5tus9i40boojqv7.apps.googleusercontent.com'; // ← replace this

  final ApiService _api;
  SharedPreferences? _prefs;

  // serverClientId দেওয়া হলে Android-এ idToken পাওয়া যাবে
  final _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: _webClientId,
  );

  AuthService(this._api);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final t = _prefs?.getString(_tokenKey);
    if (t != null && t.isNotEmpty) _api.setToken(t);
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String name,
    String? phone,
    String? dob,
    String? referralCode,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final deviceInfo = await DeviceService.getDeviceInfo();
    final data = await _api.register(
      email: email,
      password: password,
      username: username,
      name: name,
      phone: phone,
      dob: dob,
      referralCode: referralCode,
      deviceId: deviceId,
      deviceInfo: deviceInfo,
    );
    final token = data['token'] as String? ?? '';
    await _saveToken(token);
    _api.setToken(token);
    return data;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final deviceId = await DeviceService.getDeviceId();
    final deviceInfo = await DeviceService.getDeviceInfo();
    final data = await _api.login(
      email: email,
      password: password,
      deviceId: deviceId,
      deviceInfo: deviceInfo,
    );
    final token = data['token'] as String? ?? '';
    await _saveToken(token);
    _api.setToken(token);
    return data;
  }

  // FIX v3: referral_code optional parameter added
  // এখন Google login এর সময় referral code দেওয়া যাবে
  // তবে register_screen থেকে এটা call হয় dialog দেখানোর আগে
  // তাই referralCode এখানে null থাকবে — dialog থেকে applyReferral() call হবে
  Future<Map<String, dynamic>> googleSignIn({String? referralCode}) async {
    await _googleSignIn.signOut(); // fresh login every time

    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;

    // serverClientId ছাড়া idToken null আসে — এখন null হবে না
    if (idToken == null) {
      throw Exception(
        'Google token পাওয়া যায়নি। '
        'Firebase Console থেকে Web Client ID সঠিকভাবে দেওয়া আছে কিনা দেখো।',
      );
    }

    final deviceId = await DeviceService.getDeviceId();
    final deviceInfo = await DeviceService.getDeviceInfo();

    final data = await _api.googleAuth(
      idToken: idToken,
      deviceId: deviceId,
      deviceInfo: deviceInfo,
      referralCode: referralCode, // ← pass through (সাধারণত null)
    );

    final token = data['token'] as String? ?? '';
    await _saveToken(token);
    _api.setToken(token);
    return data;
  }

  Future<User> getProfile() => _api.getProfile();

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? avatarUrl,
    String? phone,
    String? username,
    String? dob,
  }) =>
      _api.updateProfile(
        name: name,
        bio: bio,
        avatarUrl: avatarUrl,
        phone: phone,
        username: username,
        dob: dob,
      );

  Future<void> logout() async {
    await _googleSignIn.signOut();
    await _prefs?.remove(_tokenKey);
    _api.setToken('');
  }

  Future<void> _saveToken(String token) async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(_tokenKey, token);
  }

  String? getToken() => _prefs?.getString(_tokenKey);

  bool isLoggedIn() {
    final t = _prefs?.getString(_tokenKey);
    return t != null && t.isNotEmpty;
  }

  Future<void> registerFCMToken(String fcmToken) async {
    final deviceId = await DeviceService.getDeviceId();
    await _api.registerFCMToken(fcmToken, deviceId: deviceId);
  }

  Future<Map<String, dynamic>> checkDeviceAccount() async {
    final deviceId = await DeviceService.getDeviceId();
    return _api.checkDevice(deviceId);
  }
}
