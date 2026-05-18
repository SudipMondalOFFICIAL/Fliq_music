import 'package:flutter/material.dart';
import '../models/earning.dart';
import '../services/api_service.dart';

class SupportProvider extends ChangeNotifier {
  final ApiService _api;

  SupportTicket? _ticket;
  List<SupportMessage> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  SupportProvider(this._api);

  SupportTicket? get ticket => _ticket;
  List<SupportMessage> get messages => _messages;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;

  Future<void> loadTicket() async {
    _isLoading = true;
    notifyListeners();
    try {
      _ticket = await _api.getMyTicket();
      if (_ticket != null) {
        await loadMessages();
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> ensureTicket() async {
    try {
      final r = await _api.createOrGetTicket();
      if (_ticket == null || _ticket!.id != r['ticket_id']) {
        await loadTicket();
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> loadMessages() async {
    if (_ticket == null) return;
    try {
      _messages = await _api.getSupportMessages(_ticket!.id);
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> sendMessage({String? text, String? imageUrl}) async {
    if (_ticket == null) return false;
    _isSending = true;
    notifyListeners();
    try {
      final msg = await _api.sendSupportMessage(_ticket!.id,
          text: text, imageUrl: imageUrl);
      _messages.add(msg);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
