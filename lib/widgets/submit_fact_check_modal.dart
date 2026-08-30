// ─────────────────────────────────────────────
//  Polyticks – Submit Fact Check Modal
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fact_check_service.dart';
import '../core/exceptions.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../screens/auth/verification_status_screen.dart';

class SubmitFactCheckModal extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const SubmitFactCheckModal({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<SubmitFactCheckModal> createState() => _SubmitFactCheckModalState();
}

class _SubmitFactCheckModalState extends State<SubmitFactCheckModal> {
  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _sourceController = TextEditingController();
  final List<String> _sources = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _noteController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  Future<void> _submitFactCheck() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // If there is text in the source input field, add it automatically
      final currentSourceText = _sourceController.text.trim();
      if (currentSourceText.isNotEmpty && !_sources.contains(currentSourceText)) {
        _sources.add(currentSourceText);
      }

      await FactCheckService.instance.submitFactCheck(
        postId: widget.postId,
        contextNote: _noteController.text.trim(),
        sourceLinks: _sources,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      // Surface mapped domain exceptions (RLS unverified / rate limit) with
      // their friendly messages; everything else gets a generic failure.
      final friendly = e is PolyticksDomainException
          ? e.userFriendlyMessage
          : 'Failed to submit context note. Please try again.';
      final needsVerification = e is PolyticksDomainException &&
          (e.code == 'RLS_UNVERIFIED_ACCOUNT' ||
              friendly.toLowerCase().contains('id-verified'));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendly),
          backgroundColor: Colors.red,
          action: needsVerification
              ? SnackBarAction(
                  label: 'VIEW STATUS',
                  textColor: AppTheme.saffron,
                  onPressed: () {
                    final modalContext = context;
                    Navigator.of(modalContext).pop(); // close the modal first
                    Navigator.of(modalContext).push(
                      MaterialPageRoute(
                        builder: (_) => VerificationStatusScreen(
                          // Minimal identity — the status screen re-fetches
                          // the live state from the DB via the auth session.
                          currentUser: AppUser(
                            id: widget.currentUserId,
                            displayName: 'You',
                            role: UserRole.janta,
                            avatarColor: '#4ECDC4',
                            email: '',
                          ),
                          onChanged: () {},
                        ),
                      ),
                    );
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _addSource() {
    final text = _sourceController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        if (!_sources.contains(text)) {
          _sources.add(text);
        }
        _sourceController.clear();
      });
    }
  }

  void _removeSource(int index) {
    setState(() {
      _sources.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: 1,
      child: SizedBox(
        width: 480,
        child: Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.edit_note, color: Color(0xFF4FC3F7), size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Submit Community Context',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Context Note Field
              TextFormField(
                controller: _noteController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Context Note',
                  labelStyle: GoogleFonts.inter(color: const Color(0xFF7C8DA6)),
                  hintText: 'Provide neutral, verifiable facts or context regarding this post...',
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF546E7A)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A405A)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2A405A)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF4FC3F7)),
                  ),
                ),
                style: GoogleFonts.inter(color: Colors.white),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a context note';
                  }
                  if (value.trim().length < 10) {
                    return 'Context note must be at least 10 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Source Input & Chips
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _sourceController,
                      decoration: InputDecoration(
                        labelText: 'Add Source URL',
                        labelStyle: GoogleFonts.inter(color: const Color(0xFF7C8DA6), fontSize: 13),
                        hintText: 'https://...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF546E7A), fontSize: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF2A405A)),
                        ),
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      onSubmitted: (_) => _addSource(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addSource,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF4FC3F7), size: 28),
                    tooltip: 'Add Source',
                  ),
                ],
              ),

              if (_sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_sources.length, (index) {
                    final source = _sources[index];
                    return Chip(
                      label: Text(
                        source,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF4FC3F7)),
                      ),
                      backgroundColor: const Color(0xFF1E3054),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                      onDeleted: () => _removeSource(index),
                    );
                  }),
                ),
              ],
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: GoogleFonts.inter(color: const Color(0xFF7C8DA6))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitFactCheck,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4FC3F7),
                      foregroundColor: const Color(0xFF0F1B2D),
                      minimumSize: const Size(100, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F1B2D)),
                          )
                        : Text('Submit Note', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
        ),
      ),
    );
  }
}
