import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  final ApiService _api;

  List<Map<String, dynamic>> _referralLeaderboard = [];
  // FIX: Watch leaderboard added — was missing, api_service.dart has getWatchLeaderboard()
  List<Map<String, dynamic>> _watchLeaderboard = [];
  Map<String, dynamic>? _myRank;
  Map<String, dynamic>? _myWatchRank;
  bool _isLoading = false;
  bool _watchLoading = false;
  String? _error;

  LeaderboardProvider(this._api);

  List<Map<String, dynamic>> get referralLeaderboard => _referralLeaderboard;
  List<Map<String, dynamic>> get watchLeaderboard => _watchLeaderboard;
  Map<String, dynamic>? get myRank => _myRank;
  Map<String, dynamic>? get myWatchRank => _myWatchRank;
  bool get isLoading => _isLoading;
  bool get watchLoading => _watchLoading;
  String? get error => _error;

  Future<void> loadReferralLeaderboard() async {
    _isLoading = true;
    notifyListeners();
    try {
      final r = await _api.getReferralLeaderboard();
      _referralLeaderboard =
          List<Map<String, dynamic>>.from(r['leaderboard'] ?? []);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // FIX: Watch leaderboard loader — was completely missing
  Future<void> loadWatchLeaderboard() async {
    _watchLoading = true;
    notifyListeners();
    try {
      final r = await _api.getWatchLeaderboard();
      _watchLeaderboard =
          List<Map<String, dynamic>>.from(r['leaderboard'] ?? []);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _watchLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMyRank() async {
    try {
      _myRank = await _api.getLeaderboardMyRank();
      notifyListeners();
    } catch (_) {}
  }

  // FIX: Watch rank loader — was missing
  Future<void> loadMyWatchRank() async {
    try {
      _myWatchRank = await _api.getWatchMyRank();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
