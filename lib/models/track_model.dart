// ╔══════════════════════════════════════════════════════════════════╗
// ║  track_model.dart — Filq Music/Video Track Model               ║
// ╚══════════════════════════════════════════════════════════════════╝

class Track {
  final String ytVideoId;
  final String title;
  final String channel;
  final String thumbnail;
  final int durationSeconds;
  final int viewCount;
  final List<String> tags;
  final String category; // 'music' | 'video' | 'gaming' etc.
  final String publishedAt;
  final String description;

  // Local state (not from API)
  final bool isDownloaded;
  final String? localPath;
  final bool isLiked;

  const Track({
    required this.ytVideoId,
    required this.title,
    required this.channel,
    required this.thumbnail,
    this.durationSeconds = 0,
    this.viewCount = 0,
    this.tags = const [],
    this.category = 'music',
    this.publishedAt = '',
    this.description = '',
    this.isDownloaded = false,
    this.localPath,
    this.isLiked = false,
  });

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        ytVideoId: json['yt_video_id'] ?? '',
        title: json['title'] ?? '',
        channel: json['channel'] ?? '',
        thumbnail: json['thumbnail'] ?? '',
        durationSeconds: json['duration_seconds'] ?? 0,
        viewCount: json['view_count'] ?? 0,
        tags: List<String>.from(json['tags'] ?? []),
        category: json['category'] ?? 'music',
        publishedAt: json['published_at'] ?? '',
        description: json['description'] ?? '',
        isLiked: json['liked'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'yt_video_id': ytVideoId,
        'title': title,
        'channel': channel,
        'thumbnail': thumbnail,
        'duration_seconds': durationSeconds,
        'view_count': viewCount,
        'tags': tags,
        'category': category,
        'published_at': publishedAt,
        'description': description,
      };

  Track copyWith({
    bool? isDownloaded,
    String? localPath,
    bool? isLiked,
    int? durationSeconds,
  }) =>
      Track(
        ytVideoId: ytVideoId,
        title: title,
        channel: channel,
        thumbnail: thumbnail,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        viewCount: viewCount,
        tags: tags,
        category: category,
        publishedAt: publishedAt,
        description: description,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        localPath: localPath ?? this.localPath,
        isLiked: isLiked ?? this.isLiked,
      );

  String get durationLabel {
    if (durationSeconds <= 0) return '';
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String get viewCountLabel {
    if (viewCount >= 1000000) {
      return '${(viewCount / 1000000).toStringAsFixed(1)}M views';
    } else if (viewCount >= 1000) {
      return '${(viewCount / 1000).toStringAsFixed(0)}K views';
    }
    return '$viewCount views';
  }

  bool get isMusic => category == 'music';

  @override
  bool operator ==(Object other) =>
      other is Track && other.ytVideoId == ytVideoId;

  @override
  int get hashCode => ytVideoId.hashCode;
}

// Download state for a track
enum DownloadStatus { none, downloading, done, failed }

class DownloadState {
  final String ytVideoId;
  final DownloadStatus status;
  final double progress; // 0.0 - 1.0
  final String? localPath;
  final String? error;

  const DownloadState({
    required this.ytVideoId,
    this.status = DownloadStatus.none,
    this.progress = 0.0,
    this.localPath,
    this.error,
  });

  bool get isDownloading => status == DownloadStatus.downloading;
  bool get isDone => status == DownloadStatus.done;
}

// Watch earn result from backend
class WatchResult {
  final bool ok;
  final bool completed;
  final int coinsEarned;
  final int dailyEarned;
  final int dailyLimit;

  const WatchResult({
    this.ok = false,
    this.completed = false,
    this.coinsEarned = 0,
    this.dailyEarned = 0,
    this.dailyLimit = 50,
  });

  factory WatchResult.fromJson(Map<String, dynamic> json) => WatchResult(
        ok: json['ok'] ?? false,
        completed: json['completed'] ?? false,
        coinsEarned: json['coins_earned'] ?? 0,
        dailyEarned: json['daily_earned'] ?? 0,
        dailyLimit: json['daily_limit'] ?? 50,
      );

  int get remaining => (dailyLimit - dailyEarned).clamp(0, dailyLimit);
  bool get limitReached => dailyEarned >= dailyLimit;
  double get progressPercent =>
      dailyLimit > 0 ? (dailyEarned / dailyLimit).clamp(0.0, 1.0) : 0.0;
}