// ╔══════════════════════════════════════════════════════════════════╗
// ║  media_screen.dart — YouTube-style Media Screen                  ║
// ║  Tabs: 🏠 Feed | 🔥 Trending | 🔍 Search | ❤️ Liked             ║
// ║  Inline video/audio player with coins earning                    ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

import '../models/track_model.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../providers/wallet_provider.dart';
import '../services/player_service.dart';

// ══════════════════════════════════════════════════════════════════
//  Media Screen Root
// ══════════════════════════════════════════════════════════════════

class MediaScreen extends StatefulWidget {
  const MediaScreen({Key? key}) : super(key: key);

  @override
  State<MediaScreen> createState() => _MediaScreenState();
}

class _MediaScreenState extends State<MediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  Track? _playerTrack;
  bool _playerVisible = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaProvider>().loadFeed(refresh: true);
      context.read<MediaProvider>().loadTrending();
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openPlayer(Track track) {
    setState(() {
      _playerTrack = track;
      _playerVisible = true;
    });
    context.read<PlayerProvider>().playTrack(track);
  }

  void _closePlayer() {
    setState(() => _playerVisible = false);
    context.read<PlayerProvider>().clearQueue();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _FeedTab(onPlay: _openPlayer),
                  _TrendingTab(onPlay: _openPlayer),
                  _SearchTab(onPlay: _openPlayer),
                  _LikedTab(onPlay: _openPlayer),
                ],
              ),
            ),
            // Inline mini player at bottom
            if (_playerVisible && _playerTrack != null)
              _InlinePlayer(
                track: _playerTrack!,
                onClose: _closePlayer,
                onExpand: () => _showFullPlayer(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
        child: Row(children: [
          const Text('Filq',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFE8FF6B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Media',
                style: TextStyle(
                    color: Color(0xFFE8FF6B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
          const Spacer(),
          Consumer<MediaProvider>(
            builder: (_, mp, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.play_circle_fill_rounded,
                    color: Color(0xFFE8FF6B), size: 13),
                const SizedBox(width: 5),
                Text('${mp.dailyWatchEarned}/${mp.dailyWatchLimit} coins',
                    style: const TextStyle(
                        color: Color(0xFFE8FF6B),
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: TabBar(
        controller: _tab,
        indicatorColor: const Color(0xFFE8FF6B),
        indicatorWeight: 2,
        labelColor: const Color(0xFFE8FF6B),
        unselectedLabelColor: const Color(0xFF555555),
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        tabs: const [
          Tab(text: '🏠  Feed'),
          Tab(text: '🔥  Trending'),
          Tab(text: '🔍  Search'),
          Tab(text: '❤️  Liked'),
        ],
      ),
    );
  }

  void _showFullPlayer(BuildContext context) {
    if (_playerTrack == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullPlayerScreen(track: _playerTrack!),
        fullscreenDialog: true,
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
          return const _ShimmerList();
        }
        if (mp.feedState == MediaFeedState.error && mp.feed.isEmpty) {
          return _ErrorState(
            msg: mp.error ?? 'Failed to load feed',
            onRetry: () => mp.loadFeed(refresh: true),
          );
        }
        return RefreshIndicator(
          color: const Color(0xFFE8FF6B),
          backgroundColor: const Color(0xFF141414),
          onRefresh: () => mp.loadFeed(refresh: true),
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
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
              return _VideoCard(
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
  final void Function(Track) onPlay;
  const _TrendingTab({required this.onPlay});

  @override
  State<_TrendingTab> createState() => _TrendingTabState();
}

class _TrendingTabState extends State<_TrendingTab> {
  final _categories = ['music', 'gaming', 'news', 'sports', 'any'];
  final _labels = ['🎵 Music', '🎮 Gaming', '📰 News', '⚽ Sports', '🌐 All'];

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(
      builder: (_, mp, __) => Column(
        children: [
          // Category chips
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
              itemCount: _categories.length,
              itemBuilder: (_, i) {
                final selected = mp.trendingCategory == _categories[i];
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => mp.loadTrending(category: _categories[i]),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFFE8FF6B)
                            : const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFE8FF6B)
                              : const Color(0xFF1E1E1E),
                        ),
                      ),
                      child: Text(
                        _labels[i],
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF0F0F0F)
                              : const Color(0xFF888888),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: mp.trendingLoading
                ? const _ShimmerList()
                : mp.trending.isEmpty
                    ? _ErrorState(
                        msg: 'Nothing trending right now',
                        onRetry: () => mp.loadTrending(),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
                        itemCount: mp.trending.length,
                        itemBuilder: (_, i) => _VideoCard(
                          track: mp.trending[i],
                          onTap: () => widget.onPlay(mp.trending[i]),
                          rank: i + 1,
                        ),
                      ),
          ),
        ],
      ),
    );
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
  String _type = 'any';

  static const _types = ['any', 'music', 'video'];
  static const _typeLabels = ['All', '🎵 Music', '🎬 Video'];

  @override
  void dispose() {
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      context.read<MediaProvider>().search(q, type: _type);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF1E1E1E)),
                ),
                child: TextField(
                  controller: _ctrl,
                  onChanged: _onChanged,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search videos, songs, channels...',
                    hintStyle:
                        TextStyle(color: Color(0xFF444444), fontSize: 13),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: Color(0xFF555555), size: 20),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
            ),
            if (_ctrl.text.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  _ctrl.clear();
                  context.read<MediaProvider>().clearSearch();
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Color(0xFF555555), size: 18),
                ),
              ),
            ],
          ]),
        ),
        // Type filter
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            itemCount: _types.length,
            itemBuilder: (_, i) {
              final sel = _type == _types[i];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _type = _types[i]);
                    if (_ctrl.text.isNotEmpty) {
                      context
                          .read<MediaProvider>()
                          .search(_ctrl.text, type: _types[i]);
                    }
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: sel
                          ? const Color(0xFFE8FF6B).withOpacity(0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFFE8FF6B).withOpacity(0.5)
                            : const Color(0xFF1E1E1E),
                      ),
                    ),
                    child: Text(
                      _typeLabels[i],
                      style: TextStyle(
                        color: sel
                            ? const Color(0xFFE8FF6B)
                            : const Color(0xFF666666),
                        fontSize: 12,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Results
        Expanded(
          child: Consumer<MediaProvider>(
            builder: (_, mp, __) {
              if (mp.searchLoading) return const _ShimmerList();
              if (mp.lastQuery.isEmpty) {
                return _SearchSuggestions(
                  onTap: (q) {
                    _ctrl.text = q;
                    mp.search(q, type: _type);
                  },
                );
              }
              if (mp.searchResults.isEmpty) {
                return _ErrorState(
                  msg: 'No results for "${mp.lastQuery}"',
                  onRetry: () => mp.search(mp.lastQuery, type: _type),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                itemCount: mp.searchResults.length,
                itemBuilder: (_, i) => _VideoCard(
                  track: mp.searchResults[i],
                  onTap: () => widget.onPlay(mp.searchResults[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchSuggestions extends StatelessWidget {
  final void Function(String) onTap;
  const _SearchSuggestions({required this.onTap});

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
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Popular searches',
            style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _suggestions.map((s) {
            return GestureDetector(
              onTap: () => onTap(s.replaceAll(RegExp(r'^[^\s]+ '), '')),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Liked Tab
// ══════════════════════════════════════════════════════════════════

class _LikedTab extends StatefulWidget {
  final void Function(Track) onPlay;
  const _LikedTab({required this.onPlay});

  @override
  State<_LikedTab> createState() => _LikedTabState();
}

class _LikedTabState extends State<_LikedTab> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MediaProvider>().loadLiked();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MediaProvider>(
      builder: (_, mp, __) {
        if (mp.likedLoading) return const _ShimmerList();
        if (mp.liked.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border_rounded,
                    color: Colors.white.withOpacity(0.15), size: 56),
                const SizedBox(height: 14),
                const Text('No liked videos yet',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 15)),
                const SizedBox(height: 6),
                const Text('Tap ❤️ on any video to save it here',
                    style: TextStyle(color: Color(0xFF333333), fontSize: 12)),
              ],
            ),
          );
        }
        return RefreshIndicator(
          color: const Color(0xFFE8FF6B),
          backgroundColor: const Color(0xFF141414),
          onRefresh: () => mp.loadLiked(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
            itemCount: mp.liked.length,
            itemBuilder: (_, i) => _VideoCard(
              track: mp.liked[i],
              onTap: () => widget.onPlay(mp.liked[i]),
            ),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Video Card (YouTube-style)
// ══════════════════════════════════════════════════════════════════

class _VideoCard extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final int? rank;

  const _VideoCard({
    required this.track,
    required this.onTap,
    this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnail,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.play_circle_outline,
                        color: Color(0xFF333333), size: 48),
                  ),
                ),
              ),
              // Duration badge
              if (track.durationSeconds > 0)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      track.durationLabel,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              // Play overlay
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                  ),
                ),
              ),
              // Rank badge
              if (rank != null)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: rank! <= 3
                          ? const Color(0xFFE8FF6B)
                          : const Color(0xFF141414),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: rank! <= 3
                              ? const Color(0xFFE8FF6B)
                              : const Color(0xFF333333)),
                    ),
                    child: Center(
                      child: Text(
                        '#$rank',
                        style: TextStyle(
                          color: rank! <= 3
                              ? const Color(0xFF0F0F0F)
                              : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Info row
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Channel avatar placeholder
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF1A1A1A),
              child: Text(
                track.channel.isNotEmpty ? track.channel[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: Color(0xFFE8FF6B),
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
            const SizedBox(width: 10),
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
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          height: 1.3),
                    ),
                    const SizedBox(height: 3),
                    Row(children: [
                      Text(track.channel,
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 12)),
                      if (track.viewCount > 0) ...[
                        const Text(' • ',
                            style: TextStyle(
                                color: Color(0xFF444444), fontSize: 12)),
                        Text(track.viewCountLabel,
                            style: const TextStyle(
                                color: Color(0xFF666666), fontSize: 12)),
                      ],
                    ]),
                  ]),
            ),
            // Like button
            Consumer<MediaProvider>(
              builder: (_, mp, __) => GestureDetector(
                onTap: () => mp.toggleLike(track.ytVideoId),
                child: Padding(
                  padding: const EdgeInsets.only(left: 8),
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
            ),
          ]),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Inline Mini Player
// ══════════════════════════════════════════════════════════════════

class _InlinePlayer extends StatelessWidget {
  final Track track;
  final VoidCallback onClose;
  final VoidCallback onExpand;

  const _InlinePlayer({
    required this.track,
    required this.onClose,
    required this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (_, player, __) => GestureDetector(
        onTap: onExpand,
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            border: Border(top: BorderSide(color: Color(0xFF1E1E1E))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SafeArea(
            top: false,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Progress bar
              Consumer<PlayerProvider>(
                builder: (_, p, __) {
                  final pos = p.position.inMilliseconds.toDouble();
                  final dur = p.duration.inMilliseconds.toDouble();
                  final progress = dur > 0 ? (pos / dur).clamp(0.0, 1.0) : 0.0;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF1E1E1E),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFE8FF6B)),
                      minHeight: 2,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              Row(children: [
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      Text(track.channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Loading indicator or play/pause
                if (player.status == PlayerStatus.loading)
                  const SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                        color: Color(0xFFE8FF6B), strokeWidth: 2),
                  )
                else
                  IconButton(
                    onPressed: () => player.togglePlayPause(),
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF555555), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Full Player Screen
// ══════════════════════════════════════════════════════════════════

class FullPlayerScreen extends StatefulWidget {
  final Track track;
  const FullPlayerScreen({Key? key, required this.track}) : super(key: key);

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  static const _bg = Color(0xFF0A0A0A);
  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Consumer<PlayerProvider>(
          builder: (_, player, __) => Column(children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                Expanded(
                  child: Column(children: [
                    const Text('NOW PLAYING',
                        style: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2)),
                    const SizedBox(height: 2),
                    Text(widget.track.channel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
                Consumer<MediaProvider>(
                  builder: (_, mp, __) => IconButton(
                    icon: Icon(
                      mp.isLiked(widget.track.ytVideoId)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: mp.isLiked(widget.track.ytVideoId)
                          ? Colors.redAccent
                          : const Color(0xFF555555),
                    ),
                    onPressed: () => mp.toggleLike(widget.track.ytVideoId),
                  ),
                ),
              ]),
            ),
            // Thumbnail / artwork
            Expanded(
              flex: 5,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: widget.track.thumbnail,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF141414),
                      child: const Icon(Icons.music_note,
                          color: Color(0xFF333333), size: 60),
                    ),
                  ),
                ),
              ),
            ),
            // Track info
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              height: 1.2)),
                      const SizedBox(height: 4),
                      Text(widget.track.channel,
                          style: const TextStyle(
                              color: Color(0xFF666666), fontSize: 14)),
                    ],
                  ),
                ),
                // Coins earned badge
                Consumer<MediaProvider>(
                  builder: (_, mp, __) => Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _lime.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _lime.withOpacity(0.3)),
                    ),
                    child: Column(children: [
                      Text('${mp.dailyWatchEarned}',
                          style: const TextStyle(
                              color: _lime,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      const Text('coins',
                          style:
                              TextStyle(color: Color(0xFF555555), fontSize: 9)),
                    ]),
                  ),
                ),
              ]),
            ),
            // Seek bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: StreamBuilder<Duration>(
                stream: player.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? Duration.zero;
                  final dur = player.duration;
                  final total = dur.inMilliseconds.toDouble();
                  final current = pos.inMilliseconds
                      .toDouble()
                      .clamp(0.0, total.isFinite && total > 0 ? total : 0.0);
                  return Column(children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape:
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
                        activeTrackColor: _lime,
                        inactiveTrackColor: const Color(0xFF222222),
                        thumbColor: _lime,
                        overlayColor: _lime.withOpacity(0.2),
                      ),
                      child: Slider(
                        min: 0,
                        max: total > 0 ? total : 1,
                        value: current,
                        onChanged: (v) =>
                            player.seek(Duration(milliseconds: v.toInt())),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
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
            // Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Shuffle
                  IconButton(
                    icon: Icon(Icons.shuffle_rounded,
                        color:
                            player.isShuffle ? _lime : const Color(0xFF444444),
                        size: 24),
                    onPressed: () => player.toggleShuffle(),
                  ),
                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => player.previousTrack(),
                  ),
                  // Play/Pause
                  GestureDetector(
                    onTap: () => player.togglePlayPause(),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: _lime,
                        shape: BoxShape.circle,
                      ),
                      child: player.status == PlayerStatus.loading
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    color: Color(0xFF0F0F0F), strokeWidth: 2),
                              ),
                            )
                          : Icon(
                              player.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: const Color(0xFF0F0F0F),
                              size: 32,
                            ),
                    ),
                  ),
                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => player.nextTrack(),
                  ),
                  // Loop
                  IconButton(
                    icon: Icon(
                      player.loopMode == 'one'
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      color: player.loopMode == 'none'
                          ? const Color(0xFF444444)
                          : _lime,
                      size: 24,
                    ),
                    onPressed: () => player.toggleLoopMode(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ]),
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

// ══════════════════════════════════════════════════════════════════
//  Shimmer Loading List
// ══════════════════════════════════════════════════════════════════

class _ShimmerList extends StatefulWidget {
  const _ShimmerList();

  @override
  State<_ShimmerList> createState() => _ShimmerListState();
}

class _ShimmerListState extends State<_ShimmerList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
        final shimmerColor = Color.lerp(
            const Color(0xFF1A1A1A), const Color(0xFF252525), _anim.value)!;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
          itemCount: 5,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: shimmerColor,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: shimmerColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(children: [
                    Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: 12,
                      width: 120,
                      decoration: BoxDecoration(
                        color: shimmerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ]),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Error State
// ══════════════════════════════════════════════════════════════════

class _ErrorState extends StatelessWidget {
  final String msg;
  final VoidCallback onRetry;

  const _ErrorState({required this.msg, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('😕', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          Text(msg,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF555555), fontSize: 14)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
