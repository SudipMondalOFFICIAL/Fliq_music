// notification_screen.dart

import 'package:flutter/material.dart';

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({Key? key}) : super(key: key);

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _border = Color(0xFF1E1E1E);
  static const _lime = Color(0xFFE8FF6B);

  // Dummy notifications for UI
  static const _items = [
    _NotifData(
      icon: Icons.music_note_rounded,
      iconColor: Color(0xFFE8FF6B),
      title: 'New trending tracks available',
      subtitle: 'Check out what\'s hot right now in music',
      time: '2m ago',
      unread: true,
    ),
    _NotifData(
      icon: Icons.monetization_on_rounded,
      iconColor: Color(0xFF4CAF50),
      title: 'You earned 10 coins!',
      subtitle: 'Watch 5 more videos to earn a bonus reward',
      time: '1h ago',
      unread: true,
    ),
    _NotifData(
      icon: Icons.people_alt_rounded,
      iconColor: Color(0xFF64B5F6),
      title: 'Referral bonus credited',
      subtitle: 'Your friend joined Fliq using your code',
      time: '3h ago',
      unread: false,
    ),
    _NotifData(
      icon: Icons.emoji_events_rounded,
      iconColor: Color(0xFFFFD54F),
      title: 'Leaderboard update',
      subtitle: 'You\'re now in the Top 100 this week!',
      time: '1d ago',
      unread: false,
    ),
    _NotifData(
      icon: Icons.download_done_rounded,
      iconColor: Color(0xFF81C784),
      title: 'Download complete',
      subtitle: 'Your track is ready to play offline',
      time: '2d ago',
      unread: false,
    ),
    _NotifData(
      icon: Icons.stars_rounded,
      iconColor: Color(0xFFFF8A65),
      title: 'Daily streak bonus',
      subtitle: 'Keep watching to maintain your streak!',
      time: '3d ago',
      unread: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 24),
          splashRadius: 22,
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              'Mark all read',
              style: TextStyle(
                color: _lime,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _items.isEmpty
          ? _EmptyNotifs()
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
              itemCount: _items.length,
              separatorBuilder: (_, __) => Divider(
                color: _border,
                height: 1,
                indent: 70,
              ),
              itemBuilder: (_, i) => _NotifTile(data: _items[i]),
            ),
    );
  }
}

// ── Notification Tile ────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final _NotifData data;
  const _NotifTile({required this.data});

  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      splashColor: Colors.white.withOpacity(0.03),
      child: Container(
        color: data.unread
            ? const Color(0xFF141414).withOpacity(0.6)
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: data.iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, color: data.iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          data.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: data.unread
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (data.unread)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: 8, top: 3),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: _lime,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                        color: Color(0xFF666666), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data.time,
                    style: const TextStyle(
                        color: Color(0xFF444444), fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────

class _EmptyNotifs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined,
              color: Color(0xFF333333), size: 56),
          SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6),
          Text(
            'We\'ll notify you when something happens',
            style: TextStyle(color: Color(0xFF3A3A3A), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ── Data model ───────────────────────────────────────────────────

class _NotifData {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String time;
  final bool unread;

  const _NotifData({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unread,
  });
}