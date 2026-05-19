// ╔══════════════════════════════════════════════════════════════════╗
// ║  profile_screen.dart — YouTube-style Profile                    ║
// ╚══════════════════════════════════════════════════════════════════╝

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
import '../providers/download_provider.dart';
import '../models/user.dart';
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
  static const _border = Color(0xFF222222);
  static const _lime = Color(0xFFE8FF6B);
  static const _dimText = Color(0xFF888888);

  final _promoCtrl = TextEditingController();
  bool _promoLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadBalance();
    });
  }

  @override
  void dispose() {
    _promoCtrl.dispose();
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
    if (_isOffline) return;
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
      _showSnack('Enter a promo code', isError: true);
      return;
    }
    setState(() => _promoLoading = true);
    try {
      final result = await context.read<ApiService>().redeemPromo(code);
      _promoCtrl.clear();
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
            style: TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF666666)))),
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
      backgroundColor: isError ? Colors.red.shade900 : const Color(0xFF1A1A1A),
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
          Text('+$coins coins added! 🎉',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
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
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _lime))
            : _user == null
                ? _noDataView()
                : RefreshIndicator(
                    color: _lime,
                    backgroundColor: _card,
                    onRefresh: () async {
                      await _loadUser(silent: true);
                      if (mounted) context.read<WalletProvider>().loadBalance();
                    },
                    child: CustomScrollView(
                      slivers: [
                        _buildAppBar(),
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              if (_isOffline) _offlineBanner(),
                              _buildAvatarSection(),
                              _buildNameSection(),
                              const SizedBox(height: 20),
                              _buildBalanceCard(),
                              const SizedBox(height: 8),
                              _buildMenuSection(),
                              const SizedBox(height: 8),
                              _buildPromoSection(),
                              const SizedBox(height: 8),
                              _buildAccountSection(),
                              const SizedBox(height: 16),
                              _buildLogoutButton(),
                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }

  // ── SliverAppBar ──────────────────────────────────────────────
  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: _bg,
      expandedHeight: 0,
      pinned: true,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      title: const Text(
        'Profile',
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
      ),
      actions: [
        if (!_loading && !_isOffline)
          IconButton(
            icon: const Icon(Icons.settings_rounded,
                color: Color(0xFF888888), size: 22),
            onPressed: _showSettingsSheet,
            tooltip: 'Settings',
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ── Avatar + name ─────────────────────────────────────────────
  Widget _buildAvatarSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
      child: Center(
        child: Stack(alignment: Alignment.center, children: [
          GestureDetector(
            onTap: _isOffline ? null : _pickAvatar,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lime.withOpacity(0.1),
                border: Border.all(color: _lime.withOpacity(0.4), width: 2.5),
              ),
              child: ClipOval(
                child: _uploading
                    ? Container(
                        color: Colors.black54,
                        child: const Center(
                            child: CircularProgressIndicator(
                                color: _lime, strokeWidth: 2)),
                      )
                    : (_user?.avatarUrl ?? '').isNotEmpty
                        ? Image.network(_user!.avatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _avatarFallback())
                        : _avatarFallback(),
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: _lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bg, width: 2)),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: Color(0xFF0F0F0F), size: 13),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _avatarFallback() => Center(
        child: Text(
          _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: _lime, fontSize: 34, fontWeight: FontWeight.w800),
        ),
      );

  Widget _buildNameSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
      child: Column(children: [
        Text(
          _user!.name,
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3),
        ),
        const SizedBox(height: 4),
        Text(
          '@${_user!.username}',
          style: const TextStyle(
              color: _dimText, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        if ((_user?.bio ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _user!.bio!,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF666666), fontSize: 13),
          ),
        ],
        const SizedBox(height: 14),
        // Edit profile button — YouTube style
        GestureDetector(
          onTap: _isOffline ? null : _showEditSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: const Text(
              'Edit profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ]),
    );
  }

  // ── Balance Card ──────────────────────────────────────────────
  Widget _buildBalanceCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Consumer<WalletProvider>(
        builder: (_, wallet, __) => Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _lime.withOpacity(0.12),
                _lime.withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _lime.withOpacity(0.2)),
          ),
          child: Row(children: [
            // Coin icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _lime.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                  child: Text('🪙', style: TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${wallet.coins} coins',
                      style: const TextStyle(
                          color: _lime,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '≈ ₹${wallet.inrBalance.toStringAsFixed(2)} • Lv.${_user!.level}',
                      style: const TextStyle(
                          color: Color(0xFF666666), fontSize: 12),
                    ),
                  ]),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/withdraw'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Withdraw',
                  style: TextStyle(
                      color: Color(0xFF0F0F0F),
                      fontWeight: FontWeight.w800,
                      fontSize: 13),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Menu Section — YouTube style list ─────────────────────────
  Widget _buildMenuSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(children: [
        _menuGroup([
          _MenuItem(
            icon: Icons.history_rounded,
            iconColor: const Color(0xFFFF9F6B),
            label: 'Watch History',
            subtitle: 'Your recently watched videos',
            onTap: () => Navigator.pushNamed(context, '/history'),
          ),
          _MenuItem(
            icon: Icons.download_rounded,
            iconColor: const Color(0xFF6BFFD8),
            label: 'Downloads',
            subtitle: _downloadsSubtitle(),
            onTap: () => Navigator.pushNamed(context, '/downloads'),
          ),
          _MenuItem(
            icon: Icons.favorite_rounded,
            iconColor: Colors.redAccent,
            label: 'Liked Videos',
            subtitle: 'Videos you\'ve liked',
            onTap: () {
              Navigator.pushNamed(context, '/media');
              // TODO: navigate directly to Liked tab if needed
            },
          ),
        ]),
        const SizedBox(height: 8),
        _menuGroup([
          _MenuItem(
            icon: Icons.card_giftcard_rounded,
            iconColor: const Color(0xFFB06BFF),
            label: 'Refer & Earn',
            subtitle: 'Invite friends, earn coins',
            onTap: () => Navigator.pushNamed(context, '/referral'),
          ),
          _MenuItem(
            icon: Icons.stars_rounded,
            iconColor: _lime,
            label: 'Earn More',
            subtitle: 'Tasks, offers & more',
            onTap: () => Navigator.pushNamed(context, '/earn'),
          ),
          _MenuItem(
            icon: Icons.leaderboard_rounded,
            iconColor: const Color(0xFFFFD700),
            label: 'Leaderboard',
            subtitle: 'See your rank',
            onTap: () => Navigator.pushNamed(context, '/leaderboard'),
          ),
        ]),
        const SizedBox(height: 8),
        _menuGroup([
          _MenuItem(
            icon: Icons.headset_mic_rounded,
            iconColor: const Color(0xFF6BFFD8),
            label: 'Help & Support',
            subtitle: 'Contact us or raise a ticket',
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SupportScreen())),
          ),
        ]),
      ]),
    );
  }

  String _downloadsSubtitle() {
    try {
      final dl = context.read<DownloadProvider>();
      final count = dl.downloadedAudioIds.length + dl.downloadedVideoIds.length;
      return count > 0 ? '$count items downloaded' : 'Offline library';
    } catch (_) {
      return 'Offline library';
    }
  }

  Widget _menuGroup(List<_MenuItem> items) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: items.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          return Column(
            children: [
              _buildMenuItem(item),
              if (i < items.length - 1)
                const Divider(
                    height: 1,
                    color: Color(0xFF1E1E1E),
                    indent: 58,
                    endIndent: 0),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMenuItem(_MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: item.iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(item.icon, color: item.iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              if (item.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(item.subtitle!,
                    style: const TextStyle(
                        color: Color(0xFF555555), fontSize: 11)),
              ],
            ]),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: Color(0xFF333333), size: 18),
        ]),
      ),
    );
  }

  // ── Promo Code ────────────────────────────────────────────────
  Widget _buildPromoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _lime.withOpacity(0.12),
                borderRadius: BorderRadius.circular(11),
              ),
              child:
                  const Icon(Icons.local_offer_rounded, color: _lime, size: 18),
            ),
            const SizedBox(width: 12),
            const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Promo Code',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Redeem for instant bonus coins',
                      style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
                ]),
          ]),
          const SizedBox(height: 14),
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
                  controller: _promoCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'ENTER CODE',
                    hintStyle: TextStyle(
                        color: Color(0xFF333333),
                        fontSize: 12,
                        letterSpacing: 1,
                        fontWeight: FontWeight.w500),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _promoLoading
                  ? null
                  : () => _redeemPromo(_promoCtrl.text.trim()),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _promoLoading ? _lime.withOpacity(0.5) : _lime,
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
    );
  }

  // ── Account Info ──────────────────────────────────────────────
  Widget _buildAccountSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        child: Column(children: [
          _infoRow(Icons.email_outlined, 'Email', _user!.email),
          const Divider(height: 1, color: Color(0xFF1E1E1E), indent: 58),
          _infoRow(Icons.card_giftcard_outlined, 'Referral Code',
              _user!.referralCode,
              trailing: GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _user!.referralCode));
                  _showSnack('Referral code copied!');
                },
                child: const Icon(Icons.copy_rounded,
                    color: Color(0xFF444444), size: 16),
              )),
          const Divider(height: 1, color: Color(0xFF1E1E1E), indent: 58),
          _infoRow(Icons.calendar_today_outlined, 'Member since',
              _user!.createdAt.toLocal().toString().split(' ')[0]),
        ]),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Icon(icon, color: _dimText, size: 18),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(color: Colors.white, fontSize: 13)),
          ]),
        ),
        if (trailing != null) trailing,
      ]),
    );
  }

  // ── Logout ────────────────────────────────────────────────────
  Widget _buildLogoutButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Logout',
              style: TextStyle(fontWeight: FontWeight.w700)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: BorderSide(color: Colors.redAccent.withOpacity(0.35)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }

  // ── Offline banner ────────────────────────────────────────────
  Widget _offlineBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.25)),
        ),
        child: Row(children: [
          const Icon(Icons.wifi_off_rounded,
              color: Colors.orangeAccent, size: 15),
          const SizedBox(width: 10),
          const Expanded(
            child: Text("Offline – showing cached profile.",
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          ),
          GestureDetector(
            onTap: () => _loadUser(),
            child: const Text('Retry',
                style: TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _noDataView() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off_rounded,
              color: Color(0xFF333333), size: 48),
          const SizedBox(height: 12),
          const Text('No connection',
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

  // ── Settings sheet (gear icon) ─────────────────────────────────
  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Settings',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 16),
          _settingsTile(
            Icons.person_outline_rounded,
            'Edit Profile',
            'Name, username, bio',
            onTap: () {
              Navigator.pop(context);
              _showEditSheet();
            },
          ),
          _settingsTile(
            Icons.lock_outline_rounded,
            'Change Password',
            'Update your password',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/forgot-password');
            },
          ),
          _settingsTile(
            Icons.notifications_outlined,
            'Notifications',
            'Manage push notifications',
            onTap: () => Navigator.pop(context),
          ),
          _settingsTile(
            Icons.shield_outlined,
            'Privacy & Security',
            'Manage your data',
            onTap: () => Navigator.pop(context),
          ),
          const Divider(
              height: 1, color: Color(0xFF1E1E1E), indent: 20, endIndent: 20),
          _settingsTile(
            Icons.logout_rounded,
            'Logout',
            '',
            iconColor: Colors.redAccent,
            labelColor: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              _logout();
            },
          ),
        ]),
      ),
    );
  }

  Widget _settingsTile(
    IconData icon,
    String label,
    String subtitle, {
    VoidCallback? onTap,
    Color iconColor = const Color(0xFF888888),
    Color labelColor = Colors.white,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor, size: 20),
      title: Text(label,
          style: TextStyle(
              color: labelColor, fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: subtitle.isNotEmpty
          ? Text(subtitle,
              style: const TextStyle(color: Color(0xFF555555), fontSize: 11))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded,
          color: Color(0xFF333333), size: 18),
      onTap: onTap,
    );
  }

  // ── Edit Profile sheet ─────────────────────────────────────────
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
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await context.read<AuthService>().updateProfile(
                        name: nameCtrl.text.trim(),
                        username: usernameCtrl.text.trim().toLowerCase(),
                        bio: bioCtrl.text.trim(),
                      );
                  if (mounted) {
                    Navigator.pop(context);
                    await _loadUser(silent: true);
                  }
                } catch (e) {
                  if (mounted)
                    _showSnack(e.toString().replaceAll('Exception: ', ''),
                        isError: true);
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

// ── Menu item model ───────────────────────────────────────────────
class _MenuItem {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.onTap,
  });
}
