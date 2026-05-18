// earn_screen.dart — Unified Dark Black + Lime theme
// Games tab completely removed
// Only Watch Ads + Offerwall tabs remain

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/earn_provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/banner_carousel.dart';
import 'offerwall_task_detail_screen.dart';

class EarnScreen extends StatefulWidget {
  const EarnScreen({Key? key}) : super(key: key);
  @override
  State<EarnScreen> createState() => _EarnScreenState();
}

class _EarnScreenState extends State<EarnScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EarnProvider>().loadStats();
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
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
          bottom: TabBar(
            controller: _tabCtrl,
            indicatorColor: _lime,
            indicatorWeight: 2,
            labelColor: _lime,
            unselectedLabelColor: const Color(0xFF555555),
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(text: 'Watch Ads'),
              Tab(text: 'Offerwall'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _WatchAdsTab(),
            _OfferwallTab(),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Watch Ads Tab
// ══════════════════════════════════════════════════════════════════
class _WatchAdsTab extends StatelessWidget {
  const _WatchAdsTab();

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return Consumer<EarnProvider>(
      builder: (_, earn, __) => ListView(
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
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Today's Progress",
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _lime.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _lime.withOpacity(0.25)),
                      ),
                      child: Text('${earn.adsToday}/${earn.dailyAdLimit}',
                          style: const TextStyle(
                              color: _lime,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: earn.dailyAdLimit > 0
                        ? earn.adsToday / earn.dailyAdLimit
                        : 0,
                    backgroundColor: _card2,
                    valueColor: const AlwaysStoppedAnimation<Color>(_lime),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 10),
                Text('${earn.adsRemaining} ads remaining today',
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _AdCard(
            icon: '📺',
            title: 'Rewarded Video Ad',
            subtitle: 'Watch a short video and earn coins',
            network: 'IronSource',
            disabled: earn.adLimitReached,
            onTap: () => _watchAd(context, earn),
          ),
          if (earn.adLimitReached) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline, color: Colors.orange, size: 17),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Daily limit reached. Come back tomorrow for more coins!',
                    style: TextStyle(color: Colors.orange, fontSize: 13),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _watchAd(BuildContext context, EarnProvider earn) async {
    final coins = await earn.onAdWatched(network: 'ironsource');
    if (coins > 0) {
      context.read<WalletProvider>().addCoins(coins);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('🎉 +$coins coins earned!',
              style: const TextStyle(
                  color: Color(0xFF0F0F0F), fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFFE8FF6B),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } else if (earn.error != null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(earn.error!),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        earn.clearError();
      }
    }
  }
}

class _AdCard extends StatelessWidget {
  final String icon, title, subtitle, network;
  final bool disabled;
  final VoidCallback onTap;
  const _AdCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.network,
    required this.disabled,
    required this.onTap,
  });

  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _lime.withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: _card2, borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 12)),
                    const SizedBox(height: 3),
                    Text('via $network',
                        style: const TextStyle(
                            color: _lime,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: _lime,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text('Watch',
                  style: TextStyle(
                      color: Color(0xFF0F0F0F),
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Offerwall Tab
// ══════════════════════════════════════════════════════════════════
class _OfferwallTab extends StatefulWidget {
  const _OfferwallTab();
  @override
  State<_OfferwallTab> createState() => _OfferwallTabState();
}

class _OfferwallTabState extends State<_OfferwallTab> {
  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<EarnProvider>().loadOfferwallTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EarnProvider>(
      builder: (_, earn, __) {
        if (earn.offerwallLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFFE8FF6B)),
          );
        }
        if (earn.offerwallTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apps_rounded,
                    color: Colors.white.withOpacity(0.2), size: 48),
                const SizedBox(height: 12),
                const Text('No tasks available',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 15)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: _lime,
          backgroundColor: _card,
          onRefresh: () => earn.loadOfferwallTasks(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
            itemCount: earn.offerwallTasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final task = earn.offerwallTasks[i];
              return _OfferwallTaskCard(
                task: task,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OfferwallTaskDetailScreen(
                      taskId: task['id'],
                    ),
                  ),
                ).then((_) => earn.loadOfferwallTasks()),
              );
            },
          ),
        );
      },
    );
  }
}

class _OfferwallTaskCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final VoidCallback onTap;
  const _OfferwallTaskCard({required this.task, required this.onTap});

  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  Color _statusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.greenAccent;
      case 'pending':
        return Colors.orangeAccent;
      case 'rejected':
        return Colors.redAccent;
      default:
        return _lime;
    }
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'approved':
        return '✓ Done';
      case 'pending':
        return '⏳ Pending';
      case 'rejected':
        return '✕ Rejected';
      default:
        return '+${task['coins_reward']} coins';
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = task['user_status'] as String?;
    final rating = (task['rating'] as num?)?.toDouble() ?? 5.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: Row(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            clipBehavior: Clip.hardEdge,
            child: task['app_image_url'] != null &&
                    (task['app_image_url'] as String).isNotEmpty
                ? Image.network(task['app_image_url'],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.apps,
                        color: Color(0xFF555555), size: 28))
                : const Icon(Icons.apps, color: Color(0xFF555555), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task['title'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Row(children: [
                  ...List.generate(
                      5,
                      (i) => Icon(
                            i < rating.floor()
                                ? Icons.star_rounded
                                : (i < rating
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded),
                            color: Colors.amber,
                            size: 13,
                          )),
                  const SizedBox(width: 4),
                  Text(rating.toStringAsFixed(1),
                      style: const TextStyle(
                          color: Color(0xFF555555), fontSize: 11)),
                ]),
                const SizedBox(height: 3),
                Text(task['category'] ?? 'app',
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: _statusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _statusColor(status).withOpacity(0.3)),
            ),
            child: Text(
              _statusLabel(status),
              style: TextStyle(
                  color: _statusColor(status),
                  fontWeight: FontWeight.w700,
                  fontSize: 12),
            ),
          ),
        ]),
      ),
    );
  }
}
