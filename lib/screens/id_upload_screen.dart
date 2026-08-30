// ─────────────────────────────────────────────
//  Polyticks – ID Upload Screen
// ─────────────────────────────────────────────
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../services/id_verification_service.dart';
import '../services/image_compressor.dart';
import '../theme/app_theme.dart';
import '../widgets/interactive_widgets.dart' show IDUploadPlaceholder;
import '../widgets/common_widgets.dart' show PrimaryButton;

class IdUploadScreen extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onContinue;

  const IdUploadScreen({
    super.key,
    required this.currentUser,
    required this.onContinue,
  });

  @override
  State<IdUploadScreen> createState() => _IdUploadScreenState();
}

class _IdUploadScreenState extends State<IdUploadScreen> {
  File? _idImage;
  bool _isUploading = false;
  bool _submitted = false;
  String? _errorMsg;
  int _compressedKb = 0;

  final _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() {
      _errorMsg = null;
      _idImage = File(picked.path);
    });

    try {
      final compressedPath = await ImageCompressor.compressId(picked.path);
      if (!mounted) return;
      final kb = (await File(compressedPath).length()) ~/ 1024;
      setState(() {
        _idImage = File(compressedPath);
        _compressedKb = kb;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Failed to compress image: $e';
      });
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navyLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.saffron),
              title: Text('Take Photo', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.saffron),
              title: Text('Choose from Gallery', style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_idImage == null) {
      setState(() => _errorMsg = 'Please select your government ID to continue.');
      return;
    }
    setState(() {
      _isUploading = true;
      _errorMsg = null;
    });

    try {
      await IDVerificationService.processIDVerification(
        widget.currentUser.id,
        _idImage!,
      );

      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _submitted = true;
      });

      _showConfirmationDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMsg = 'Upload failed: $e';
      });
    }
  }

  void _showConfirmationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppTheme.saffron, size: 28),
            const SizedBox(width: 12),
            Text('ID Submitted', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          'Your government ID has been uploaded securely and is pending review by moderators.',
          style: GoogleFonts.inter(color: const Color(0xFF90A4AE), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onContinue();
            },
            child: const Text('Continue', style: TextStyle(color: AppTheme.saffron)),
          ),
        ],
      ),
    );
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
                    Text('Government ID Verification',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To prevent bots and maintain political discourse integrity, please upload a valid government-issued photo ID (Driver\'s License, Voter ID, or Passport).',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF90A4AE), fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 28),
                if (_submitted)
                  _buildSubmitted()
                else ...[
                  IDUploadPlaceholder(
                    onTap: _isUploading ? null : _showImageSourceDialog,
                    imagePath: _idImage?.path,
                  ),
                  if (_compressedKb > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Compressed size: $_compressedKb KB (< 150 KB target)',
                      style: GoogleFonts.inter(
                          color: const Color(0xFF4CAF50), fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: GoogleFonts.inter(color: Colors.red[200], fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  const SizedBox(height: 8),
                  PrimaryButton(
                    label: 'Submit for Review',
                    onPressed: _submit,
                    isLoading: _isUploading,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
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
        PrimaryButton(
          label: 'Browse Feed (Read-Only)',
          onPressed: widget.onContinue,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }
}
