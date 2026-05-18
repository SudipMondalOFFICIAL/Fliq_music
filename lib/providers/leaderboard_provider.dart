// providers/leaderboard_provider.dart
// GameProvider replace করে — শুধু referral leaderboard + my rank

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class LeaderboardProvider extends ChangeNotifier {
  final ApiService _api;

  List<Map<String, dynamic>> _referralLeaderboard = [];
  Map<String, dynamic>? _myRank;
  bool _isLoading = false;
  String? _error;

  LeaderboardProvider(this._api);

  List<Map<String, dynamic>> get referralLeaderboard => _referralLeaderboard;
  Map<String, dynamic>? get myRank => _myRank;
  bool get isLoading => _isLoading;
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

  Future<void> loadMyRank() async {
    try {
      _myRank = await _api.getLeaderboardMyRank();
      notifyListeners();
    } catch (_) {}
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
