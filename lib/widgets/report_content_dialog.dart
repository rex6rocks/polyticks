//
// report_content_dialog.dart
//
// Stateful widget for reporting content via AlertDialog.
//

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:polyticks/services/report_service.dart';
import 'package:flutter_radio_group/flutter_radio_group.dart';


class ReportContentDialog extends StatefulWidget {
  final String postId;
  final String currentUserId;

  const ReportContentDialog({
    super.key,
    required this.postId,
    required this.currentUserId,
  });

  @override
  State<ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<ReportContentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedReason;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reportReasons = [
    'Illegal Content',
    'Harassment / Hate Speech',
    'Bot Activity / Spam',
    'Misinformation',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate() || _selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      await ReportService.submitReport(
        postId: widget.postId,
        userId: widget.currentUserId,
        reason: _selectedReason!,
        comment: _commentController.text.isEmpty ? null : _commentController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A2E44),
      title: Row(
        children: [
          const Icon(Icons.report_problem, color: Color(0xFFEF5350)),
          const SizedBox(width: 8),
          Text(
            'Report Content',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reason Selection
              Text(
                'Reason for Report',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              FlutterRadioGroup(
                titles: _reportReasons,
                defaultSelected: _selectedReason != null ? _reportReasons.indexOf(_selectedReason!) : null,
                onChanged: (index) {
                  if (index != null) {
                    setState(() {
                      _selectedReason = _reportReasons[index];
                    });
                  }
                },
                orientation: RGOrientation.VERTICAL,
                activeColor: const Color(0xFFEF5350),
                titleStyle: GoogleFonts.inter(color: Colors.white),
              ),
              const SizedBox(height: 16),

              // Comment Field
              TextFormField(
                controller: _commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Additional Comments (Optional)',
                  labelStyle: GoogleFonts.inter(color: const Color(0xFF7C8DA6)),
                  hintText: 'Provide more details...',
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
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.inter(color: const Color(0xFF7C8DA6)),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF5350),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  'Submit Report',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ],
    );
  }
}