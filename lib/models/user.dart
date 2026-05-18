class User {
  final String id;
  final String email;
  final String username;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final String? dob;
  final int coins;
  final int totalEarned;
  final String referralCode;
  final int level;
  final bool isOnline;
  final String? lastSeen;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.phone,
    this.dob,
    this.coins = 0,
    this.totalEarned = 0,
    this.referralCode = '',
    this.level = 1,
    this.isOnline = false,
    this.lastSeen,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] ?? '',
        email: json['email'] ?? '',
        username: json['username'] ?? '',
        name: json['name'] ?? '',
        avatarUrl: json['avatar_url'],
        bio: json['bio'],
        phone: json['phone'],
        dob: json['dob'],
        coins: json['coins'] ?? 0,
        totalEarned: json['total_earned'] ?? 0,
        referralCode: json['referral_code'] ?? '',
        level: json['level'] ?? 1,
        isOnline: json['is_online'] ?? false,
        lastSeen: json['last_seen'],
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'username': username,
        'name': name,
        'avatar_url': avatarUrl,
        'bio': bio,
        'phone': phone,
        'dob': dob,
        'coins': coins,
        'total_earned': totalEarned,
        'referral_code': referralCode,
        'level': level,
        'is_online': isOnline,
        'last_seen': lastSeen,
        'created_at': createdAt.toIso8601String(),
      };

  User copyWith({
    String? name,
    String? avatarUrl,
    String? bio,
    int? coins,
    int? totalEarned,
    int? level,
  }) =>
      User(
        id: id,
        email: email,
        username: username,
        name: name ?? this.name,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        phone: phone,
        dob: dob,
        coins: coins ?? this.coins,
        totalEarned: totalEarned ?? this.totalEarned,
        referralCode: referralCode,
        level: level ?? this.level,
        isOnline: isOnline,
        lastSeen: lastSeen,
        createdAt: createdAt,
      );
}
