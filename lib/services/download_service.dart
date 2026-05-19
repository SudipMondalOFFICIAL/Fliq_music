// ╔══════════════════════════════════════════════════════════════════╗
// ║  download_service.dart — Audio & Video offline download         ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/track_model.dart';
import 'api_service.dart';

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

typedef DownloadProgressCallback = void Function(double progress);

class DownloadService {
  final ApiService _api;
  final Dio _dio = Dio();
  final YoutubeExplode _yt = YoutubeExplode();
  final Map<String, CancelToken> _cancelTokens = {};

  DownloadService(this._api);

  // ── Android storage permission (handles API 29/30/33+) ────────
  Future<bool> _requestStoragePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final sdkInt = info.version.sdkInt;
      if (sdkInt >= 30) {
        // Android 11+: app-internal dirs don't need permission
        return true;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    } catch (_) {
      return true;
    }
  }

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

    if (!await _requestStoragePermission()) {
      return const DownloadResult(
          success: false, error: 'Storage permission denied');
    }

    final cancelToken = CancelToken();
    _cancelTokens[key] = cancelToken;

    try {
      final dir = await _downloadsDir();
      final savePath = _audioPath(dir, track.ytVideoId);

      if (File(savePath).existsSync()) {
        _cancelTokens.remove(key);
        final size = await File(savePath).length();
        await _logDownload(track, 'audio', savePath, size);
        return DownloadResult(
            success: true, filePath: savePath, fileSizeBytes: size);
      }

      onProgress?.call(0.02);
      final manifest =
          await _yt.videos.streamsClient.getManifest(track.ytVideoId);

      final audioStreams = manifest.audioOnly.sortByBitrate();
      if (audioStreams.isEmpty) {
        throw Exception('No audio streams available for this video');
      }
      final streamInfo = audioStreams.last;

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

  // ── Video download (.mp4 muxed, max 720p) ─────────────────────────
  Future<DownloadResult> downloadVideo(
    Track track, {
    DownloadProgressCallback? onProgress,
  }) async {
    final key = '${track.ytVideoId}_video';
    if (_cancelTokens.containsKey(key)) {
      return const DownloadResult(success: false, error: 'Already downloading');
    }

    if (!await _requestStoragePermission()) {
      return const DownloadResult(
          success: false, error: 'Storage permission denied');
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

      final muxed = manifest.muxed.sortByVideoQuality();
      if (muxed.isEmpty) {
        throw Exception('No muxed video streams available');
      }
      final streamInfo = muxed.last;

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
      print('[DownloadService] backend log failed: $e');
    }
  }

  void dispose() {
    _yt.close();
    _dio.close();
  }
}
