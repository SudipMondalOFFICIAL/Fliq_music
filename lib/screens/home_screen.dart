import '../widgets/banner_carousel.dart';
import '../services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/earn_provider.dart';
import '../providers/task_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/leaderboard_provider.dart';
import 'earn_screen.dart';
import 'referral_screen.dart';
import 'withdraw_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([
      context.read<WalletProvider>().loadBalance(),
      context.read<EarnProvider>().loadStats(),
      context.read<TaskProvider>().loadTasks(),
      context.read<AppConfigProvider>().load(),
    ]);
    // referral rank load (non-blocking)
    context.read<LeaderboardProvider>().loadMyRank();
  }

  List<Widget> get _pages => [
        _DashboardPage(onSwitchTab: switchTab),
        const EarnScreen(),
        const ReferEarnScreen(),
        const WithdrawScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: IndexedStack(index: _tab, children: _pages),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
      BottomNavigationBarItem(
          icon: Icon(Icons.play_circle_outline), label: 'Earn'),
      BottomNavigationBarItem(
          icon: Icon(Icons.card_giftcard_outlined), label: 'Refer'),
      BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined), label: 'Wallet'),
      BottomNavigationBarItem(
          icon: Icon(Icons.person_outline), label: 'Profile'),
    ];

    return BottomNavigationBar(
      currentIndex: _tab,
      onTap: (i) => setState(() => _tab = i),
      backgroundColor: _bg,
      selectedItemColor: _lime,
      unselectedItemColor: const Color(0xFF555555),
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 10,
      unselectedFontSize: 10,
      elevation: 0,
      items: items,
    );
  }

  void switchTab(int tab) => setState(() => _tab = tab);
}

// ══════════════════════════════════════════════════════════════════
//  Dashboard Page
// ══════════════════════════════════════════════════════════════════

class _DashboardPage extends StatefulWidget {
  final void Function(int) onSwitchTab;
  const _DashboardPage({required this.onSwitchTab});

  @override
  State<_DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<_DashboardPage> {
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);
  static const _teal = Color(0xFF6BFFD8);
  static const _orange = Color(0xFFFF9F6B);
  static const _purple = Color(0xFFB06BFF);

  final _promoController = TextEditingController();
  bool _promoLoading = false;

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: 18,
        title: Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(shape: BoxShape.circle, color: _lime),
          ),
          const SizedBox(width: 8),
          const Text('Filq',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
        ]),
        actions: [
          Consumer<WalletProvider>(
            builder: (_, wallet, __) => Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration:
                      const BoxDecoration(shape: BoxShape.circle, color: _lime),
                  child: const Icon(Icons.circle,
                      color: Color(0xFF0F0F0F), size: 8),
                ),
                const SizedBox(width: 5),
                Text('${wallet.coins}',
                    style: const TextStyle(
                        color: _lime,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ]),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.headset_mic_outlined,
                color: Color(0xFF555555), size: 20),
            onPressed: () => Navigator.pushNamed(context, '/support'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        color: _lime,
        backgroundColor: _card,
        onRefresh: () async {
          await Future.wait([
            context.read<WalletProvider>().loadBalance(),
            context.read<EarnProvider>().loadStats(),
            context.read<TaskProvider>().loadTasks(),
            context.read<AppConfigProvider>().load(),
          ]);
          context.read<LeaderboardProvider>().loadMyRank();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
          children: [
            _leaderboardBanner(),
            const SizedBox(height: 10),
            _balanceCard(),
            const SizedBox(height: 10),
            _promoSection(),
            const SizedBox(height: 10),
            Consumer<AppConfigProvider>(
              builder: (_, cfg, __) {
                final banners = cfg.bannersFor('home');
                if (banners.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: BannerCarousel(banners: banners),
                );
              },
            ),
            _statsRow(),
            const SizedBox(height: 10),
            _quickActions(),
            const SizedBox(height: 10),
            _recentTasks(),
          ],
        ),
      ),
    );
  }

  // ── Leaderboard Banner — shows referral rank ──────────────────
  Widget _leaderboardBanner() {
    return Consumer<LeaderboardProvider>(
      builder: (_, lp, __) {
        final rank = lp.myRank;
        final referralRankStr =
            (rank == null || (rank['referral_rank'] ?? 0) == 0)
                ? '—'
                : '#${rank['referral_rank']}';
        final referralCount = rank?['total_referrals'] ?? 0;

        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/leaderboard'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1A2A1A), Color(0xFF0F0F0F)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _lime.withOpacity(0.2)),
            ),
            child: Row(children: [
              // Trophy icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _lime.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _lime.withOpacity(0.2)),
                ),
                child: const Center(
                  child: Text('🏆', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Leaderboard',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Refer friends & climb the ranks!',
                        style:
                            TextStyle(color: Color(0xFF555555), fontSize: 11),
                      ),
                    ]),
              ),
              // Referral rank + count
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(
                  referralRankStr,
                  style: const TextStyle(
                      color: _lime,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5),
                ),
                Text(
                  '$referralCount refs',
                  style:
                      const TextStyle(color: Color(0xFF555555), fontSize: 11),
                ),
              ]),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  color: Color(0xFF444444), size: 20),
            ]),
          ),
        );
      },
    );
  }

  // ── Balance Card ──────────────────────────────────────────────
  Widget _balanceCard() {
    return Consumer<WalletProvider>(
      builder: (_, wallet, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('BALANCE',
                style: TextStyle(
                  color: Color(0xFF555555),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                )),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: _lime.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _lime.withOpacity(0.18)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: _lime)),
                const SizedBox(width: 5),
                const Text('Earning',
                    style: TextStyle(
                        color: _lime,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${wallet.coins}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -2,
                    height: 1,
                  )),
              const SizedBox(width: 6),
              const Text('coins',
                  style: TextStyle(
                      color: Color(0xFF333333),
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 4),
          Text('≈ ₹${wallet.inrBalance.toStringAsFixed(2)}',
              style: const TextStyle(color: Color(0xFF444444), fontSize: 12)),
          const SizedBox(height: 14),
          Container(height: 1, color: _border),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.trending_up_rounded,
                  color: Color(0xFF555555), size: 13),
              const SizedBox(width: 4),
              Text('Total earned: ${wallet.totalEarned} coins',
                  style:
                      const TextStyle(color: Color(0xFF555555), fontSize: 11)),
            ]),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/history'),
              child: const Text('History →',
                  style: TextStyle(
                      color: _lime, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }

  // ── Promo Section ─────────────────────────────────────────────
  Widget _promoSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child:
                const Icon(Icons.local_offer_outlined, color: _lime, size: 15),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Redeem Promo Code',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            Text('Instant bonus coins',
                style: TextStyle(color: Color(0xFF444444), fontSize: 10)),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: _bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: TextField(
                controller: _promoController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: const InputDecoration(
                  hintText: 'ENTER CODE HERE',
                  hintStyle: TextStyle(
                    color: Color(0xFF333333),
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _promoLoading
                ? null
                : () => _redeemPromo(_promoController.text.trim()),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: _promoLoading ? _lime.withOpacity(0.4) : _lime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: _promoLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF0F0F0F),
                        ),
                      )
                    : const Text('Apply',
                        style: TextStyle(
                          color: Color(0xFF0F0F0F),
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        )),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _redeemPromo(String code) async {
    if (code.isEmpty) {
      _showSnack('Please enter a promo code', isError: true);
      return;
    }
    setState(() => _promoLoading = true);
    try {
      final result = await context.read<ApiService>().redeemPromo(code);
      _promoController.clear();
      final coins = result['coins_earned'] as int? ?? 0;
      await context.read<WalletProvider>().loadBalance();
      if (mounted) _showPromoSuccess(code, coins);
    } catch (e) {
      if (mounted) {
        _showSnack(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _promoLoading = false);
    }
  }

  void _showPromoSuccess(String code, int coins) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF1E1E1E)),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _lime.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _lime.withOpacity(0.3)),
            ),
            child: const Icon(Icons.check_rounded, color: _lime, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Code Applied!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(code,
              style: const TextStyle(
                  color: _lime,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 2)),
          const SizedBox(height: 8),
          Text('+$coins coins added to your wallet! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: _lime,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Awesome!',
                  style: TextStyle(
                      color: Color(0xFF0F0F0F), fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor:
          isError ? const Color(0xFF2A2A2A) : const Color(0xFF141414),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ── Stats Row ─────────────────────────────────────────────────
  Widget _statsRow() {
    return Consumer2<EarnProvider, TaskProvider>(
      builder: (_, earn, tasks, __) => Row(children: [
        _statCard('Ads Today', '${earn.adsToday}/${earn.dailyAdLimit}',
            Icons.play_circle_outline_rounded, _lime),
        const SizedBox(width: 8),
        _statCard('Tasks Done', '${tasks.completedCount}/${tasks.tasks.length}',
            Icons.check_box_outlined, _teal),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: _card2, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF444444), fontSize: 10)),
        ]),
      ),
    );
  }

  // ── Quick Actions ─────────────────────────────────────────────
  Widget _quickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Quick Actions',
          style: TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Row(children: [
        _actionBtn('Watch', Icons.play_circle_outline_rounded, _lime,
            () => widget.onSwitchTab(1)),
        const SizedBox(width: 7),
        _actionBtn('Offerwall', Icons.grid_view_rounded, _teal,
            () => widget.onSwitchTab(1)),
        const SizedBox(width: 7),
        _actionBtn('Tasks', Icons.task_alt_rounded, _orange,
            () => Navigator.pushNamed(context, '/tasks')),
        const SizedBox(width: 7),
        _actionBtn('Withdraw', Icons.account_balance_wallet_outlined, _purple,
            () => widget.onSwitchTab(3)),
      ]),
    ]);
  }

  Widget _actionBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: _card2, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 15),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 10,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  // ── Recent / Pending Tasks ────────────────────────────────────
  Widget _recentTasks() {
    return Consumer<TaskProvider>(
      builder: (_, tasks, __) {
        final pending = tasks.tasks.where((t) => !t.completed).take(3).toList();
        if (pending.isEmpty) return const SizedBox.shrink();

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Pending Tasks',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/tasks'),
              child: const Text('See all',
                  style: TextStyle(
                      color: _lime, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 8),
          ...pending.map((t) => Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: _card2, borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child:
                            Text(t.icon, style: const TextStyle(fontSize: 18))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              style: const TextStyle(
                                  color: Color(0xFFDDDDDD),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(t.description,
                              style: const TextStyle(
                                  color: Color(0xFF444444), fontSize: 10),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ]),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _card2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _lime.withOpacity(0.25)),
                    ),
                    child: Text('+${t.coinsReward}',
                        style: const TextStyle(
                            color: _lime,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              )),
        ]);
      },
    );
  }
}
