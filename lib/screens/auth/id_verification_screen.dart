// ─────────────────────────────────────────────
//  Polyticks – Government ID Verification Screen
// ─────────────────────────────────────────────
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/models.dart';
import '../../config.dart';
import '../../core/exceptions.dart';
import '../../services/supabase_service.dart';
import '../../services/digilocker_verification_service.dart';
import '../../services/deep_link_service.dart';
import '../../services/image_compressor.dart';
import '../../theme/app_theme.dart';

class IdVerificationScreen extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onContinue;
  const IdVerificationScreen({
    super.key,
    required this.currentUser,
    required this.onContinue,
  });

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen>
    implements DeepLinkListener {
  File? _idImage;
  Uint8List? _webImage; // web: no dart:io — keep picked bytes for preview+upload
  bool _isUploading = false;
  bool _submitted = false;
  String? _errorMsg;
  int _compressedKb = 0;

  // V4.0 DigiLocker flow state.
  bool _digilockerBusy = false;
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    // B7: receive polyticks://digilocker/callback redirects.
    DeepLinkHandler.instance.register(this);
  }

  @override
  void dispose() {
    DeepLinkHandler.instance.unregister(this);
    super.dispose();
  }

  /// B7: production deep-link route. Verifies the OAuth2 `state` matches
  /// the request we started, then finalizes with the provider `code`.
  @override
  bool handleUri(Uri uri) {
    final cb = DigiLockerCallback.fromUri(uri);
    if (cb == null) return false;
    if (_pendingRequestId == null || cb.state != _pendingRequestId) {
      // CSRF guard: state mismatch — ignore foreign callbacks.
      if (mounted) {
        setState(() =>
            _errorMsg = 'Verification link could not be validated. Please retry.');
      }
      return true; // consumed: don't let other handlers see DigiLocker links
    }
    _completeDigiLocker(code: cb.code);
    return true;
  }

  final _picker = ImagePicker();

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _errorMsg = null;
      _idImage = null;
      _webImage = null;
    });

    if (kIsWeb) {
      // Web: no dart:io — keep bytes for preview + binary upload.
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _webImage = bytes;
        _compressedKb = bytes.length ~/ 1024;
      });
      return;
    }

    // Compress on-device to keep storage near $0 (<150 KB target).
    final compressed = await ImageCompressor.compressId(picked.path);
    if (!mounted) return;
    final kb = (await File(compressed).length()) ~/ 1024;
    setState(() {
      _idImage = File(compressed);
      _compressedKb = kb;
    });
  }

  Future<void> _submit() async {
    final hasImage = _idImage != null || _webImage != null;
    if (!hasImage) {
      setState(() => _errorMsg = 'Please select your government ID to continue.');
      return;
    }
    setState(() {
      _isUploading = true;
      _errorMsg = null;
    });

    try {
      await SupabaseService.instance.uploadIDVerification(
        widget.currentUser.id,
        _idImage?.path ?? '',
        webBytes: _webImage,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMsg =
            'Upload failed — please check your connection and try again.';
      });
      debugPrint('ID upload failed: $e');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isUploading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.deepNavy, Color(0xFF0D1F3C), Color(0xFF0A1628)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.navyLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.verified_user_outlined,
                          color: AppTheme.saffron, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text('Verify Your Identity',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To post on Polyticks and keep bots out, confirm your identity with a valid government ID.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF7C8DA6), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 28),

                if (_submitted)
                  _buildSubmitted()
                else ...[
                  // V4.0: primary automated path (blueprint §5 Phase 2).
                  if (DigiLockerVerificationService.isAvailable) ...[
                    _buildDigiLockerCta(),
                    const SizedBox(height: 20),
                    Row(children: [
                      const Expanded(child: Divider(color: Color(0xFF243450))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text('OR',
                            style: GoogleFonts.inter(
                                color: const Color(0xFF7C8DA6), fontSize: 12)),
                      ),
                      const Expanded(child: Divider(color: Color(0xFF243450))),
                    ]),
                    const SizedBox(height: 20),
                  ],
                  _buildUploadArea(),
                  if (_idImage != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppTheme.saffron, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          _compressedKb > 0
                              ? 'Compressed to ~$_compressedKb KB on-device'
                              : 'Image ready',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF90A4AE), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                  if (_errorMsg != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.crimson, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!,
                                style: GoogleFonts.inter(
                                    color: AppTheme.crimson, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _submit,
                    child: _isUploading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Submit for Verification'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── V4.0: automated DigiLocker verification path ────────────────────────

  Future<void> _startDigiLocker() async {
    setState(() {
      _digilockerBusy = true;
      _errorMsg = null;
    });
    try {
      final request = await DigiLockerVerificationService.startVerification();
      if (!mounted) return;
      setState(() => _pendingRequestId = request.requestId);

      final uri = Uri.tryParse(request.consentUrl);
      final opened = uri != null && await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );

      if (!opened) {
        // Instant simulated verification: feed synthetic callback through DeepLinkHandler
        await Future.delayed(const Duration(milliseconds: 600));
        DeepLinkHandler.instance.handleUri(
            DeepLinkHandler.mockDigiLockerCallback(request.requestId));
        return;
      }
      // Real flow: the provider redirects back into the app; completion is
      // triggered from the deep-link handler which calls _completeDigiLocker.
    } on PolyticksDomainException catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.userFriendlyMessage);
    } finally {
      if (mounted) setState(() => _digilockerBusy = false);
    }
  }

  /// Completes the flow. In production this is invoked by the deep-link
  /// handler carrying the authorization [code]; in simulation/mock it runs
  /// immediately with no code.
  Future<void> _completeDigiLocker({String? code}) async {
    final requestId = _pendingRequestId;
    if (requestId == null) return;
    try {
      final result = await DigiLockerVerificationService.finalizeVerification(
        requestId: requestId,
        code: code,
      );
      if (!mounted) return;
      if (result.verified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Identity verified instantly via DigiLocker 🎉')));
        widget.onContinue();
      } else {
        setState(() =>
            _errorMsg = 'DigiLocker verification failed. Please try manual upload.');
      }
    } on PolyticksDomainException catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = e.userFriendlyMessage);
    }
  }

  Widget _buildDigiLockerCta() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.saffron, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.bolt_rounded, color: AppTheme.saffron, size: 22),
            const SizedBox(width: 8),
            Text('Verify instantly with DigiLocker',
                style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Approve once in your DigiLocker app — no document upload, no waiting for a moderator.',
            style: GoogleFonts.inter(
                color: const Color(0xFF90A4AE), fontSize: 12, height: 1.5),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: _digilockerBusy ? null : _startDigiLocker,
            child: _digilockerBusy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Text(AppConfig.isDigilockerEnabled &&
                        !SupabaseService.instance.isRealSupabase
                    ? 'Verify Now (Simulated)'
                    : 'Verify Now'),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildUploadArea() {
    return InkWell(
      onTap: _isUploading ? null : _pickImage,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        height: 220,
        decoration: BoxDecoration(
          color: AppTheme.navyLight,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: _idImage == null
                  ? const Color(0xFF243450)
                  : AppTheme.saffron,
              width: 1.5),
        ),
        child: _webImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.memory(_webImage!, fit: BoxFit.cover),
              )
            : _idImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.file(_idImage!, fit: BoxFit.cover),
                  )
                : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      color: AppTheme.saffron, size: 44),
                  const SizedBox(height: 12),
                  Text('Tap to select your ID',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Driver\'s license · Voter ID · Passport',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF7C8DA6), fontSize: 12)),
                ],
              ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  Widget _buildSubmitted() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Center(child: Text('📋', style: TextStyle(fontSize: 64))),
        const SizedBox(height: 16),
        Center(
          child: Text('Verification Pending',
              style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
        const SizedBox(height: 8),
        Text(
          'Your government ID has been uploaded securely to a private store. A moderator will review it shortly. You can browse the feed in the meantime.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
              color: const Color(0xFF90A4AE), fontSize: 13, height: 1.6),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.saffron.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.saffron.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock_outline, color: AppTheme.saffron, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'For your privacy, your ID document is permanently deleted from our storage as soon as it is approved or rejected.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF90A4AE), fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: widget.onContinue,
          child: const Text('Browse Feed (Read-Only)'),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
