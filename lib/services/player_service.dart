// ╔══════════════════════════════════════════════════════════════════╗
// ║  player_service.dart — YouTube extract + Audio + Download       ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'track_model.dart';

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

  AudioPlayer get player => _player;

  // ── Stream URL fetch ─────────────────────────────────────────
  Future<String?> getAudioStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // Prefer audio-only stream, highest bitrate
      final streams = manifest.audioOnly.sortByBitrate();
      if (streams.isEmpty) return null;
      return streams.last.url.toString();
    } catch (e) {
      print('[PlayerService] stream fetch error: $e');
      return null;
    }
  }

  Future<String?> getVideoStreamUrl(String videoId) async {
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(videoId);
      // muxed = video + audio combined
      final streams = manifest.muxed.sortByVideoQuality();
      if (streams.isEmpty) return null;
      return streams.last.url.toString();
    } catch (e) {
      print('[PlayerService] video stream error: $e');
      return null;
    }
  }

  // ── Play a track ─────────────────────────────────────────────
  Future<bool> playTrack(Track track, {bool isVideo = false}) async {
    try {
      String? url;
      if (track.localPath != null && File(track.localPath!).existsSync()) {
        // Play from local file
        await _player.setAudioSource(
          AudioSource.file(
            track.localPath!,
            tag: _mediaItem(track),
          ),
        );
        await _player.play();
        return true;
      }

      // Fetch stream URL
      url = isVideo
          ? await getVideoStreamUrl(track.ytVideoId)
          : await getAudioStreamUrl(track.ytVideoId);

      if (url == null) return false;

      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          tag: _mediaItem(track),
        ),
      );
      await _player.play();
      return true;
    } catch (e) {
      print('[PlayerService] playTrack error: $e');
      return false;
    }
  }

  // ── Play queue (ConcatenatingAudioSource) ────────────────────
  Future<bool> playQueue(
    List<Track> tracks,
    int initialIndex, {
    bool isVideo = false,
  }) async {
    try {
      // Fetch URLs for all tracks (can be slow for large queues)
      // For now: lazy — only fetch current, preload next
      final track = tracks[initialIndex];
      return await playTrack(track, isVideo: isVideo);
    } catch (e) {
      print('[PlayerService] playQueue error: $e');
      return false;
    }
  }

  MediaItem _mediaItem(Track t) => MediaItem(
        id: t.ytVideoId,
        title: t.title,
        artist: t.channel,
        artUri: Uri.parse(t.thumbnail),
        duration: t.durationSeconds > 0
            ? Duration(seconds: t.durationSeconds)
            : null,
      );

  // ── Playback controls ────────────────────────────────────────
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration pos) => _player.seek(pos);

  Future<void> seekRelative(Duration offset) async {
    final current = _player.position;
    final duration = _player.duration ?? Duration.zero;
    final target = (current + offset).clamp(Duration.zero, duration);
    await _player.seek(target);
  }

  void setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));
  void setSpeed(double s) => _player.setSpeed(s.clamp(0.25, 2.0));

  // ── Streams ──────────────────────────────────────────────────
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<double> get volumeStream => _player.volumeStream;

  bool get isPlaying => _player.playing;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  double get volume => _player.volume;

  // ── Download ─────────────────────────────────────────────────
  Future<String?> downloadTrack(
    Track track, {
    void Function(double)? onProgress,
  }) async {
    try {
      // Permission check
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final manageStatus =
              await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) return null;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final filqDir = Directory('${dir.path}/filq_downloads');
      if (!filqDir.existsSync()) filqDir.createSync(recursive: true);

      final filePath = '${filqDir.path}/${track.ytVideoId}.m4a';

      // Already downloaded?
      if (File(filePath).existsSync()) return filePath;

      // Fetch audio stream URL
      final url = await getAudioStreamUrl(track.ytVideoId);
      if (url == null) return null;

      await _dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

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
    } catch (e) {
      print('[PlayerService] delete error: $e');
    }
  }

  Future<List<String>> getDownloadedIds() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filqDir = Directory('${dir.path}/filq_downloads');
      if (!filqDir.existsSync()) return [];
      return filqDir
          .listSync()
          .whereType<File>()
          .map((f) => f.path.split('/').last.replaceAll('.m4a', ''))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> isDownloaded(String ytVideoId) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/filq_downloads/$ytVideoId.m4a').existsSync();
  }

  void dispose() {
    _player.dispose();
    _yt.close();
    _dio.close();
  }
}