// ╔══════════════════════════════════════════════════════════════════╗
// ║              app_banner.dart — Admin Banner Model                ║
// ╚══════════════════════════════════════════════════════════════════╝

/// Represents a single banner shown on Home or Referral screen.
/// Controlled entirely from admin panel via /config endpoint.
///
/// Admin panel should set config key: "banners"
/// Value (JSON):
/// [
///   {
///     "id": "b1",
///     "image_url": "https://...",   // Cloudinary URL (optional)
///     "title": "Dhamaka Offer!",
///     "subtitle": "Complete Paytm install — only today!",
///     "badge": "HOT",               // optional badge text
///     "bg_color_start": "#7B1FA2",  // gradient start hex
///     "bg_color_end": "#E040FB",    // gradient end hex
///     "target": "home",             // "home" | "referral" | "earn" | "withdraw"
///     "action": "earn",             // route to push on tap
///     "enabled": true
///   }
/// ]
class AppBanner {
  final String id;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String badge;
  final String bgColorStart;
  final String bgColorEnd;
  final String target; // which screen shows this banner
  final String action; // route on tap
  final bool enabled;

  AppBanner({
    required this.id,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    this.badge = '',
    this.bgColorStart = '#004D20',
    this.bgColorEnd = '#00C853',
    this.target = 'home',
    this.action = '/home',
    this.enabled = true,
  });

  factory AppBanner.fromJson(Map<String, dynamic> json) => AppBanner(
        id: json['id']?.toString() ?? '',
        imageUrl: json['image_url'] as String?,
        title: json['title'] ?? '',
        subtitle: json['subtitle'] ?? '',
        badge: json['badge'] ?? '',
        bgColorStart: json['bg_color_start'] ?? '#004D20',
        bgColorEnd: json['bg_color_end'] ?? '#00C853',
        target: json['target'] ?? 'home',
        action: json['action'] ?? '/home',
        enabled: json['enabled'] ?? true,
      );

  /// Parses "#RRGGBB" → Color
  static int _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return int.parse('FF$h', radix: 16);
  }

  int get startColorValue => _hex(bgColorStart);
  int get endColorValue => _hex(bgColorEnd);
}

/// Splash animation config from admin panel.
/// Admin sets config key: "splash_animation"
/// Value:
/// {
///   "style": "ripple",       // "ripple" | "pulse" | "bounce"
///   "primary_color": "#00C853",
///   "ripple_count": 3,
///   "duration_ms": 900,
///   "tagline": "Earn coins, Get rewarded!"
/// }
class SplashConfig {
  final String style;
  final String primaryColor;
  final int rippleCount;
  final int durationMs;
  final String tagline;

  const SplashConfig({
    this.style = 'ripple',
    this.primaryColor = '#00C853',
    this.rippleCount = 3,
    this.durationMs = 900,
    this.tagline = 'Earn coins, Get rewarded!',
  });

  factory SplashConfig.fromJson(Map<String, dynamic> json) => SplashConfig(
        style: json['style'] ?? 'ripple',
        primaryColor: json['primary_color'] ?? '#00C853',
        rippleCount: json['ripple_count'] ?? 3,
        durationMs: json['duration_ms'] ?? 900,
        tagline: json['tagline'] ?? 'Earn coins, Get rewarded!',
      );

  static int _hex(String hex) {
    final h = hex.replaceAll('#', '');
    return int.parse('FF$h', radix: 16);
  }

  int get colorValue => _hex(primaryColor);
}
