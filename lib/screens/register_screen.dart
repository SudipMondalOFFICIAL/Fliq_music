// register_screen.dart — Unified Dark Black + Lime theme
// 4-step flow: Email → OTP → Password → Name + Referral → Home
// Fix v3: Google icon corrected with proper CustomPainter

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/notification_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  int _step = 0;

  final _emailCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  int _resendCountdown = 60;
  bool _resendLoading = false;
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _googleRefCtrl = TextEditingController();

  bool _isLoading = false;
  bool _googleLoading = false;
  String? _error;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0.06, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _refCtrl.dispose();
    _googleRefCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _goStep(int step) {
    _animCtrl.reverse().then((_) {
      if (!mounted) return;
      setState(() {
        _step = step;
        _error = null;
      });
      _animCtrl.forward();
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    final tempPass = _passCtrl.text.isNotEmpty ? _passCtrl.text : 'temp123456';
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final deviceId = await DeviceService.getDeviceId();
      final deviceInfo = await DeviceService.getDeviceInfo();
      await context.read<ApiService>().sendOtp(
            email: email,
            password: tempPass,
            deviceId: deviceId,
            deviceInfo: deviceInfo,
          );
      if (!mounted) return;
      _goStep(1);
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  Future<void> _resendOtp() async {
    setState(() {
      _resendLoading = true;
      _error = null;
    });
    try {
      await context
          .read<ApiService>()
          .resendOtp(email: _emailCtrl.text.trim(), purpose: 'register');
      if (!mounted) return;
      for (final c in _otpCtrls) c.clear();
      _otpFocus[0].requestFocus();
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _resendLoading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit code sent to your email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context
          .read<ApiService>()
          .verifyOtp(email: _emailCtrl.text.trim(), otp: otp);
      if (!mounted) return;
      _goStep(2);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _confirmPassword() {
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() => _error = null);
    _goStep(3);
  }

  Future<void> _completeRegister({bool skipRef = false}) async {
    final name = _nameCtrl.text.trim();
    final username = _usernameCtrl.text.trim().toLowerCase();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    if (username.length < 3 ||
        !RegExp(r'^[a-z0-9_]{3,32}$').hasMatch(username)) {
      setState(() =>
          _error = 'Username: 3-32 chars, letters/numbers/underscore only');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().register(
            email: _emailCtrl.text.trim(),
            password: _passCtrl.text,
            username: username,
            name: name,
            referralCode: skipRef ? null : _refCtrl.text.trim(),
          );
      if (!mounted) return;
      NotificationService.registerAfterLogin(context);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      final result = await context.read<AuthService>().googleSignIn();
      if (!mounted) return;
      NotificationService.registerAfterLogin(context);

      final isNewUser = result['is_new_user'] == true;
      final referralAlreadyApplied = result['referral_already_applied'] == true;

      if (isNewUser && !referralAlreadyApplied) {
        if (mounted) setState(() => _googleLoading = false);
        _showReferralDialog();
      } else {
        if (mounted) Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg != 'Google sign in cancelled') {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted && _googleLoading) {
        setState(() => _googleLoading = false);
      }
    }
  }

  void _showReferralDialog() {
    _googleRefCtrl.clear();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ReferralDialog(
        refCtrl: _googleRefCtrl,
        onSkip: () {
          Navigator.pop(ctx);
          Navigator.pushReplacementNamed(context, '/home');
        },
        onApply: (code) async {
          if (code.isNotEmpty) {
            try {
              await context.read<ApiService>().applyReferral(
                    referralCode: code,
                  );
            } catch (_) {}
          }
          if (!mounted) return;
          Navigator.pop(ctx);
          Navigator.pushReplacementNamed(context, '/home');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: GestureDetector(
            onTap: _step > 0
                ? () => _goStep(_step - 1)
                : () => Navigator.pushReplacementNamed(context, '/login'),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: LinearProgressIndicator(
              value: (_step + 1) / 4,
              backgroundColor: const Color(0xFF1E1E1E),
              valueColor: const AlwaysStoppedAnimation<Color>(_lime),
              minHeight: 3,
            ),
          ),
        ),
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 28),
                    Text('Step ${_step + 1} of 4',
                        style: const TextStyle(
                            color: Color(0xFF444444), fontSize: 13)),
                    const SizedBox(height: 16),
                    if (_step == 0) _buildStep0(),
                    if (_step == 1) _buildStep1(),
                    if (_step == 2) _buildStep2(),
                    if (_step == 3) _buildStep3(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep0() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Create\nAccount'),
          const SizedBox(height: 8),
          _subtitle('Enter your email to get started'),
          const SizedBox(height: 36),
          _field(_emailCtrl, 'Email address', Icons.email_outlined,
              keyboardType: TextInputType.emailAddress),
          if (_error != null) _errorWidget(_error!),
          const SizedBox(height: 28),
          _primaryBtn('Send OTP', _isLoading ? null : _sendOtp),
          const SizedBox(height: 20),
          _orDivider(),
          const SizedBox(height: 20),
          _googleBtn(),
          const SizedBox(height: 24),
          Center(
            child: TextButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/login'),
              child: RichText(
                text: const TextSpan(
                  text: 'Already have an account? ',
                  style: TextStyle(color: Color(0xFF555555), fontSize: 14),
                  children: [
                    TextSpan(
                        text: 'Log In',
                        style: TextStyle(
                            color: _lime, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      );

  Widget _buildStep1() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Check Your\nEmail'),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              text: 'We sent a code to ',
              style: const TextStyle(
                  color: Color(0xFF555555), fontSize: 15, height: 1.5),
              children: [
                TextSpan(
                  text: _emailCtrl.text.trim(),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _goStep(0),
            child: const Text('Wrong email? Change it',
                style: TextStyle(color: _lime, fontSize: 13)),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, _otpBox),
          ),
          if (_error != null) _errorWidget(_error!),
          const SizedBox(height: 28),
          _primaryBtn('Verify', _isLoading ? null : _verifyOtp),
          const SizedBox(height: 20),
          Center(
            child: _resendCountdown > 0
                ? Text('Resend code in ${_resendCountdown}s',
                    style:
                        const TextStyle(color: Color(0xFF444444), fontSize: 14))
                : _resendLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: _lime))
                    : GestureDetector(
                        onTap: _resendOtp,
                        child: const Text('Resend code',
                            style: TextStyle(
                                color: _lime,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                      ),
          ),
          const SizedBox(height: 40),
        ],
      );

  Widget _otpBox(int index) => SizedBox(
        width: 46,
        height: 56,
        child: TextField(
          controller: _otpCtrls[index],
          focusNode: _otpFocus[index],
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 1,
          style: const TextStyle(
              color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          cursorColor: _lime,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: _card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _lime, width: 2)),
          ),
          onChanged: (val) {
            if (val.isNotEmpty && index < 5)
              _otpFocus[index + 1].requestFocus();
            else if (val.isEmpty && index > 0)
              _otpFocus[index - 1].requestFocus();
            if (index == 5 && val.isNotEmpty) _verifyOtp();
          },
        ),
      );

  Widget _buildStep2() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Set a\nPassword'),
          const SizedBox(height: 8),
          _subtitle('Use at least 6 characters. Keep it safe!'),
          const SizedBox(height: 36),
          _field(_passCtrl, 'Create password', Icons.lock_outline_rounded,
              obscure: _obscurePass,
              suffix: IconButton(
                icon: Icon(
                    _obscurePass
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF555555),
                    size: 20),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              )),
          if (_error != null) _errorWidget(_error!),
          const SizedBox(height: 28),
          _primaryBtn('Continue', _confirmPassword),
          const SizedBox(height: 40),
        ],
      );

  Widget _buildStep3() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heading('Your\nProfile'),
          const SizedBox(height: 8),
          _subtitle('Set your name and a username. You can update anytime.'),
          const SizedBox(height: 32),
          _field(_nameCtrl, 'Full name', Icons.person_rounded),
          const SizedBox(height: 12),
          _field(_usernameCtrl, 'Username  (letters, numbers, _)',
              Icons.alternate_email_rounded),
          const Padding(
            padding: EdgeInsets.only(left: 4, top: 6),
            child: Text('Min 3 chars. No spaces. Eg: john_doe123',
                style: TextStyle(color: Color(0xFF444444), fontSize: 12)),
          ),
          const SizedBox(height: 16),
          _field(_refCtrl, 'Referral code (optional)',
              Icons.card_giftcard_rounded),
          if (_error != null) _errorWidget(_error!),
          const SizedBox(height: 28),
          _primaryBtn(
              'Create Account', _isLoading ? null : () => _completeRegister()),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      _refCtrl.clear();
                      _completeRegister(skipRef: true);
                    },
              child: const Text('Skip referral & continue',
                  style: TextStyle(color: Color(0xFF444444), fontSize: 14)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      );

  Widget _orDivider() => Row(children: [
        Expanded(child: Divider(color: const Color(0xFF1E1E1E), thickness: 1)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or',
              style: TextStyle(color: Color(0xFF444444), fontSize: 13)),
        ),
        Expanded(child: Divider(color: const Color(0xFF1E1E1E), thickness: 1)),
      ]);

  Widget _googleBtn() => SizedBox(
        width: double.infinity,
        height: 54,
        child: OutlinedButton(
          onPressed: (_isLoading || _googleLoading) ? null : _googleSignIn,
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF2A2A2A)),
            backgroundColor: const Color(0xFF141414),
            disabledBackgroundColor:
                const Color(0xFF141414).withValues(alpha: 0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: _googleLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _lime))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CustomPaint(painter: _GoogleIconPainter()),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Continue with Google',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      );

  Widget _heading(String text) => Text(text,
      style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.15));

  Widget _subtitle(String text) => Text(text,
      style:
          const TextStyle(color: Color(0xFF555555), fontSize: 15, height: 1.5));

  Widget _field(TextEditingController ctrl, String hint, IconData icon,
      {bool obscure = false, Widget? suffix, TextInputType? keyboardType}) {
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: TextField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        cursorColor: _lime,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF444444)),
          prefixIcon: Icon(icon, color: const Color(0xFF555555), size: 20),
          suffixIcon: suffix,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _errorWidget(String msg) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.redAccent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13))),
          ]),
        ),
      );

  Widget _primaryBtn(String label, VoidCallback? onTap) => SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _lime,
            disabledBackgroundColor: _lime.withValues(alpha: 0.35),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 0,
          ),
          child: _isLoading && onTap == null
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Color(0xFF0F0F0F)))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F0F0F),
                      letterSpacing: 0.3)),
        ),
      );
}

// ── Referral Dialog ────────────────────────────────────────────
class _ReferralDialog extends StatefulWidget {
  final TextEditingController refCtrl;
  final VoidCallback onSkip;
  final Future<void> Function(String code) onApply;

  const _ReferralDialog({
    required this.refCtrl,
    required this.onSkip,
    required this.onApply,
  });

  @override
  State<_ReferralDialog> createState() => _ReferralDialogState();
}

class _ReferralDialogState extends State<_ReferralDialog> {
  bool _applying = false;

  static const _bg2 = Color(0xFF141414);
  static const _border = Color(0xFF1E1E1E);
  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _bg2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      title: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _lime.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: _lime.withValues(alpha: 0.2)),
            ),
            child: const Center(
              child: Text('🎁', style: TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Got a Referral Code?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Enter a referral code to get bonus coins on your new account!',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Color(0xFF777777), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: widget.refCtrl,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                  color: _lime,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2),
              cursorColor: _lime,
              decoration: const InputDecoration(
                hintText: 'Enter code here',
                hintStyle: TextStyle(
                    color: Color(0xFF444444),
                    fontSize: 14,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w400),
                prefixIcon: Icon(Icons.card_giftcard_rounded,
                    color: Color(0xFF555555), size: 20),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _applying
                      ? null
                      : () async {
                          setState(() => _applying = true);
                          await widget.onApply(widget.refCtrl.text.trim());
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _lime,
                    disabledBackgroundColor: _lime.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _applying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0F0F0F)))
                      : const Text(
                          'Apply & Continue',
                          style: TextStyle(
                            color: Color(0xFF0F0F0F),
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: _applying ? null : widget.onSkip,
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Color(0xFF555555), fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Google G Icon — সঠিক CustomPainter ────────────────────────
// Official Google G logo:
//   - 4টি pie segment (blue, red, yellow, green)
//   - center এ white hole
//   - blue horizontal bar (right half)
//   - bar এর উপরে white block → G shape তৈরি হয়
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = math.min(size.width, size.height) / 2;
    final center = Offset(cx, cy);
    final outerRect = Rect.fromCircle(center: center, radius: r);

    // সব কিছু outer circle এর ভেতরে clip করো
    canvas.save();
    canvas.clipPath(Path()..addOval(outerRect));

    // 1. White background
    canvas.drawCircle(center, r, Paint()..color = Colors.white);

    // 2. Pie segments
    void drawPie(double startDeg, double sweepDeg, Color color) {
      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(
          outerRect,
          startDeg * math.pi / 180,
          sweepDeg * math.pi / 180,
          false,
        )
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    drawPie(-120, 90, const Color(0xFF4285F4)); // Blue  upper-left
    drawPie(-30, 120, const Color(0xFFEA4335)); // Red   upper-right
    drawPie(90, 120, const Color(0xFFFBBC05)); // Yellow lower-right
    drawPie(210, 120, const Color(0xFF34A853)); // Green  lower-left

    // 3. Inner white circle (hole)
    canvas.drawCircle(center, r * 0.60, Paint()..color = Colors.white);

    // 4. Blue horizontal bar (center.x → right, vertically centered)
    final barH = r * 0.27;
    final barTop = cy - barH / 2;
    canvas.drawRect(
      Rect.fromLTRB(cx, barTop, cx + r, barTop + barH),
      Paint()..color = const Color(0xFF4285F4),
    );

    // 5. White block উপরে bar এর (G এর opening)
    canvas.drawRect(
      Rect.fromLTRB(cx, cy - r, cx + r, barTop),
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
