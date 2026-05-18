class ApiConfig {
  static const String baseUrl =
      "https://fliq-6mh2.onrender.com"; // ← update this

  // ── Auth ──────────────────────────────────────────────────────
  static const String sendOtpEndpoint = "/auth/send-otp";
  static const String verifyOtpEndpoint = "/auth/verify-otp";
  static const String registerEndpoint = "/auth/register";
  static const String loginEndpoint = "/auth/login";
  static const String forgotPasswordEndpoint = "/auth/forgot-password";
  static const String resetPasswordEndpoint = "/auth/reset-password";
  static const String resendOtpEndpoint = "/auth/resend-otp";
  static const String meEndpoint = "/auth/me";
  static const String fcmTokenEndpoint = "/auth/fcm-token";
  static const String googleAuthEndpoint = "/auth/google";

  // ── User ──────────────────────────────────────────────────────
  static const String userStatsEndpoint = "/user/stats";

  // ── Coins ─────────────────────────────────────────────────────
  static const String coinBalanceEndpoint = "/coins/balance";
  static const String coinHistoryEndpoint = "/coins/history";

  // ── Tasks ─────────────────────────────────────────────────────
  static const String tasksEndpoint = "/tasks";

  // ── Referral ──────────────────────────────────────────────────
  static const String referralStatsEndpoint = "/referral/stats";
  static const String applyReferralEndpoint = "/referral/apply";

  // ── Leaderboard ───────────────────────────────────────────────
  static const String referralLeaderboardEndpoint = "/leaderboard/referral";
  // FIX: offerwallLeaderboardEndpoint was missing — used in api_service.dart line 387
  static const String offerwallLeaderboardEndpoint = "/leaderboard/offerwall";
  static const String watchLeaderboardEndpoint = "/leaderboard/watch";
  static const String leaderboardMyRankEndpoint = "/leaderboard/my-rank";
  static const String watchMyRankEndpoint = "/leaderboard/watch/my-rank";

  // ── Withdraw ──────────────────────────────────────────────────
  static const String withdrawEndpoint = "/withdraw";
  static const String withdrawHistoryEndpoint = "/withdraw/history";
  static const String withdrawRateEndpoint = "/withdraw/rate";
  static const String paymentDetailsEndpoint = "/withdraw/payment-details";

  // ── Promo ─────────────────────────────────────────────────────
  static const String promoRedeemEndpoint = "/promo/redeem";

  // ── Support ───────────────────────────────────────────────────
  static const String supportTicketEndpoint = "/support/ticket";

  // ── Upload ────────────────────────────────────────────────────
  static const String signUploadEndpoint = "/upload/sign";
  static const String signAvatarUploadEndpoint = "/upload/sign/avatar";

  // ── Config ────────────────────────────────────────────────────
  static const String configEndpoint = "/config";

  // ── Device ────────────────────────────────────────────────────
  static const String deviceCheckEndpoint = "/device/check";

  // ── Music / Video ─────────────────────────────────────────────
  static const String musicSearchEndpoint = "/music/search";
  static const String musicTrendingEndpoint = "/music/trending";
  static const String musicFeedEndpoint = "/music/feed";
  static const String musicWatchEndpoint = "/music/watch";
  static const String musicHistoryEndpoint = "/music/history";
  static const String musicLikeEndpoint = "/music/like";
  static const String musicLikesEndpoint = "/music/likes";
  static const String musicRecommendationsEndpoint = "/music/recommendations";

  // ── URL builder helpers ───────────────────────────────────────

  static String taskProgressEndpoint(String taskId) =>
      "/tasks/$taskId/progress";

  static String supportMessagesEndpoint(String ticketId) =>
      "/support/ticket/$ticketId/messages";

  static String sendSupportMessageEndpoint(String ticketId) =>
      "/support/ticket/$ticketId/message";

  static String coinHistoryUrl({
    int limit = 30,
    int offset = 0,
    String? type,
  }) {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
      if (type != null && type.isNotEmpty) 'type': type,
    };
    return Uri.parse('$baseUrl$coinHistoryEndpoint')
        .replace(queryParameters: params)
        .toString();
  }

  static String musicSearchUrl({
    required String q,
    String type = 'any',
    int maxResults = 20,
  }) {
    final params = <String, String>{
      'q': q,
      'type': type,
      'max_results': maxResults.toString(),
    };
    return Uri.parse('$baseUrl$musicSearchEndpoint')
        .replace(queryParameters: params)
        .toString();
  }

  static String musicTrendingUrl({
    String category = 'music',
    int maxResults = 20,
  }) {
    final params = <String, String>{
      'category': category,
      'max_results': maxResults.toString(),
    };
    return Uri.parse('$baseUrl$musicTrendingEndpoint')
        .replace(queryParameters: params)
        .toString();
  }

  static String musicFeedUrl({int page = 1}) {
    return Uri.parse('$baseUrl$musicFeedEndpoint')
        .replace(queryParameters: {'page': page.toString()}).toString();
  }

  static String musicHistoryUrl({int limit = 30, int offset = 0}) {
    return Uri.parse('$baseUrl$musicHistoryEndpoint').replace(queryParameters: {
      'limit': limit.toString(),
      'offset': offset.toString(),
    }).toString();
  }
}
