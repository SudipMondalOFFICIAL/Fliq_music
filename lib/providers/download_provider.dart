// ╔══════════════════════════════════════════════════════════════════╗
// ║  download_provider.dart — Download state management             ║
// ║  Place in: lib/providers/download_provider.dart                 ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import '../models/track_model.dart';
import '../services/download_service.dart';

// ── Extended state per track ─────────────────────────────────────────
class TrackDownloadState {
  final String ytVideoId;
  final DownloadStatus audioStatus;
  final DownloadStatus videoStatus;
  final double audioProgress; // 0.0 – 1.0
  final double videoProgress;
  final String? audioPath;
  final String? videoPath;
  final String? audioError;
  final String? videoError;
  final int audioSize; // bytes
  final int videoSize;

  const TrackDownloadState({
    required this.ytVideoId,
    this.audioStatus = DownloadStatus.none,
    this.videoStatus = DownloadStatus.none,
    this.audioProgress = 0.0,
    this.videoProgress = 0.0,
    this.audioPath,
    this.videoPath,
    this.audioError,
    this.videoError,
    this.audioSize = 0,
    this.videoSize = 0,
  });

  TrackDownloadState copyWith({
    DownloadStatus? audioStatus,
    DownloadStatus? videoStatus,
    double? audioProgress,
    double? videoProgress,
    String? audioPath,
    String? videoPath,
    String? audioError,
    String? videoError,
    int? audioSize,
    int? videoSize,
  }) =>
      TrackDownloadState(
        ytVideoId: ytVideoId,
        audioStatus: audioStatus ?? this.audioStatus,
        videoStatus: videoStatus ?? this.videoStatus,
        audioProgress: audioProgress ?? this.audioProgress,
        videoProgress: videoProgress ?? this.videoProgress,
        audioPath: audioPath ?? this.audioPath,
        videoPath: videoPath ?? this.videoPath,
        audioError: audioError ?? this.audioError,
        videoError: videoError ?? this.videoError,
        audioSize: audioSize ?? this.audioSize,
        videoSize: videoSize ?? this.videoSize,
      );

  bool get isAudioDownloaded => audioStatus == DownloadStatus.done;
  bool get isVideoDownloaded => videoStatus == DownloadStatus.done;
  bool get isAudioDownloading => audioStatus == DownloadStatus.downloading;
  bool get isVideoDownloading => videoStatus == DownloadStatus.downloading;
}

// ══════════════════════════════════════════════════════════════════════
//  DownloadProvider
// ══════════════════════════════════════════════════════════════════════

class DownloadProvider extends ChangeNotifier {
  final DownloadService _service;

  final Map<String, TrackDownloadState> _states = {};

  // Aggregate storage info
  int _audioStorageBytes = 0;
  int _videoStorageBytes = 0;

  DownloadProvider(this._service) {
    _loadLocalState();
  }

  // Getters
  TrackDownloadState stateOf(String ytVideoId) =>
      _states[ytVideoId] ?? TrackDownloadState(ytVideoId: ytVideoId);

  bool isAudioDownloaded(String id) => stateOf(id).isAudioDownloaded;
  bool isVideoDownloaded(String id) => stateOf(id).isVideoDownloaded;
  bool isAudioDownloading(String id) => stateOf(id).isAudioDownloading;
  bool isVideoDownloading(String id) => stateOf(id).isVideoDownloading;

  // Total storage
  String get audioStorageLabel => _bytesLabel(_audioStorageBytes);
  String get videoStorageLabel => _bytesLabel(_videoStorageBytes);
  String get totalStorageLabel =>
      _bytesLabel(_audioStorageBytes + _videoStorageBytes);

  // All downloaded tracks (audio)
  List<String> get downloadedAudioIds => _states.values
      .where((s) => s.isAudioDownloaded)
      .map((s) => s.ytVideoId)
      .toList();

  List<String> get downloadedVideoIds => _states.values
      .where((s) => s.isVideoDownloaded)
      .map((s) => s.ytVideoId)
      .toList();

  // ── Load existing local files on startup ────────────────────────
  Future<void> _loadLocalState() async {
    try {
      final locals = await _service.listLocalDownloads();
      for (final item in locals) {
        final id = item['yt_video_id'] as String;
        final type = item['file_type'] as String;
        final path = item['file_path'] as String;
        final size = item['file_size'] as int;
        final old = _states[id] ?? TrackDownloadState(ytVideoId: id);

        _states[id] = type == 'audio'
            ? old.copyWith(
                audioStatus: DownloadStatus.done,
                audioPath: path,
                audioSize: size,
              )
            : old.copyWith(
                videoStatus: DownloadStatus.done,
                videoPath: path,
                videoSize: size,
              );
      }
      await _refreshStorageTotals();
      notifyListeners();
    } catch (e) {
      debugPrint('[DownloadProvider] _loadLocalState error: $e');
    }
  }

  // ── Download audio ───────────────────────────────────────────────
  Future<void> downloadAudio(Track track) async {
    final id = track.ytVideoId;
    if (stateOf(id).isAudioDownloading) return; // already in progress

    _update(
        id,
        (s) => s.copyWith(
            audioStatus: DownloadStatus.downloading,
            audioProgress: 0.0,
            audioError: null));

    final result = await _service.downloadAudio(
      track,
      onProgress: (p) {
        _update(id, (s) => s.copyWith(audioProgress: p));
      },
    );

    if (result.success) {
      _update(
          id,
          (s) => s.copyWith(
              audioStatus: DownloadStatus.done,
              audioPath: result.filePath,
              audioSize: result.fileSizeBytes,
              audioError: null));
    } else {
      _update(
          id,
          (s) => s.copyWith(
              audioStatus: DownloadStatus.failed, audioError: result.error));
    }
    await _refreshStorageTotals();
  }

  // ── Download video ───────────────────────────────────────────────
  Future<void> downloadVideo(Track track) async {
    final id = track.ytVideoId;
    if (stateOf(id).isVideoDownloading) return;

    _update(
        id,
        (s) => s.copyWith(
            videoStatus: DownloadStatus.downloading,
            videoProgress: 0.0,
            videoError: null));

    final result = await _service.downloadVideo(
      track,
      onProgress: (p) {
        _update(id, (s) => s.copyWith(videoProgress: p));
      },
    );

    if (result.success) {
      _update(
          id,
          (s) => s.copyWith(
              videoStatus: DownloadStatus.done,
              videoPath: result.filePath,
              videoSize: result.fileSizeBytes,
              videoError: null));
    } else {
      _update(
          id,
          (s) => s.copyWith(
              videoStatus: DownloadStatus.failed, videoError: result.error));
    }
    await _refreshStorageTotals();
  }

  // ── Cancel ───────────────────────────────────────────────────────
  void cancelAudio(String ytVideoId) {
    _service.cancelDownload(ytVideoId, type: 'audio');
    _update(
        ytVideoId,
        (s) =>
            s.copyWith(audioStatus: DownloadStatus.none, audioProgress: 0.0));
  }

  void cancelVideo(String ytVideoId) {
    _service.cancelDownload(ytVideoId, type: 'video');
    _update(
        ytVideoId,
        (s) =>
            s.copyWith(videoStatus: DownloadStatus.none, videoProgress: 0.0));
  }

  // ── Delete ───────────────────────────────────────────────────────
  Future<void> deleteAudio(String ytVideoId) async {
    await _service.deleteDownload(ytVideoId, type: 'audio');
    _update(
        ytVideoId,
        (s) => s.copyWith(
            audioStatus: DownloadStatus.none,
            audioPath: null,
            audioSize: 0,
            audioError: null));
    await _refreshStorageTotals();
  }

  Future<void> deleteVideo(String ytVideoId) async {
    await _service.deleteDownload(ytVideoId, type: 'video');
    _update(
        ytVideoId,
        (s) => s.copyWith(
            videoStatus: DownloadStatus.none,
            videoPath: null,
            videoSize: 0,
            videoError: null));
    await _refreshStorageTotals();
  }

  // ── Offline playback path ─────────────────────────────────────────
  Future<String?> getAudioPath(String ytVideoId) async {
    final s = stateOf(ytVideoId);
    if (s.isAudioDownloaded && s.audioPath != null) return s.audioPath;
    return _service.localPath(ytVideoId, type: 'audio');
  }

  Future<String?> getVideoPath(String ytVideoId) async {
    final s = stateOf(ytVideoId);
    if (s.isVideoDownloaded && s.videoPath != null) return s.videoPath;
    return _service.localPath(ytVideoId, type: 'video');
  }

  // ── Private helpers ───────────────────────────────────────────────
  void _update(String id, TrackDownloadState Function(TrackDownloadState) fn) {
    _states[id] = fn(_states[id] ?? TrackDownloadState(ytVideoId: id));
    notifyListeners();
  }

  Future<void> _refreshStorageTotals() async {
    final usage = await _service.storageUsage();
    _audioStorageBytes = usage['audio'] ?? 0;
    _videoStorageBytes = usage['video'] ?? 0;
    notifyListeners();
  }

  String _bytesLabel(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
