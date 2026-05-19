// ╔══════════════════════════════════════════════════════════════════╗
// ║  reels_screen.dart — YouTube Shorts / Reels                      ║
// ║  TikTok-style vertical swipe player                              ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/track_model.dart';
import '../providers/media_provider.dart';

// ── Shorts video IDs — backend থেকে আসবে, এগুলো fallback ──────────
// Backend এ /music/search?q=shorts&type=any call করে short videos আনা হবে

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({Key? key}) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen> {
  late PageController _pageCtrl;
  int _currentIndex = 0;
  List<Track> _reels = [];
  bool _loading = true;
  String? _error;

  static const _bg = Color(0xFF000000);
  static const _lime = Color(0xFFE8FF6B);

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadShorts();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadShorts() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Backend থেকে short videos search করো
      final mp = context.read<MediaProvider>();
      await mp.searchShorts();
      final results = mp.shortsResults;
      if (results.isEmpty) throw Exception('No shorts found');
      setState(() {
        _reels = results;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Load more when near end
    if (index >= _reels.length - 3) {
      context.read<MediaProvider>().loadMoreShorts().then((_) {
        final mp = context.read<MediaProvider>();
        if (mounted) setState(() => _reels = mp.shortsResults);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: _loading
            ? const _ShortsLoadingState()
            : _error != null && _reels.isEmpty
                ? _ShortsErrorState(
                    error: _error!,
                    onRetry: _loadShorts,
                  )
                : Stack(
                    children: [
                      // ── Vertical PageView ───────────────────
                      PageView.builder(
                        controller: _pageCtrl,
                        scrollDirection: Axis.vertical,
                        onPageChanged: _onPageChanged,
                        itemCount: _reels.length,
                        itemBuilder: (_, i) => _ReelItem(
                          track: _reels[i],
                          isActive: i == _currentIndex,
                          onLike: () => context
                              .read<MediaProvider>()
                              .toggleLike(_reels[i].ytVideoId),
                        ),
                      ),

                      // ── Top bar ─────────────────────────────
                      SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                          child: Row(children: [
                            const Text(
                              'Reels',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _lime.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Shorts',
                                style: TextStyle(
                                  color: _lime,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            // Coin indicator
                            Consumer<MediaProvider>(
                              builder: (_, mp, __) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.monetization_on_rounded,
                                          color: _lime, size: 13),
                                      const SizedBox(width: 4),
                                      Text(
                                          '${mp.dailyWatchEarned}/${mp.dailyWatchLimit}',
                                          style: const TextStyle(
                                              color: _lime,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                              ),
                            ),
                          ]),
                        ),
                      ),

                      // ── Scroll indicator dots ───────────────
                      if (_reels.length > 1)
                        Positioned(
                          right: 6,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                _reels.length.clamp(0, 8),
                                (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  width: 3,
                                  height: i == _currentIndex ? 18 : 5,
                                  decoration: BoxDecoration(
                                    color: i == _currentIndex
                                        ? _lime
                                        : Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Single Reel Item — YouTube Player fullscreen
// ══════════════════════════════════════════════════════════════════

class _ReelItem extends StatefulWidget {
  final Track track;
  final bool isActive;
  final VoidCallback onLike;

  const _ReelItem({
    required this.track,
    required this.isActive,
    required this.onLike,
  });

  @override
  State<_ReelItem> createState() => _ReelItemState();
}

class _ReelItemState extends State<_ReelItem> {
  YoutubePlayerController? _ctrl;
  bool _ready = false;
  bool _showCoinBadge = false;
  int _watchedSecs = 0;
  bool _coinLogged = false;
  Timer? _watchTimer;

  static const _lime = Color(0xFFE8FF6B);

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _initPlayer();
  }

  @override
  void didUpdateWidget(_ReelItem old) {
    super.didUpdateWidget(old);
    if (widget.isActive && !old.isActive) {
      _initPlayer();
    } else if (!widget.isActive && old.isActive) {
      _pauseAndDispose();
    }
  }

  void _initPlayer() {
    _ctrl?.dispose();
    _watchTimer?.cancel();
    _watchedSecs = 0;
    _coinLogged = false;

    _ctrl = YoutubePlayerController(
      initialVideoId: widget.track.ytVideoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        loop: true,
        disableDragSeek: true,
        hideControls: true,
        hideThumbnail: false,
        forceHD: false,
        enableCaption: false,
      ),
    );

    _ctrl!.addListener(() {
      if (!mounted) return;
      if (_ctrl!.value.isReady && !_ready) {
        setState(() => _ready = true);
      }
    });

    // Watch time tracker
    _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_ctrl?.value.isPlaying == true) {
        _watchedSecs++;
        // Coin after 15s watch (shorts are short!)
        if (!_coinLogged && _watchedSecs >= 15) {
          _coinLogged = true;
          _logWatch();
        }
      }
    });

    setState(() => _ready = false);
  }

  void _pauseAndDispose() {
    _watchTimer?.cancel();
    if (_watchedSecs > 5 && !_coinLogged) _logWatch();
    _ctrl?.pause();
    _ctrl?.dispose();
    _ctrl = null;
    if (mounted) setState(() => _ready = false);
  }

  void _logWatch() {
    try {
      context.read<MediaProvider>().logWatch(
            track: widget.track,
            watchDurationSeconds: _watchedSecs,
          );
    } catch (_) {}
  }

  void _showCoin() {
    setState(() => _showCoinBadge = true);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _showCoinBadge = false);
    });
  }

  @override
  void dispose() {
    _watchTimer?.cancel();
    if (_watchedSecs > 5 && !_coinLogged) _logWatch();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox(
      width: size.width,
      height: size.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background thumbnail (shown while loading) ────────
          CachedNetworkImage(
            imageUrl: widget.track.thumbnail,
            fit: BoxFit.cover,
            width: size.width,
            height: size.height,
            placeholder: (_, __) => Container(color: const Color(0xFF111111)),
            errorWidget: (_, __, ___) =>
                Container(color: const Color(0xFF111111)),
          ),

          // ── YouTube Player ────────────────────────────────────
          if (_ctrl != null && widget.isActive)
            YoutubePlayerBuilder(
              player: YoutubePlayer(
                controller: _ctrl!,
                showVideoProgressIndicator: false,
                onReady: () {
                  if (mounted) setState(() => _ready = true);
                },
              ),
              builder: (ctx, player) => SizedBox(
                width: size.width,
                height: size.height,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: size.width,
                    height: size.width * 16 / 9,
                    child: player,
                  ),
                ),
              ),
            ),

          // ── Loading spinner ───────────────────────────────────
          if (!_ready && widget.isActive)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFE8FF6B), strokeWidth: 2),
              ),
            ),

          // ── Gradient overlay (bottom) ─────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: size.height * 0.45,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // ── Gradient overlay (top) — for header readability ───
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: Container(
              height: 120,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
            ),
          ),

          // ── Right side actions ────────────────────────────────
          Positioned(
            right: 14,
            bottom: 100,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Like button
                Consumer<MediaProvider>(
                  builder: (_, mp, __) => _ActionBtn(
                    icon: mp.isLiked(widget.track.ytVideoId)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: mp.isLiked(widget.track.ytVideoId)
                        ? Colors.redAccent
                        : Colors.white,
                    label: 'Like',
                    onTap: () {
                      widget.onLike();
                      _showCoin();
                    },
                  ),
                ),
                const SizedBox(height: 20),
                // Share button
                _ActionBtn(
                  icon: Icons.reply_rounded,
                  color: Colors.white,
                  label: 'Share',
                  onTap: () {},
                  mirrorHorizontal: true,
                ),
                const SizedBox(height: 20),
                // Coin button
                _ActionBtn(
                  icon: Icons.monetization_on_rounded,
                  color: _lime,
                  label: '${_watchedSecs}s',
                  onTap: _logWatch,
                ),
              ],
            ),
          ),

          // ── Bottom info ───────────────────────────────────────
          Positioned(
            left: 16,
            right: 80,
            bottom: MediaQuery.of(context).padding.bottom + 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Channel name
                Row(children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1A1A1A),
                      border: Border.all(color: Colors.white30, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        widget.track.channel.isNotEmpty
                            ? widget.track.channel[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: _lime,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.track.channel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Follow',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                // Title
                Text(
                  widget.track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                    shadows: [
                      Shadow(
                          color: Colors.black54,
                          offset: Offset(0, 1),
                          blurRadius: 4),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                // Views
                if (widget.track.viewCount > 0)
                  Row(children: [
                    const Icon(Icons.play_arrow_rounded,
                        color: Colors.white54, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      widget.track.viewCountLabel,
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ]),
              ],
            ),
          ),

          // ── Coin earned badge (animated) ──────────────────────
          if (_showCoinBadge)
            Positioned(
              top: size.height * 0.4,
              left: 0,
              right: 0,
              child: Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 400),
                  builder: (_, v, child) => Transform.scale(
                    scale: v,
                    child: child,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _lime,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: _lime.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 2)
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded,
                            color: Color(0xFF0F0F0F), size: 18),
                        SizedBox(width: 4),
                        Text(
                          '+2 coins',
                          style: TextStyle(
                            color: Color(0xFF0F0F0F),
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Action Button (right side)
// ══════════════════════════════════════════════════════════════════

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  final bool mirrorHorizontal;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
    this.mirrorHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform(
            alignment: Alignment.center,
            transform: mirrorHorizontal
                ? (Matrix4.identity()..scale(-1.0, 1.0))
                : Matrix4.identity(),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                    color: Colors.black87, offset: Offset(0, 1), blurRadius: 3)
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Loading State
// ══════════════════════════════════════════════════════════════════

class _ShortsLoadingState extends StatelessWidget {
  const _ShortsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFE8FF6B), strokeWidth: 2),
            SizedBox(height: 20),
            Text(
              'Loading Reels...',
              style: TextStyle(color: Color(0xFF555555), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Error State
// ══════════════════════════════════════════════════════════════════

class _ShortsErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ShortsErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('📱', style: TextStyle(fontSize: 52)),
              const SizedBox(height: 16),
              const Text(
                'Could not load Reels',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF555555), fontSize: 13),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8FF6B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(
                        color: Color(0xFF0F0F0F),
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
