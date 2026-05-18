import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // ── Theme constants (matches HomeScreen) ──────────────────────
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _teal = Color(0xFF6BFFD8);
  static const _orange = Color(0xFFFF9F6B);
  static const _purple = Color(0xFFB06BFF);
  static const _red = Color(0xFFFF6B6B);
  static const _border = Color(0xFF1E1E1E);

  // ── State ─────────────────────────────────────────────────────
  final int _limit = 30;
  int _offset = 0;
  int _total = 0;
  bool _loading = false;
  String? _type; // null = all

  List<Map<String, dynamic>> _transactions = [];

  // Summary
  int _totalCredit = 0;
  int _totalDebit = 0;

  // ── Filter chips ──────────────────────────────────────────────
  static const _filters = [
    {'label': 'All', 'type': null},
    {'label': 'Tasks', 'type': 'task'},
    {'label': 'Referral', 'type': 'referral'},
    {'label': 'Watch', 'type': 'watch'},
    {'label': 'Promo', 'type': 'promo'},
    {'label': 'Withdraw', 'type': 'withdraw'},
    {'label': 'Admin', 'type': 'admin'},
  ];

  // ── Type display config ───────────────────────────────────────
  static const _typeConfig = {
    'watch': {
      'icon': Icons.play_circle_outline,
      'label': 'Video Watched',
      'color': _lime
    },
    'task': {
      'icon': Icons.check_circle_outline,
      'label': 'Task Completed',
      'color': _teal
    },
    'referral': {
      'icon': Icons.card_giftcard_outlined,
      'label': 'Referral Bonus',
      'color': _orange
    },
    'promo': {
      'icon': Icons.local_offer_outlined,
      'label': 'Promo Code',
      'color': _lime
    },
    'withdraw': {
      'icon': Icons.account_balance_wallet_outlined,
      'label': 'Withdrawal',
      'color': _red
    },
    'admin': {
      'icon': Icons.admin_panel_settings_outlined,
      'label': 'Admin',
      'color': _teal
    },
    'bonus': {'icon': Icons.stars_outlined, 'label': 'Bonus', 'color': _orange},
  };

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  // ── API call ──────────────────────────────────────────────────
  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _offset = 0;
      _transactions = [];
    }
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final result = await api.getCoinHistory(
        limit: _limit,
        offset: _offset,
        type: _type,
      );
      final txns =
          List<Map<String, dynamic>>.from(result['transactions'] ?? []);
      setState(() {
        _total = result['total'] ?? 0;
        _transactions = reset ? txns : [..._transactions, ...txns];
        _offset = _transactions.length;
        // Compute summary from entire fetched list
        _totalCredit = _transactions
            .where((t) => (t['amount'] as int) > 0)
            .fold(0, (s, t) => s + (t['amount'] as int));
        _totalDebit = _transactions
            .where((t) => (t['amount'] as int) < 0)
            .fold(0, (s, t) => s + (t['amount'] as int).abs());
      });
    } catch (e) {
      if (mounted) _showSnack(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: const Color(0xFF2A2A2A),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);
    final timeStr =
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (day == today) return 'Today · $timeStr';
    if (day == yesterday) return 'Yesterday · $timeStr';
    return '${d.day} ${_months[d.month - 1]} · $timeStr';
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];

  String _groupLabel(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return '${d.day} ${_months[d.month - 1]} ${d.year}';
  }

  // ── Build ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Color(0xFF555555), size: 14),
            ),
          ),
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Transaction History',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('$_total transaction${_total != 1 ? 's' : ''}',
                style: const TextStyle(color: Color(0xFF444444), fontSize: 10)),
          ]),
          titleSpacing: 0,
        ),
        body: Column(children: [
          _summaryRow(),
          _filterChips(),
          Expanded(
            child: RefreshIndicator(
              color: _lime,
              backgroundColor: _card,
              onRefresh: () => _load(reset: true),
              child: _transactions.isEmpty && !_loading
                  ? _emptyState()
                  : _txnList(),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────
  Widget _summaryRow() {
    final net = _totalCredit - _totalDebit;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: Row(children: [
        _summaryCard('CREDITED', '+$_totalCredit', 'coins earned', _lime),
        const SizedBox(width: 8),
        _summaryCard('DEBITED', '-$_totalDebit', 'coins spent', _red),
        const SizedBox(width: 8),
        _summaryCard('NET', '$net', 'balance', _teal),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                color: Color(0xFF444444),
                fontSize: 9,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.7,
              )),
          const SizedBox(height: 5),
          Text(value,
              style: TextStyle(
                color: color,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              )),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: Color(0xFF444444), fontSize: 9)),
        ]),
      ),
    );
  }

  // ── Filter Chips ──────────────────────────────────────────────
  Widget _filterChips() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 7),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = _type == f['type'];
          return GestureDetector(
            onTap: () {
              if (_type == f['type']) return;
              setState(() => _type = f['type'] as String?);
              _load(reset: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(
                color: active ? _lime : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _lime : _border),
              ),
              alignment: Alignment.center,
              child: Text(f['label'] as String,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF0F0F0F)
                        : const Color(0xFF888888),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  )),
            ),
          );
        },
      ),
    );
  }

  // ── Transaction List ──────────────────────────────────────────
  Widget _txnList() {
    // Group by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    final groupOrder = <String>[];
    for (final t in _transactions) {
      final g = _groupLabel(t['created_at'] ?? '');
      if (!grouped.containsKey(g)) {
        grouped[g] = [];
        groupOrder.add(g);
      }
      grouped[g]!.add(t);
    }

    final hasMore = _transactions.length < _total;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: groupOrder.length + (hasMore ? 1 : 0) + (_loading ? 1 : 0),
      itemBuilder: (_, idx) {
        if (idx < groupOrder.length) {
          final group = groupOrder[idx];
          final items = grouped[group]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6, left: 2),
                child: Text(group,
                    style: const TextStyle(
                      color: Color(0xFF444444),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    )),
              ),
              ...items.map(_buildTxnCard),
            ],
          );
        }
        if (hasMore && !_loading) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: GestureDetector(
              onTap: _load,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: const Center(
                  child: Text('Load more',
                      style: TextStyle(
                          color: _lime,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          );
        }
        return const Padding(
          padding: EdgeInsets.only(top: 20),
          child: Center(
              child: CircularProgressIndicator(color: _lime, strokeWidth: 2)),
        );
      },
    );
  }

  Widget _buildTxnCard(Map<String, dynamic> txn) {
    final type = txn['type'] as String? ?? 'admin';
    final amount = txn['amount'] as int? ?? 0;
    final desc = txn['description'] as String? ?? '';
    final date = _formatDate(txn['created_at'] as String? ?? '');
    final cfg = _typeConfig[type] ?? _typeConfig['admin']!;
    final icon = cfg['icon'] as IconData;
    final label = cfg['label'] as String;
    final color = cfg['color'] as Color;
    final isPos = amount > 0;
    final amtStr = (isPos ? '+' : '') + amount.toString();
    final amtClr = isPos ? _lime : _red;

    return Container(
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(desc,
                style: const TextStyle(
                  color: Color(0xFFDDDDDD),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 9,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 6),
              Text(date,
                  style:
                      const TextStyle(color: Color(0xFF444444), fontSize: 9)),
            ]),
          ]),
        ),
        const SizedBox(width: 8),
        Text(amtStr,
            style: TextStyle(
              color: amtClr,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            )),
      ]),
    );
  }

  // ── Empty State ───────────────────────────────────────────────
  Widget _emptyState() {
    return ListView(children: [
      Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Column(children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.receipt_long_outlined,
                color: Color(0xFF444444), size: 24),
          ),
          const SizedBox(height: 12),
          const Text('No transactions found',
              style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Try a different filter',
              style: TextStyle(color: Color(0xFF444444), fontSize: 11)),
        ]),
      ),
    ]);
  }
}
