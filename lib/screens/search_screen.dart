// search_screen.dart
// YouTube-style dedicated search screen

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../models/track_model.dart';
import '../providers/media_provider.dart';
import 'media_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);
  static const _card = Color(0xFF141414);
  static const _border = Color(0xFF1E1E1E);

  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _hasTyped = false;

  static const _suggestions = [
    '🎵 Arijit Singh',
    '🎶 Bollywood Hits 2024',
    '🎸 Lo-fi Music',
    '🎤 Taylor Swift',
    '🥁 Hip Hop Beats',
    '📻 Chill Vibes',
    '🎻 Classical Music',
    '🎹 Piano Relaxing',
    '🎙️ Atif Aslam',
    '🎺 EDM Mix',
    '🎼 K-pop',
    '🪗 Folk Songs',
  ];

  @override
  void initState() {
    super.initState();
    // Auto-focus keyboard when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String q) {
    setState(() => _hasTyped = q.isNotEmpty);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (q.trim().isNotEmpty) {
        context.read<MediaProvider>().search(q.trim(), type: 'any');
      } else {
        context.read<MediaProvider>().clearSearch();
      }
    });
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _hasTyped = false);
    context.read<MediaProvider>().clearSearch();
    _focusNode.requestFocus();
  }

  void _submitSearch(String q) {
    if (q.trim().isEmpty) return;
    _focusNode.unfocus();
    context.read<MediaProvider>().search(q.trim(), type: 'any');
  }

  void _tapSuggestion(String raw) {
    final q = raw.replaceAll(RegExp(r'^[^\s]+\s'), '');
    _searchCtrl.text = q;
    setState(() => _hasTyped = true);
    context.read<MediaProvider>().search(q, type: 'any');
    _focusNode.unfocus();
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
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  // Back arrow
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: Colors.white, size: 24),
                    splashRadius: 22,
                  ),
                  // Search field
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: _card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _focusNode.hasFocus
                              ? _lime.withOpacity(0.5)
                              : _border,
                        ),
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _focusNode,
                        onChanged: _onSearchChanged,
                        onSubmitted: _submitSearch,
                        textInputAction: TextInputAction.search,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: 'Search songs, videos...',
                          hintStyle: const TextStyle(
                              color: Color(0xFF555555), fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded,
                              color: Color(0xFF666666), size: 21),
                          suffixIcon: _hasTyped
                              ? GestureDetector(
                                  onTap: _clearSearch,
                                  child: const Icon(Icons.close_rounded,
                                      color: Color(0xFF777777), size: 19),
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────────────────────
            Expanded(
              child: Consumer<MediaProvider>(
                builder: (_, mp, __) {
                  // Loading
                  if (mp.searchLoading) {
                    return _SearchShimmer();
                  }

                  // Has search results
                  if (_hasTyped && mp.searchResults.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                      itemCount: mp.searchResults.length,
                      itemBuilder: (_, i) => _SearchResultTile(
                        track: mp.searchResults[i],
                        onTap: () => _openPlayer(mp.searchResults[i]),
                      ),
                    );
                  }

                  // Typed but no results
                  if (_hasTyped &&
                      mp.searchResults.isEmpty &&
                      mp.lastQuery.isNotEmpty) {
                    return _NoResults(query: mp.lastQuery);
                  }

                  // Default: suggestions grid
                  return _SuggestionsView(
                    suggestions: _suggestions,
                    onTap: _tapSuggestion,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Search Result Tile — compact YouTube-style
// ══════════════════════════════════════════════════════════════════

class _SearchResultTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  const _SearchResultTile({required this.track, required this.onTap});

  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withOpacity(0.04),
      highlightColor: Colors.white.withOpacity(0.02),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: track.thumbnail,
                    width: 130,
                    height: 74,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      width: 130,
                      height: 74,
                      color: const Color(0xFF1A1A1A),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: 130,
                      height: 74,
                      color: const Color(0xFF1A1A1A),
                      child: const Icon(Icons.play_circle_outline,
                          color: Color(0xFF333333), size: 28),
                    ),
                  ),
                  if (track.durationSeconds > 0)
                    Positioned(
                      bottom: 4,
                      right: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          track.durationLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Info
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
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF777777), fontSize: 12),
                  ),
                  if (track.viewCount > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      '${track.viewCountLabel} views',
                      style: const TextStyle(
                          color: Color(0xFF555555), fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            // Three dot menu
            GestureDetector(
              onTap: () {},
              child: const Padding(
                padding: EdgeInsets.only(left: 4, top: 2),
                child: Icon(Icons.more_vert_rounded,
                    color: Color(0xFF555555), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Suggestions Grid
// ══════════════════════════════════════════════════════════════════

class _SuggestionsView extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onTap;
  const _SuggestionsView(
      {required this.suggestions, required this.onTap});

  static const _colors = [
    Color(0xFF1A2744),
    Color(0xFF2A1A1A),
    Color(0xFF1A2A1A),
    Color(0xFF2A1A2A),
    Color(0xFF1A2226),
    Color(0xFF26221A),
    Color(0xFF221A26),
    Color(0xFF1A2622),
    Color(0xFF262222),
    Color(0xFF22261A),
    Color(0xFF261A22),
    Color(0xFF1A2626),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: Text(
              'Explore',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: suggestions.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 3.2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (_, i) {
              final color = _colors[i % _colors.length];
              return GestureDetector(
                onTap: () => onTap(suggestions[i]),
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    suggestions[i],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  No Results
// ══════════════════════════════════════════════════════════════════

class _NoResults extends StatelessWidget {
  final String query;
  const _NoResults({required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off_rounded,
                color: Color(0xFF333333), size: 56),
            const SizedBox(height: 16),
            Text(
              'No results for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Color(0xFF666666),
                  fontSize: 15,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try different keywords',
              style: TextStyle(color: Color(0xFF444444), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Shimmer
// ══════════════════════════════════════════════════════════════════

class _SearchShimmer extends StatefulWidget {
  @override
  State<_SearchShimmer> createState() => _SearchShimmerState();
}

class _SearchShimmerState extends State<_SearchShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
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
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: 6,
          itemBuilder: (_, __) => Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 130,
                  height: 74,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 13,
                        decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 11,
                        width: 100,
                        decoration: BoxDecoration(
                            color: c,
                            borderRadius: BorderRadius.circular(4)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}