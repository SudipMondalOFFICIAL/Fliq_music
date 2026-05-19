// ╔══════════════════════════════════════════════════════════════════╗
// ║  downloads_screen.dart — Offline library screen                 ║
// ║  Place in: lib/screens/downloads_screen.dart                    ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track_model.dart';
import '../providers/download_provider.dart';
import '../providers/player_provider.dart';
import '../services/download_service.dart';

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

// ── Storage usage badge ──────────────────────────────────────────────
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

// ── Tab list ─────────────────────────────────────────────────────────
class _DownloadList extends StatelessWidget {
  final String type; // 'audio' | 'video'
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
            return _DownloadTile(
              ytVideoId: id,
              state: state,
              type: type,
            );
          },
        );
      },
    );
  }
}

// ── Single download tile ─────────────────────────────────────────────
class _DownloadTile extends StatelessWidget {
  final String ytVideoId;
  final TrackDownloadState state;
  final String type;

  const _DownloadTile({
    required this.ytVideoId,
    required this.state,
    required this.type,
  });

  String get _path =>
      type == 'audio' ? (state.audioPath ?? '') : (state.videoPath ?? '');
  int get _size => type == 'audio' ? state.audioSize : state.videoSize;

  String _sizeLabel() {
    if (_size <= 0) return '';
    if (_size < 1024 * 1024) return '${(_size / 1024).toStringAsFixed(0)} KB';
    return '${(_size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final dl = context.read<DownloadProvider>();

    return Dismissible(
      key: Key('$ytVideoId-$type'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red.shade800,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) {
        if (type == 'audio') {
          dl.deleteAudio(ytVideoId);
        } else {
          dl.deleteVideo(ytVideoId);
        }
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(
                  type == 'audio' ? Icons.audiotrack : Icons.videocam,
                  color: Colors.white38,
                  size: 32,
                ),
              ),
            ),
            // Green checkmark overlay
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
        title: Text(
          ytVideoId, // Replace with title from a track cache if available
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: Row(
          children: [
            Icon(
              type == 'audio' ? Icons.music_note : Icons.videocam,
              size: 12,
              color: const Color(0xFF00C853),
            ),
            const SizedBox(width: 4),
            Text(
              type.toUpperCase(),
              style: const TextStyle(color: Color(0xFF00C853), fontSize: 11),
            ),
            if (_sizeLabel().isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                _sizeLabel(),
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white54),
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  DownloadButton widget — drop this on any track tile
// ══════════════════════════════════════════════════════════════════════
//
// Usage in any widget:
//   DownloadButton(track: track)
//

class DownloadButton extends StatelessWidget {
  final Track track;
  final String type; // 'audio' | 'video'
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
            child: Icon(
              Icons.download_done_rounded,
              size: size,
              color: const Color(0xFF00C853),
            ),
          );
        }

        // Not downloaded
        return GestureDetector(
          onTap: () {
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
          child: Icon(
            Icons.download_rounded,
            size: size,
            color: Colors.white54,
          ),
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
