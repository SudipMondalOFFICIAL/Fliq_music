// ╔══════════════════════════════════════════════════════════════════╗
// ║  mini_player.dart — Compact Player Widget (2 variants)           ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/track_model.dart';
import '../providers/player_provider.dart';

/// Inline mini player (compact bar at bottom)
class MiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback? onClose;

  const MiniPlayer({
    Key? key,
    required this.onTap,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        if (player.currentTrack == null) {
          return const SizedBox.shrink();
        }

        final track = player.currentTrack!;
        return GestureDetector(
          onTap: onTap,
          child: Container(
            color: Colors.blue.shade900,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      track.thumbnail,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 48,
                          height: 48,
                          color: Colors.grey[400],
                          child: const Icon(Icons.music_note),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          track.channel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      player.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () => player.togglePlayPause(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 20,
                    ),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Floating mini player (small centered player)
class FloatingMiniPlayer extends StatelessWidget {
  final VoidCallback onTap;
  final Offset initialPosition;
  final ValueChanged<Offset>? onPositionChanged;

  const FloatingMiniPlayer({
    Key? key,
    required this.onTap,
    this.initialPosition = const Offset(0.85, 0.85),
    this.onPositionChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<PlayerProvider>(
      builder: (context, player, _) {
        if (player.currentTrack == null) {
          return const SizedBox.shrink();
        }

        final track = player.currentTrack!;
        return Positioned(
          right: 16,
          bottom: 80,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      track.thumbnail,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey[400],
                          child: const Icon(Icons.music_note),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                  Center(
                    child: GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        child: Icon(
                          player.isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.blue.shade900,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  // Progress indicator at bottom
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: StreamBuilder<Duration>(
                      stream: player.positionStream,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? Duration.zero;
                        final duration = player.duration;
                        final progress = duration.inMilliseconds > 0
                            ? position.inMilliseconds / duration.inMilliseconds
                            : 0.0;
                        return Container(
                          height: 3,
                          width: 100 * progress.clamp(0.0, 1.0),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade400,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
