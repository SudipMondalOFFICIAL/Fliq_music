// ╔══════════════════════════════════════════════════════════════════╗
// ║  track_tile.dart — Music/Video Track List Tile Widget            ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/track_model.dart';
import '../providers/player_provider.dart';

class TrackTile extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onMoreOptions;
  final bool isActive;
  final Widget? trailingWidget;

  const TrackTile({
    Key? key,
    required this.track,
    required this.onTap,
    this.onMoreOptions,
    this.isActive = false,
    this.trailingWidget,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.blue.withOpacity(0.1) : null,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: track.thumbnail,
            width: 50,
            height: 50,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              width: 50,
              height: 50,
              color: Colors.grey[800],
              child:
                  const Icon(Icons.music_note, color: Colors.white38, size: 20),
            ),
            errorWidget: (_, __, ___) => Container(
              width: 50,
              height: 50,
              color: Colors.grey[800],
              child:
                  const Icon(Icons.music_note, color: Colors.white38, size: 20),
            ),
          ),
        ),
        title: Text(
          track.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.blue : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              track.channel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  track.durationLabel,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(width: 8),
                if (track.viewCount > 0)
                  Expanded(
                    child: Text(
                      track.viewCountLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ],
        ),
        trailing: trailingWidget ??
            IconButton(
              icon: Icon(
                track.isLiked ? Icons.favorite : Icons.favorite_border,
                color: track.isLiked ? Colors.red : Colors.grey,
                size: 20,
              ),
              onPressed: onMoreOptions,
            ),
        onTap: onTap,
      ),
    );
  }
}

class TrackCardView extends StatelessWidget {
  final Track track;
  final VoidCallback onTap;
  final VoidCallback? onLikeTap;
  final bool isLiked;

  const TrackCardView({
    Key? key,
    required this.track,
    required this.onTap,
    this.onLikeTap,
    this.isLiked = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: track.thumbnail,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note,
                      size: 64, color: Colors.white38),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[800],
                  child: const Icon(Icons.music_note,
                      size: 64, color: Colors.white38),
                ),
              ),
            ),
            // Gradient overlay
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),
            // Info at bottom
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    track.channel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Like button
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onLikeTap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withOpacity(0.5),
                  ),
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.red : Colors.white,
                    size: 20,
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
