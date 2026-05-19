// media_provider.dart — Music/Video feed, search, trending, likes

import 'package:flutter/material.dart';
import '../models/track_model.dart';
import '../services/api_service.dart';

enum MediaFeedState { idle, loading, loaded, error }

class MediaProvider extends ChangeNotifier {
  final ApiService _api;

  // ── Feed ─────────────────────────────────────────────────────
  List<Track> _feed = [];
  MediaFeedState _feedState = MediaFeedState.idle;
  bool _feedHasMore = true;
  int _feedPage = 1;

  // ── Trending ─────────────────────────────────────────────────
  List<Track> _trending = [];
  bool _trendingLoading = false;
  String _trendingCategory = 'music';

  // ── Search ───────────────────────────────────────────────────
  List<Track> _searchResults = [];
  bool _searchLoading = false;
  String _lastQuery = '';

  // ── Liked ────────────────────────────────────────────────────
  List<Track> _liked = [];
  bool _likedLoading = false;
  final Set<String> _likedIds = {};

  // ── Shorts / Reels ───────────────────────────────────────────
  List<Track> _shortsResults = [];
  bool _shortsLoading = false;
  bool _shortsHasMore = true;
  int _shortsPage = 1;

  // ── Watch coins ──────────────────────────────────────────────
  int _dailyWatchEarned = 0;
  int _dailyWatchLimit = 50;

  String? _error;

  MediaProvider(this._api);

  // Getters
  List<Track> get feed => _feed;
  MediaFeedState get feedState => _feedState;
  bool get feedHasMore => _feedHasMore;
  List<Track> get trending => _trending;
  bool get trendingLoading => _trendingLoading;
  String get trendingCategory => _trendingCategory;
  List<Track> get searchResults => _searchResults;
  bool get searchLoading => _searchLoading;
  String get lastQuery => _lastQuery;
  List<Track> get liked => _liked;
  bool get likedLoading => _likedLoading;
  int get dailyWatchEarned => _dailyWatchEarned;
  int get dailyWatchLimit => _dailyWatchLimit;
  String? get error => _error;

  List<Track> get shortsResults => _shortsResults;
  bool get shortsLoading => _shortsLoading;
  bool get shortsHasMore => _shortsHasMore;

  bool isLiked(String ytVideoId) => _likedIds.contains(ytVideoId);

  // ── Feed ─────────────────────────────────────────────────────
  Future<void> loadFeed({bool refresh = false}) async {
    if (_feedState == MediaFeedState.loading) return;
    if (refresh) {
      _feed = [];
      _feedPage = 1;
      _feedHasMore = true;
    }
    _feedState = MediaFeedState.loading;
    _error = null;
    notifyListeners();
    try {
      final r = await _api.getMusicFeed(page: _feedPage);
      final items = r['feed'] as List<dynamic>? ?? [];
      final tracks =
          items.map((e) => Track.fromJson(e as Map<String, dynamic>)).toList();
      _feed = refresh ? tracks : [..._feed, ...tracks];
      _feedHasMore = r['has_more'] == true;
      _feedPage++;
      _feedState = MediaFeedState.loaded;
    } catch (e) {
      _feedState = MediaFeedState.error;
      _error = e.toString().replaceAll('Exception: ', '');
    }
    notifyListeners();
  }

  Future<void> loadMoreFeed() async {
    if (!_feedHasMore || _feedState == MediaFeedState.loading) return;
    await loadFeed();
  }

  // ── Trending ─────────────────────────────────────────────────
  Future<void> loadTrending({String category = 'music'}) async {
    _trendingLoading = true;
    _trendingCategory = category;
    notifyListeners();
    try {
      _trending = await _api.getTrendingMusic(category: category);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _trendingLoading = false;
      notifyListeners();
    }
  }

  // ── Search ───────────────────────────────────────────────────
  Future<void> search(String q, {String type = 'any'}) async {
    if (q.isEmpty) return;
    _searchLoading = true;
    _lastQuery = q;
    _error = null;
    notifyListeners();
    try {
      _searchResults = await _api.searchMusic(q: q, type: type);
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
      _searchResults = [];
    } finally {
      _searchLoading = false;
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchResults = [];
    _lastQuery = '';
    _searchLoading = false;
    notifyListeners();
  }

  // ── Liked ────────────────────────────────────────────────────
  Future<void> loadLiked() async {
    _likedLoading = true;
    notifyListeners();
    try {
      _liked = await _api.getLikedVideos();
      _likedIds.addAll(_liked.map((t) => t.ytVideoId));
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _likedLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleLike(String ytVideoId) async {
    final nowLiked = !_likedIds.contains(ytVideoId);
    if (nowLiked) {
      _likedIds.add(ytVideoId);
    } else {
      _likedIds.remove(ytVideoId);
      _liked.removeWhere((t) => t.ytVideoId == ytVideoId);
    }
    notifyListeners();
    try {
      await _api.toggleLike(ytVideoId, liked: nowLiked);
    } catch (_) {
      // Revert on failure
      if (nowLiked) {
        _likedIds.remove(ytVideoId);
      } else {
        _likedIds.add(ytVideoId);
      }
      notifyListeners();
    }
  }

  // ── Watch log ────────────────────────────────────────────────
  Future<int> logWatch({
    required Track track,
    required int watchDurationSeconds,
  }) async {
    try {
      final r = await _api.logWatch(
        ytVideoId: track.ytVideoId,
        watchDurationSeconds: watchDurationSeconds,
        durationSeconds: track.durationSeconds,
        title: track.title,
        thumbnail: track.thumbnail,
        channel: track.channel,
        tags: track.tags,
        category: track.category,
      );
      final earned = r['coins_earned'] as int? ?? 0;
      if (earned > 0) {
        _dailyWatchEarned =
            r['daily_earned'] as int? ?? _dailyWatchEarned + earned;
        _dailyWatchLimit = r['daily_limit'] as int? ?? _dailyWatchLimit;
        notifyListeners();
      }
      return earned;
    } catch (_) {
      return 0;
    }
  }

  // ── Shorts / Reels ─────────────────────────────────────────
  Future<void> searchShorts({bool refresh = false}) async {
    if (_shortsLoading) return;
    if (refresh) {
      _shortsResults = [];
      _shortsPage = 1;
      _shortsHasMore = true;
    }
    _shortsLoading = true;
    notifyListeners();
    try {
      // YouTube Shorts search — vertical short videos (< 60s usually)
      final queries = [
        'youtube shorts',
        'shorts trending india',
        'viral shorts 2024',
      ];
      final q = queries[(_shortsPage - 1) % queries.length];
      final results = await _api.searchMusic(q: q, type: 'any', maxResults: 20);
      // Filter for shorter videos (shorts are typically < 65 seconds)
      // If duration is 0 (unknown), include it — might be a short
      final shorts = results
          .where((t) => t.durationSeconds == 0 || t.durationSeconds <= 65)
          .toList();
      final allResults = shorts.isNotEmpty ? shorts : results.take(10).toList();
      _shortsResults =
          refresh ? allResults : [..._shortsResults, ...allResults];
      _shortsHasMore = allResults.length >= 10;
      _shortsPage++;
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      _shortsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreShorts() async {
    if (!_shortsHasMore || _shortsLoading) return;
    await searchShorts();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
