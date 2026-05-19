// ╔══════════════════════════════════════════════════════════════════╗
// ║  downloads_screen.dart — Offline library                        ║
// ║  FIX: Play downloaded audio/video offline (net off support)     ║
// ║  FIX: Shows track title/channel (not raw videoId)               ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../models/track_model.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E1A),
        appBar: AppBar(
          title: const Text('Downloads'),
          backgroundColor: const Color(0xFF111827),
          actions: [_StorageBadge()],
          bottom: const TabBar(
            indicatorColor: Color(0xFF00C853),
            labelColor: Color(0xFF00C853),
            unselectedLabelColor: Colors.white54,
            tabs: [
              Tab(icon: Icon(Icons.audiotrack), text: 'Audio'),
              Tab(icon: Icon(Icons.videocam), text: 'Video'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DownloadList(type: 'audio'),
            _DownloadList(type: 'video'),
          ],
        ),
      ),
    );
  }
}

class _StorageBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (_, dl, __) => Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(dl.totalStorageLabel,
                style: const TextStyle(
                    color: Color(0xFF00C853),
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const Text('stored',
                style: TextStyle(color: Colors.white38, fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class _DownloadList extends StatelessWidget {
  final String type;
  const _DownloadList({required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, dl, _) {
        final ids =
            type == 'audio' ? dl.downloadedAudioIds : dl.downloadedVideoIds;

        if (ids.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  type == 'audio' ? Icons.audiotrack : Icons.videocam,
                  size: 64,
                  color: Colors.white24,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${type == 'audio' ? 'audio' : 'video'} downloads yet',
                  style: const TextStyle(color: Colors.white38, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap the download icon on any track',
                  style: TextStyle(color: Colors.white24, fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: ids.length,
          itemBuilder: (ctx, i) {
            final id = ids[i];
            final state = dl.stateOf(id);
            final track = dl.cachedTrackOf(id);
            return _DownloadTile(
              ytVideoId: id,
              state: state,
              type: type,
              track: track,
            );
          },
        );
      },
    );
  }
}

class _DownloadTile extends StatelessWidget {
  final String ytVideoId;
  final TrackDownloadState state;
  final String type;
  final Track? track;

  const _DownloadTile({
    required this.ytVideoId,
    required this.state,
    required this.type,
    this.track,
  });

  String get _path =>
      type == 'audio' ? (state.audioPath ?? '') : (state.videoPath ?? '');
  int get _size => type == 'audio' ? state.audioSize : state.videoSize;

  String _sizeLabel() {
    if (_size <= 0) return '';
    if (_size < 1024 * 1024) return '${(_size / 1024).toStringAsFixed(0)} KB';
    return '${(_size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // FIX: Play offline — no internet needed
  void _playOffline(BuildContext context) {
    if (_path.isEmpty || !File(_path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File not found — try re-downloading'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (type == 'audio') {
      final player = context.read<PlayerProvider>();
      final offlineTrack = (track ??
              Track(
                ytVideoId: ytVideoId,
                title: ytVideoId,
                channel: 'Downloaded',
                thumbnail: '',
              ))
          .copyWith(localPath: _path, isDownloaded: true);
      player.playTrack(offlineTrack);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing: ${offlineTrack.title}'),
          backgroundColor: const Color(0xFF1E2433),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _OfflineVideoPlayer(
            filePath: _path,
            title: track?.title ?? ytVideoId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadProvider>();
    final displayTitle = track?.title ?? ytVideoId;
    final displayChannel = track?.channel ?? 'Downloaded';
    final thumbnail = track?.thumbnail ?? '';

    return Dismissible(
      key: Key('$ytVideoId-$type'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade800,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(height: 4),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      onDismissed: (_) {
        if (type == 'audio') {
          dl.deleteAudio(ytVideoId);
        } else {
          dl.deleteVideo(ytVideoId);
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: GestureDetector(
          onTap: () => _playOffline(context),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnail.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: thumbnail,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _iconBox(type),
                        errorWidget: (_, __, ___) => _iconBox(type),
                      )
                    : _iconBox(type),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 26),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Color(0xFF00C853),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 10),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          displayTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Flexible(
              child: Text(
                displayChannel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
            if (_sizeLabel().isNotEmpty) ...[
              const Text('  •  ',
                  style: TextStyle(color: Colors.white24, fontSize: 11)),
              Text(
                _sizeLabel(),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.play_circle_filled_rounded,
                  color: Color(0xFF00C853), size: 32),
              onPressed: () => _playOffline(context),
              tooltip: 'Play offline',
            ),
            PopupMenuButton<String>(
              icon:
                  const Icon(Icons.more_vert, color: Colors.white38, size: 20),
              color: const Color(0xFF1E2433),
              onSelected: (action) async {
                if (action == 'delete') {
                  if (type == 'audio') {
                    await dl.deleteAudio(ytVideoId);
                  } else {
                    await dl.deleteVideo(ytVideoId);
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Deleted from downloads'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _playOffline(context),
      ),
    );
  }

  Widget _iconBox(String type) => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1E2433),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          type == 'audio' ? Icons.audiotrack : Icons.videocam,
          color: Colors.white38,
          size: 28,
        ),
      );
}

// ══════════════════════════════════════════════════════════════════════
//  Offline Video Player
// ══════════════════════════════════════════════════════════════════════
class _OfflineVideoPlayer extends StatefulWidget {
  final String filePath;
  final String title;
  const _OfflineVideoPlayer({required this.filePath, required this.title});

  @override
  State<_OfflineVideoPlayer> createState() => _OfflineVideoPlayerState();
}

class _OfflineVideoPlayerState extends State<_OfflineVideoPlayer> {
  late VideoPlayerController _ctrl;
  bool _initialized = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.filePath))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl.play();
        }
      }).catchError((_) {
        if (mounted) setState(() => _initialized = false);
      });
    _ctrl.addListener(_onVideo);
  }

  void _onVideo() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onVideo);
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF00C853).withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF00C853), width: 1),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_pin, color: Color(0xFF00C853), size: 12),
                SizedBox(width: 4),
                Text('Offline',
                    style: TextStyle(
                        color: Color(0xFF00C853),
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
      body: !_initialized
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF00C853)),
                  SizedBox(height: 16),
                  Text('Loading video…',
                      style: TextStyle(color: Colors.white54)),
                ],
              ),
            )
          : GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: _ctrl.value.aspectRatio,
                      child: VideoPlayer(_ctrl),
                    ),
                  ),
                  if (_showControls)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black54,
                              Colors.transparent,
                              Colors.transparent,
                              Colors.black87,
                            ],
                            stops: [0, 0.3, 0.6, 1],
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  VideoProgressIndicator(
                                    _ctrl,
                                    allowScrubbing: true,
                                    colors: const VideoProgressColors(
                                      playedColor: Color(0xFF00C853),
                                      bufferedColor: Colors.white30,
                                      backgroundColor: Colors.white12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(_fmt(_ctrl.value.position),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11)),
                                      Text(_fmt(_ctrl.value.duration),
                                          style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.replay_10_rounded,
                                      color: Colors.white, size: 32),
                                  onPressed: () {
                                    final p = _ctrl.value.position;
                                    final t = p - const Duration(seconds: 10);
                                    _ctrl.seekTo(
                                        t < Duration.zero ? Duration.zero : t);
                                  },
                                ),
                                const SizedBox(width: 16),
                                GestureDetector(
                                  onTap: () {
                                    _ctrl.value.isPlaying
                                        ? _ctrl.pause()
                                        : _ctrl.play();
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF00C853),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _ctrl.value.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: Colors.black,
                                      size: 34,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                IconButton(
                                  icon: const Icon(Icons.forward_10_rounded,
                                      color: Colors.white, size: 32),
                                  onPressed: () {
                                    final p = _ctrl.value.position;
                                    final d = _ctrl.value.duration;
                                    final t = p + const Duration(seconds: 10);
                                    _ctrl.seekTo(t > d ? d : t);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  DownloadButton widget — reusable
// ══════════════════════════════════════════════════════════════════════
class DownloadButton extends StatelessWidget {
  final Track track;
  final String type;
  final double size;

  const DownloadButton({
    super.key,
    required this.track,
    this.type = 'audio',
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, dl, _) {
        final state = dl.stateOf(track.ytVideoId);
        final downloading = type == 'audio'
            ? state.isAudioDownloading
            : state.isVideoDownloading;
        final done =
            type == 'audio' ? state.isAudioDownloaded : state.isVideoDownloaded;
        final progress =
            type == 'audio' ? state.audioProgress : state.videoProgress;

        if (downloading) {
          return GestureDetector(
            onTap: () {
              if (type == 'audio') {
                dl.cancelAudio(track.ytVideoId);
              } else {
                dl.cancelVideo(track.ytVideoId);
              }
            },
            child: SizedBox(
              width: size,
              height: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress > 0 ? progress : null,
                    strokeWidth: 2,
                    color: const Color(0xFF00C853),
                  ),
                  Icon(Icons.close, size: size * 0.4, color: Colors.white54),
                ],
              ),
            ),
          );
        }

        if (done) {
          return GestureDetector(
            onTap: () => _showDeleteConfirm(context, dl),
            child: Icon(Icons.download_done_rounded,
                size: size, color: const Color(0xFF00C853)),
          );
        }

        return GestureDetector(
          onTap: () {
            dl.cacheTrack(track); // FIX: save track metadata
            if (type == 'audio') {
              dl.downloadAudio(track);
            } else {
              dl.downloadVideo(track);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content:
                    Text('Downloading ${type == 'audio' ? 'audio' : 'video'}…'),
                backgroundColor: const Color(0xFF1E2433),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
          child:
              Icon(Icons.download_rounded, size: size, color: Colors.white54),
        );
      },
    );
  }

  void _showDeleteConfirm(BuildContext context, DownloadProvider dl) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E2433),
        title: const Text('Remove download',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete offline ${type == 'audio' ? 'audio' : 'video'} for "${track.title}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (type == 'audio') {
                dl.deleteAudio(track.ytVideoId);
              } else {
                dl.deleteVideo(track.ytVideoId);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
