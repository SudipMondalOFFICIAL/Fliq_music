// ╔══════════════════════════════════════════════════════════════════╗
// ║  player_provider.dart — Music Player State Management             ║
// ║  Queue • Current Track • Download • Playing State                 ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../models/track_model.dart';
import '../services/player_service.dart';
import 'dart:io';

enum PlayerStatus { idle, loading, playing, paused, error }

class PlayerProvider extends ChangeNotifier {
  final PlayerService _playerService = PlayerService.instance;

  // Queue management
  List<Track> _queue = [];
  int _currentIndex = 0;
  Track? _currentTrack;
  PlayerStatus _status = PlayerStatus.idle;
  String? _errorMessage;

  // Player state
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  double _speed = 1.0;

  // Playback mode: none, one, shuffle
  String _loopMode = 'none';
  bool _isShuffle = false;

  // Download progress tracking
  Map<String, double> _downloadProgress = {};
  Set<String> _downloadedVideos = {};

  // Getters
  List<Track> get queue => _queue;
  Track? get currentTrack => _currentTrack;
  int get currentIndex => _currentIndex;
  PlayerStatus get status => _status;
  String? get errorMessage => _errorMessage;

  Duration get duration => _duration;
  Duration get position => _position;
  bool get isPlaying => _isPlaying;
  double get speed => _speed;
  String get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;

  Map<String, double> get downloadProgress => _downloadProgress;
  Set<String> get downloadedVideos => _downloadedVideos;

  // Stream getters from AudioPlayer
  Stream<Duration?> get durationStream => _playerService.player.durationStream;
  Stream<Duration> get positionStream => _playerService.player.positionStream;
  Stream<bool> get playingStream => _playerService.player.playingStream;

  PlayerProvider() {
    _initializeListeners();
  }

  void _initializeListeners() {
    _playerService.player.durationStream.listen((duration) {
      _duration = duration ?? Duration.zero;
      notifyListeners();
    });

    // FIX: position stream এ notifyListeners() সরানো হয়েছে।
    // Mini player এ StreamBuilder সরাসরি positionStream listen করে,
    // তাই এখানে প্রতি 200ms notifyListeners() দিলে পুরো widget tree rebuild হয় — massive lag।
    _playerService.player.positionStream.listen((position) {
      _position = position;
      // notifyListeners() intentionally removed — prevents rebuild storm
    });

    _playerService.player.playingStream.listen((playing) {
      _isPlaying = playing;
      notifyListeners();
    });

    _playerService.player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _playNext();
      }
    });
  }

  /// Set queue and start playing from index
  Future<void> setQueue(List<Track> tracks, {int startIndex = 0}) async {
    _queue = tracks;
    _currentIndex = startIndex;
    if (startIndex < tracks.length) {
      await playTrack(tracks[startIndex]);
    }
  }

  /// Add track to queue
  void addToQueue(Track track) {
    _queue.add(track);
    notifyListeners();
  }

  /// Add multiple tracks to queue
  void addMultipleToQueue(List<Track> tracks) {
    _queue.addAll(tracks);
    notifyListeners();
  }

  /// Remove from queue by index
  void removeFromQueue(int index) {
    if (index >= 0 && index < _queue.length) {
      _queue.removeAt(index);
      if (index == _currentIndex && _queue.isNotEmpty) {
        _currentIndex =
            _currentIndex >= _queue.length ? _queue.length - 1 : _currentIndex;
      }
      notifyListeners();
    }
  }

  /// Clear queue
  void clearQueue() {
    _queue.clear();
    _currentIndex = 0;
    _currentTrack = null;
    _stop();
    notifyListeners();
  }

  /// Play specific track from queue
  Future<void> playTrack(Track track, {bool isVideo = false}) async {
    try {
      _status = PlayerStatus.loading;
      _currentTrack = track;
      _errorMessage = null;
      notifyListeners();

      final success = await _playerService.playTrack(track, isVideo: isVideo);
      if (success) {
        _status = PlayerStatus.playing;
        _isPlaying = true;
      } else {
        _status = PlayerStatus.error;
        _errorMessage = 'Failed to load track';
      }
    } catch (e) {
      _status = PlayerStatus.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Play track at queue index
  Future<void> playTrackAtIndex(int index) async {
    if (index >= 0 && index < _queue.length) {
      _currentIndex = index;
      await playTrack(_queue[index]);
    }
  }

  /// Play/Pause
  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _playerService.player.pause();
        _status = PlayerStatus.paused;
      } else {
        if (_currentTrack == null && _queue.isNotEmpty) {
          await playTrack(_queue[0]);
        } else if (_currentTrack != null) {
          await _playerService.player.play();
          _status = PlayerStatus.playing;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      _status = PlayerStatus.error;
    }
    notifyListeners();
  }

  /// Play next track
  Future<void> _playNext() async {
    if (_loopMode == 'one') {
      // Replay current
      if (_currentTrack != null) {
        await _playerService.player.seek(Duration.zero);
        await _playerService.player.play();
      }
    } else if (_currentIndex < _queue.length - 1) {
      _currentIndex++;
      await playTrack(_queue[_currentIndex]);
    } else if (_loopMode == 'all' && _queue.isNotEmpty) {
      _currentIndex = 0;
      await playTrack(_queue[0]);
    }
  }

  Future<void> nextTrack() async {
    await _playNext();
  }

  /// Play previous track
  Future<void> previousTrack() async {
    if (_position.inSeconds > 3) {
      // If more than 3 seconds played, replay current
      await _playerService.player.seek(Duration.zero);
    } else if (_currentIndex > 0) {
      _currentIndex--;
      await playTrack(_queue[_currentIndex]);
    }
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _playerService.player.seek(position);
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Set playback speed
  Future<void> setSpeed(double speed) async {
    try {
      _speed = speed;
      await _playerService.player.setSpeed(speed);
    } catch (e) {
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Toggle loop mode: none → all → one → none
  void toggleLoopMode() {
    if (_loopMode == 'none') {
      _loopMode = 'all';
    } else if (_loopMode == 'all') {
      _loopMode = 'one';
    } else {
      _loopMode = 'none';
    }
    notifyListeners();
  }

  /// Toggle shuffle
  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (_isShuffle && _queue.length > 1) {
      // Shuffle queue but keep current track
      Track current = _queue[_currentIndex];
      _queue.shuffle();
      _currentIndex = _queue.indexOf(current);
    }
    notifyListeners();
  }

  /// Stop playback
  Future<void> _stop() async {
    try {
      await _playerService.player.stop();
      _isPlaying = false;
      _status = PlayerStatus.idle;
    } catch (e) {
      _errorMessage = e.toString();
    }
  }

  /// Update download progress
  void setDownloadProgress(String videoId, double progress) {
    _downloadProgress[videoId] = progress;
    if (progress >= 1.0) {
      _downloadedVideos.add(videoId);
      _downloadProgress.remove(videoId);
    }
    notifyListeners();
  }

  /// Mark video as downloaded
  void markAsDownloaded(String videoId) {
    _downloadedVideos.add(videoId);
    _downloadProgress.remove(videoId);
    notifyListeners();
  }

  /// Check if video is downloaded
  bool isDownloaded(String videoId) {
    return _downloadedVideos.contains(videoId);
  }

  /// Get download progress percentage
  double getDownloadProgress(String videoId) {
    return _downloadProgress[videoId] ?? 0.0;
  }

  @override
  void dispose() {
    // FIX: Do NOT dispose the singleton AudioPlayer here.
    // PlayerService.instance manages its own lifecycle for the whole app.
    // Disposing it here would break playback after widget rebuild.
    super.dispose();
  }
}
