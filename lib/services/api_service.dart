import 'package:http/http.dart' as http;
import 'dart:convert';
import '../constants/api_config.dart';
import '../models/user.dart';
import '../models/earning.dart';
import '../models/track_model.dart';

class ApiService {
  String _token = '';
  final http.Client _httpClient = http.Client();

  void setToken(String t) => _token = t;
  String get token => _token;

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      };

  void _check(http.Response r, String fallback) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    try {
      final e = jsonDecode(r.body);
      throw Exception(e['detail'] ?? fallback);
    } catch (ex) {
      if (ex is Exception) rethrow;
      throw Exception('$fallback (${r.statusCode})');
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  DEVICE
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> checkDevice(String deviceId) async {
    try {
      final r = await _httpClient
          .post(
            Uri.parse('${ApiConfig.baseUrl}${ApiConfig.deviceCheckEndpoint}'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'device_id': deviceId}),
          )
          .timeout(const Duration(seconds: 10));
      if (r.statusCode == 200)
        return jsonDecode(r.body) as Map<String, dynamic>;
    } catch (_) {}
    return {'has_account': false};
  }

  // ══════════════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════════════

  Future<void> sendOtp({
    required String email,
    required String password,
    String deviceId = '',
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.sendOtpEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_info': deviceInfo,
      }),
    );
    _check(r, 'Failed to send OTP');
  }

  Future<void> verifyOtp({required String email, required String otp}) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.verifyOtpEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    _check(r, 'Invalid or expired OTP');
  }

  Future<void> resendOtp(
      {required String email, required String purpose}) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resendOtpEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'purpose': purpose}),
    );
    _check(r, 'Failed to resend OTP');
  }

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
    required String name,
    String? phone,
    String? dob,
    String? referralCode,
    String deviceId = '',
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'username': username,
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (dob != null && dob.isNotEmpty) 'dob': dob,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
        'device_id': deviceId,
        'device_info': deviceInfo,
      }),
    );
    _check(r, 'Registration failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
    String deviceId = '',
    Map<String, dynamic> deviceInfo = const {},
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.loginEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'device_id': deviceId,
        'device_info': deviceInfo,
      }),
    );
    _check(r, 'Login failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> googleAuth({
    required String idToken,
    required String deviceId,
    required Map<String, dynamic> deviceInfo,
    String? referralCode,
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.googleAuthEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id_token': idToken,
        'device_id': deviceId,
        'device_info': deviceInfo,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode,
      }),
    );
    _check(r, 'Google sign in failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<void> forgotPassword(String email) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.forgotPasswordEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    _check(r, 'Failed to send reset code');
  }

  Future<void> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.resetPasswordEndpoint}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'otp': otp,
        'new_password': newPassword,
      }),
    );
    _check(r, 'Password reset failed');
  }

  Future<User> getProfile() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get profile failed');
    return User.fromJson(jsonDecode(r.body));
  }

  Future<bool> updateProfile({
    String? name,
    String? bio,
    String? avatarUrl,
    String? phone,
    String? username,
    String? dob,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (bio != null) body['bio'] = bio;
    if (avatarUrl != null) body['avatar_url'] = avatarUrl;
    if (phone != null) body['phone'] = phone;
    if (username != null) body['username'] = username;
    if (dob != null) body['dob'] = dob;
    if (body.isEmpty) return true;
    final r = await _httpClient.put(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.meEndpoint}'),
      headers: _headers(),
      body: jsonEncode(body),
    );
    return r.statusCode == 200;
  }

  Future<void> registerFCMToken(String fcmToken,
      {String platform = 'android', String deviceId = ''}) async {
    try {
      await _httpClient.post(
        Uri.parse('${ApiConfig.baseUrl}${ApiConfig.fcmTokenEndpoint}'),
        headers: _headers(),
        body: jsonEncode({
          'token': fcmToken,
          'platform': platform,
          'device_id': deviceId,
        }),
      );
    } catch (e) {
      // Non-critical — silently fail
    }
  }

  // ══════════════════════════════════════════════════════════════
  //  USER STATS
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getUserStats() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.userStatsEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get stats failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════
  //  COINS
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCoinBalance() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.coinBalanceEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get balance failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCoinHistory({
    int limit = 30,
    int offset = 0,
    String? type,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (type != null && type.isNotEmpty) 'type': type,
    };
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.coinHistoryEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Get history failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // Watch Ads removed

  // ══════════════════════════════════════════════════════════════
  //  PROMO
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> redeemPromo(String code) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.promoRedeemEndpoint}'),
      headers: _headers(),
      body: jsonEncode({'code': code}),
    );
    _check(r, 'Promo redemption failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════
  //  TASKS
  // ══════════════════════════════════════════════════════════════

  Future<List<EarnTask>> getTasks() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.tasksEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get tasks failed');
    final List<dynamic> data = jsonDecode(r.body);
    return data.map((e) => EarnTask.fromJson(e)).toList();
  }

  Future<Map<String, dynamic>> updateTaskProgress(String taskId,
      {int progress = 1}) async {
    final r = await _httpClient.post(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.tasksEndpoint}/$taskId/progress'),
      headers: _headers(),
      body: jsonEncode({'task_id': taskId, 'progress': progress}),
    );
    _check(r, 'Task update failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════
  //  REFERRAL
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> applyReferral({
    required String referralCode,
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.applyReferralEndpoint}'),
      headers: _headers(),
      body: jsonEncode({
        'referral_code': referralCode,
      }),
    );
    _check(r, 'Referral apply failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<ReferralStats> getReferralStats() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.referralStatsEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get referral stats failed');
    return ReferralStats.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  // ══════════════════════════════════════════════════════════════
  //  LEADERBOARD  (Game features removed — referral + offerwall)
  // ══════════════════════════════════════════════════════════════

  /// GET /leaderboard/referral → { leaderboard: [...] }
  Future<Map<String, dynamic>> getReferralLeaderboard() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.referralLeaderboardEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get referral leaderboard failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  /// GET /leaderboard/offerwall removed

  /// GET /leaderboard/my-rank → { referral_rank, total_referrals }
  Future<Map<String, dynamic>> getLeaderboardMyRank() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.leaderboardMyRankEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get my rank failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ══════════════════════════════════════════════════════════════
  //  WITHDRAW
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getWithdrawRate() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.withdrawRateEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get rate failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getPaymentDetails() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.paymentDetailsEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get payment details failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> savePaymentDetails({
    String? upiId,
    String? upiHolderName,
    String? upiPhone,
    String? accountName,
    String? accountNo,
    String? ifsc,
    String? bankPhone,
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.paymentDetailsEndpoint}'),
      headers: _headers(),
      body: jsonEncode({
        if (upiId != null) 'upi_id': upiId,
        if (upiHolderName != null) 'upi_holder_name': upiHolderName,
        if (upiPhone != null) 'upi_phone': upiPhone,
        if (accountName != null) 'account_name': accountName,
        if (accountNo != null) 'account_no': accountNo,
        if (ifsc != null) 'ifsc': ifsc,
        if (bankPhone != null) 'bank_phone': bankPhone,
      }),
    );
    _check(r, 'Save payment details failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createWithdraw({
    required int coins,
    required String method,
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.withdrawEndpoint}'),
      headers: _headers(),
      body: jsonEncode({'coins': coins, 'method': method}),
    );
    _check(r, 'Withdraw request failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<WithdrawRequest>> getWithdrawHistory() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.withdrawHistoryEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get withdraw history failed');
    final List<dynamic> data = jsonDecode(r.body);
    return data.map((e) => WithdrawRequest.fromJson(e)).toList();
  }

  // ══════════════════════════════════════════════════════════════
  //  SUPPORT
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> createOrGetTicket(
      {String subject = 'Support Request'}) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.supportTicketEndpoint}'),
      headers: _headers(),
      body: jsonEncode({'subject': subject}),
    );
    _check(r, 'Create ticket failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<SupportTicket?> getMyTicket() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.supportTicketEndpoint}'),
      headers: _headers(),
    );
    if (r.statusCode == 200) {
      final data = jsonDecode(r.body);
      if (data == null) return null;
      return SupportTicket.fromJson(data);
    }
    return null;
  }

  Future<List<SupportMessage>> getSupportMessages(String ticketId) async {
    final r = await _httpClient.get(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.supportTicketEndpoint}/$ticketId/messages'),
      headers: _headers(),
    );
    _check(r, 'Get messages failed');
    final List<dynamic> data = jsonDecode(r.body);
    return data.map((e) => SupportMessage.fromJson(e)).toList();
  }

  Future<SupportMessage> sendSupportMessage(String ticketId,
      {String? text, String? imageUrl}) async {
    final r = await _httpClient.post(
      Uri.parse(
          '${ApiConfig.baseUrl}${ApiConfig.supportTicketEndpoint}/$ticketId/message'),
      headers: _headers(),
      body: jsonEncode({'text': text ?? '', 'image_url': imageUrl ?? ''}),
    );
    _check(r, 'Send message failed');
    return SupportMessage.fromJson(jsonDecode(r.body));
  }

  // ══════════════════════════════════════════════════════════════
  //  UPLOAD / CLOUDINARY
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getUploadSignature(
      {String folder = 'support'}) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signUploadEndpoint}'),
      headers: _headers(),
      body: jsonEncode({'folder': folder, 'resource_type': 'image'}),
    );
    _check(r, 'Get upload signature failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAvatarUploadSignature() async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.signAvatarUploadEndpoint}'),
      headers: _headers(),
      body: jsonEncode({}),
    );
    _check(r, 'Get avatar signature failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // Offerwall removed

  // ══════════════════════════════════════════════════════════════
  //  CONFIG
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getConfig() async {
    final r = await _httpClient
        .get(Uri.parse('${ApiConfig.baseUrl}${ApiConfig.configEndpoint}'))
        .timeout(const Duration(seconds: 8));
    if (r.statusCode == 200) return jsonDecode(r.body) as Map<String, dynamic>;
    return {};
  }

  // ══════════════════════════════════════════════════════════════
  //  MUSIC / VIDEO
  // ══════════════════════════════════════════════════════════════

  Future<List<Track>> searchMusic({
    required String q,
    String type = 'any',
    int maxResults = 20,
  }) async {
    final params = <String, String>{
      'q': q,
      'type': type,
      'max_results': maxResults.toString(),
    };
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.musicSearchEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Music search failed');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Track>> getTrendingMusic({
    String category = 'music',
    int maxResults = 20,
  }) async {
    final params = <String, String>{
      'category': category,
      'max_results': maxResults.toString(),
    };
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.musicTrendingEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Get trending failed');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getMusicFeed({int page = 1}) async {
    final params = <String, String>{'page': page.toString()};
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.musicFeedEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Get feed failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> logWatch({
    required String ytVideoId,
    required int watchDurationSeconds,
    required int durationSeconds,
    String? title,
    String? thumbnail,
    String? channel,
    List<String>? tags,
    String? category,
  }) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.musicWatchEndpoint}'),
      headers: _headers(),
      body: jsonEncode({
        'yt_video_id': ytVideoId,
        'watch_duration_seconds': watchDurationSeconds,
        'duration_seconds': durationSeconds,
        if (title != null) 'title': title,
        if (thumbnail != null) 'thumbnail': thumbnail,
        if (channel != null) 'channel': channel,
        if (tags != null) 'tags': tags,
        if (category != null) 'category': category,
      }),
    );
    _check(r, 'Watch log failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getWatchHistory({
    int limit = 30,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.musicHistoryEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Get history failed');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final history = (data['history'] as List<dynamic>?) ?? [];
    return history.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> toggleLike(String ytVideoId,
      {bool liked = true}) async {
    final r = await _httpClient.post(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.musicLikeEndpoint}'),
      headers: _headers(),
      body: jsonEncode({
        'yt_video_id': ytVideoId,
        'liked': liked,
      }),
    );
    _check(r, 'Like toggle failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<List<Track>> getLikedVideos({
    int limit = 50,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.musicLikesEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Get likes failed');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final likes = (data['likes'] as List<dynamic>?) ?? [];
    return likes.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Track>> getRecommendations({int limit = 20}) async {
    final params = <String, String>{'limit': limit.toString()};
    final uri = Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.musicRecommendationsEndpoint}',
    ).replace(queryParameters: params);
    final r = await _httpClient.get(uri, headers: _headers());
    _check(r, 'Get recommendations failed');
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>?) ?? [];
    return results
        .map((e) => Track.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ══════════════════════════════════════════════════════════════
  //  LEADERBOARD - WATCH
  // ══════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getWatchLeaderboard() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.watchLeaderboardEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get watch leaderboard failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getWatchMyRank() async {
    final r = await _httpClient.get(
      Uri.parse('${ApiConfig.baseUrl}${ApiConfig.watchMyRankEndpoint}'),
      headers: _headers(),
    );
    _check(r, 'Get watch rank failed');
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  void dispose() => _httpClient.close();
}
