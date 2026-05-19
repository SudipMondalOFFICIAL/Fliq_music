// ╔══════════════════════════════════════════════════════════════════╗
// ║  player_service.dart — YouTube extract + Audio + Background Play ║
// ║  FIX: Android 13+ permission, stream leak, error handling        ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/track_model.dart';

// ── Init (call once in main.dart before runApp) ───────────────────
Future<void> initAudioBackground() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.filq.audio',
    androidNotificationChannelName: 'Filq Music',
    androidNotificationOngoing: true,
    androidStopForegroundOnPause: true,
  );
}

// ── URL cache with TTL ────────────────────────────────────────────
class _CachedUrl {
  final String url;
  final DateTime fetchedAt;
  static const _ttl = Duration(hours: 5); // YouTube URLs expire ~6h

  _CachedUrl(this.url) : fetchedAt = DateTime.now();
  bool get isExpired => DateTime.now().difference(fetchedAt) > _ttl;
}

// ═════════════════════════════════════════════════════════════════
//  PlayerService — singleton
// ═════════════════════════════════════════════════════════════════

class PlayerService {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  // Cache stream URLs with expiry (YouTube URLs expire ~6h)
  final Map<String, _CachedUrl> _audioUrlCache = {};
  final Map<String, _CachedUrl> _videoUrlCache = {};

  AudioPlayer get player => _player;

  // ── Audio stream URL ──────────────────────────────────────────
  Future<String?> getAudioStreamUrl(String videoId) async {
    final cached = _audioUrlCache[videoId];
    if (cached != null && !cached.isExpired) return cached.url;
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 20));
      final streams = manifest.audioOnly;
      if (streams.isEmpty) return null;
      final url = streams.withHighestBitrate().url.toString();
      _audioUrlCache[videoId] = _CachedUrl(url);
      return url;
    } catch (e) {
      debugPrint('[PlayerService] audio stream fetch error: $e');
      return null;
    }
  }

  // ── Video stream URL (muxed = audio+video) ────────────────────
  Future<String?> getVideoStreamUrl(String videoId) async {
    final cached = _videoUrlCache[videoId];
    if (cached != null && !cached.isExpired) return cached.url;
    try {
      final manifest = await _yt.videos.streamsClient
          .getManifest(videoId)
          .timeout(const Duration(seconds: 20));
      final streams = manifest.muxed;
      if (streams.isEmpty) return null;
      final sorted = streams.toList()
        ..sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));
      MuxedStreamInfo best = sorted.first;
      for (final s in sorted) {
        if (s.videoQualityLabel.contains('1080') ||
            s.videoQualityLabel.contains('720') ||
            s.videoQualityLabel.contains('480') ||
            s.videoQualityLabel.contains('360')) {
          best = s;
          break;
        }
      }
      final url = best.url.toString();
      _videoUrlCache[videoId] = _CachedUrl(url);
      return url;
    } catch (e) {
      debugPrint('[PlayerService] video stream error: $e');
      return null;
    }
  }

  // ── Play a track (audio — used for background play) ───────────
  Future<bool> playTrack(Track track, {bool isVideo = false}) async {
    try {
      if (track.localPath != null && File(track.localPath!).existsSync()) {
        await _player.setAudioSource(
          AudioSource.file(track.localPath!, tag: _mediaItem(track)),
        );
        await _player.play();
        return true;
      }
      final url = await getAudioStreamUrl(track.ytVideoId);
      if (url == null) return false;
      await _player.setAudioSource(
        AudioSource.uri(Uri.parse(url), tag: _mediaItem(track)),
      );
      await _player.play();
      return true;
    } catch (e) {
      debugPrint('[PlayerService] playTrack error: $e');
      return false;
    }
  }

  MediaItem _mediaItem(Track t) => MediaItem(
        id: t.ytVideoId,
        title: t.title,
        artist: t.channel,
        artUri: Uri.parse(t.thumbnail),
        duration:
            t.durationSeconds > 0 ? Duration(seconds: t.durationSeconds) : null,
      );

  // ── Playback controls ─────────────────────────────────────────
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration pos) => _player.seek(pos);

  Future<void> seekRelative(Duration offset) async {
    final current = _player.position;
    final total = _player.duration ?? Duration.zero;
    final raw = current + offset;
    final target = raw < Duration.zero
        ? Duration.zero
        : raw > total
            ? total
            : raw;
    await _player.seek(target);
  }

  void setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));
  void setSpeed(double s) => _player.setSpeed(s.clamp(0.25, 2.0));

  // ── Streams ───────────────────────────────────────────────────
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  double get volume => _player.volume;

  // ── Download ──────────────────────────────────────────────────
  //
  // FIX: Android 13+ (SDK 33+) এ Permission.storage কাজ করে না।
  // getApplicationDocumentsDirectory() app-private directory দেয়,
  // সেখানে কোনো permission ছাড়াই write করা যায় — সব Android version এ।
  // তাই storage permission চেক সম্পূর্ণ সরিয়ে দেওয়া হয়েছে।
  //
  Future<String?> downloadTrack(
    Track track, {
    void Function(double)? onProgress,
    CancelToken? cancelToken,
  }) async {
    try {
      // app-private directory — no permission needed on any Android version
      final dir = await getApplicationDocumentsDirectory();
      final filqDir = Directory('${dir.path}/filq_downloads');
      if (!filqDir.existsSync()) filqDir.createSync(recursive: true);

      final filePath = '${filqDir.path}/${track.ytVideoId}.m4a';

      // Already downloaded — return immediately
      if (File(filePath).existsSync()) return filePath;

      final url = await getAudioStreamUrl(track.ytVideoId);
      if (url == null) return null;

      await _dio.download(
        url,
        filePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      return filePath;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        debugPrint('[PlayerService] download cancelled: ${track.ytVideoId}');
      } else {
        debugPrint('[PlayerService] download error: $e');
      }
      return null;
    } catch (e) {
      debugPrint('[PlayerService] download error: $e');
      return null;
    }
  }

  // ── External storage download (optional — user's Music folder) ─
  // শুধু user explicitly "save to Music" চাইলে call করো।
  // Android 13+ এ READ_MEDIA_AUDIO permission লাগে।
  Future<bool> requestExternalStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      if (info.version.sdkInt >= 33) {
        // Android 13+ — audio-specific permission
        final status = await Permission.audio.request();
        return status.isGranted;
      } else {
        // Android 12 এবং নিচে — legacy storage permission
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> deleteDownload(String ytVideoId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/filq_downloads/$ytVideoId.m4a');
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  Future<bool> isDownloaded(String ytVideoId) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return File('${dir.path}/filq_downloads/$ytVideoId.m4a').existsSync();
    } catch (_) {
      return false;
    }
  }

  // ── Cache management ──────────────────────────────────────────
  void clearCache() {
    _audioUrlCache.clear();
    _videoUrlCache.clear();
  }

  // Expired cache entries পরিষ্কার করো (call periodically if needed)
  void pruneExpiredCache() {
    _audioUrlCache.removeWhere((_, v) => v.isExpired);
    _videoUrlCache.removeWhere((_, v) => v.isExpired);
  }

  void dispose() {
    _player.dispose();
    _yt.close();
    _dio.close();
  }
}
