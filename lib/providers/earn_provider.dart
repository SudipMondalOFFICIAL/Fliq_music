import 'package:flutter/material.dart';
import '../services/api_service.dart';

class EarnProvider extends ChangeNotifier {
  final ApiService _api;

  int _adsToday = 0;
  int _dailyAdLimit = 20;
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> _offerwallTasks = [];
  bool _offerwallLoading = false;

  // ── Offerwall Leaderboard ──────────────────────────────────────
  List<Map<String, dynamic>> _offerwallLeaderboard = [];
  bool _offerwallLeaderboardLoading = false;

  EarnProvider(this._api);

  int get adsToday => _adsToday;
  int get dailyAdLimit => _dailyAdLimit;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get adLimitReached => _adsToday >= _dailyAdLimit;
  int get adsRemaining => (_dailyAdLimit - _adsToday).clamp(0, _dailyAdLimit);

  List<Map<String, dynamic>> get offerwallTasks => _offerwallTasks;
  bool get offerwallLoading => _offerwallLoading;

  List<Map<String, dynamic>> get offerwallLeaderboard => _offerwallLeaderboard;
  bool get offerwallLeaderboardLoading => _offerwallLeaderboardLoading;

  Future<void> loadStats() async {
    try {
      final r = await _api.getUserStats();
      _adsToday = r['ads_today'] ?? 0;
      _dailyAdLimit = r['daily_ad_limit'] ?? 20;
      notifyListeners();
    } catch (_) {}
  }

  Future<int> onAdWatched({String network = 'ironsource'}) async {
    if (adLimitReached) return 0;
    try {
      final r = await _api.logAdView(adType: 'rewarded', network: network);
      _adsToday = r['ads_today'] ?? (_adsToday + 1);
      notifyListeners();
      return r['coins_earned'] ?? 0;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return 0;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  Future<void> loadOfferwallTasks() async {
    _offerwallLoading = true;
    notifyListeners();
    try {
      _offerwallTasks = await _api.getOfferwallTasks();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _offerwallLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadOfferwallLeaderboard() async {
    _offerwallLeaderboardLoading = true;
    notifyListeners();
    try {
      // api_service এ getOfferwallLeaderboard() method আছে
      final r = await _api.getOfferwallLeaderboard();
      _offerwallLeaderboard =
          List<Map<String, dynamic>>.from(r['leaderboard'] ?? []);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _offerwallLeaderboardLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> submitTask({
    required String taskId,
    required String screenshotUrl,
    String screenshotPublicId = '',
  }) async {
    try {
      final result = await _api.submitOfferwallTask(
        taskId: taskId,
        screenshotUrl: screenshotUrl,
        screenshotPublicId: screenshotPublicId,
      );
      await loadOfferwallTasks();
      return result;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return null;
    }
  }
}
