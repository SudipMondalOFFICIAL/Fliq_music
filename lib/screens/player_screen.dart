// ╔══════════════════════════════════════════════════════════════════╗
// ║  player_screen.dart — Full Music Player with Queue                ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track_model.dart';
import '../providers/player_provider.dart';
import '../providers/download_provider.dart';
// FIX: track_tile.dart is in widgets/, not screens/ — corrected import path
import '../widgets/track_tile.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({Key? key}) : super(key: key);

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showQueue = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Now Playing'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Consumer<PlayerProvider>(
        builder: (context, player, _) {
          if (player.currentTrack == null) {
            return const Center(
              child: Text('No track playing'),
            );
          }

          return Stack(
            children: [
              // Main player view
              SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    // Album art
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: CachedNetworkImage(
                          imageUrl: player.currentTrack!.thumbnail,
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note,
                                size: 100, color: Colors.white38),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: double.infinity,
                            height: 300,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note,
                                size: 100, color: Colors.white38),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Track info
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      player.currentTrack!.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      player.currentTrack!.channel,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  player.currentTrack!.isLiked
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: player.currentTrack!.isLiked
                                      ? Colors.red
                                      : Colors.grey,
                                  size: 28,
                                ),
                                onPressed: () {
                                  // Toggle like
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Progress bar
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          StreamBuilder<Duration>(
                            stream: player.positionStream,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = player.duration;
                              final progress = duration.inMilliseconds > 0
                                  ? position.inMilliseconds /
                                      duration.inMilliseconds
                                  : 0.0;

                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderThemeData(
                                      trackHeight: 3,
                                      thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6,
                                      ),
                                      overlayShape:
                                          const RoundSliderOverlayShape(
                                        overlayRadius: 12,
                                      ),
                                    ),
                                    child: Slider(
                                      min: 0.0,
                                      max: duration.inMilliseconds.toDouble(),
                                      value: position.inMilliseconds
                                          .toDouble()
                                          .clamp(
                                            0.0,
                                            duration.inMilliseconds.toDouble(),
                                          ),
                                      onChanged: (value) {
                                        player.seek(
                                          Duration(
                                            milliseconds: value.toInt(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 0,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDuration(position),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                        Text(
                                          _formatDuration(duration),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Control buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Loop button
                          IconButton(
                            icon: Icon(
                              player.loopMode == 'one'
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                              color: player.loopMode == 'none'
                                  ? Colors.grey
                                  : Colors.blue,
                              size: 28,
                            ),
                            onPressed: () => player.toggleLoopMode(),
                          ),
                          // Previous button
                          IconButton(
                            icon: const Icon(
                              Icons.skip_previous,
                              size: 36,
                            ),
                            onPressed: () => player.previousTrack(),
                          ),
                          // Play/Pause button
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                            ),
                            child: IconButton(
                              icon: Icon(
                                player.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: 36,
                              ),
                              iconSize: 56,
                              onPressed: () => player.togglePlayPause(),
                            ),
                          ),
                          // Next button
                          IconButton(
                            icon: const Icon(
                              Icons.skip_next,
                              size: 36,
                            ),
                            onPressed: () => player.nextTrack(),
                          ),
                          // Shuffle button
                          IconButton(
                            icon: Icon(
                              Icons.shuffle,
                              color:
                                  player.isShuffle ? Colors.blue : Colors.grey,
                              size: 28,
                            ),
                            onPressed: () => player.toggleShuffle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Queue button + Download button row
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.queue_music),
                              label: Text(
                                'Queue (${player.queue.length})',
                              ),
                              onPressed: () {
                                setState(() => _showQueue = !_showQueue);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          // ── Download button ──
                          Consumer<DownloadProvider>(
                            builder: (context, dl, _) {
                              final track = player.currentTrack!;
                              final audioState = dl.stateOf(track.ytVideoId);
                              final isDownloaded = audioState.isAudioDownloaded;
                              final isDownloading =
                                  audioState.isAudioDownloading;

                              return ElevatedButton.icon(
                                icon: isDownloading
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          value: audioState.audioProgress,
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        isDownloaded
                                            ? Icons.download_done_rounded
                                            : Icons.download_rounded,
                                      ),
                                label: Text(
                                  isDownloading
                                      ? '${(audioState.audioProgress * 100).toInt()}%'
                                      : isDownloaded
                                          ? 'Saved'
                                          : 'Download',
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDownloaded
                                      ? Colors.green.shade700
                                      : null,
                                ),
                                onPressed: isDownloading
                                    ? () => dl.cancelAudio(track.ytVideoId)
                                    : isDownloaded
                                        ? () => _showDeleteDialog(
                                            context, dl, track)
                                        : () {
                                            dl.cacheTrack(track);
                                            dl.downloadAudio(track);
                                          },
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
              // Queue sheet
              if (_showQueue)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _QueueSheet(
                    onClose: () => setState(() => _showQueue = false),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, DownloadProvider dl, Track track) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Download'),
        content: const Text('Delete this downloaded audio file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              dl.deleteAudio(track.ytVideoId);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

class _QueueSheet extends StatelessWidget {
  final VoidCallback onClose;

  const _QueueSheet({Key? key, required this.onClose}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Column(
            children: [
              // Handle bar
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Queue',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: onClose,
                    ),
                  ],
                ),
              ),
              // Queue list
              Expanded(
                child: player.queue.isEmpty
                    ? const Center(
                        child: Text('Queue is empty'),
                      )
                    : ListView.builder(
                        itemCount: player.queue.length,
                        itemBuilder: (context, index) {
                          final track = player.queue[index];
                          final isCurrentTrack = index == player.currentIndex;

                          return TrackTile(
                            track: track,
                            isActive: isCurrentTrack,
                            onTap: () {
                              player.playTrackAtIndex(index);
                            },
                            onMoreOptions: () {
                              _showTrackOptions(
                                context,
                                player,
                                track,
                                index,
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTrackOptions(
    BuildContext context,
    PlayerProvider player,
    Track track,
    int index,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove from queue'),
              onTap: () {
                player.removeFromQueue(index);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(
                track.isLiked ? Icons.favorite : Icons.favorite_border,
              ),
              title: Text(track.isLiked ? 'Remove from likes' : 'Add to likes'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share track'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
