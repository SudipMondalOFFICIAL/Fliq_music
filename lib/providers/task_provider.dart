import 'package:flutter/material.dart';
import '../models/earning.dart';
import '../services/api_service.dart';

class TaskProvider extends ChangeNotifier {
  final ApiService _api;

  List<EarnTask> _tasks = [];
  bool _isLoading = false;
  String? _error;

  TaskProvider(this._api);

  List<EarnTask> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<EarnTask> get dailyTasks =>
      _tasks.where((t) => t.type == 'daily').toList();
  List<EarnTask> get oneTimeTasks =>
      _tasks.where((t) => t.type == 'one_time').toList();
  int get completedCount => _tasks.where((t) => t.completed).length;
  int get totalCoinsAvailable =>
      _tasks.where((t) => !t.completed).fold(0, (s, t) => s + t.coinsReward);

  Future<void> loadTasks() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _tasks = await _api.getTasks();
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> completeTask(String taskId) async {
    try {
      final r = await _api.updateTaskProgress(taskId);
      final coinsEarned = r['coins_earned'] ?? 0;
      if (r['completed'] == true) {
        final idx = _tasks.indexWhere((t) => t.id == taskId);
        if (idx != -1) {
          final t = _tasks[idx];
          _tasks[idx] = EarnTask(
            id: t.id,
            title: t.title,
            description: t.description,
            icon: t.icon,
            coinsReward: t.coinsReward,
            type: t.type,
            actionType: t.actionType,
            actionValue: t.actionValue,
            isActive: t.isActive,
            sortOrder: t.sortOrder,
            progress: t.target,
            completed: true,
            completedAt: DateTime.now().toIso8601String(),
          );
          notifyListeners();
        }
      }
      return coinsEarned;
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
}
