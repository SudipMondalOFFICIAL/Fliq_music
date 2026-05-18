// splash_screen.dart — with Force Update support
// White background, black "Filq" title, light tagline, single soft scale+fade effect

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../providers/app_config_provider.dart';
import '../models/app_banner.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _dotCtrl;

  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _dotOpacity;

  SplashConfig _cfg = const SplashConfig();
  bool _maintenance = false;
  String _maintenanceMsg = 'App is under maintenance. Please try again later.';

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

    _logoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _textCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic),
    );
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoCtrl, curve: Curves.easeIn),
    );
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeIn),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic),
    );
    _dotOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dotCtrl, curve: Curves.easeIn),
    );

    _start();
  }

  Future<void> _start() async {
    try {
      final cfg = context.read<AppConfigProvider>();
      await cfg.load();
      if (mounted) {
        setState(() {
          _cfg = cfg.splashConfig;
          _maintenance = cfg.maintenance;
          _maintenanceMsg = cfg.maintenanceMsg;
        });
      }
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 180));
    await _logoCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 100));
    await _textCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 80));
    _dotCtrl.forward();
    await Future.delayed(const Duration(milliseconds: 950));

    _navigate();
  }

  Future<void> _navigate() async {
    if (!mounted) return;

    // 1️⃣ Force update check — highest priority
    final cfg = context.read<AppConfigProvider>();
    if (cfg.forceUpdate && cfg.forceUpdateVersion.isNotEmpty) {
      final info = await PackageInfo.fromPlatform();
      final current = info.version; // e.g. "1.0.0"
      final required = cfg.forceUpdateVersion; // e.g. "1.1.0"
      if (_isOutdated(current, required)) {
        _showForceUpdate(cfg.updateUrl, cfg.forceUpdateMsg);
        return;
      }
    }

    // 2️⃣ Maintenance check
    if (_maintenance) {
      _showMaintenance();
      return;
    }

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    final auth = context.read<AuthService>();
    Navigator.of(context)
        .pushReplacementNamed(auth.isLoggedIn() ? '/home' : '/login');
  }

  /// Returns true if [current] is older than [required].
  /// Compares semver parts: "1.0.0" < "1.1.0" → true
  bool _isOutdated(String current, String required) {
    try {
      final cur = current.split('.').map(int.parse).toList();
      final req = required.split('.').map(int.parse).toList();
      for (int i = 0; i < req.length; i++) {
        final c = i < cur.length ? cur[i] : 0;
        if (c < req[i]) return true;
        if (c > req[i]) return false;
      }
      return false; // equal version → not outdated
    } catch (_) {
      return false;
    }
  }

  void _showForceUpdate(String url, String msg) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => WillPopScope(
        onWillPop: () async => false, // back button disabled
        child: AlertDialog(
          backgroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Row(
            children: [
              Text('🚀 ', style: TextStyle(fontSize: 22)),
              Text(
                'Update Required',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          content: Text(
            msg,
            style: const TextStyle(
              color: Color(0xFF555555),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => _launchUpdate(url),
                child: const Text(
                  'Update Now',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUpdate(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showMaintenance() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('🔧 Maintenance',
            style: TextStyle(color: Color(0xFF111111))),
        content: Text(_maintenanceMsg,
            style: const TextStyle(color: Color(0xFF666666))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logoCtrl.reset();
              _textCtrl.reset();
              _dotCtrl.reset();
              _start();
            },
            child:
                const Text('Retry', style: TextStyle(color: Color(0xFF111111))),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _logoCtrl,
              builder: (_, __) => Transform.scale(
                scale: _logoScale.value,
                child: Opacity(
                  opacity: _logoOpacity.value,
                  child: const _LogoMark(),
                ),
              ),
            ),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _textCtrl,
              builder: (_, __) => SlideTransition(
                position: _textSlide,
                child: Opacity(
                  opacity: _textOpacity.value,
                  child: Column(children: [
                    const Text(
                      'Filq',
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111111),
                        letterSpacing: -1.5,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _cfg.tagline,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFFAAAAAA),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 72),
            AnimatedBuilder(
              animation: _dotCtrl,
              builder: (_, __) => Opacity(
                opacity: _dotOpacity.value,
                child: const _MinimalLoader(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────

class _LogoMark extends StatelessWidget {
  const _LogoMark();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF111111),
      ),
      child: const Center(
        child: Text(
          'F',
          style: TextStyle(
            fontSize: 40,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ── Loader ────────────────────────────────────────────────────────

class _MinimalLoader extends StatefulWidget {
  const _MinimalLoader();
  @override
  State<_MinimalLoader> createState() => _MinimalLoaderState();
}

class _MinimalLoaderState extends State<_MinimalLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_ctrl.value - i * 0.22).clamp(0.0, 1.0);
          final alpha = phase < 0.5 ? phase * 2 : (1 - phase) * 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color.fromRGBO(
                17,
                17,
                17,
                (0.12 + alpha * 0.65).clamp(0.0, 1.0),
              ),
            ),
          );
        }),
      ),
    );
  }
}
