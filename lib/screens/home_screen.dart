// home_screen.dart
// YouTube-style clean home: search bar on top, video feed below

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/track_model.dart';
import '../providers/media_provider.dart';
import '../providers/wallet_provider.dart';
import 'earn_screen.dart';
import 'reels_screen.dart';
import 'referral_screen.dart';
import 'withdraw_screen.dart';
import 'profile_screen.dart';
import 'media_screen.dart';
import 'search_screen.dart';
import 'notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);

  DateTime? _lastBackPress;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadBalance();
      context.read<MediaProvider>().loadFeed(refresh: true);
      context.read<MediaProvider>().loadTrending();
    });
  }

  List<Widget> get _pages => [
        const _HomeFeedPage(),
        ReelsScreen(isActive: _tab == 1),
        const ReferEarnScreen(),
        const WithdrawScreen(),
        const ProfileScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_tab != 0) {
          setState(() => _tab = 0);
          return;
        }
        final now = DateTime.now();
        if (_lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Press back again to exit'),
              duration: const Duration(seconds: 2),
              backgroundColor: const Color(0xFF1A1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _bg,
          body: IndexedStack(index: _tab, children: _pages),
          bottomNavigationBar: _buildBottomNav(),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    const items = [
      BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
      BottomNavigationBarItem(
          icon: Icon(Icons.music_note_rounded), label: 'Music'),
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
}

// ══════════════════════════════════════════════════════════════════
//  Home Feed Page — YouTube-style
// ══════════════════════════════════════════════════════════════════

class _HomeFeedPage extends StatefulWidget {
  const _HomeFeedPage();

  @override
  State<_HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<_HomeFeedPage> {
  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);
  static const _card = Color(0xFF141414);

  final _scrollCtrl = ScrollController();

  final _categories = ['All', '🎵 Music', '🎮 Gaming', '📰 News', '⚽ Sports'];
  int _selectedCat = 0;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(() {
      final mp = context.read<MediaProvider>();
      if (_scrollCtrl.position.pixels >=
          _scrollCtrl.position.maxScrollExtent - 300) {
        mp.loadMoreFeed();
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openPlayer(Track track) {
    final mp = context.read<MediaProvider>();
    final all = [...mp.feed, ...mp.trending, ...mp.searchResults];
    final suggested =
        all.where((t) => t.ytVideoId != track.ytVideoId).take(20).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VideoPlayerScreen(track: track, suggestedTracks: suggested),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // ── Safe area + Header ──────────────────────────────────
          SafeArea(
            bottom: false,
            child: Column(children: [
              // App bar row
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Row(children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle, color: _lime),
                    ),
                    const SizedBox(width: 7),
                    const Text('Filq',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        )),
                  ]),
                  const Spacer(),
                  // Coins badge
                  Consumer<WalletProvider>(
                    builder: (_, wallet, __) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, color: _lime),
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
                  const SizedBox(width: 8),
                  // Notification icon
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const NotificationScreen()),
                    ),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _card,
                        shape: BoxShape.circle,
                        border: Border.all(color: _border),
                      ),
                      child: const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 12),

              // ── Search Bar ──────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SearchScreen()),
                  ),
                  child: AbsorbPointer(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border),
                      ),
                      child: const Row(children: [
                        SizedBox(width: 14),
                        Icon(Icons.search_rounded,
                            color: Color(0xFF555555), size: 20),
                        SizedBox(width: 8),
                        Text('Search songs, videos, channels...',
                            style: TextStyle(
                                color: Color(0xFF444444), fontSize: 13)),
                      ]),
                    ),
                  ),
                ),
              ),

              // ── Category chips ──────────────────────────────────
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final sel = _selectedCat == i;
                    return GestureDetector(
                      onTap: () {
                        setState(() => _selectedCat = i);
                        if (i == 0) {
                          context.read<MediaProvider>().loadFeed(refresh: true);
                        } else {
                          final cats = [
                            'any',
                            'music',
                            'gaming',
                            'news',
                            'sports'
                          ];
                          context
                              .read<MediaProvider>()
                              .loadTrending(category: cats[i]);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: sel ? _lime : _card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: sel ? _lime : _border),
                        ),
                        child: Text(
                          _categories[i],
                          style: TextStyle(
                            color: sel
                                ? const Color(0xFF0F0F0F)
                                : const Color(0xFF888888),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 6),
            ]),
          ),

          // ── Feed / Search Results ───────────────────────────────
          Expanded(
            child: Consumer<MediaProvider>(
              builder: (_, mp, __) {
                // Feed / Trending mode
                final isAll = _selectedCat == 0;
                final tracks = isAll ? mp.feed : mp.trending;
                final loading = isAll
                    ? (mp.feedState == MediaFeedState.loading &&
                        mp.feed.isEmpty)
                    : mp.trendingLoading;
                final error = isAll
                    ? (mp.feedState == MediaFeedState.error && mp.feed.isEmpty)
                    : false;

                if (loading) return const _ShimmerFeed();
                if (error) {
                  return _EmptyState(
                    icon: '😕',
                    msg: mp.error ?? 'Failed to load feed',
                    onRetry: () => mp.loadFeed(refresh: true),
                  );
                }
                if (tracks.isEmpty) {
                  return _EmptyState(
                    icon: '📭',
                    msg: 'Nothing here yet',
                    onRetry: () =>
                        isAll ? mp.loadFeed(refresh: true) : mp.loadTrending(),
                  );
                }

                return RefreshIndicator(
                  color: _lime,
                  backgroundColor: _card,
                  onRefresh: () =>
                      isAll ? mp.loadFeed(refresh: true) : mp.loadTrending(),
                  child: ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(0, 8, 0, 120),
                    itemCount:
                        tracks.length + (isAll && mp.feedHasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == tracks.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: _lime, strokeWidth: 2),
                          ),
                        );
                      }
                      return _VideoCard(
                        track: tracks[i],
                        onTap: () => _openPlayer(tracks[i]),
                        rank: _selectedCat != 0 ? i + 1 : null,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  YouTube-style Video Card (full width thumbnail)
// ══════════════════════════════════════════════════════════════════

class _VideoCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final int? rank;

  const _VideoCard({required this.track, required this.onTap, this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail — full width, no horizontal padding
          Stack(children: [
            CachedNetworkImage(
              imageUrl: track.thumbnail,
              width: double.infinity,
              height: 210,
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  Container(height: 210, color: const Color(0xFF1A1A1A)),
              errorWidget: (_, __, ___) => Container(
                height: 210,
                color: const Color(0xFF1A1A1A),
                child: const Icon(Icons.play_circle_outline,
                    color: Color(0xFF333333), size: 48),
              ),
            ),
            // Duration badge
            if (track.durationSeconds > 0)
              Positioned(
                bottom: 8,
                right: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(track.durationLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            // Rank badge
            if (rank != null)
              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        rank! <= 3 ? const Color(0xFFE8FF6B) : Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('#$rank',
                      style: TextStyle(
                          color: rank! <= 3
                              ? const Color(0xFF0F0F0F)
                              : Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
                ),
              ),
            // Play overlay
            Positioned.fill(
              child: Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 32),
                ),
              ),
            ),
          ]),

          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(
                radius: 19,
                backgroundColor: const Color(0xFF1A1A1A),
                child: Text(
                  track.channel.isNotEmpty
                      ? track.channel[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      color: Color(0xFFE8FF6B),
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.3)),
                      const SizedBox(height: 3),
                      Row(children: [
                        Text(track.channel,
                            style: const TextStyle(
                                color: Color(0xFF666666), fontSize: 12)),
                        if (track.viewCount > 0) ...[
                          const Text(' · ',
                              style: TextStyle(
                                  color: Color(0xFF444444), fontSize: 12)),
                          Text(track.viewCountLabel,
                              style: const TextStyle(
                                  color: Color(0xFF666666), fontSize: 12)),
                        ],
                      ]),
                    ]),
              ),
              const SizedBox(width: 8),
              Consumer<MediaProvider>(
                builder: (_, mp, __) => GestureDetector(
                  onTap: () => mp.toggleLike(track.ytVideoId),
                  child: Icon(
                    mp.isLiked(track.ytVideoId)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: mp.isLiked(track.ytVideoId)
                        ? Colors.redAccent
                        : const Color(0xFF444444),
                    size: 20,
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Search Suggestions
// ══════════════════════════════════════════════════════════════════

class _SearchSuggestionsView extends StatelessWidget {
  final void Function(String) onTap;
  const _SearchSuggestionsView({required this.onTap});

  static const _suggestions = [
    '🎵 Arijit Singh songs',
    '🎶 Bollywood hits 2024',
    '🎸 Lo-fi music',
    '🎤 Taylor Swift',
    '🎬 Short films',
    '📻 Chill beats',
    '🎻 Classical music',
    '🎹 Piano relaxing',
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        const Text('Popular searches',
            style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((s) {
            return GestureDetector(
              onTap: () => onTap(s.replaceAll(RegExp(r'^[^\s]+ '), '')),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E1E1E)),
                ),
                child: Text(s,
                    style: const TextStyle(
                        color: Color(0xFFCCCCCC), fontSize: 13)),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Mini Player
// ══════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════
//  Shimmer Loading
// ══════════════════════════════════════════════════════════════════

class _ShimmerFeed extends StatefulWidget {
  const _ShimmerFeed();

  @override
  State<_ShimmerFeed> createState() => _ShimmerFeedState();
}

class _ShimmerFeedState extends State<_ShimmerFeed>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final c = Color.lerp(
            const Color(0xFF1A1A1A), const Color(0xFF252525), _anim.value)!;
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 40),
          itemCount: 4,
          itemBuilder: (_, __) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(height: 210, color: c),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 38,
                          height: 38,
                          decoration:
                              BoxDecoration(color: c, shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(children: [
                          Container(
                              height: 13,
                              decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(4))),
                          const SizedBox(height: 6),
                          Container(
                              height: 11,
                              width: 130,
                              decoration: BoxDecoration(
                                  color: c,
                                  borderRadius: BorderRadius.circular(4))),
                        ]),
                      ),
                    ]),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Empty / Error State
// ══════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final String icon;
  final String msg;
  final VoidCallback onRetry;

  const _EmptyState(
      {required this.icon, required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF555555), fontSize: 14)),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFE8FF6B).withOpacity(0.4)),
              ),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Color(0xFFE8FF6B), fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ),
    );
  }
}
