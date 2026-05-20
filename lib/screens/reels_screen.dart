// ╔══════════════════════════════════════════════════════════════════╗
// ║  reels_screen.dart — Filq Music                                  ║
// ║  Spotify / YT Music style full music player                      ║
// ║  • Feed, Trending (Hindi/Bengali/etc), Search tabs               ║
// ║  • Background play with notification controls                    ║
// ║  • Thumbnail album art, ⏮ ⏯ ⏭ controls, download               ║
// ║  FILE NAME & CLASS NAME unchanged — only content changed         ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/track_model.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';

// ══════════════════════════════════════════════════════════════════
//  ReelsScreen root — এখন Music Screen
// ══════════════════════════════════════════════════════════════════

class ReelsScreen extends StatefulWidget {
  final bool isActive;
  const ReelsScreen({Key? key, this.isActive = true}) : super(key: key);

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _bg = Color(0xFF0A0A0A);
  static const _lime = Color(0xFFE8FF6B);
  static const _card = Color(0xFF141414);
  static const _border = Color(0xFF1E1E1E);

  // Genre chips for trending
  final _genres = [
    {'label': '🎵 Hindi', 'q': 'hindi songs 2024'},
    {'label': '🎶 Bengali', 'q': 'bengali songs 2024'},
    {'label': '🎸 Punjabi', 'q': 'punjabi hits 2024'},
    {'label': '🎤 English', 'q': 'english pop hits 2024'},
    {'label': '🎹 Lo-fi', 'q': 'lofi chill music'},
    {'label': '🎻 Classical', 'q': 'indian classical music'},
    {'label': '💃 Dance', 'q': 'dance hits bollywood'},
    {'label': '😌 Sad', 'q': 'sad songs hindi 2024'},
    {'label': '🕉 Devotional', 'q': 'bhakti songs hindi'},
    {'label': '🎬 OST', 'q': 'bollywood ost 2024'},
  ];
  int _selectedGenre = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mp = context.read<MediaProvider>();
      mp.loadFeed(refresh: true);
      mp.loadTrending(category: 'music');
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _playTrack(Track track) {
    final mp = context.read<MediaProvider>();
    final all = [...mp.feed, ...mp.trending, ...mp.searchResults];
    final queue = all.where((t) => t.ytVideoId != track.ytVideoId).toList();
    context.read<PlayerProvider>().playTrack(
          track,
          downloads: context.read<DownloadProvider>(),
        );
    // Add rest to queue for skip/prev
    context.read<PlayerProvider>().addMultipleToQueue(queue);
    _showNowPlaying(track);
  }

  void _showNowPlaying(Track track) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NowPlayingSheet(track: track),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          // ── Header ───────────────────────────────────────────
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(children: [
                const Text(
                  'Music',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _lime.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Filq',
                    style: TextStyle(
                      color: _lime,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                // Daily earn badge
                Consumer<MediaProvider>(
                  builder: (_, mp, __) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bolt_rounded, color: _lime, size: 13),
                      const SizedBox(width: 3),
                      Text(
                        '${mp.dailyWatchEarned}/${mp.dailyWatchLimit}',
                        style: const TextStyle(
                          color: _lime,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ]),
                  ),
                ),
              ]),
            ),
          ),

          // ── Tab bar ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TabBar(
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
                Tab(text: '🏠  Feed'),
                Tab(text: '🔥  Trending'),
                Tab(text: '🔍  Search'),
              ],
            ),
          ),

          // ── Content ──────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _FeedTab(onPlay: _playTrack),
                _TrendingTab(
                  genres: _genres,
                  selectedGenre: _selectedGenre,
                  onGenreChange: (i) {
                    setState(() => _selectedGenre = i);
                    context
                        .read<MediaProvider>()
                        .search(_genres[i]['q']!, type: 'music');
                  },
                  onPlay: _playTrack,
                ),
                _SearchTab(onPlay: _playTrack),
              ],
            ),
          ),

          // ── Mini player ───────────────────────────────────────
          _MiniPlayer(onTap: (track) => _showNowPlaying(track)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Feed Tab
// ══════════════════════════════════════════════════════════════════

class _FeedTab extends StatefulWidget {
  final void Function(Track) onPlay;
  const _FeedTab({required this.onPlay});

  @override
  State<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends State<_FeedTab> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
        context.read<MediaProvider>().loadMoreFeed();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(
      builder: (_, mp, __) {
        if (mp.feedState == MediaFeedState.loading && mp.feed.isEmpty) {
          return const _Shimmer();
        }
        if (mp.feedState == MediaFeedState.error && mp.feed.isEmpty) {
          return _ErrorView(
            msg: mp.error ?? 'Failed to load',
            onRetry: () => mp.loadFeed(refresh: true),
          );
        }
        return RefreshIndicator(
          color: const Color(0xFFE8FF6B),
          backgroundColor: const Color(0xFF141414),
          onRefresh: () => mp.loadFeed(refresh: true),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: mp.feed.length + (mp.feedHasMore ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == mp.feed.length) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFE8FF6B), strokeWidth: 2),
                  ),
                );
              }
              return _TrackCard(
                track: mp.feed[i],
                onTap: () => widget.onPlay(mp.feed[i]),
              );
            },
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Trending Tab
// ══════════════════════════════════════════════════════════════════

class _TrendingTab extends StatefulWidget {
  final List<Map<String, String>> genres;
  final int selectedGenre;
  final void Function(int) onGenreChange;
  final void Function(Track) onPlay;

  const _TrendingTab({
    required this.genres,
    required this.selectedGenre,
    required this.onGenreChange,
    required this.onPlay,
  });

  @override
  State<_TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<_TrendingTab> {
  static const _lime = Color(0xFFE8FF6B);
  static const _card = Color(0xFF141414);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    // Load first genre on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<MediaProvider>()
          .search(widget.genres[0]['q']!, type: 'music');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Genre chips
      const SizedBox(height: 10),
      SizedBox(
        height: 38,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: widget.genres.length,
          itemBuilder: (_, i) {
            final sel = widget.selectedGenre == i;
            return GestureDetector(
              onTap: () => widget.onGenreChange(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: const EdgeInsets.only(right: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel ? _lime : _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: sel ? _lime : _border),
                ),
                child: Text(
                  widget.genres[i]['label']!,
                  style: TextStyle(
                    color:
                        sel ? const Color(0xFF0A0A0A) : const Color(0xFF888888),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      // Results
      Expanded(
        child: Consumer<MediaProvider>(
          builder: (_, mp, __) {
            if (mp.searchLoading) return const _Shimmer();
            if (mp.searchResults.isEmpty) {
              return _ErrorView(
                msg: 'No songs found',
                onRetry: () => context.read<MediaProvider>().search(
                    widget.genres[widget.selectedGenre]['q']!,
                    type: 'music'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              itemCount: mp.searchResults.length,
              itemBuilder: (_, i) => _TrackCard(
                track: mp.searchResults[i],
                rank: i + 1,
                onTap: () => widget.onPlay(mp.searchResults[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  Search Tab
// ══════════════════════════════════════════════════════════════════

class _SearchTab extends StatefulWidget {
  final void Function(Track) onPlay;
  const _SearchTab({required this.onPlay});

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  static const _suggestions = [
    '🎵 Arijit Singh',
    '🎶 Jubin Nautiyal',
    '🎤 Shreya Ghoshal',
    '💕 Romantic Hindi',
    '😌 Sad songs Bengali',
    '🔥 Trending Punjabi',
    '🎹 Lo-fi beats',
    '🎸 A.R. Rahman',
    '🕉 Bhakti songs',
    '🎬 Bollywood 2024',
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _search(String q) {
    _debounce?.cancel();
    if (q.trim().isEmpty) {
      context.read<MediaProvider>().clearSearch();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<MediaProvider>().search(q.trim(), type: 'music');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Search bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E1E1E)),
          ),
          child: Row(children: [
            const SizedBox(width: 14),
            const Icon(Icons.search_rounded,
                color: Color(0xFF555555), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _ctrl,
                onChanged: _search,
                autofocus: false,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Songs, artists, albums...',
                  hintStyle: TextStyle(color: Color(0xFF444444), fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_ctrl.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  context.read<MediaProvider>().clearSearch();
                  setState(() {});
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.close_rounded,
                      color: Color(0xFF555555), size: 18),
                ),
              ),
          ]),
        ),
      ),
      // Results / suggestions
      Expanded(
        child: Consumer<MediaProvider>(
          builder: (_, mp, __) {
            if (mp.searchLoading) return const _Shimmer();
            if (mp.lastQuery.isEmpty) {
              return _SearchSuggestionsView(
                suggestions: _suggestions,
                onTap: (q) {
                  final clean = q.replaceAll(RegExp(r'^[^\s]+\s'), '').trim();
                  _ctrl.text = clean;
                  setState(() {});
                  mp.search(clean, type: 'music');
                },
              );
            }
            if (mp.searchResults.isEmpty) {
              return _ErrorView(
                msg: 'No results for "${mp.lastQuery}"',
                onRetry: () => mp.search(mp.lastQuery, type: 'music'),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
              itemCount: mp.searchResults.length,
              itemBuilder: (_, i) => _TrackCard(
                track: mp.searchResults[i],
                onTap: () => widget.onPlay(mp.searchResults[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  Track Card — Spotify style horizontal row
// ══════════════════════════════════════════════════════════════════

class _TrackCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final int? rank;

  const _TrackCard({required this.track, required this.onTap, this.rank});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF1E1E1E)),
        ),
        child: Row(children: [
          // Rank
          if (rank != null) ...[
            SizedBox(
              width: 28,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: rank! <= 3
                      ? const Color(0xFFE8FF6B)
                      : const Color(0xFF555555),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: track.thumbnail,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 56,
                height: 56,
                color: const Color(0xFF1A1A1A),
                child: const Icon(Icons.music_note,
                    color: Color(0xFF333333), size: 22),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 56,
                height: 56,
                color: const Color(0xFF1A1A1A),
                child: const Icon(Icons.music_note,
                    color: Color(0xFF333333), size: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Title + channel
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Row(children: [
                  Text(
                    track.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 12,
                    ),
                  ),
                  if (track.durationLabel.isNotEmpty) ...[
                    const Text(' · ',
                        style:
                            TextStyle(color: Color(0xFF444444), fontSize: 12)),
                    Text(
                      track.durationLabel,
                      style: const TextStyle(
                          color: Color(0xFF555555), fontSize: 12),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Like + Play
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
          const SizedBox(width: 10),
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFE8FF6B),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Color(0xFF0A0A0A), size: 22),
          ),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Mini Player — bottom bar
// ══════════════════════════════════════════════════════════════════

class _MiniPlayer extends StatelessWidget {
  final void Function(Track) onTap;
  const _MiniPlayer({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final track = player.currentTrack;
        if (track == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => onTap(track),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              border: Border(top: BorderSide(color: Color(0xFF252525))),
            ),
            child: SafeArea(
              top: false,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                // Progress bar
                Consumer<PlayerProvider>(
                  builder: (_, p, __) {
                    final pos = p.position.inMilliseconds.toDouble();
                    final dur = p.duration.inMilliseconds.toDouble();
                    final progress =
                        dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                    return LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF252525),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFE8FF6B)),
                      minHeight: 2,
                    );
                  },
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(children: [
                    // Album art
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CachedNetworkImage(
                        imageUrl: track.thumbnail,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: const Color(0xFF1A1A1A),
                          child: const Icon(Icons.music_note,
                              color: Color(0xFF444444)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            track.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            track.channel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Prev
                    IconButton(
                      icon: const Icon(Icons.skip_previous_rounded,
                          color: Colors.white, size: 26),
                      onPressed: () => player.previousTrack(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 4),
                    // Play/Pause
                    player.status == PlayerStatus.loading
                        ? const SizedBox(
                            width: 36,
                            height: 36,
                            child: CircularProgressIndicator(
                                color: Color(0xFFE8FF6B), strokeWidth: 2),
                          )
                        : GestureDetector(
                            onTap: () => player.togglePlayPause(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8FF6B),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: const Color(0xFF0A0A0A),
                                size: 22,
                              ),
                            ),
                          ),
                    const SizedBox(width: 4),
                    // Next
                    IconButton(
                      icon: const Icon(Icons.skip_next_rounded,
                          color: Colors.white, size: 26),
                      onPressed: () => player.nextTrack(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Now Playing Full Sheet — Spotify style
// ══════════════════════════════════════════════════════════════════

class _NowPlayingSheet extends StatefulWidget {
  final Track track;
  const _NowPlayingSheet({required this.track});

  @override
  State<_NowPlayingSheet> createState() => _NowPlayingSheetState();
}

class _NowPlayingSheetState extends State<_NowPlayingSheet> {
  static const _lime = Color(0xFFE8FF6B);

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Consumer<PlayerProvider>(
      builder: (_, player, __) {
        final track = player.currentTrack ?? widget.track;

        return Container(
          height: size.height * 0.92,
          decoration: const BoxDecoration(
            color: Color(0xFF0F0F0F),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 30),
                ),
                const Expanded(
                  child: Text(
                    'Now Playing',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                // Download button
                Consumer<DownloadProvider>(
                  builder: (_, dl, __) {
                    final ds = dl.stateOf(track.ytVideoId);
                    return GestureDetector(
                      onTap: ds.isAudioDownloading
                          ? () => dl.cancelAudio(track.ytVideoId)
                          : ds.isAudioDownloaded
                              ? null
                              : () {
                                  dl.cacheTrack(track);
                                  dl.downloadAudio(track);
                                },
                      child: ds.isAudioDownloading
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                value: ds.audioProgress,
                                strokeWidth: 2,
                                color: _lime,
                              ),
                            )
                          : Icon(
                              ds.isAudioDownloaded
                                  ? Icons.download_done_rounded
                                  : Icons.download_for_offline_rounded,
                              color: ds.isAudioDownloaded
                                  ? Colors.green
                                  : const Color(0xFF666666),
                              size: 26,
                            ),
                    );
                  },
                ),
              ]),
            ),

            // Album art — big thumbnail
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: track.thumbnail,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                        child: Icon(Icons.music_note,
                            color: Color(0xFF333333), size: 60),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF1A1A1A),
                      child: const Center(
                        child: Icon(Icons.music_note,
                            color: Color(0xFF333333), size: 60),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Title + like
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        track.channel,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
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
                      size: 28,
                    ),
                  ),
                ),
              ]),
            ),

            // Seek bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final dur = player.duration;
                  final total = dur.inMilliseconds.toDouble();
                  final current = pos.inMilliseconds.toDouble();
                  return Column(children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 16),
                        activeTrackColor: _lime,
                        inactiveTrackColor: const Color(0xFF2A2A2A),
                        thumbColor: _lime,
                        overlayColor: _lime.withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 0,
                        max: total > 0 ? total : 1,
                        value: current.clamp(0, total > 0 ? total : 1),
                        onChanged: (v) =>
                            player.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(pos),
                              style: const TextStyle(
                                  color: Color(0xFF555555), fontSize: 12)),
                          Text(_fmt(dur),
                              style: const TextStyle(
                                  color: Color(0xFF555555), fontSize: 12)),
                        ],
                      ),
                    ),
                  ]);
                },
              ),
            ),

            // Controls ⏮ ⏯ ⏭
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  GestureDetector(
                    onTap: () => player.toggleShuffle(),
                    child: Icon(
                      Icons.shuffle_rounded,
                      color: player.isShuffle ? _lime : const Color(0xFF444444),
                      size: 26,
                    ),
                  ),
                  // Prev
                  GestureDetector(
                    onTap: () => player.previousTrack(),
                    child: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white, size: 40),
                  ),
                  // Play/Pause
                  GestureDetector(
                    onTap: () => player.togglePlayPause(),
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        color: _lime,
                        shape: BoxShape.circle,
                      ),
                      child: player.status == PlayerStatus.loading
                          ? const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF0A0A0A),
                                  strokeWidth: 2.5,
                                ),
                              ),
                            )
                          : Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFF0A0A0A),
                              size: 36,
                            ),
                    ),
                  ),
                  // Next
                  GestureDetector(
                    onTap: () => player.nextTrack(),
                    child: const Icon(Icons.skip_next_rounded,
                        color: Colors.white, size: 40),
                  ),
                  // Loop
                  GestureDetector(
                    onTap: () => player.toggleLoopMode(),
                    child: Icon(
                      player.loopMode == 'one'
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: player.loopMode == 'none'
                          ? const Color(0xFF444444)
                          : _lime,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
          ]),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Search Suggestions
// ══════════════════════════════════════════════════════════════════

class _SearchSuggestionsView extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _SearchSuggestionsView(
      {required this.suggestions, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        const Text(
          'Popular searches',
          style: TextStyle(
            color: Color(0xFF666666),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) {
            return GestureDetector(
              onTap: () => onTap(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1E1E1E)),
                ),
                child: Text(
                  s,
                  style:
                      const TextStyle(color: Color(0xFFCCCCCC), fontSize: 13),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Shimmer Loading
// ══════════════════════════════════════════════════════════════════

class _Shimmer extends StatefulWidget {
  const _Shimmer();

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF141414),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(children: [
              Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                      color: c, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 13,
                        decoration: BoxDecoration(
                            color: c, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 7),
                    Container(
                        height: 11,
                        width: 100,
                        decoration: BoxDecoration(
                            color: c, borderRadius: BorderRadius.circular(4))),
                  ],
                ),
              ),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Error / Empty View
// ══════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;
  const _ErrorView({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🎵', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF555555), fontSize: 14),
          ),
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
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFFE8FF6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
