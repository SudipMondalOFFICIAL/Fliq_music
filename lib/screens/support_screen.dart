// support_screen.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/support_provider.dart';
import '../services/upload_service.dart';
import '../models/earning.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({Key? key}) : super(key: key);
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen>
    with WidgetsBindingObserver {
  // ← lifecycle observer
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  Timer? _pollTimer; // ← polling timer
  int _lastCount = 0;

  static const _lime = Color(0xFFE8FF6B);
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _border = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final support = context.read<SupportProvider>();
    support.ensureTicket().then((_) {
      _lastCount = support.messages.length;
      _scrollToBottom();
      _startPolling(); // ← start polling
    });
  }

  // ── App foreground/background ──────────────────────────────
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _stopPolling();
    }
  }

  // ── Polling ────────────────────────────────────────────────
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted) return;
      final support = context.read<SupportProvider>();
      await support.loadMessages();
      // Auto-scroll only if new messages arrived
      if (support.messages.length != _lastCount) {
        _lastCount = support.messages.length;
        _scrollToBottom();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final txt = _msgCtrl.text.trim();
    if (txt.isEmpty) return;
    _msgCtrl.clear();
    final ok = await context.read<SupportProvider>().sendMessage(text: txt);
    if (ok) {
      _lastCount = context.read<SupportProvider>().messages.length;
      _scrollToBottom();
    }
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    try {
      final upload = context.read<UploadService>();
      final result = await upload.uploadSupportImage(File(picked.path));
      final url = result['secure_url'] as String? ?? '';
      if (url.isNotEmpty && mounted) {
        await context.read<SupportProvider>().sendMessage(imageUrl: url);
        _lastCount = context.read<SupportProvider>().messages.length;
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _card,
        elevation: 0,
        title: const Row(children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Color(0xFFE8FF6B),
            child: Icon(Icons.headset_mic_rounded,
                color: Color(0xFF0F0F0F), size: 16),
          ),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('FilqSupport',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            Text('Typically replies within 24h',
                style: TextStyle(color: Color(0xFF555555), fontSize: 11)),
          ]),
        ]),
        actions: [
          // ── Live indicator ──────────────────────────────────
          Container(
            margin: const EdgeInsets.only(right: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _lime.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _lime.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: _lime)),
              const SizedBox(width: 4),
              const Text('Live',
                  style: TextStyle(
                      color: _lime, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF555555)),
            onPressed: () => context
                .read<SupportProvider>()
                .loadMessages()
                .then((_) => _scrollToBottom()),
          ),
        ],
      ),
      body: Consumer<SupportProvider>(
        builder: (_, support, __) {
          if (support.isLoading && support.messages.isEmpty) {
            return const Center(
                child: CircularProgressIndicator(color: _lime, strokeWidth: 2));
          }
          return Column(children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(12),
                itemCount: support.messages.length,
                itemBuilder: (_, i) => _MessageBubble(msg: support.messages[i]),
              ),
            ),
            _inputBar(support),
          ]);
        },
      ),
    );
  }

  Widget _inputBar(SupportProvider support) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: _card,
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Row(children: [
        // Image button
        GestureDetector(
          onTap: _sendImage,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _card2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.image_outlined,
                color: Color(0xFF555555), size: 18),
          ),
        ),
        const SizedBox(width: 8),
        // Text field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
            ),
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              cursorColor: _lime,
              maxLines: 4,
              minLines: 1,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 13),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Send button
        GestureDetector(
          onTap: support.isSending ? null : _send,
          child: Container(
            width: 42,
            height: 42,
            decoration:
                const BoxDecoration(color: _lime, shape: BoxShape.circle),
            child: support.isSending
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                        color: Color(0xFF0F0F0F), strokeWidth: 2))
                : const Icon(Icons.send_rounded,
                    color: Color(0xFF0F0F0F), size: 18),
          ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
//  Message Bubble
// ══════════════════════════════════════════════════════════════════

class _MessageBubble extends StatelessWidget {
  final SupportMessage msg;
  const _MessageBubble({required this.msg});

  static const _lime = Color(0xFFE8FF6B);
  static const _card = Color(0xFF141414);
  static const _border = Color(0xFF1E1E1E);

  @override
  Widget build(BuildContext context) {
    final isAdmin = msg.isAdmin;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isAdmin ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isAdmin) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: _lime,
              child:
                  Icon(Icons.support_agent, color: Color(0xFF0F0F0F), size: 14),
            ),
            const SizedBox(width: 8),
          ],
          ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isAdmin
                    ? _card
                    : const Color(0xFFE8FF6B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isAdmin ? 4 : 16),
                  bottomRight: Radius.circular(isAdmin ? 16 : 4),
                ),
                border: Border.all(
                  color: isAdmin ? _border : _lime.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.hasImage)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(msg.imageUrl,
                            height: 180, fit: BoxFit.cover),
                      ),
                    if (msg.text.isNotEmpty) ...[
                      if (msg.hasImage) const SizedBox(height: 6),
                      Text(msg.text,
                          style: TextStyle(
                            color: isAdmin ? Colors.white : _lime,
                            fontSize: 14,
                          )),
                    ],
                    const SizedBox(height: 4),
                    // Timestamp
                    Text(
                      _formatTime(msg.createdAt.toIso8601String()),
                      style: TextStyle(
                        color: isAdmin
                            ? const Color(0xFF444444)
                            : _lime.withValues(alpha: 0.5),
                        fontSize: 9,
                      ),
                    ),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}
