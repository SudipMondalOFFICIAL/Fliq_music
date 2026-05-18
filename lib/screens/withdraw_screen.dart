// ╔══════════════════════════════════════════════════════════════════╗
// ║     withdraw_screen.dart — Black + Lime + Saved Payment Details  ║
// ╚══════════════════════════════════════════════════════════════════╝

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/banner_carousel.dart';

class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({Key? key}) : super(key: key);
  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen>
    with SingleTickerProviderStateMixin {
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);
  static const _teal = Color(0xFF6BFFD8);
  static const _red = Color(0xFFFF6B6B);

  final _coinsCtrl = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // ── Add Payment sheet controllers ──
  final _upiIdCtrl = TextEditingController();
  final _upiNameCtrl = TextEditingController();
  final _upiPhoneCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNoCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  final _bankPhoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final w = context.read<WalletProvider>();
    await Future.wait([
      w.loadRate(),
      w.loadPaymentDetails(),
      w.loadWithdrawHistory(),
    ]);
  }

  @override
  void dispose() {
    _coinsCtrl.dispose();
    _upiIdCtrl.dispose();
    _upiNameCtrl.dispose();
    _upiPhoneCtrl.dispose();
    _accNameCtrl.dispose();
    _accNoCtrl.dispose();
    _ifscCtrl.dispose();
    _bankPhoneCtrl.dispose();
    super.dispose();
  }

  // ── Submit Withdraw ─────────────────────────────────────────
  Future<void> _submitWithdraw(String method) async {
    final coins = int.tryParse(_coinsCtrl.text.trim()) ?? 0;
    if (coins <= 0) {
      setState(() => _error = 'Enter coin amount');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final err = await context.read<WalletProvider>().createWithdraw(
          coins: coins,
          method: method,
        );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _error = err;
      });
      if (err == null) {
        _coinsCtrl.clear();
        _showSuccessDialog();
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border),
        ),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _lime.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _lime.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.check_rounded, color: _lime, size: 28),
          ),
          const SizedBox(height: 14),
          const Text('Request Submitted!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'Your withdrawal request is under review.\nWe\'ll process it within 24-48 hours.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF555555), fontSize: 12)),
        ]),
        actions: [
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: _lime,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Got it!',
                  style: TextStyle(
                      color: Color(0xFF0F0F0F), fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Add UPI Sheet ───────────────────────────────────────────
  void _showAddUpiSheet() {
    _upiIdCtrl.clear();
    _upiNameCtrl.clear();
    _upiPhoneCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddPaymentSheet(
        title: 'Add UPI Details',
        icon: Icons.payment_outlined,
        color: _lime,
        fields: [
          _SheetField(
              _upiIdCtrl, 'UPI ID', 'e.g. name@upi', Icons.alternate_email),
          _SheetField(_upiNameCtrl, 'Account Holder Name', 'Full name',
              Icons.person_outline),
          _SheetField(_upiPhoneCtrl, 'Contact Number', '10-digit number',
              Icons.phone_outlined,
              inputType: TextInputType.phone),
        ],
        onSave: () async {
          Navigator.pop(context);
          final err = await context.read<WalletProvider>().savePaymentDetails(
                upiId: _upiIdCtrl.text.trim(),
                upiHolderName: _upiNameCtrl.text.trim(),
                upiPhone: _upiPhoneCtrl.text.trim(),
              );
          if (err != null && mounted)
            _showSnack(err, isError: true);
          else if (mounted) _showSnack('UPI details saved!');
        },
      ),
    );
  }

  // ── Add Bank Sheet ──────────────────────────────────────────
  void _showAddBankSheet() {
    _accNameCtrl.clear();
    _accNoCtrl.clear();
    _ifscCtrl.clear();
    _bankPhoneCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _AddPaymentSheet(
        title: 'Add Bank Account',
        icon: Icons.account_balance_outlined,
        color: _teal,
        fields: [
          _SheetField(_accNameCtrl, 'Account Holder Name', 'Full name',
              Icons.person_outline),
          _SheetField(_accNoCtrl, 'Account Number', 'Bank account number',
              Icons.numbers_outlined,
              inputType: TextInputType.number),
          _SheetField(
              _ifscCtrl, 'IFSC Code', 'e.g. SBIN0001234', Icons.code_outlined,
              caps: TextCapitalization.characters),
          _SheetField(_bankPhoneCtrl, 'Contact Number', '10-digit number',
              Icons.phone_outlined,
              inputType: TextInputType.phone),
        ],
        onSave: () async {
          Navigator.pop(context);
          final err = await context.read<WalletProvider>().savePaymentDetails(
                accountName: _accNameCtrl.text.trim(),
                accountNo: _accNoCtrl.text.trim(),
                ifsc: _ifscCtrl.text.trim(),
                bankPhone: _bankPhoneCtrl.text.trim(),
              );
          if (err != null && mounted)
            _showSnack(err, isError: true);
          else if (mounted) _showSnack('Bank details saved!');
        },
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: isError ? const Color(0xFF2A1A1A) : _card,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleSpacing: 18,
        title: Row(children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  const BoxDecoration(shape: BoxShape.circle, color: _lime)),
          const SizedBox(width: 8),
          const Text('Withdraw',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ]),
      ),
      body: Consumer<WalletProvider>(
        builder: (_, wallet, __) => RefreshIndicator(
          color: _lime,
          backgroundColor: _card,
          onRefresh: _init,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
            children: [
              // ── Admin Banners ──────────────────────────────
              Consumer<AppConfigProvider>(
                builder: (_, cfg, __) {
                  final banners = cfg.bannersFor('withdraw');
                  if (banners.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: BannerCarousel(banners: banners, height: 100),
                  );
                },
              ),

              // ── Balance Card ───────────────────────────────
              _balanceCard(wallet),
              const SizedBox(height: 10),

              // ── Payment Methods ────────────────────────────
              _paymentMethodsSection(wallet),
              const SizedBox(height: 10),

              // ── Withdraw Form ──────────────────────────────
              if (wallet.hasUpi || wallet.hasBank) ...[
                _withdrawForm(wallet),
                const SizedBox(height: 10),
              ],

              // ── History ────────────────────────────────────
              _historySection(wallet),
            ],
          ),
        ),
      ),
    );
  }

  // ── Balance Card ─────────────────────────────────────────────
  Widget _balanceCard(WalletProvider wallet) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('AVAILABLE BALANCE',
            style: TextStyle(
                color: Color(0xFF555555),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1)),
        const SizedBox(height: 12),
        Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${wallet.coins}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2,
                      height: 1)),
              const SizedBox(width: 6),
              const Text('coins',
                  style: TextStyle(color: Color(0xFF333333), fontSize: 14)),
            ]),
        const SizedBox(height: 4),
        Text('≈ ₹${wallet.inrBalance.toStringAsFixed(2)}',
            style: const TextStyle(color: Color(0xFF444444), fontSize: 12)),
        const SizedBox(height: 12),
        Container(height: 1, color: _border),
        const SizedBox(height: 10),
        Row(children: [
          _infoChip('Min: ${wallet.minWithdraw} coins', _lime),
          const SizedBox(width: 8),
          _infoChip('Max: ${wallet.maxWithdraw} coins', _teal),
        ]),
      ]),
    );
  }

  Widget _infoChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  // ── Payment Methods Section ───────────────────────────────────
  Widget _paymentMethodsSection(WalletProvider wallet) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Payment Methods',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
          if (wallet.isPaymentLocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _red.withValues(alpha: 0.3)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline, color: _red, size: 10),
                SizedBox(width: 4),
                Text('Locked',
                    style: TextStyle(
                        color: _red,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
        ]),
        const SizedBox(height: 4),
        const Text('Add once — used for all withdrawals',
            style: TextStyle(color: Color(0xFF444444), fontSize: 10)),
        const SizedBox(height: 14),

        // UPI
        _paymentMethodTile(
          icon: Icons.payment_outlined,
          color: _lime,
          title: 'UPI',
          saved: wallet.hasUpi,
          detail: wallet.hasUpi ? wallet.paymentDetails['upi_id'] ?? '' : null,
          subDetail: wallet.hasUpi
              ? wallet.paymentDetails['upi_holder_name'] ?? ''
              : null,
          onAdd: wallet.isPaymentLocked ? null : _showAddUpiSheet,
        ),

        const SizedBox(height: 8),

        // Bank
        _paymentMethodTile(
          icon: Icons.account_balance_outlined,
          color: _teal,
          title: 'Bank Account',
          saved: wallet.hasBank,
          detail: wallet.hasBank
              ? '****${(wallet.paymentDetails['account_no'] ?? '').toString().padLeft(4).substring(((wallet.paymentDetails['account_no'] ?? '').toString().length - 4).clamp(0, double.maxFinite.toInt()))}'
              : null,
          subDetail: wallet.hasBank
              ? wallet.paymentDetails['account_name'] ?? ''
              : null,
          onAdd: wallet.isPaymentLocked ? null : _showAddBankSheet,
        ),

        if (wallet.isPaymentLocked) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withValues(alpha: 0.15)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline, color: _red, size: 13),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Both methods saved. Contact support to update details.',
                  style: TextStyle(color: _red, fontSize: 11),
                ),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _paymentMethodTile({
    required IconData icon,
    required Color color,
    required String title,
    required bool saved,
    String? detail,
    String? subDetail,
    VoidCallback? onAdd,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _card2,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: saved ? color.withValues(alpha: 0.3) : _border),
      ),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: saved
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 10)),
                  Text(detail ?? '',
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  if (subDetail != null && subDetail.isNotEmpty)
                    Text(subDetail,
                        style: const TextStyle(
                            color: Color(0xFF555555), fontSize: 10)),
                ])
              : Text(title,
                  style:
                      const TextStyle(color: Color(0xFF888888), fontSize: 13)),
        ),
        if (saved)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.check_circle_outline, color: color, size: 11),
              const SizedBox(width: 4),
              Text('Saved',
                  style: TextStyle(
                      color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          )
        else if (onAdd != null)
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text('+ Add',
                  style: TextStyle(
                      color: color, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _border,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('Locked',
                style: TextStyle(color: Color(0xFF555555), fontSize: 10)),
          ),
      ]),
    );
  }

  // ── Withdraw Form ─────────────────────────────────────────────
  Widget _withdrawForm(WalletProvider wallet) {
    final hasBoth = wallet.hasUpi && wallet.hasBank;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Withdraw Coins',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),

        // Coin amount field
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: TextField(
            controller: _coinsCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(
                color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Enter coins to withdraw',
              hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 12),
              prefixIcon: Icon(Icons.circle, color: _lime, size: 14),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _red.withValues(alpha: 0.25)),
            ),
            child: Text(_error!,
                style: const TextStyle(color: _red, fontSize: 12)),
          ),
        ],

        const SizedBox(height: 14),

        // If both methods saved → show selection buttons
        if (hasBoth) ...[
          const Text('Select payment method',
              style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
          const SizedBox(height: 10),
          Row(children: [
            _submitBtn('UPI', Icons.payment_outlined, _lime,
                () => _submitWithdraw('upi')),
            const SizedBox(width: 8),
            _submitBtn('Bank', Icons.account_balance_outlined, _teal,
                () => _submitWithdraw('bank')),
          ]),
        ] else ...[
          // Only one method — single button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () => _submitWithdraw(wallet.hasUpi ? 'upi' : 'bank'),
              child: Container(
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF0F0F0F), strokeWidth: 2.5))
                      : const Text('Request Withdrawal',
                          style: TextStyle(
                              color: Color(0xFF0F0F0F),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                ),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _submitBtn(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: _isLoading
              ? Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: color, strokeWidth: 2)))
              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 6),
                  Text(label,
                      style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ]),
        ),
      ),
    );
  }

  // ── History ───────────────────────────────────────────────────
  Widget _historySection(WalletProvider wallet) {
    if (wallet.withdrawHistory.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Withdrawal History',
          style: TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      ...wallet.withdrawHistory.map((r) {
        Color statusColor;
        switch (r.status) {
          case 'approved':
          case 'paid':
            statusColor = _lime;
            break;
          case 'rejected':
            statusColor = _red;
            break;
          default:
            statusColor = _teal;
        }
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child:
                      Text(r.statusIcon, style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '₹${r.amountInr.toStringAsFixed(2)} via ${r.method.toUpperCase()}',
                        style: const TextStyle(
                            color: Color(0xFFDDDDDD),
                            fontWeight: FontWeight.w600,
                            fontSize: 12)),
                    Text('${r.coins} coins',
                        style: const TextStyle(
                            color: Color(0xFF444444), fontSize: 10)),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Text(r.status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        );
      }),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════
//  Add Payment Bottom Sheet
// ══════════════════════════════════════════════════════════════════

class _SheetField {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType inputType;
  final TextCapitalization caps;

  const _SheetField(
    this.ctrl,
    this.label,
    this.hint,
    this.icon, {
    this.inputType = TextInputType.text,
    this.caps = TextCapitalization.words,
  });
}

class _AddPaymentSheet extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<_SheetField> fields;
  final Future<void> Function() onSave;

  const _AddPaymentSheet({
    required this.title,
    required this.icon,
    required this.color,
    required this.fields,
    required this.onSave,
  });

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  static const _bg = Color(0xFF0F0F0F);
  static const _card2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF1E1E1E);

  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
        decoration: const BoxDecoration(
          color: Color(0xFF141414),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Handle
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),

          // Title
          Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 17),
            ),
            const SizedBox(width: 10),
            Text(widget.title,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ]),

          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: widget.color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: widget.color.withValues(alpha: 0.15)),
            ),
            child: Row(children: [
              Icon(Icons.lock_outline, color: widget.color, size: 12),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Details can only be saved once. Admin approval required to change.',
                  style: TextStyle(color: Color(0xFF888888), fontSize: 10),
                ),
              ),
            ]),
          ),

          const SizedBox(height: 16),

          // Fields
          ...widget.fields.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: TextField(
                    controller: f.ctrl,
                    keyboardType: f.inputType,
                    textCapitalization: f.caps,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: f.hint,
                      hintStyle: const TextStyle(
                          color: Color(0xFF333333), fontSize: 12),
                      prefixIcon: Icon(f.icon,
                          color: const Color(0xFF555555), size: 17),
                      labelText: f.label,
                      labelStyle: TextStyle(
                          color: widget.color.withValues(alpha: 0.7),
                          fontSize: 11),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                    ),
                  ),
                ),
              )),

          const SizedBox(height: 6),

          // Save button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: GestureDetector(
              onTap: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      await widget.onSave();
                      if (mounted) setState(() => _saving = false);
                    },
              child: Container(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Color(0xFF0F0F0F), strokeWidth: 2.5))
                      : const Text('Save Details',
                          style: TextStyle(
                              color: Color(0xFF0F0F0F),
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
