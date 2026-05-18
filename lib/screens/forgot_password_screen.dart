// forgot_password_screen.dart — Unified Dark Black + Lime theme

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  int _step = 0; // 0=email, 1=OTP+new password
  final _emailCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocus = List.generate(6, (_) => FocusNode());
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  String? _error;
  int _resendCountdown = 0;

  // ── Unified theme ──────────────────────────────────────────────
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<ApiService>().forgotPassword(email);
      if (!mounted) return;
      setState(() {
        _step = 1;
        _resendCountdown = 60;
      });
      _startTimer();
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      return _resendCountdown > 0;
    });
  }

  Future<void> _resetPassword() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length < 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    if (_passCtrl.text.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<ApiService>().resetPassword(
            email: _emailCtrl.text.trim(),
            otp: otp,
            newPassword: _passCtrl.text,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset successfully!')));
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                ? () => setState(() {
                      _step = 0;
                      _error = null;
                    })
                : () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 16),
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                if (_step == 0) ...[
                  _heading('Reset\nPassword'),
                  const SizedBox(height: 8),
                  _subtitle('Enter your email to receive a reset code'),
                  const SizedBox(height: 36),
                  _field(_emailCtrl, 'Email address', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  if (_error != null) _errorWidget(_error!),
                  const SizedBox(height: 28),
                  _primaryBtn('Send Code', _isLoading ? null : _sendReset),
                ] else ...[
                  _heading('Enter\nNew Password'),
                  const SizedBox(height: 8),
                  _subtitle('Code sent to ${_emailCtrl.text.trim()}'),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, _otpBox),
                  ),
                  const SizedBox(height: 20),
                  _field(_passCtrl, 'New password', Icons.lock_outline_rounded,
                      obscure: _obscure,
                      suffix: IconButton(
                        icon: Icon(
                            _obscure
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF555555),
                            size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      )),
                  if (_error != null) _errorWidget(_error!),
                  const SizedBox(height: 28),
                  _primaryBtn(
                      'Reset Password', _isLoading ? null : _resetPassword),
                  const SizedBox(height: 16),
                  Center(
                    child: _resendCountdown > 0
                        ? Text('Resend in ${_resendCountdown}s',
                            style: const TextStyle(
                                color: Color(0xFF444444), fontSize: 14))
                        : TextButton(
                            onPressed: _sendReset,
                            child: const Text('Resend code',
                                style: TextStyle(
                                    color: _lime,
                                    fontWeight: FontWeight.w700))),
                  ),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _otpBox(int i) => SizedBox(
        width: 46,
        height: 56,
        child: TextField(
          controller: _otpCtrls[i],
          focusNode: _otpFocus[i],
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
            if (val.isNotEmpty && i < 5)
              _otpFocus[i + 1].requestFocus();
            else if (val.isEmpty && i > 0) _otpFocus[i - 1].requestFocus();
          },
        ),
      );

  Widget _heading(String text) => Text(text,
      style: const TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          height: 1.15));

  Widget _subtitle(String text) => Text(text,
      style: const TextStyle(color: Color(0xFF555555), fontSize: 15));

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
                      color: Color(0xFF0F0F0F))),
        ),
      );
}
