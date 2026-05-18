// screens/leaderboard_screen.dart
// Game features সম্পূর্ণ removed
// Tabs: 👥 Refer Board | 📋 Task Board
// GameProvider dependency নেই — LeaderboardProvider use করে

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/leaderboard_provider.dart';
import '../providers/earn_provider.dart';

// ── Standalone Route ──────────────────────────────────────────────
class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  static const _bg = Color(0xFF0F0F0F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: const LeaderboardBody()),
    );
  }
}

// ── Embeddable Body ───────────────────────────────────────────────
class LeaderboardBody extends StatefulWidget {
  const LeaderboardBody({Key? key}) : super(key: key);

  @override
  State<LeaderboardBody> createState() => _LeaderboardBodyState();
}

class _LeaderboardBodyState extends State<LeaderboardBody>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  late TabController _tab;
  bool _loadedReferral = false;
  bool _loadedOfferwall = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() {
      if (_tab.indexIsChanging) return;
      if (_tab.index == 0 && !_loadedReferral) _loadReferral();
      if (_tab.index == 1 && !_loadedOfferwall) _loadOfferwall();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LeaderboardProvider>().loadMyRank();
      _loadReferral();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadReferral() async {
    await context.read<LeaderboardProvider>().loadReferralLeaderboard();
    if (mounted) setState(() => _loadedReferral = true);
  }

  Future<void> _loadOfferwall() async {
    await context.read<EarnProvider>().loadOfferwallLeaderboard();
    if (mounted) setState(() => _loadedOfferwall = true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        _buildMyRankCard(),
        const SizedBox(height: 12),
        _buildTabBar(),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _ReferralLeaderboardList(onRefresh: _loadReferral),
              _OfferwallLeaderboardList(onRefresh: _loadOfferwall),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMyRankCard() {
    return Consumer<LeaderboardProvider>(
      builder: (_, lp, __) {
        final rank = lp.myRank;
        final referralRankStr =
            (rank == null || (rank['referral_rank'] ?? 0) == 0)
                ? '-'
                : '#${rank['referral_rank']}';
        final totalRefs = rank?['total_referrals'] ?? 0;

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _lime.withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _lime.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                  child: Icon(Icons.person_rounded, color: _lime, size: 22)),
            ),
            const SizedBox(width: 12),
            const Text('Your Rank',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const Spacer(),
            _miniStat(referralRankStr, 'Refer Rank'),
            const SizedBox(width: 20),
            _miniStat('$totalRefs', 'Referrals'),
          ]),
        );
      },
    );
  }

  Widget _miniStat(String val, String label) => Column(children: [
        Text(val,
            style: const TextStyle(
                color: _lime, fontSize: 16, fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 10)),
      ]);

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: TabBar(
          controller: _tab,
          labelColor: const Color(0xFF0F0F0F),
          unselectedLabelColor: const Color(0xFF555555),
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          indicator: BoxDecoration(
            color: _lime,
            borderRadius: BorderRadius.circular(8),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          overlayColor: MaterialStateProperty.all(Colors.transparent),
          tabs: const [
            Tab(text: '👥 Refer Board'),
            Tab(text: '📋 Task Board'),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Referral Leaderboard
// ══════════════════════════════════════════════════════════════════
class _ReferralLeaderboardList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _ReferralLeaderboardList({required this.onRefresh});

  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    return Consumer<LeaderboardProvider>(
      builder: (_, lp, __) {
        if (lp.isLoading) {
          return const Center(
              child: CircularProgressIndicator(color: _lime, strokeWidth: 2));
        }
        final list = lp.referralLeaderboard;
        if (list.isEmpty) {
          return _emptyState('No referrals yet', onRefresh);
        }
        return RefreshIndicator(
          color: _lime,
          backgroundColor: _card,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _prizeInfo();
              final entry = list[i - 1];
              return _EntryTile(
                rank: entry['rank'] as int? ?? i,
                name: entry['name'] as String? ?? '',
                username: entry['username'] as String? ?? '',
                avatarUrl: entry['avatar_url'] as String? ?? '',
                primaryValue: '${entry['total_referrals'] ?? 0} referrals',
                secondaryValue: null,
              );
            },
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Offerwall Task Leaderboard
// ══════════════════════════════════════════════════════════════════
class _OfferwallLeaderboardList extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _OfferwallLeaderboardList({required this.onRefresh});

  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    return Consumer<EarnProvider>(
      builder: (_, earn, __) {
        if (earn.offerwallLeaderboardLoading) {
          return const Center(
              child: CircularProgressIndicator(color: _lime, strokeWidth: 2));
        }
        final list = earn.offerwallLeaderboard;
        if (list.isEmpty) {
          return _emptyState('No task completions yet', onRefresh);
        }
        return RefreshIndicator(
          color: _lime,
          backgroundColor: _card,
          onRefresh: onRefresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) return _taskInfo();
              final entry = list[i - 1];
              return _EntryTile(
                rank: entry['rank'] as int? ?? i,
                name: entry['name'] as String? ?? '',
                username: entry['username'] as String? ?? '',
                avatarUrl: entry['avatar_url'] as String? ?? '',
                primaryValue: '${entry['completed_tasks'] ?? 0} tasks',
                secondaryValue: '${entry['total_coins'] ?? 0} coins',
              );
            },
          ),
        );
      },
    );
  }

  Widget _taskInfo() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8FF6B).withOpacity(0.2)),
      ),
      child: const Row(children: [
        Text('📋', style: TextStyle(fontSize: 20)),
        SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Complete tasks to rank up!',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            SizedBox(height: 2),
            Text('Most approved tasks wins',
                style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
          ]),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Shared Helpers
// ══════════════════════════════════════════════════════════════════
Widget _prizeInfo() {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFF1A150A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.3)),
    ),
    child: const Row(children: [
      Text('🥇🥈🥉', style: TextStyle(fontSize: 20)),
      SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Top 10 win prizes!',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          SizedBox(height: 2),
          Text('Most referrals wins rewards',
              style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
        ]),
      ),
    ]),
  );
}

Widget _emptyState(String msg, Future<void> Function() onRefresh) {
  return Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Text('🏆', style: TextStyle(fontSize: 48)),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: Color(0xFF555555), fontSize: 15)),
      const SizedBox(height: 16),
      TextButton(
        onPressed: onRefresh,
        child:
            const Text('Refresh', style: TextStyle(color: Color(0xFFE8FF6B))),
      ),
    ]),
  );
}

// ── Unified Entry Tile ────────────────────────────────────────────
class _EntryTile extends StatelessWidget {
  final int rank;
  final String name;
  final String username;
  final String avatarUrl;
  final String primaryValue;
  final String? secondaryValue;

  const _EntryTile({
    required this.rank,
    required this.name,
    required this.username,
    required this.avatarUrl,
    required this.primaryValue,
    this.secondaryValue,
  });

  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;
    final rankEmoji = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '#$rank';
    final rankColor = rank == 1
        ? const Color(0xFFFFD700)
        : rank == 2
            ? const Color(0xFFC0C0C0)
            : rank == 3
                ? const Color(0xFFCD7F32)
                : const Color(0xFF555555);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isTop3 ? rankColor.withOpacity(0.05) : _card,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: isTop3 ? rankColor.withOpacity(0.3) : _border),
      ),
      child: Row(children: [
        SizedBox(
          width: 36,
          child: Text(rankEmoji,
              style: TextStyle(
                  color: rankColor,
                  fontSize: isTop3 ? 22 : 14,
                  fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _lime.withOpacity(0.1),
          ),
          child: avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initials(name)))
              : _initials(name),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text('@$username',
                style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(primaryValue,
              style: TextStyle(
                  color: isTop3 ? rankColor : _lime,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
          if (secondaryValue != null)
            Text(secondaryValue!,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 10)),
        ]),
      ]),
    );
  }

  Widget _initials(String n) => Center(
        child: Text(
          n.isNotEmpty ? n[0].toUpperCase() : '?',
          style: const TextStyle(
              color: _lime, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      );
}
