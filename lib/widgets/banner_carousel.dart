import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_banner.dart';
import '../screens/referral_screen.dart';
import '../screens/withdraw_screen.dart';

class BannerCarousel extends StatefulWidget {
  final List<AppBanner> banners;
  final double height;

  const BannerCarousel({
    Key? key,
    required this.banners,
    this.height = 130,
  }) : super(key: key);

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  late PageController _pageCtrl;
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    if (widget.banners.length > 1) _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_current + 1) % widget.banners.length;
      _pageCtrl.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pageCtrl,
            onPageChanged: (i) => setState(() => _current = i),
            itemCount: widget.banners.length,
            itemBuilder: (_, i) => _BannerCard(
              banner: widget.banners[i],
              onTap: () =>
                  AppDeepLink.handle(context, widget.banners[i].action),
            ),
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.banners.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _current == i ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color:
                      _current == i ? const Color(0xFF00C853) : Colors.white24,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
//  DEEP LINK HANDLER
//
//  Backend-এ banner create করার সময় action_url এভাবে দাও:
//
//  Offerwall task open করতে:
//    → filq://offerwall/abc123xyz
//      (abc123xyz = offerwall task এর _id যেটা API response এ আসে)
//
//  Task ID পাবে কীভাবে?
//    GET /offerwall/tasks → response এ প্রতিটা task এর "id" বা "_id" field
//    সেটা copy করে filq://offerwall/সেই_ID দাও
// ─────────────────────────────────────────────────────────────────
class AppDeepLink {
  AppDeepLink._();

  static Future<void> handle(BuildContext context, String? action) async {
    if (action == null || action.trim().isEmpty) return;

    final trimmed = action.trim();

    // ── filq:// scheme — in-app navigation ──────────────────────
    if (trimmed.startsWith('filq://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return;

      switch (uri.host) {
        // filq://offerwall removed

        // filq://referral
        case 'referral':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReferEarnScreen()),
          );
          break;

        // filq://withdraw
        case 'withdraw':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const WithdrawScreen()),
          );
          break;

        // filq://earn  (Watch Ads tab)
        case 'earn':
          Navigator.pushNamed(context, '/earn', arguments: {'tab': 0});
          break;

        // filq://tasks
        case 'tasks':
          Navigator.pushNamed(context, '/tasks');
          break;

        default:
          // Unknown filq:// scheme — ignore silently
          break;
      }
      return;
    }

    // ── Named route (starts with /) ──────────────────────────────
    if (trimmed.startsWith('/')) {
      Navigator.pushNamed(context, trimmed);
      return;
    }

    // ── External URL (http / https) ──────────────────────────────
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final uri = Uri.tryParse(trimmed);
      if (uri != null && await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    // ── Fallback: try as named route ─────────────────────────────
    Navigator.pushNamed(context, trimmed);
  }
}

// ─────────────────────────────────────────────────────────────────
//  BANNER CARD (unchanged design, same as before)
// ─────────────────────────────────────────────────────────────────
class _BannerCard extends StatelessWidget {
  final AppBanner banner;
  final VoidCallback onTap;

  const _BannerCard({required this.banner, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(banner.startColorValue),
              Color(banner.endColorValue),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Color(banner.endColorValue).withOpacity(0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image
            if ((banner.imageUrl ?? '').isNotEmpty)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    banner.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            // Content overlay
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (banner.badge.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Text(
                              banner.badge,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          banner.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          banner.subtitle,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 12,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
