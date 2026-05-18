// profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../providers/wallet_provider.dart';
import '../models/user.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  bool _loading = true;
  bool _uploading = false;
  bool _isOffline = false; // true when showing cached data

  // ── Cache key ──────────────────────────────────────────────────
  static const _cacheKey = 'cached_profile';

  // ── Unified theme ──────────────────────────────────────────────
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  // ── Save user to cache ─────────────────────────────────────────
  Future<void> _saveCache(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(user.toJson()));
    } catch (_) {}
  }

  // ── Load from cache ────────────────────────────────────────────
  Future<User?> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw != null) return User.fromJson(jsonDecode(raw));
    } catch (_) {}
    return null;
  }

  // ── Load user: network first, fallback to cache ────────────────
  Future<void> _loadUser({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);

    try {
      final u = await context.read<AuthService>().getProfile();
      await _saveCache(u);
      if (mounted) {
        setState(() {
          _user = u;
          _loading = false;
          _isOffline = false;
        });
      }
    } catch (_) {
      // Network failed — try cache
      final cached = await _loadCache();
      if (mounted) {
        setState(() {
          _user = cached;
          _loading = false;
          _isOffline = cached != null;
        });
      }
    }
  }

  Future<void> _pickAvatar() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No internet connection. Please try later.'),
        backgroundColor: Colors.redAccent,
      ));
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
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
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
      // Clear cache on logout
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheKey);
      await context.read<AuthService>().logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
    }
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
            // Refresh button (only when online or to retry)
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
                  tooltip: _isOffline ? 'Retry connection' : 'Refresh',
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
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
                    children: [
                      // Offline banner
                      if (_isOffline) _offlineBanner(),
                      _avatarSection(),
                      const SizedBox(height: 16),
                      _nameSection(),
                      const SizedBox(height: 24),
                      _statsCard(),
                      const SizedBox(height: 20),
                      _infoSection(),
                      const SizedBox(height: 28),
                      _logoutButton(),
                    ],
                  ),
      ),
    );
  }

  // ── Offline banner ─────────────────────────────────────────────
  Widget _offlineBanner() => Container(
        margin: const EdgeInsets.only(bottom: 16),
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
            child: Text(
              'You\'re offline. Showing cached profile.',
              style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
            ),
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

  // ── No data (no cache + no network) ───────────────────────────
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
          const Text('Profile will load when you\'re back online.',
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

  Widget _avatarSection() {
    return Center(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: Container(
              width: 108,
              height: 108,
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
                    child:
                        CircularProgressIndicator(color: _lime, strokeWidth: 2),
                  ),
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
        ],
      ),
    );
  }

  Widget _avatarFallback() => Center(
        child: Text(
          _user!.name.isNotEmpty ? _user!.name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: _lime, fontSize: 38, fontWeight: FontWeight.w800),
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
        const SizedBox(height: 8),
        Text(_user!.bio!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 14)),
      ],
    ]);
  }

  Widget _statsCard() {
    return Consumer<WalletProvider>(
      builder: (_, wallet, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _lime.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('${wallet.coins}', 'Coins'),
            Container(width: 1, height: 36, color: _border),
            _statItem('${wallet.totalEarned}', 'Total Earned'),
            Container(width: 1, height: 36, color: _border),
            _statItem('Lv.${_user!.level}', 'Level'),
          ],
        ),
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
