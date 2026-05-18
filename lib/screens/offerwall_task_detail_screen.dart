import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'campaign_webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../providers/earn_provider.dart';
import '../services/api_service.dart';

class OfferwallTaskDetailScreen extends StatefulWidget {
  final String taskId;
  const OfferwallTaskDetailScreen({Key? key, required this.taskId})
      : super(key: key);

  @override
  State<OfferwallTaskDetailScreen> createState() =>
      _OfferwallTaskDetailScreenState();
}

class _OfferwallTaskDetailScreenState extends State<OfferwallTaskDetailScreen> {
  static const _bg = Color(0xFF0F0F0F);
  static const _card = Color(0xFF141414);
  static const _card2 = Color(0xFF1A1A1A);
  static const _lime = Color(0xFFE8FF6B);
  static const _border = Color(0xFF1E1E1E);

  Map<String, dynamic>? _task;
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getOfferwallTask(widget.taskId);
      if (mounted)
        setState(() {
          _task = data;
          _loading = false;
        });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _steps {
    final raw = _task?['steps'];
    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }

  String? get _submissionStatus =>
      (_task?['submission'] as Map?)?.cast<String, dynamic>()?['status'];

  // ── Open campaign link → "Open App" button ─────────────────
  Future<void> _openCampaignLink() async {
    final link = _task?['campaign_link'] as String?;
    if (link == null || link.isEmpty) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CampaignWebViewScreen(
          campaignUrl: link,
          trackingUrl: _task?['tracking_link'] as String?,
          taskTitle: _task?['title'] as String? ?? 'Campaign',
        ),
      ),
    );
  }

  // ── Open tracking link → shown below steps ─────────────────
  Future<void> _openTrackingLink() async {
    final link = _task?['tracking_link'] as String?;
    if (link == null || link.isEmpty) return;
    final uri = Uri.tryParse(link);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pickAndSubmitScreenshot() async {
    final picker = ImagePicker();
    XFile? picked;

    await showModalBottomSheet(
      context: context,
      backgroundColor: _card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _border, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: _lime),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                picked = await picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 85,
                    maxWidth: 1920);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: _lime),
              title: const Text('Take a Screenshot / Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () async {
                picked = await picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 85,
                    maxWidth: 1920);
                if (context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final api = context.read<ApiService>();

      // 1. Get Cloudinary signature from backend
      final sig = await api.getUploadSignature(folder: 'offerwall');
      final cloudName = sig['cloud_name'] as String;
      final apiKey = sig['api_key'] as String;
      final signature = sig['signature'] as String;
      final timestamp = sig['timestamp'].toString();
      final folder = sig['folder'] as String? ?? 'offerwall';

      // 2. Upload to Cloudinary
      final uploadUri =
          Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final req = http.MultipartRequest('POST', uploadUri)
        ..fields['api_key'] = apiKey
        ..fields['signature'] = signature
        ..fields['timestamp'] = timestamp
        ..fields['folder'] = folder
        ..files.add(await http.MultipartFile.fromPath('file', picked!.path));

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();

      if (streamed.statusCode != 200) {
        throw Exception('Image upload failed. Please try again.');
      }

      final uploadResult = jsonDecode(body) as Map<String, dynamic>;
      final screenshotUrl = uploadResult['secure_url'] as String;
      final publicId = uploadResult['public_id'] as String;

      // 3. Submit to backend
      final result = await context.read<EarnProvider>().submitTask(
            taskId: widget.taskId,
            screenshotUrl: screenshotUrl,
            screenshotPublicId: publicId,
          );

      if (!mounted) return;

      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text(
            '✅ Submission sent! We\'ll review it shortly.',
            style: TextStyle(
                color: Color(0xFF0F0F0F), fontWeight: FontWeight.w600),
          ),
          backgroundColor: _lime,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        await _load();
      } else {
        final err = context.read<EarnProvider>().error ?? 'Submission failed';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F0F0F),
        body:
            Center(child: CircularProgressIndicator(color: Color(0xFFE8FF6B))),
      );
    }
    if (_error != null || _task == null) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(backgroundColor: _bg, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: Colors.white30, size: 48),
                const SizedBox(height: 12),
                Text(_error ?? 'Task not found',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 15)),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _lime),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Retry', style: TextStyle(color: _lime)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final task = _task!;
    final steps = _steps;
    final status = _submissionStatus;
    final rating = (task['rating'] as num?)?.toDouble() ?? 5.0;
    final coins = task['coins_reward'] ?? 0;
    final hasCampaignLink =
        (task['campaign_link'] as String?)?.isNotEmpty == true; // ← changed
    final hasTrackingLink =
        (task['tracking_link'] as String?)?.isNotEmpty == true; // ← for steps
    final hasVideo = (task['steps_video_url'] as String?)?.isNotEmpty == true;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(task['title'] ?? '',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16)),
          // ← Share button সরানো হয়েছে (actions নেই)
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── App info card ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _card2,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _border),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: (task['app_image_url'] as String?)?.isNotEmpty ==
                            true
                        ? Image.network(task['app_image_url'],
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(Icons.apps,
                                color: Color(0xFF555555), size: 36))
                        : const Icon(Icons.apps,
                            color: Color(0xFF555555), size: 36),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task['title'] ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16)),
                        const SizedBox(height: 4),
                        Row(children: [
                          ...List.generate(
                              5,
                              (i) => Icon(
                                    i < rating.floor()
                                        ? Icons.star_rounded
                                        : (i < rating
                                            ? Icons.star_half_rounded
                                            : Icons.star_outline_rounded),
                                    color: Colors.amber,
                                    size: 14,
                                  )),
                          const SizedBox(width: 4),
                          Text(rating.toStringAsFixed(1),
                              style: const TextStyle(
                                  color: Color(0xFF555555), fontSize: 12)),
                        ]),
                        const SizedBox(height: 4),
                        Text(task['category'] ?? 'app',
                            style: const TextStyle(
                                color: Color(0xFF555555), fontSize: 12)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _lime.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _lime.withValues(alpha: 0.3)),
                    ),
                    child: Column(children: [
                      Text('$coins',
                          style: const TextStyle(
                              color: _lime,
                              fontWeight: FontWeight.w800,
                              fontSize: 18)),
                      const Text('coins',
                          style: TextStyle(color: _lime, fontSize: 10)),
                    ]),
                  ),
                ]),
              ),

              // ── Description ────────────────────────────────────
              if ((task['description'] as String?)?.isNotEmpty == true) ...[
                const SizedBox(height: 14),
                Text(task['description'],
                    style: const TextStyle(
                        color: Color(0xFF888888), fontSize: 14, height: 1.5)),
              ],

              // ── Steps ──────────────────────────────────────────
              if (steps.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('How to complete',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15)),
                const SizedBox(height: 10),
                ...steps.asMap().entries.map((e) {
                  final idx = e.key;
                  final step = e.value;
                  final stepVideo = step['video_url'] as String?;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _lime.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: _lime.withValues(alpha: 0.3)),
                          ),
                          child: Center(
                            child: Text('${idx + 1}',
                                style: const TextStyle(
                                    color: _lime,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(step['text'] ?? '',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      height: 1.4)),
                              if (stepVideo != null &&
                                  stepVideo.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: () async {
                                    final uri = Uri.tryParse(stepVideo);
                                    if (uri != null) {
                                      await launchUrl(uri,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: Colors.blue
                                              .withValues(alpha: 0.3)),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.play_circle_outline,
                                            color: Colors.lightBlue, size: 14),
                                        SizedBox(width: 4),
                                        Text('Watch step video',
                                            style: TextStyle(
                                                color: Colors.lightBlue,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],

              // ── Tracking link (steps-এর নিচে) ─────────────────
              if (hasTrackingLink) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openTrackingLink,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _lime.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _lime.withValues(alpha: 0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.track_changes_rounded, color: _lime, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('View tracking link',
                            style: TextStyle(
                                color: _lime,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      Icon(Icons.open_in_new, color: _lime, size: 14),
                    ]),
                  ),
                ),
              ],

              // ── Global step video ──────────────────────────────
              if (hasVideo) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () async {
                    final uri = Uri.tryParse(task['steps_video_url'] as String);
                    if (uri != null) {
                      await launchUrl(uri,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.play_circle_fill_rounded,
                          color: Colors.lightBlue, size: 22),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Watch full tutorial video',
                            style: TextStyle(
                                color: Colors.lightBlue,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                      ),
                      Icon(Icons.open_in_new,
                          color: Colors.lightBlue, size: 14),
                    ]),
                  ),
                ),
              ],

              // ── Submission status banner ───────────────────────
              if (status != null) ...[
                const SizedBox(height: 14),
                _StatusBanner(
                  status: status,
                  rejectReason: (_task?['submission'] as Map?)
                      ?.cast<String, dynamic>()?['reject_reason'],
                ),
              ],
            ],
          ),
        ),

        // ── Bottom action buttons ──────────────────────────────
        bottomNavigationBar: Container(
          padding: EdgeInsets.fromLTRB(
              16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
          decoration: BoxDecoration(
            color: _bg,
            border: Border(top: BorderSide(color: _border)),
          ),
          child: Row(children: [
            // ← campaign_link দিয়ে "Open App" button
            if (hasCampaignLink)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _openCampaignLink,
                  icon: const Icon(Icons.open_in_new, size: 16, color: _lime),
                  label: const Text('Open App',
                      style:
                          TextStyle(color: _lime, fontWeight: FontWeight.w700)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _lime.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            if (hasCampaignLink) const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: _SubmitButton(
                status: status,
                uploading: _uploading,
                onTap: status == 'approved' ? null : _pickAndSubmitScreenshot,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Status banner ────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final String status;
  final String? rejectReason;
  const _StatusBanner({required this.status, this.rejectReason});

  @override
  Widget build(BuildContext context) {
    Color color;
    String message;
    IconData icon;
    switch (status) {
      case 'approved':
        color = Colors.greenAccent;
        message = '✓ Task approved! Coins have been credited.';
        icon = Icons.check_circle_outline;
        break;
      case 'pending':
        color = Colors.orangeAccent;
        message = '⏳ Submission under review. We\'ll notify you soon!';
        icon = Icons.hourglass_top_rounded;
        break;
      default:
        color = Colors.redAccent;
        message = (rejectReason?.isNotEmpty == true)
            ? '✕ Rejected: $rejectReason'
            : '✕ Submission rejected. Please try again.';
        icon = Icons.cancel_outlined;
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13))),
      ]),
    );
  }
}

// ── Submit button ────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final String? status;
  final bool uploading;
  final VoidCallback? onTap;
  const _SubmitButton(
      {required this.status, required this.uploading, this.onTap});

  static const _lime = Color(0xFFE8FF6B);

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color bg;
    final bool disabled;

    if (uploading) {
      label = 'Uploading...';
      bg = _lime.withValues(alpha: 0.5);
      disabled = true;
    } else if (status == 'approved') {
      label = '✓ Completed';
      bg = Colors.greenAccent.withValues(alpha: 0.3);
      disabled = true;
    } else if (status == 'pending') {
      label = '⏳ Under Review';
      bg = Colors.orangeAccent.withValues(alpha: 0.3);
      disabled = true;
    } else {
      label = 'Submit Screenshot';
      bg = _lime;
      disabled = onTap == null;
    }

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: (disabled && status != 'approved' && status != 'pending')
            ? 0.5
            : 1.0,
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Color(0xFF0F0F0F), strokeWidth: 2))
                : Text(label,
                    style: TextStyle(
                        color: (status == 'approved' || status == 'pending')
                            ? Colors.white
                            : const Color(0xFF0F0F0F),
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
          ),
        ),
      ),
    );
  }
}
