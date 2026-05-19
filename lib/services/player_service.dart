// ╔══════════════════════════════════════════════════════════════════╗
// ║  player_service.dart — YouTube extract + Audio + Background Play ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
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

// ═════════════════════════════════════════════════════════════════
//  PlayerService — singleton
// ═════════════════════════════════════════════════════════════════

class PlayerService {
  PlayerService._();
  static final PlayerService instance = PlayerService._();

  final AudioPlayer _player = AudioPlayer();
  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();

  // Cache stream URLs to avoid re-fetching on pause/resume
  final Map<String, String> _audioUrlCache = {};
  final Map<String, String> _videoUrlCache = {};

  AudioPlayer get player => _player;

  // ── Audio stream URL ──────────────────────────────────────────
  Future<String?> getAudioStreamUrl(String videoId) async {
    if (_audioUrlCache.containsKey(videoId)) {
      return _audioUrlCache[videoId];
    }
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.audioOnly;
      if (streams.isEmpty) return null;
      final url = streams.withHighestBitrate().url.toString();
      _audioUrlCache[videoId] = url;
      return url;
    } catch (e) {
      print('[PlayerService] audio stream fetch error: $e');
      return null;
    }
  }

  // ── Video stream URL (muxed = audio+video) ────────────────────
  Future<String?> getVideoStreamUrl(String videoId) async {
    if (_videoUrlCache.containsKey(videoId)) {
      return _videoUrlCache[videoId];
    }
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      final streams = manifest.muxed;
      if (streams.isEmpty) return null;
      final sorted = streams.toList()
        ..sort((a, b) => b.videoQuality.index.compareTo(a.videoQuality.index));
      // Prefer 720p or lower for smooth playback
      MuxedStreamInfo best = sorted.first;
      for (final s in sorted) {
        if (s.videoQualityLabel.contains('720') ||
            s.videoQualityLabel.contains('480') ||
            s.videoQualityLabel.contains('360')) {
          best = s;
          break;
        }
      }
      final url = best.url.toString();
      _videoUrlCache[videoId] = url;
      return url;
    } catch (e) {
      print('[PlayerService] video stream error: $e');
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
      print('[PlayerService] playTrack error: $e');
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
  Future<String?> downloadTrack(Track track,
      {void Function(double)? onProgress}) async {
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final ms = await Permission.manageExternalStorage.request();
          if (!ms.isGranted) return null;
        }
      }
      final dir = await getApplicationDocumentsDirectory();
      final filqDir = Directory('${dir.path}/filq_downloads');
      if (!filqDir.existsSync()) filqDir.createSync(recursive: true);
      final filePath = '${filqDir.path}/${track.ytVideoId}.m4a';
      if (File(filePath).existsSync()) return filePath;
      final url = await getAudioStreamUrl(track.ytVideoId);
      if (url == null) return null;
      await _dio.download(url, filePath, onReceiveProgress: (r, t) {
        if (t > 0 && onProgress != null) onProgress(r / t);
      });
      return filePath;
    } catch (e) {
      print('[PlayerService] download error: $e');
      return null;
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
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/filq_downloads/$ytVideoId.m4a').existsSync();
  }

  void clearCache() {
    _audioUrlCache.clear();
    _videoUrlCache.clear();
  }

  void dispose() {
    _player.dispose();
    _yt.close();
    _dio.close();
  }
}
