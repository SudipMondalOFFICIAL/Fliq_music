// ── Task ────────────────────────────────────────────────────────
class EarnTask {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int coinsReward;
  final String type; // 'daily' | 'one_time' | 'weekly'
  final String actionType; // 'refer' | 'profile' | 'generic' | 'watch'
  final String actionValue;
  final bool isActive;
  final int sortOrder;
  // User progress
  final int progress;
  final bool completed;
  final String? completedAt;

  EarnTask({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.coinsReward,
    required this.type,
    required this.actionType,
    this.actionValue = '',
    this.isActive = true,
    this.sortOrder = 0,
    this.progress = 0,
    this.completed = false,
    this.completedAt,
  });

  factory EarnTask.fromJson(Map<String, dynamic> json) => EarnTask(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        description: json['description'] ?? '',
        icon: json['icon'] ?? '🎯',
        coinsReward: json['coins_reward'] ?? 0,
        type: json['type'] ?? 'daily',
        actionType: json['action_type'] ?? 'generic',
        actionValue: json['action_value'] ?? '',
        isActive: json['is_active'] ?? true,
        sortOrder: json['sort_order'] ?? 0,
        progress: json['progress'] ?? 0,
        completed: json['completed'] ?? false,
        completedAt: json['completed_at'],
      );

  int get target {
    try {
      return int.parse(actionValue);
    } catch (_) {
      return 1;
    }
  }

  double get progressPercent => completed
      ? 1.0
      : (target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0);
}

// ── Coin Transaction ────────────────────────────────────────────
class CoinTransaction {
  final String id;
  final String userId;
  final int amount;
  final String type;
  final String description;
  final String refId;
  final DateTime createdAt;

  CoinTransaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.description,
    required this.refId,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) =>
      CoinTransaction(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        amount: json['amount'] ?? 0,
        type: json['type'] ?? '',
        description: json['description'] ?? '',
        refId: json['ref_id'] ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  bool get isCredit => amount > 0;

  String get typeIcon {
    switch (type) {
      case 'watch':
        return '🎬';
      case 'task':
        return '✅';
      case 'referral':
        return '👥';
      case 'withdraw':
        return '💸';
      case 'bonus':
        return '🎁';
      case 'admin':
        return '⚙️';
      case 'promo':
        return '🎟️';
      default:
        return '💰';
    }
  }
}

// ── Withdraw Request ────────────────────────────────────────────
class WithdrawRequest {
  final String id;
  final String userId;
  final int coins;
  final double amountInr;
  final String method;
  final String upiId;
  final String accountName;
  final String status;
  final String adminNote;
  final DateTime? processedAt;
  final DateTime createdAt;

  WithdrawRequest({
    required this.id,
    required this.userId,
    required this.coins,
    required this.amountInr,
    required this.method,
    this.upiId = '',
    this.accountName = '',
    required this.status,
    this.adminNote = '',
    this.processedAt,
    required this.createdAt,
  });

  factory WithdrawRequest.fromJson(Map<String, dynamic> json) =>
      WithdrawRequest(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        coins: json['coins'] ?? 0,
        amountInr: (json['amount_inr'] ?? 0).toDouble(),
        method: json['method'] ?? 'upi',
        upiId: json['upi_id'] ?? '',
        accountName: json['account_name'] ?? '',
        status: json['status'] ?? 'pending',
        adminNote: json['admin_note'] ?? '',
        processedAt: json['processed_at'] != null
            ? DateTime.parse(json['processed_at'])
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );

  String get statusIcon {
    switch (status) {
      case 'pending':
        return '⏳';
      case 'approved':
        return '✅';
      case 'rejected':
        return '❌';
      case 'paid':
        return '💸';
      default:
        return '❓';
    }
  }
}

// ── Support Ticket ──────────────────────────────────────────────
class SupportTicket {
  final String id;
  final String userId;
  final String subject;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] ?? '',
        userId: json['user_id'] ?? '',
        subject: json['subject'] ?? '',
        status: json['status'] ?? 'open',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'])
            : DateTime.now(),
      );
}

// ── Support Message ─────────────────────────────────────────────
class SupportMessage {
  final String id;
  final String ticketId;
  final String senderType;
  final String? senderId;
  final String text;
  final String imageUrl;
  final DateTime createdAt;

  SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderType,
    this.senderId,
    required this.text,
    this.imageUrl = '',
    required this.createdAt,
  });

  bool get isAdmin => senderType == 'admin';
  bool get hasImage => imageUrl.isNotEmpty;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] ?? '',
        ticketId: json['ticket_id'] ?? '',
        senderType: json['sender_type'] ?? 'user',
        senderId: json['sender_id'],
        text: json['text'] ?? '',
        imageUrl: json['image_url'] ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'])
            : DateTime.now(),
      );
}

// ── Referral Stats ──────────────────────────────────────────────
class ReferralStats {
  final String referralCode;
  final int totalReferrals;
  final int totalBonusEarned;
  final int referrerBonusPerInvite;
  final int referredBonus;
  final List<Map<String, dynamic>> referrals;

  ReferralStats({
    required this.referralCode,
    required this.totalReferrals,
    required this.totalBonusEarned,
    required this.referrerBonusPerInvite,
    required this.referredBonus,
    required this.referrals,
  });

  factory ReferralStats.fromJson(Map<String, dynamic> json) => ReferralStats(
        referralCode: json['referral_code'] ?? '',
        totalReferrals: json['total_referrals'] ?? 0,
        totalBonusEarned: json['total_bonus_earned'] ?? 0,
        referrerBonusPerInvite: json['referrer_bonus_per_invite'] ?? 0,
        referredBonus: json['referred_bonus'] ?? 0,
        referrals: List<Map<String, dynamic>>.from(json['referrals'] ?? []),
      );
}

// ── Watch Earn Stats ─────────────────────────────────────────────
class WatchEarnStats {
  final int dailyEarned;
  final int dailyLimit;
  final int coinsPerWatch;
  final int coinsPerComplete;

  WatchEarnStats({
    this.dailyEarned = 0,
    this.dailyLimit = 50,
    this.coinsPerWatch = 2,
    this.coinsPerComplete = 5,
  });

  int get remaining => (dailyLimit - dailyEarned).clamp(0, dailyLimit);
  bool get limitReached => dailyEarned >= dailyLimit;
  double get progressPercent =>
      dailyLimit > 0 ? (dailyEarned / dailyLimit).clamp(0.0, 1.0) : 0.0;
}