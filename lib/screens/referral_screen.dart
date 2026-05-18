// ╔══════════════════════════════════════════════════════════════════╗
// ║     refer_earn_screen.dart — Black + Lime Theme                  ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../providers/app_config_provider.dart';
import '../models/earning.dart';
import '../widgets/banner_carousel.dart';

class ReferEarnScreen extends StatefulWidget {
  const ReferEarnScreen({Key? key}) : super(key: key);
  @override
  State<ReferEarnScreen> createState() => _ReferEarnScreenState();
}

class _ReferEarnScreenState extends State<ReferEarnScreen> {
  ReferralStats? _stats;
  bool _loading = true;

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await context.read<ApiService>().getReferralStats();
      if (mounted)
        setState(() {
          _stats = s;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copy() {
    if (_stats == null) return;
    Clipboard.setData(ClipboardData(text: _stats!.referralCode));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Referral code copied!',
          style: TextStyle(color: Colors.white)),
      backgroundColor: _card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _share() {
    if (_stats == null) return;
    Share.share(
      '🎉 Join Filq and start earning coins!\n'
      'Use my referral code: ${_stats!.referralCode}\n'
      'Download the app and sign up to get bonus coins! Official app: https://fliq.us.cc/app-download',
      subject: 'Join Filq — Earn coins & get rewarded!',
    );
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
          const Text('Refer & Earn',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
        ]),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _lime, strokeWidth: 2))
          : RefreshIndicator(
              color: _lime,
              backgroundColor: _card,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                children: [
                  // ── Admin Banners ──────────────────────────────
                  Consumer<AppConfigProvider>(
                    builder: (_, cfg, __) {
                      final banners = cfg.bannersFor('referral');
                      if (banners.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: BannerCarousel(banners: banners, height: 110),
                      );
                    },
                  ),

                  // ── Hero Card ──────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Column(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: _card2,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: _lime.withValues(alpha: 0.2)),
                        ),
                        child: const Center(
                          child: Text('👥', style: TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text('Invite Friends, Earn Together!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: _lime.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                          border:
                              Border.all(color: _lime.withValues(alpha: 0.18)),
                        ),
                        child: Text(
                          'You get ${_stats?.referrerBonusPerInvite ?? 50} coins  ·  Friend gets ${_stats?.referredBonus ?? 20} coins',
                          style: const TextStyle(
                              color: _lime,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // ── Referral Code Box ──────────────────────────
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                    ),
                    child: Column(children: [
                      const Text('YOUR REFERRAL CODE',
                          style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          )),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _card2,
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: _lime.withValues(alpha: 0.25)),
                        ),
                        child: Text(
                          _stats?.referralCode ?? '------',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: _lime,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _copy,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: _card2,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: _border),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.copy_outlined,
                                      color: _lime, size: 15),
                                  SizedBox(width: 6),
                                  Text('Copy Code',
                                      style: TextStyle(
                                        color: _lime,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _share,
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                color: _lime,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.share_rounded,
                                      color: Color(0xFF0F0F0F), size: 15),
                                  SizedBox(width: 6),
                                  Text('Share',
                                      style: TextStyle(
                                        color: Color(0xFF0F0F0F),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                      )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ]),
                    ]),
                  ),

                  const SizedBox(height: 10),

                  // ── Stats Row ──────────────────────────────────
                  Row(children: [
                    _statBox(
                        'Total Referrals',
                        '${_stats?.totalReferrals ?? 0}',
                        Icons.people_outline_rounded),
                    const SizedBox(width: 8),
                    _statBox('Bonus Earned', '${_stats?.totalBonusEarned ?? 0}',
                        Icons.circle_outlined,
                        suffix: ' coins'),
                  ]),

                  // ── How It Works ───────────────────────────────
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('How It Works',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 14),
                          _step('1', 'Share your referral code with friends'),
                          _step('2',
                              'Friend signs up using your code and completes their first campaign task'),
                          _step(
                              '3', 'Both of you get bonus coins instantly! 🎉'),
                        ]),
                  ),

                  // ── Referred Users List ────────────────────────
                  if (_stats != null && _stats!.referrals.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _border),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('People You Invited',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                )),
                            const SizedBox(height: 12),
                            ..._stats!.referrals.map((r) {
                              final u =
                                  r['users'] as Map<String, dynamic>? ?? {};
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _card2,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _border),
                                ),
                                child: Row(children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor:
                                        _lime.withValues(alpha: 0.1),
                                    backgroundImage:
                                        (u['avatar_url'] ?? '').isNotEmpty
                                            ? NetworkImage(
                                                u['avatar_url'] as String)
                                            : null,
                                    child: (u['avatar_url'] ?? '').isEmpty
                                        ? Text(
                                            ((u['username'] as String?) ??
                                                    'U')[0]
                                                .toUpperCase(),
                                            style: const TextStyle(
                                                color: _lime,
                                                fontWeight: FontWeight.w700))
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('@${u['username'] ?? ''}',
                                              style: const TextStyle(
                                                color: Color(0xFFDDDDDD),
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                              )),
                                          Text(u['name'] ?? '',
                                              style: const TextStyle(
                                                  color: Color(0xFF444444),
                                                  fontSize: 10)),
                                        ]),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _card,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: _lime.withValues(alpha: 0.25)),
                                    ),
                                    child: Text('+${r['referrer_bonus']} coins',
                                        style: const TextStyle(
                                          color: _lime,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        )),
                                  ),
                                ]),
                              );
                            }),
                          ]),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _statBox(String label, String value, IconData icon,
      {String suffix = ''}) {
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
            child: Icon(icon, color: _lime, size: 14),
          ),
          const SizedBox(height: 10),
          Text('$value$suffix',
              style: const TextStyle(
                color: _lime,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(color: Color(0xFF444444), fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _step(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _lime.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: _lime.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(num,
                style: const TextStyle(
                  color: _lime,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                )),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
        ),
      ]),
    );
  }
}
