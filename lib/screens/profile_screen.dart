// profile_screen.dart
// Profile page — avatar, stats, banner, promo redeem, quick actions, leaderboard, info, logout

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../providers/wallet_provider.dart';
import '../providers/task_provider.dart';
import '../providers/app_config_provider.dart';
import '../providers/leaderboard_provider.dart';
import '../models/user.dart';
import '../widgets/banner_carousel.dart';
import 'support_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _uploading = false;
  bool _isOffline = false;

  static const _cacheKey = 'cached_profile';

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
  void initState() {
    super.initState();
    _loadUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TaskProvider>().loadTasks();
      context.read<AppConfigProvider>().load();
      context.read<LeaderboardProvider>().loadMyRank();
    });
  }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  Future<void> _saveCache(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  Future<User?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) return User.fromJson(jsonDecode(raw));
    } catch (_) {}
    return null;
  }

  Future<void> _loadUser({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final u = await context.read<AuthService>().getProfile();
      await _saveCache(u);
      if (mounted)
        setState(() {
          _user = u;
          _loading = false;
          _isOffline = false;
        });
    } catch (_) {
      final cached = await _loadCache();
      if (mounted)
        setState(() {
          _user = cached;
          _loading = false;
          _isOffline = cached != null;
        });
    }
  }

  Future<void> _pickAvatar() async {
    if (_isOffline) {
      _showSnack('No internet connection. Please try later.', isError: true);
      return;
    }
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final upload = context.read<UploadService>();
      final result = await upload.uploadAvatar(File(picked.path));
      final url = result['secure_url'] as String? ?? '';
      if (url.isNotEmpty) {
        await context.read<AuthService>().updateProfile(avatarUrl: url);
        await _loadUser(silent: true);
      }
    } catch (e) {
      if (mounted) _showSnack('Upload failed: $e', isError: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
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
      if (mounted)
        _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _promoLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border),
        ),
        title: const Text('Logout',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: Color(0xFF555555))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF555555)))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout',
                  style: TextStyle(
                      color: Colors.redAccent, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirm == true && mounted) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await context.read<AuthService>().logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor:
          isError ? const Color(0xFF2A1A1A) : const Color(0xFF141414),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _showPromoSuccess(String code, int coins) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border),
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
          title: const Text('Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 18)),
          actions: [
            if (!_loading)
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: IconButton(
                  icon: Icon(
                    _isOffline ? Icons.wifi_off_rounded : Icons.refresh_rounded,
                    color: _isOffline
                        ? Colors.orangeAccent
                        : const Color(0xFF555555),
                    size: 18,
                  ),
                  onPressed: () => _loadUser(),
                ),
              ),
            Container(
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Color(0xFF555555), size: 18),
                onPressed: _isOffline ? null : _showEditSheet,
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _lime))
            : _user == null
                ? _noDataView()
                : RefreshIndicator(
                    color: _lime,
                    backgroundColor: _card,
                    onRefresh: () async {
                      await _loadUser(silent: true);
                      if (mounted) {
                        context.read<WalletProvider>().loadBalance();
                        context.read<TaskProvider>().loadTasks();
                        context.read<AppConfigProvider>().load();
                        context.read<LeaderboardProvider>().loadMyRank();
                      }
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                      children: [
                        if (_isOffline) _offlineBanner(),

                        // ── Avatar + Name ───────────────────────────────────
                        _avatarSection(),
                        const SizedBox(height: 14),
                        _nameSection(),
                        const SizedBox(height: 20),

                        // ── Wallet stats card ───────────────────────────────
                        _walletCard(),
                        const SizedBox(height: 12),

                        // ── Banners (moved from home) ───────────────────────
                        Consumer<AppConfigProvider>(
                          builder: (_, cfg, __) {
                            final banners = cfg.bannersFor('home');
                            if (banners.isEmpty) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: BannerCarousel(banners: banners),
                            );
                          },
                        ),

                        // ── Leaderboard rank banner ─────────────────────────
                        _leaderboardBanner(),
                        const SizedBox(height: 12),

                        // ── Quick Actions (moved from home) ─────────────────
                        _quickActions(),
                        const SizedBox(height: 12),

                        // ── Task stats row ──────────────────────────────────
                        _statsRow(),
                        const SizedBox(height: 12),

                        // ── Promo Redeem (moved from home) ──────────────────
                        _promoSection(),
                        const SizedBox(height: 20),

                        // ── Support ─────────────────────────────────────────
                        _supportSection(),
                        const SizedBox(height: 20),

                        // ── Account info ────────────────────────────────────
                        _sectionTitle('Account Info'),
                        const SizedBox(height: 8),
                        _infoSection(),
                        const SizedBox(height: 24),

                        // ── Logout ──────────────────────────────────────────
                        _logoutButton(),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── Section title ──────────────────────────────────────────────
  Widget _sectionTitle(String title) => Text(title,
      style: const TextStyle(
          color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700));

  // ── Offline banner ─────────────────────────────────────────────
  Widget _offlineBanner() => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded,
              color: Colors.orangeAccent, size: 16),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("You're offline. Showing cached profile.",
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          ),
          GestureDetector(
            onTap: () => _loadUser(),
            child: const Text('Retry',
                style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.orangeAccent)),
          ),
        ]),
      );

  Widget _noDataView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded,
              color: Color(0xFF333333), size: 48),
          const SizedBox(height: 12),
          const Text('No internet connection',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          const Text("Profile will load when you're back online.",
              style: TextStyle(color: Color(0xFF555555), fontSize: 13)),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => _loadUser(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Text('Try Again',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      );

  // ── Avatar ─────────────────────────────────────────────────────
  Widget _avatarSection() {
    return Center(
      child: Stack(children: [
        GestureDetector(
          onTap: _pickAvatar,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _lime.withOpacity(0.1),
              border: Border.all(color: _lime.withOpacity(0.3), width: 2),
            ),
            child: ClipOval(
              child: (_user?.avatarUrl ?? '').isNotEmpty
                  ? Image.network(_user!.avatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _avatarFallback())
                  : _avatarFallback(),
            ),
          ),
        ),
        if (_uploading)
          Positioned.fill(
            child: ClipOval(
              child: Container(
                color: Colors.black54,
                child: const Center(
                    child: CircularProgressIndicator(
                        color: _lime, strokeWidth: 2)),
              ),
            ),
          ),
        if (!_isOffline)
          Positioned(
            right: 0,
            bottom: 0,
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                    color: _lime,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bg, width: 2)),
                child: const Icon(Icons.camera_alt,
                    color: Color(0xFF0F0F0F), size: 14),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _avatarFallback() => Center(
        child: Text(
          _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: _lime, fontSize: 36, fontWeight: FontWeight.w800),
        ),
      );

  Widget _nameSection() {
    return Column(children: [
      Text(_user!.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text('@${_user!.username}',
          style: const TextStyle(
              color: _lime, fontSize: 14, fontWeight: FontWeight.w600)),
      if ((_user?.bio ?? '').isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(_user!.bio!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 13)),
      ],
    ]);
  }

  // ── Wallet stats card ──────────────────────────────────────────
  Widget _walletCard() {
    return Consumer<WalletProvider>(
      builder: (_, wallet, __) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lime.withOpacity(0.2)),
        ),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _statItem('${wallet.coins}', 'Coins'),
            Container(width: 1, height: 36, color: _border),
            _statItem('${wallet.totalEarned}', 'Total Earned'),
            Container(width: 1, height: 36, color: _border),
            _statItem('Lv.${_user!.level}', 'Level'),
          ]),
          const SizedBox(height: 12),
          Container(height: 1, color: _border),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Row(children: [
              const Icon(Icons.trending_up_rounded,
                  color: Color(0xFF555555), size: 13),
              const SizedBox(width: 4),
              Text('≈ ₹${wallet.inrBalance.toStringAsFixed(2)}',
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

  Widget _statItem(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: _lime, fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 12)),
      ]);

  // ── Leaderboard banner ─────────────────────────────────────────
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
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _lime.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _lime.withOpacity(0.2)),
                ),
                child: const Center(
                    child: Text('🏆', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Leaderboard',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                      SizedBox(height: 2),
                      Text('Refer friends & climb the ranks!',
                          style: TextStyle(
                              color: Color(0xFF555555), fontSize: 11)),
                    ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(referralRankStr,
                    style: const TextStyle(
                        color: _lime,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5)),
                Text('$referralCount refs',
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 11)),
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

  // ── Quick Actions ──────────────────────────────────────────────
  Widget _quickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Quick Actions'),
      const SizedBox(height: 8),
      Row(children: [
        _actionBtn('Earn', Icons.stars_rounded, _lime,
            () => Navigator.pushNamed(context, '/earn')),
        const SizedBox(width: 7),
        _actionBtn('Tasks', Icons.task_alt_rounded, _orange,
            () => Navigator.pushNamed(context, '/tasks')),
        const SizedBox(width: 7),
        _actionBtn('Refer', Icons.card_giftcard_outlined, _teal,
            () => Navigator.pushNamed(context, '/referral')),
        const SizedBox(width: 7),
        _actionBtn('Withdraw', Icons.account_balance_wallet_outlined, _purple,
            () => Navigator.pushNamed(context, '/withdraw')),
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

  // ── Task stats row ─────────────────────────────────────────────
  Widget _statsRow() {
    return Consumer<TaskProvider>(
      builder: (_, tasks, __) => Row(children: [
        _statCard('Tasks Done', '${tasks.completedCount}/${tasks.tasks.length}',
            Icons.check_box_outlined, _teal),
        const SizedBox(width: 8),
        _statCard('Coins Available', '+${tasks.totalCoinsAvailable}',
            Icons.stars_rounded, _lime),
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

  // ── Promo section ──────────────────────────────────────────────
  Widget _promoSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Promo Code'),
      const SizedBox(height: 8),
      Container(
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
              child: const Icon(Icons.local_offer_outlined,
                  color: _lime, size: 15),
            ),
            const SizedBox(width: 10),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                height: 42,
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
                        fontWeight: FontWeight.w500),
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
                height: 42,
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
                              strokeWidth: 2, color: Color(0xFF0F0F0F)),
                        )
                      : const Text('Apply',
                          style: TextStyle(
                              color: Color(0xFF0F0F0F),
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                ),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  // ── Account info ───────────────────────────────────────────────
  Widget _infoSection() {
    return Column(children: [
      _infoRow(Icons.email_outlined, 'Email', _user!.email),
      if ((_user?.phone ?? '').isNotEmpty)
        _infoRow(Icons.phone_outlined, 'Phone', _user!.phone!),
      _infoRow(
          Icons.card_giftcard_outlined, 'Referral Code', _user!.referralCode),
      _infoRow(Icons.calendar_today_outlined, 'Member since',
          _user!.createdAt.toLocal().toString().split(' ')[0]),
    ]);
  }

  Widget _infoRow(IconData icon, String label, String value) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Row(children: [
          Icon(icon, color: const Color(0xFF555555), size: 18),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF444444), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 14)),
          ]),
        ]),
      );

  // ── Support section ───────────────────────────────────────────
  Widget _supportSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionTitle('Support'),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SupportScreen()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                color: _card2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.headset_mic_outlined,
                  color: _teal, size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Help & Support',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('Contact us or raise a ticket',
                        style:
                            TextStyle(color: Color(0xFF555555), fontSize: 11)),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: Color(0xFF444444), size: 20),
          ]),
        ),
      ),
    ]);
  }

  // ── Logout ─────────────────────────────────────────────────────
  Widget _logoutButton() => SizedBox(
        width: double.infinity,
        height: 52,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 16),
          label: const Text('Logout',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: BorderSide(color: Colors.redAccent.withOpacity(0.4)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );

  // ── Edit sheet ─────────────────────────────────────────────────
  void _showEditSheet() {
    final nameCtrl = TextEditingController(text: _user?.name);
    final bioCtrl = TextEditingController(text: _user?.bio);
    final usernameCtrl = TextEditingController(text: _user?.username);
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          const Text('Edit Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          _editField(nameCtrl, 'Name'),
          const SizedBox(height: 12),
          _editField(usernameCtrl, 'Username'),
          const SizedBox(height: 12),
          _editField(bioCtrl, 'Bio', maxLines: 3),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                await context.read<AuthService>().updateProfile(
                      name: nameCtrl.text.trim(),
                      username: usernameCtrl.text.trim().toLowerCase(),
                      bio: bioCtrl.text.trim(),
                    );
                if (mounted) {
                  Navigator.pop(context);
                  await _loadUser(silent: true);
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _lime,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0),
              child: const Text('Save Changes',
                  style: TextStyle(
                      color: Color(0xFF0F0F0F), fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _editField(TextEditingController ctrl, String label,
      {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: _lime,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF555555)),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _lime)),
      ),
    );
  }
}
