// ╔══════════════════════════════════════════════════════════════════╗
// ║  media_screen.dart — YouTube-style Media Screen                  ║
// ║  Tabs: 🏠 Feed | 🔥 Trending | 🔍 Search | ❤️ Liked             ║
// ║  Features:                                                        ║
// ║    • Video tap → real video player (video_player + chewie)       ║
// ║    • Music tap → audio player (just_audio background)            ║
// ║    • Double-tap ±10s seek                                        ║
// ║    • Fullscreen (landscape rotate)                               ║
// ║    • Screen-off background play (audio)                          ║
// ║    • Autoplay next — toggle on/off                               ║
// ║    • Suggested videos below player                               ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../models/track_model.dart';
import '../providers/media_provider.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
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
    // Video → open full video screen
    if (track.category != 'music') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoPlayerScreen(
            track: track,
            suggestedTracks: _getSuggested(track),
          ),
        ),
      );
      return;
    }
    // Music → audio player (inline + background)
    // FIX: pass DownloadProvider so offline tracks play without internet
    setState(() {
      _playerTrack = track;
      _playerVisible = true;
    });
    context.read<PlayerProvider>().playTrack(
          track,
          downloads: context.read<DownloadProvider>(),
        );
  }

  List<Track> _getSuggested(Track track) {
    final mp = context.read<MediaProvider>();
    final all = [...mp.feed, ...mp.trending, ...mp.searchResults];
    return all.where((t) => t.ytVideoId != track.ytVideoId).take(15).toList();
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
            // Inline mini audio player at bottom
            if (_playerVisible && _playerTrack != null)
              _InlinePlayer(
                track: _playerTrack!,
                onClose: _closePlayer,
                onExpand: () => _showFullAudioPlayer(context),
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

  void _showFullAudioPlayer(BuildContext context) {
    if (_playerTrack == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullAudioPlayerScreen(track: _playerTrack!),
        fullscreenDialog: true,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  VIDEO PLAYER SCREEN — YouTube-style
//  • video_player + chewie
//  • Double-tap left/right ±10s seek
//  • Fullscreen (landscape)
//  • Autoplay toggle
//  • Suggested videos below
// ══════════════════════════════════════════════════════════════════

class VideoPlayerScreen extends StatefulWidget {
  final Track track;
  final List<Track> suggestedTracks;

  const VideoPlayerScreen({
    Key? key,
    required this.track,
    this.suggestedTracks = const [],
  }) : super(key: key);

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen>
    with WidgetsBindingObserver {
  YoutubePlayerController? _ytCtrl;

  bool _loading = true;
  String? _error;
  bool _autoplay = true;
  bool _showDoubleTapLeft = false;
  bool _showDoubleTapRight = false;
  Timer? _doubleTapTimer;

  // Background audio: screen-off / minimize এ just_audio দিয়ে চলবে
  bool _backgroundAudioActive = false;

  // FIX: Fullscreen state tracking
  bool _isFullscreen = false;

  // FIX: Quality options — YouTube player flags
  final List<Map<String, dynamic>> _qualityOptions = [
    {'label': 'Auto', 'hd': false},
    {'label': 'HD 720p', 'hd': true},
  ];
  int _selectedQuality = 0; // 0 = Auto, 1 = HD

  // Track watch time for coin earning
  Timer? _watchTimer;
  int _watchedSeconds = 0;
  bool _coinLogged = false;

  static const _bg = Color(0xFF0F0F0F);
  static const _lime = Color(0xFFE8FF6B);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initPlayer(widget.track);
  }

  // ── App lifecycle: screen off / minimize → background audio ──────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App background গেছে — YouTube WebView pause হবে।
      // just_audio দিয়ে audio stream চালু রাখো।
      _activateBackgroundAudio();
    } else if (state == AppLifecycleState.resumed) {
      // App foreground এ ফিরলে background audio বন্ধ, YouTube আবার চালু।
      _deactivateBackgroundAudio();
    }
  }

  Future<void> _activateBackgroundAudio() async {
    if (_backgroundAudioActive) return;
    final track = widget.track;
    if (track.ytVideoId.isEmpty) return;
    _backgroundAudioActive = true;
    // YouTube player pause করো (background এ এমনিই হবে, explicit করা better)
    _ytCtrl?.pause();
    // just_audio দিয়ে audio-only stream চালু করো
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    await playerProvider.playTrack(track);
  }

  Future<void> _deactivateBackgroundAudio() async {
    if (!_backgroundAudioActive) return;
    _backgroundAudioActive = false;
    // Background audio বন্ধ করো
    final playerProvider = Provider.of<PlayerProvider>(context, listen: false);
    await playerProvider.togglePlayPause(); // pause করবে
    // YouTube player আবার চালু করো — seek করে position মেলাও
    _ytCtrl?.play();
  }

  void _initPlayer(Track track) {
    setState(() {
      _loading = true;
      _error = null;
      _watchedSeconds = 0;
      _coinLogged = false;
      _isFullscreen = false; // FIX: fullscreen reset on new video
    });

    // Dispose previous
    _ytCtrl?.dispose();
    _watchTimer?.cancel();

    final videoId = track.ytVideoId;
    if (videoId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Invalid video ID';
      });
      return;
    }

    try {
      _ytCtrl = YoutubePlayerController(
        initialVideoId: videoId,
        flags: YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          disableDragSeek: false,
          loop: false,
          isLive: false,
          forceHD: false,
          enableCaption: false,
        ),
      );

      _ytCtrl!.addListener(_onPlayerStateChange);

      setState(() => _loading = false);

      // Watch time tracker for coin earning
      _watchTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_ytCtrl?.value.isPlaying == true) {
          _watchedSeconds++;
          if (!_coinLogged && _watchedSeconds >= 30) {
            _coinLogged = true;
            context.read<MediaProvider>().logWatch(
                  track: track,
                  watchDurationSeconds: _watchedSeconds,
                );
          }
        }
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load video. Please try again.\n$e';
      });
    }
  }

  void _onPlayerStateChange() {
    final ctrl = _ytCtrl;
    if (ctrl == null) return;

    // Autoplay next when video ends
    if (ctrl.value.playerState == PlayerState.ended && _autoplay) {
      _playNext();
    }
  }

  // FIX: Fullscreen toggle — landscape/portrait orientation
  void _toggleFullscreen() {
    setState(() => _isFullscreen = !_isFullscreen);
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  // FIX: Quality change — recreates controller with forceHD flag
  void _changeQuality(int index) {
    if (_selectedQuality == index) return;
    setState(() => _selectedQuality = index);
    final currentPos = _ytCtrl?.value.position ?? Duration.zero;
    final videoId = widget.track.ytVideoId;

    _ytCtrl?.removeListener(_onPlayerStateChange);
    _ytCtrl?.dispose();

    _ytCtrl = YoutubePlayerController(
      initialVideoId: videoId,
      flags: YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        disableDragSeek: false,
        loop: false,
        forceHD: index == 1, // HD 720p
        enableCaption: false,
      ),
    );
    _ytCtrl!.addListener(_onPlayerStateChange);
    // Seek to previous position after ready
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && currentPos.inSeconds > 0) {
        _ytCtrl?.seekTo(currentPos);
      }
    });
    setState(() {});
  }

  void _showDeleteVideoDialog(BuildContext context, DownloadProvider dl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Remove Download',
            style: TextStyle(color: Colors.white)),
        content: const Text('Delete this downloaded video file?',
            style: TextStyle(color: Color(0xFF888888))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              dl.deleteVideo(widget.track.ytVideoId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _playNext() {
    if (widget.suggestedTracks.isEmpty) return;
    final next = widget.suggestedTracks.first;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          track: next,
          suggestedTracks: widget.suggestedTracks
              .where((t) => t.ytVideoId != next.ytVideoId)
              .toList(),
        ),
      ),
    );
  }

  void _seekLeft() {
    final pos = _ytCtrl?.value.position ?? Duration.zero;
    final target = pos - const Duration(seconds: 10);
    _ytCtrl?.seekTo(target < Duration.zero ? Duration.zero : target);
    setState(() => _showDoubleTapLeft = true);
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showDoubleTapLeft = false);
    });
  }

  void _seekRight() {
    final pos = _ytCtrl?.value.position ?? Duration.zero;
    final dur = _ytCtrl?.value.metaData.duration ?? Duration.zero;
    final target = pos + const Duration(seconds: 10);
    _ytCtrl?.seekTo(target > dur ? dur : target);
    setState(() => _showDoubleTapRight = true);
    _doubleTapTimer?.cancel();
    _doubleTapTimer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showDoubleTapRight = false);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _watchTimer?.cancel();
    _doubleTapTimer?.cancel();
    // Log final watch time
    if (_watchedSeconds > 5 && !_coinLogged) {
      context.read<MediaProvider>().logWatch(
            track: widget.track,
            watchDurationSeconds: _watchedSeconds,
          );
    }
    _ytCtrl?.removeListener(_onPlayerStateChange);
    _ytCtrl?.dispose();
    // FIX: Always restore portrait + system UI on leave
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    // YoutubePlayer needs to wrap the whole subtree
    if (_ytCtrl == null) {
      return Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Column(children: [
            _buildErrorOrLoading(screenW),
            Expanded(child: _buildInfoAndSuggested()),
          ]),
        ),
      );
    }

    return YoutubePlayerBuilder(
      player: YoutubePlayer(
        controller: _ytCtrl!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: _lime,
        progressColors: const ProgressBarColors(
          playedColor: _lime,
          handleColor: _lime,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
        onReady: () {
          debugPrint('[YoutubePlayer] ready');
        },
        onEnded: (_) {
          if (_autoplay) _playNext();
        },
      ),
      builder: (context, player) {
        // FIX: fullscreen mode — video takes entire screen
        if (_isFullscreen) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                Center(child: player),
                // Exit fullscreen button
                Positioned(
                  top: 12,
                  right: 12,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: _toggleFullscreen,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.fullscreen_exit_rounded,
                            color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ),
                // Back button
                Positioned(
                  top: 12,
                  left: 12,
                  child: SafeArea(
                    child: GestureDetector(
                      onTap: () {
                        _toggleFullscreen();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: _bg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Video player area ────────────────────────
                _buildVideoArea(screenW, player),

                // ── Info + controls + suggested (scrollable) ─
                Expanded(child: _buildInfoAndSuggested()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorOrLoading(double screenW) {
    final videoH = screenW * 9 / 16;
    return SizedBox(
      width: screenW,
      height: videoH,
      child: Container(
        color: Colors.black,
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE8FF6B)))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 40),
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                              textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE8FF6B),
                                foregroundColor: Colors.black),
                            onPressed: () => _initPlayer(widget.track),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildVideoArea(double screenW, Widget player) {
    final videoH = screenW * 9 / 16;

    return SizedBox(
      width: screenW,
      height: videoH,
      child: Stack(
        children: [
          // YouTube player
          player,

          // ── Double-tap zones ──────────────────────────────
          // Left zone — seek -10s
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: screenW * 0.35,
            child: GestureDetector(
              onDoubleTap: _seekLeft,
              behavior: HitTestBehavior.translucent,
              child: AnimatedOpacity(
                opacity: _showDoubleTapLeft ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black38, Colors.transparent],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.replay_10_rounded,
                            color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text('10 sec',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Right zone — seek +10s
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: screenW * 0.35,
            child: GestureDetector(
              onDoubleTap: _seekRight,
              behavior: HitTestBehavior.translucent,
              child: AnimatedOpacity(
                opacity: _showDoubleTapRight ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black38],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.forward_10_rounded,
                            color: Colors.white, size: 40),
                        SizedBox(height: 4),
                        Text('10 sec',
                            style:
                                TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 8,
            left: 4,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // FIX: Fullscreen + Quality buttons (bottom-right)
          Positioned(
            bottom: 6,
            right: 6,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quality selector button
                GestureDetector(
                  onTap: () => _showQualitySheet(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.settings_rounded,
                            color: Colors.white, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          _qualityOptions[_selectedQuality]['label'] as String,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Fullscreen button
                GestureDetector(
                  onTap: _toggleFullscreen,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      _isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // FIX: Quality sheet — bottom modal
  void _showQualitySheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Video Quality',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ..._qualityOptions.asMap().entries.map((e) {
              final i = e.key;
              final opt = e.value;
              final selected = _selectedQuality == i;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _changeQuality(i);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? _lime.withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? _lime.withOpacity(0.5)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(children: [
                    Icon(
                      opt['hd'] as bool
                          ? Icons.hd_rounded
                          : Icons.auto_fix_high_rounded,
                      color: selected ? _lime : const Color(0xFF888888),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        color: selected ? _lime : Colors.white,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w400,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (selected)
                      const Icon(Icons.check_rounded, color: _lime, size: 18),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAndSuggested() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _buildVideoInfo(),
        _buildAutoplayToggle(),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: Text('Up Next',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ),
        ...widget.suggestedTracks.take(10).map((t) => _SuggestedTile(
              track: t,
              onTap: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      track: t,
                      suggestedTracks: widget.suggestedTracks
                          .where((x) => x.ytVideoId != t.ytVideoId)
                          .toList(),
                    ),
                  ),
                );
              },
            )),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildVideoInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.track.title,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.3)),
        const SizedBox(height: 6),
        Row(children: [
          Text(widget.track.channel,
              style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
          if (widget.track.viewCount > 0) ...[
            const Text(' • ', style: TextStyle(color: Color(0xFF555555))),
            Text(widget.track.viewCountLabel,
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          ],
        ]),
        const SizedBox(height: 12),
        // Like + Download buttons
        Consumer2<MediaProvider, DownloadProvider>(
          builder: (_, mp, dl, __) {
            final ds = dl.stateOf(widget.track.ytVideoId);
            return Row(children: [
              // Like button
              GestureDetector(
                onTap: () => mp.toggleLike(widget.track.ytVideoId),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: mp.isLiked(widget.track.ytVideoId)
                        ? Colors.red.withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: mp.isLiked(widget.track.ytVideoId)
                          ? Colors.redAccent
                          : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(
                      mp.isLiked(widget.track.ytVideoId)
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: mp.isLiked(widget.track.ytVideoId)
                          ? Colors.redAccent
                          : const Color(0xFF888888),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      mp.isLiked(widget.track.ytVideoId) ? 'Liked' : 'Like',
                      style: TextStyle(
                          color: mp.isLiked(widget.track.ytVideoId)
                              ? Colors.redAccent
                              : const Color(0xFF888888),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
              const SizedBox(width: 10),
              // ── Video Download button ──
              GestureDetector(
                onTap: ds.isVideoDownloading
                    ? () => dl.cancelVideo(widget.track.ytVideoId)
                    : ds.isVideoDownloaded
                        ? () => _showDeleteVideoDialog(context, dl)
                        : () {
                            dl.cacheTrack(widget.track);
                            dl.downloadVideo(widget.track);
                          },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: ds.isVideoDownloaded
                        ? Colors.green.withOpacity(0.15)
                        : const Color(0xFF1A1A1A),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ds.isVideoDownloaded
                          ? Colors.green
                          : const Color(0xFF2A2A2A),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    ds.isVideoDownloading
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              value: ds.videoProgress,
                              strokeWidth: 2,
                              color: _lime,
                            ),
                          )
                        : Icon(
                            ds.isVideoDownloaded
                                ? Icons.download_done_rounded
                                : Icons.download_rounded,
                            color: ds.isVideoDownloaded
                                ? Colors.green
                                : const Color(0xFF888888),
                            size: 18,
                          ),
                    const SizedBox(width: 6),
                    Text(
                      ds.isVideoDownloading
                          ? '${(ds.videoProgress * 100).toInt()}%'
                          : ds.isVideoDownloaded
                              ? 'Saved'
                              : 'Download',
                      style: TextStyle(
                          color: ds.isVideoDownloaded
                              ? Colors.green
                              : const Color(0xFF888888),
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
              ),
            ]);
          },
        ),
        const Divider(color: Color(0xFF1E1E1E), height: 24),
      ]),
    );
  }

  Widget _buildAutoplayToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Row(children: [
        const Icon(Icons.playlist_play_rounded,
            color: Color(0xFF888888), size: 20),
        const SizedBox(width: 8),
        const Text('Autoplay',
            style: TextStyle(color: Color(0xFF888888), fontSize: 14)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() => _autoplay = !_autoplay),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: _autoplay ? _lime : const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment:
                  _autoplay ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: _autoplay ? const Color(0xFF0F0F0F) : Colors.white54,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Suggested video tile (compact)
// ══════════════════════════════════════════════════════════════════

class _SuggestedTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;

  const _SuggestedTile({required this.track, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Thumbnail
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: track.thumbnail,
                  width: 120,
                  height: 68,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    width: 120,
                    height: 68,
                    color: const Color(0xFF1A1A1A),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    width: 120,
                    height: 68,
                    color: const Color(0xFF1A1A1A),
                    child: const Icon(Icons.play_circle_outline,
                        color: Color(0xFF333333), size: 28),
                  ),
                ),
              ),
              if (track.durationSeconds > 0)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(track.durationLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              const Positioned.fill(
                child: Center(
                  child: Icon(Icons.play_arrow_rounded,
                      color: Colors.white60, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          // Info
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(track.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.3)),
              const SizedBox(height: 4),
              Text(track.channel,
                  style:
                      const TextStyle(color: Color(0xFF666666), fontSize: 12)),
            ]),
          ),
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
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      track.category == 'music'
                          ? Icons.music_note_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
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
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
//  Inline Mini Audio Player
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
//  Full Audio Player Screen (music only)
// ══════════════════════════════════════════════════════════════════

class FullAudioPlayerScreen extends StatefulWidget {
  final Track track;
  const FullAudioPlayerScreen({Key? key, required this.track})
      : super(key: key);

  @override
  State<FullAudioPlayerScreen> createState() => _FullAudioPlayerScreenState();
}

class _FullAudioPlayerScreenState extends State<FullAudioPlayerScreen> {
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
                // ── Audio Download button ──
                Consumer<DownloadProvider>(
                  builder: (_, dl, __) {
                    final ds = dl.stateOf(widget.track.ytVideoId);
                    return IconButton(
                      icon: ds.isAudioDownloading
                          ? SizedBox(
                              width: 20,
                              height: 20,
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
                                  : const Color(0xFF555555),
                            ),
                      tooltip: ds.isAudioDownloading
                          ? 'Cancel download'
                          : ds.isAudioDownloaded
                              ? 'Downloaded — tap to remove'
                              : 'Download audio',
                      onPressed: ds.isAudioDownloading
                          ? () => dl.cancelAudio(widget.track.ytVideoId)
                          : ds.isAudioDownloaded
                              ? () => _showDeleteAudioDialog(context, dl)
                              : () {
                                  dl.cacheTrack(widget.track);
                                  dl.downloadAudio(widget.track);
                                },
                    );
                  },
                ),
              ]),
            ),
            // Album art
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
                              color: Color(0xFF555555), fontSize: 14)),
                    ],
                  ),
                ),
              ]),
            ),
            // Seek bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            const RoundSliderThumbShape(enabledThumbRadius: 6),
                        overlayShape:
                            const RoundSliderOverlayShape(overlayRadius: 14),
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
                  IconButton(
                    icon: Icon(Icons.shuffle_rounded,
                        color:
                            player.isShuffle ? _lime : const Color(0xFF444444),
                        size: 24),
                    onPressed: () => player.toggleShuffle(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => player.previousTrack(),
                  ),
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
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded,
                        color: Colors.white, size: 32),
                    onPressed: () => player.nextTrack(),
                  ),
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

  void _showDeleteAudioDialog(BuildContext context, DownloadProvider dl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        title: const Text('Remove Download',
            style: TextStyle(color: Colors.white)),
        content: const Text('Delete this downloaded audio file?',
            style: TextStyle(color: Color(0xFF888888))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF888888))),
          ),
          TextButton(
            onPressed: () {
              dl.deleteAudio(widget.track.ytVideoId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
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
