// tasks_screen.dart — Unified Dark Black + Lime theme

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../models/earning.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({Key? key}) : super(key: key);
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  // ── Unified theme ──────────────────────────────────────────────
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    context.read<TaskProvider>().loadTasks();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: const Text('Tasks',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh_rounded,
                    color: Color(0xFF555555), size: 18),
                onPressed: () => context.read<TaskProvider>().loadTasks(),
              ),
            ),
          ],
        ),
        body: Consumer<TaskProvider>(
          builder: (_, tasks, __) {
            if (tasks.isLoading) {
              return const Center(
                  child: CircularProgressIndicator(color: _lime));
            }
            if (tasks.tasks.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                          color: _card,
                          shape: BoxShape.circle,
                          border: Border.all(color: _border)),
                      child: const Icon(Icons.task_alt_outlined,
                          color: Color(0xFF555555), size: 28),
                    ),
                    const SizedBox(height: 16),
                    const Text('No tasks available',
                        style:
                            TextStyle(color: Color(0xFF555555), fontSize: 15)),
                  ],
                ),
              );
            }
            final daily = tasks.dailyTasks;
            final oneTime = tasks.oneTimeTasks;
            return RefreshIndicator(
              color: _lime,
              backgroundColor: _card,
              onRefresh: tasks.loadTasks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  _summaryCard(tasks),
                  if (daily.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('Daily Tasks'),
                    const SizedBox(height: 10),
                    ...daily.map((t) => _TaskCard(task: t)),
                  ],
                  if (oneTime.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionLabel('One-time Tasks'),
                    const SizedBox(height: 10),
                    ...oneTime.map((t) => _TaskCard(task: t)),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(TaskProvider tasks) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lime.withValues(alpha: 0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: _lime.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _lime.withValues(alpha: 0.25))),
            child: const Icon(Icons.task_alt_rounded, color: _lime, size: 22),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${tasks.completedCount}/${tasks.tasks.length} Completed',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16)),
            const SizedBox(height: 2),
            Text('+${tasks.totalCoinsAvailable} coins remaining',
                style: const TextStyle(color: Color(0xFF555555), fontSize: 13)),
          ]),
          const Spacer(),
          Text(
              '${((tasks.completedCount / (tasks.tasks.length == 0 ? 1 : tasks.tasks.length)) * 100).round()}%',
              style: const TextStyle(
                  color: _lime,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ]),
      );

  Widget _sectionLabel(String label) => Text(label,
      style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14));
}

// ══════════════════════════════════════════════════════════════════
//  Task Card
// ══════════════════════════════════════════════════════════════════
class _TaskCard extends StatelessWidget {
  final EarnTask task;
  const _TaskCard({required this.task});

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: task.completed ? _lime.withValues(alpha: 0.2) : _border,
        ),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
                color: _card2, borderRadius: BorderRadius.circular(12)),
            child: Center(
                child: Text(task.icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title,
                  style: TextStyle(
                      color: task.completed
                          ? const Color(0xFF444444)
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      decoration:
                          task.completed ? TextDecoration.lineThrough : null)),
              const SizedBox(height: 2),
              Text(task.description,
                  style:
                      const TextStyle(color: Color(0xFF444444), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
          const SizedBox(width: 8),
          task.completed
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lime.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _lime.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, color: _lime, size: 13),
                      SizedBox(width: 4),
                      Text('Done',
                          style: TextStyle(
                              color: _lime,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              : GestureDetector(
                  onTap: () => _claim(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _lime,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('+${task.coinsReward}',
                        style: const TextStyle(
                            color: Color(0xFF0F0F0F),
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
        ]),
        if (!task.completed && task.target > 1) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: task.progressPercent,
                  backgroundColor: _card2,
                  valueColor: const AlwaysStoppedAnimation<Color>(_lime),
                  minHeight: 5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text('${task.progress}/${task.target}',
                style: const TextStyle(color: Color(0xFF444444), fontSize: 11)),
          ]),
        ],
      ]),
    );
  }

  Future<void> _claim(BuildContext context) async {
    final coins = await context.read<TaskProvider>().completeTask(task.id);
    if (coins > 0) {
      context.read<WalletProvider>().addCoins(coins);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎉 +$coins coins earned from "${task.title}"!',
              style: const TextStyle(
                  color: Color(0xFF0F0F0F), fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFFE8FF6B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }
}
