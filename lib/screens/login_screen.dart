import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _googleLoading = false;
  String? _error;

  bool _checkingDevice = true;
  Map<String, dynamic>? _existingAccount;

  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500))
      ..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _detectDevice();
  }

  Future<void> _detectDevice() async {
    try {
      final auth = context.read<AuthService>();
      final result = await auth.checkDeviceAccount();
      if (mounted && result['has_account'] == true) {
        setState(() {
          _existingAccount = result;
          _emailCtrl.text = result['email'] ?? '';
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _checkingDevice = false);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _error = 'Enter your password');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().login(email: email, password: pass);
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

  Future<void> _googleLogin() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().googleSignIn();
      if (!mounted) return;
      NotificationService.registerAfterLogin(context);
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg != 'Google sign in cancelled') {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),
                  _logo(),
                  const SizedBox(height: 40),
                  if (!_checkingDevice)
                    _existingAccount != null ? _deviceBanner() : _welcomeText(),
                  const SizedBox(height: 32),
                  _field(_emailCtrl, 'Email address', Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(_passCtrl, 'Password', Icons.lock_outline_rounded,
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
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/forgot-password'),
                      child: const Text('Forgot password?',
                          style: TextStyle(color: _lime, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _primaryBtn('Log In', _isLoading ? null : _login),
                  const SizedBox(height: 16),
                  _orDivider(),
                  const SizedBox(height: 16),
                  _googleBtn(),
                  const SizedBox(height: 24),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          Navigator.pushReplacementNamed(context, '/register'),
                      child: RichText(
                        text: const TextSpan(
                          text: 'New here? ',
                          style:
                              TextStyle(color: Color(0xFF555555), fontSize: 14),
                          children: [
                            TextSpan(
                                text: 'Create account',
                                style: TextStyle(
                                    color: _lime, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() => Row(children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _lime,
            border: Border.all(color: _lime.withValues(alpha: 0.4), width: 2),
          ),
          child: const Icon(Icons.monetization_on_rounded,
              color: Color(0xFF0F0F0F), size: 24),
        ),
        const SizedBox(width: 12),
        const Text('Filq',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5)),
      ]);

  Widget _welcomeText() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Welcome back 👋',
              style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          SizedBox(height: 6),
          Text('Login to continue earning coins',
              style: TextStyle(color: Color(0xFF555555), fontSize: 15)),
        ],
      );

  Widget _deviceBanner() {
    final account = _existingAccount!;
    final username = account['username'] ?? '';
    final name = account['name'] ?? '';
    final avatar = account['avatar_url'] ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Welcome back 👋',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _lime.withValues(alpha: 0.25)),
          ),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _lime.withValues(alpha: 0.1),
                  border: Border.all(color: _lime.withValues(alpha: 0.3))),
              child: avatar.isNotEmpty
                  ? ClipOval(child: Image.network(avatar, fit: BoxFit.cover))
                  : Center(
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: const TextStyle(
                            color: _lime,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15)),
                    Text('@$username',
                        style: const TextStyle(color: _lime, fontSize: 13)),
                  ]),
            ),
            const Icon(Icons.device_hub, color: _lime, size: 18),
          ]),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4),
          child: Text('🔒 This device is linked to this account',
              style: TextStyle(color: Color(0xFF444444), fontSize: 12)),
        ),
      ],
    );
  }

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
          onPressed: (_isLoading || _googleLoading) ? null : _googleLogin,
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
                    _googleIcon(),
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

  // SVG-free Google G icon
  Widget _googleIcon() => Container(
        width: 20,
        height: 20,
        decoration: const BoxDecoration(shape: BoxShape.circle),
        child: CustomPaint(painter: _GoogleIconPainter()),
      );

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

// Google G icon — no asset needed
class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Background circle
    canvas.drawCircle(
      Offset(cx, cy),
      r,
      Paint()..color = Colors.white,
    );

    final colors = [
      const Color(0xFF4285F4), // blue
      const Color(0xFF34A853), // green
      const Color(0xFFFBBC05), // yellow
      const Color(0xFFEA4335), // red
    ];
    final sweeps = [90.0, 90.0, 90.0, 90.0];
    double start = -90.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.72);
    for (int i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        start * 3.14159 / 180,
        sweeps[i] * 3.14159 / 180,
        true,
        Paint()..color = colors[i],
      );
      start += sweeps[i];
    }
    // White center
    canvas.drawCircle(Offset(cx, cy), r * 0.44, Paint()..color = Colors.white);

    // Blue right bar (the crossbar of G)
    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx, cy - r * 0.13, r * 0.72, r * 0.26),
      const Radius.circular(2),
    );
    canvas.drawRRect(barRect, Paint()..color = const Color(0xFF4285F4));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
