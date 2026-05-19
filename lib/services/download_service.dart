// ╔══════════════════════════════════════════════════════════════════╗
// ║  download_service.dart — Audio & Video offline download         ║
// ║  Place in: lib/services/download_service.dart                   ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Strategy:
//  Audio  → youtube_explode_dart extracts best .m4a stream → DIO downloads
//  Video  → youtube_explode_dart extracts best muxed mp4   → DIO downloads
//
// Files saved to:  <appDocDir>/filq_downloads/<videoId>_audio.m4a
//                  <appDocDir>/filq_downloads/<videoId>_video.mp4
//
// Backend is notified after successful download via /music/download/log.
// Backend is notified on delete via DELETE /music/download/log.

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/track_model.dart';
import 'api_service.dart';

// ── Download result ──────────────────────────────────────────────────
class DownloadResult {
  final bool success;
  final String? filePath;
  final String? error;
  final int fileSizeBytes;

  const DownloadResult({
    this.success = false,
    this.filePath,
    this.error,
    this.fileSizeBytes = 0,
  });
}

// ── Progress callback type ───────────────────────────────────────────
typedef DownloadProgressCallback = void Function(double progress);

// ══════════════════════════════════════════════════════════════════════
//  DownloadService
// ══════════════════════════════════════════════════════════════════════

class DownloadService {
  final ApiService _api;
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();

  // Active cancellation tokens — keyed by "videoId_type"
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadService(this._api);

  // ── Directory ─────────────────────────────────────────────────────
  Future<Directory> _downloadsDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/filq_downloads');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _audioPath(Directory dir, String videoId) =>
      '${dir.path}/${videoId}_audio.m4a';

  String _videoPath(Directory dir, String videoId) =>
      '${dir.path}/${videoId}_video.mp4';

  // ── Check if already downloaded ───────────────────────────────────
  Future<bool> isDownloaded(String ytVideoId, {String type = 'audio'}) async {
    final dir = await _downloadsDir();
    final path = type == 'audio'
        ? _audioPath(dir, ytVideoId)
        : _videoPath(dir, ytVideoId);
    return File(path).existsSync();
  }

  Future<String?> localPath(String ytVideoId, {String type = 'audio'}) async {
    final dir = await _downloadsDir();
    final path = type == 'audio'
        ? _audioPath(dir, ytVideoId)
        : _videoPath(dir, ytVideoId);
    return File(path).existsSync() ? path : null;
  }

  // ── Cancel ────────────────────────────────────────────────────────
  void cancelDownload(String ytVideoId, {String type = 'audio'}) {
    final key = '${ytVideoId}_$type';
    final token = _cancelTokens[key];
    if (token != null && !token.isCancelled) token.cancel('User cancelled');
    _cancelTokens.remove(key);
  }

  // ── Audio download (.m4a) ─────────────────────────────────────────
  Future<DownloadResult> downloadAudio(
    Track track, {
    DownloadProgressCallback? onProgress,
  }) async {
    final key = '${track.ytVideoId}_audio';
    if (_cancelTokens.containsKey(key)) {
      return const DownloadResult(success: false, error: 'Already downloading');
    }

    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;

    try {
      final dir = await _downloadsDir();
      final savePath = _audioPath(dir, track.ytVideoId);

      // Already exists — skip re-download
      if (File(savePath).existsSync()) {
        _cancelTokens.remove(key);
        final size = await File(savePath).length();
        await _logDownload(track, 'audio', savePath, size);
        return DownloadResult(
            success: true, filePath: savePath, fileSizeBytes: size);
      }

      // ── Extract audio stream URL via youtube_explode_dart ─────────
      onProgress?.call(0.02);
      final manifest =
          await _yt.videos.streamsClient.getManifest(track.ytVideoId);

      // Best audio: highest bitrate audio-only stream
      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for this video');
      }
      final streamInfo = audioStreams.last; // highest bitrate last

      onProgress?.call(0.05);

      // ── Download ──────────────────────────────────────────────────
      await _dio.download(
        streamInfo.url.toString(),
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final pct = 0.05 + (received / total) * 0.95;
            onProgress?.call(pct.clamp(0.0, 1.0));
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 30),
          responseType: ResponseType.stream,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      onProgress?.call(1.0);

      final size = await File(savePath).length();
      await _logDownload(track, 'audio', savePath, size);
      _cancelTokens.remove(key);
      return DownloadResult(
          success: true, filePath: savePath, fileSizeBytes: size);
    } on DioException catch (e) {
      _cancelTokens.remove(key);
      if (e.type == DioExceptionType.cancel) {
        return const DownloadResult(
            success: false, error: 'Download cancelled');
      }
      return DownloadResult(
          success: false, error: 'Download failed: ${e.message}');
    } catch (e) {
      _cancelTokens.remove(key);
      return DownloadResult(success: false, error: e.toString());
    }
  }

  // ── Video download (.mp4) ─────────────────────────────────────────
  Future<DownloadResult> downloadVideo(
    Track track, {
    DownloadProgressCallback? onProgress,
  }) async {
    final key = '${track.ytVideoId}_video';
    if (_cancelTokens.containsKey(key)) {
      return const DownloadResult(success: false, error: 'Already downloading');
    }

    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;

    try {
      final dir = await _downloadsDir();
      final savePath = _videoPath(dir, track.ytVideoId);

      if (File(savePath).existsSync()) {
        _cancelTokens.remove(key);
        final size = await File(savePath).length();
        await _logDownload(track, 'video', savePath, size);
        return DownloadResult(
            success: true, filePath: savePath, fileSizeBytes: size);
      }

      onProgress?.call(0.02);
      final manifest =
          await _yt.videos.streamsClient.getManifest(track.ytVideoId);

      // Prefer muxed (audio+video combined) — simplest offline playback
      // Fallback: highest quality muxed stream
      final muxed = manifest.muxed.sortByVideoQuality();
      if (muxed.isEmpty) {
        throw Exception('No muxed video streams available');
      }
      final streamInfo = muxed.last; // best quality

      onProgress?.call(0.05);

      await _dio.download(
        streamInfo.url.toString(),
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final pct = 0.05 + (received / total) * 0.95;
            onProgress?.call(pct.clamp(0.0, 1.0));
          }
        },
        options: Options(
          receiveTimeout: const Duration(minutes: 30),
          sendTimeout: const Duration(seconds: 30),
          responseType: ResponseType.stream,
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      onProgress?.call(1.0);

      final size = await File(savePath).length();
      await _logDownload(track, 'video', savePath, size);
      _cancelTokens.remove(key);
      return DownloadResult(
          success: true, filePath: savePath, fileSizeBytes: size);
    } on DioException catch (e) {
      _cancelTokens.remove(key);
      if (e.type == DioExceptionType.cancel) {
        return const DownloadResult(
            success: false, error: 'Download cancelled');
      }
      return DownloadResult(
          success: false, error: 'Download failed: ${e.message}');
    } catch (e) {
      _cancelTokens.remove(key);
      return DownloadResult(success: false, error: e.toString());
    }
  }

  // ── Delete ────────────────────────────────────────────────────────
  Future<bool> deleteDownload(String ytVideoId, {String type = 'audio'}) async {
    try {
      final dir = await _downloadsDir();
      final path = type == 'audio'
          ? _audioPath(dir, ytVideoId)
          : _videoPath(dir, ytVideoId);
      final file = File(path);
      if (await file.exists()) await file.delete();
      await _api.removeDownloadLog(ytVideoId, fileType: type);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ── Storage usage ─────────────────────────────────────────────────
  Future<Map<String, int>> storageUsage() async {
    final dir = await _downloadsDir();
    int audio = 0;
    int video = 0;
    if (!await dir.exists()) return {'audio': 0, 'video': 0, 'total': 0};

    await for (final entity in dir.list()) {
      if (entity is File) {
        final size = await entity.length();
        if (entity.path.endsWith('_audio.m4a')) {
          audio += size;
        } else if (entity.path.endsWith('_video.mp4')) {
          video += size;
        }
      }
    }
    return {'audio': audio, 'video': video, 'total': audio + video};
  }

  // ── List all local downloads ───────────────────────────────────────
  Future<List<Map<String, dynamic>>> listLocalDownloads() async {
    final dir = await _downloadsDir();
    final list = <Map<String, dynamic>>[];
    if (!await dir.exists()) return list;

    await for (final entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        String? videoId;
        String? type;
        if (name.endsWith('_audio.m4a')) {
          videoId = name.replaceAll('_audio.m4a', '');
          type = 'audio';
        } else if (name.endsWith('_video.mp4')) {
          videoId = name.replaceAll('_video.mp4', '');
          type = 'video';
        }
        if (videoId != null && type != null) {
          list.add({
            'yt_video_id': videoId,
            'file_type': type,
            'file_path': entity.path,
            'file_size': await entity.length(),
          });
        }
      }
    }
    return list;
  }

  // ── Private helpers ───────────────────────────────────────────────
  Future<void> _logDownload(
      Track track, String fileType, String filePath, int fileSize) async {
    try {
      await _api.logDownload(
        ytVideoId: track.ytVideoId,
        title: track.title,
        channel: track.channel,
        thumbnail: track.thumbnail,
        durationSeconds: track.durationSeconds,
        fileType: fileType,
        filePath: filePath,
        fileSizeBytes: fileSize,
      );
    } catch (e) {
      // Non-fatal — log and continue
      // ignore: avoid_print
      print('[DownloadService] backend log failed: $e');
    }
  }

  void dispose() {
    _yt.close();
    _dio.close();
  }
}
