import 'package:flutter/material.dart';
import '../models/earning.dart';
import '../services/api_service.dart';

class WalletProvider extends ChangeNotifier {
  final ApiService _api;

  int _coins = 0;
  int _totalEarned = 0;
  List<WithdrawRequest> _withdrawHistory = [];
  Map<String, dynamic> _rate = {};
  Map<String, dynamic> _paymentDetails = {};
  bool _isLoading = false;
  String? _error;

  WalletProvider(this._api);

  int get coins => _coins;
  int get totalEarned => _totalEarned;
  List<WithdrawRequest> get withdrawHistory => _withdrawHistory;
  Map<String, dynamic> get rate => _rate;
  Map<String, dynamic> get paymentDetails => _paymentDetails;
  bool get isLoading => _isLoading;
  String? get error => _error;

  num get inrBalance => _coins * (_rate['coins_to_inr_rate'] ?? 0.01);
  int get minWithdraw => _rate['min_coins'] ?? 500;
  int get maxWithdraw => _rate['max_coins'] ?? 50000;

  bool get hasUpi => _paymentDetails['has_upi'] == true;
  bool get hasBank => _paymentDetails['has_bank'] == true;
  bool get isPaymentLocked => _paymentDetails['is_locked'] == true;

  Future<void> loadBalance() async {
    try {
      final r = await _api.getCoinBalance();
      _coins = r['coins'] ?? 0;
      _totalEarned = r['total_earned'] ?? 0;
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
  }

  // ── getCoinHistory এখন Map return করে — HistoryScreen নিজেই
  //    সরাসরি api call করে, তাই provider এ শুধু balance দরকার।
  //    কিন্তু যদি provider থেকেও history দরকার হয়, এই method রাখো:
  Future<Map<String, dynamic>> loadHistory({
    int limit = 30,
    int offset = 0,
    String? type,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final result = await _api.getCoinHistory(
        limit: limit,
        offset: offset,
        type: type,
      );
      return result;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      return {'transactions': [], 'total': 0};
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadWithdrawHistory() async {
    try {
      _withdrawHistory = await _api.getWithdrawHistory();
      notifyListeners();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<void> loadRate() async {
    try {
      _rate = await _api.getWithdrawRate();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadPaymentDetails() async {
    try {
      _paymentDetails = await _api.getPaymentDetails();
      notifyListeners();
    } catch (_) {}
  }

  Future<String?> savePaymentDetails({
    String? upiId,
    String? upiHolderName,
    String? upiPhone,
    String? accountName,
    String? accountNo,
    String? ifsc,
    String? bankPhone,
  }) async {
    try {
      await _api.savePaymentDetails(
        upiId: upiId,
        upiHolderName: upiHolderName,
        upiPhone: upiPhone,
        accountName: accountName,
        accountNo: accountNo,
        ifsc: ifsc,
        bankPhone: bankPhone,
      );
      await loadPaymentDetails();
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  Future<String?> createWithdraw({
    required int coins,
    required String method,
  }) async {
    try {
      await _api.createWithdraw(coins: coins, method: method);
      _coins -= coins;
      notifyListeners();
      await loadWithdrawHistory();
      return null;
    } catch (e) {
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  void addCoins(int amount) {
    _coins += amount;
    _totalEarned += amount;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
