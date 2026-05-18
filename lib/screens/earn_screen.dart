// earn_screen.dart — Redirects to Tasks
// Watch Ads and Offerwall completely removed

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/task_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/banner_carousel.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({Key? key}) : super(key: key);
  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen> {
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
    });
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
          titleSpacing: 18,
          title: const Text('Earn Coins',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
        ),
        body: Consumer<TaskProvider>(
          builder: (_, tasks, __) {
            return RefreshIndicator(
              color: _lime,
              backgroundColor: _card,
              onRefresh: tasks.loadTasks,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                children: [
                  Consumer<AppConfigProvider>(
                    builder: (_, cfg, __) {
                      final banners = cfg.bannersFor('earn');
                      if (banners.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: BannerCarousel(banners: banners, height: 110),
                      );
                    },
                  ),
                  // Summary card
                  _summaryCard(tasks),
                  const SizedBox(height: 16),
                  // How to earn
                  _howToEarnCard(),
                  const SizedBox(height: 16),
                  // Pending tasks
                  if (!tasks.isLoading) _pendingTasksSection(context, tasks),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _summaryCard(TaskProvider tasks) {
    return Consumer<WalletProvider>(
      builder: (_, wallet, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lime.withOpacity(0.2)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _lime.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _lime.withOpacity(0.25)),
            ),
            child: const Icon(Icons.stars_rounded, color: _lime, size: 24),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${wallet.coins} Coins',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18)),
            const SizedBox(height: 2),
            Text(
                '${tasks.completedCount}/${tasks.tasks.length} tasks done today',
                style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/tasks'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: _lime,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Tasks',
                  style: TextStyle(
                      color: Color(0xFF0F0F0F),
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _howToEarnCard() {
    final ways = [
      {
        'icon': '✅',
        'title': 'Complete Tasks',
        'sub': 'Daily & one-time tasks for coins'
      },
      {
        'icon': '👥',
        'title': 'Refer Friends',
        'sub': 'Earn bonus when friends join'
      },
      {
        'icon': '🎟️',
        'title': 'Promo Codes',
        'sub': 'Redeem special codes for coins'
      },
      {
        'icon': '🎵',
        'title': 'Watch Music',
        'sub': 'Earn coins watching videos'
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How to Earn',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          const SizedBox(height: 14),
          ...ways.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: _card2, borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text(w['icon']!,
                            style: const TextStyle(fontSize: 20))),
                  ),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w['title']!,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(w['sub']!,
                            style: const TextStyle(
                                color: Color(0xFF555555), fontSize: 11)),
                      ]),
                ]),
              )),
        ],
      ),
    );
  }

  Widget _pendingTasksSection(BuildContext context, TaskProvider tasks) {
    final pending = tasks.tasks.where((t) => !t.completed).take(5).toList();
    if (pending.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: const Column(children: [
          Text('🎉', style: TextStyle(fontSize: 32)),
          SizedBox(height: 8),
          Text('All tasks done!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          SizedBox(height: 4),
          Text('Come back tomorrow for more',
              style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Pending Tasks',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14)),
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/tasks'),
          child: const Text('See all →',
              style: TextStyle(
                  color: _lime, fontSize: 12, fontWeight: FontWeight.w600)),
        ),
      ]),
      const SizedBox(height: 10),
      ...pending.map((t) => GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/tasks'),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
              ),
              child: Row(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: _card2, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                      child:
                          Text(t.icon, style: const TextStyle(fontSize: 20))),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(t.description,
                            style: const TextStyle(
                                color: Color(0xFF555555), fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ]),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _lime.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _lime.withOpacity(0.25)),
                  ),
                  child: Text('+${t.coinsReward}',
                      style: const TextStyle(
                          color: _lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          )),
    ]);
  }
}
