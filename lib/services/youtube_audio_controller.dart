// lib/services/youtube_audio_controller.dart

import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class YoutubeAudioController extends ChangeNotifier {
  YoutubePlayerController? _controller;
  String? _currentVideoId;
  bool _isPlaying = false;
  bool _isReady = false;

  YoutubePlayerController? get controller => _controller;
  String? get currentVideoId => _currentVideoId;
  bool get isPlaying => _isPlaying;
  bool get isReady => _isReady;

  void play(String videoId) {
    if (_currentVideoId == videoId && _controller != null) {
      _controller!.play();
      _isPlaying = true;
      notifyListeners();
      return;
    }

    _controller?.dispose();
    _currentVideoId = videoId;
    _isReady = false;
    _isPlaying = false;

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        hideControls: true,
        hideThumbnail: true,
        enableCaption: false,
        forceHD: false,
      ),
    )..addListener(_onControllerUpdate);

    notifyListeners();
  }

  void _onControllerUpdate() {
    if (_controller == null) return;
    final value = _controller!.value;

    if (value.isReady && !_isReady) {
      _isReady = true;
      notifyListeners();
    }

    if (value.isPlaying != _isPlaying) {
      _isPlaying = value.isPlaying;
      notifyListeners();
    }
  }

  void pause() {
    _controller?.pause();
    _isPlaying = false;
    notifyListeners();
  }

  void resume() {
    _controller?.play();
    _isPlaying = true;
    notifyListeners();
  }

  void togglePlayPause() {
    if (_isPlaying) {
      pause();
    } else {
      resume();
    }
  }

  void seekTo(Duration position) {
    _controller?.seekTo(position);
  }

  Duration get position => _controller?.value.position ?? Duration.zero;

  @override
  void dispose() {
    _controller?.removeListener(_onControllerUpdate);
    _controller?.dispose();
    super.dispose();
  }
}