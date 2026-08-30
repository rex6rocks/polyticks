// ─────────────────────────────────────────────
//  Polyticks – Submit Fact Check Modal (Screen Route)
// ─────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/fact_check_service.dart';

class SubmitFactCheckModal extends StatefulWidget {
  final String postId;

  const SubmitFactCheckModal({
    super.key,
    required this.postId,
  });

  @override
  State<SubmitFactCheckModal> createState() => _SubmitFactCheckModalState();
}

class _SubmitFactCheckModalState extends State<SubmitFactCheckModal> {
  final TextEditingController _contextNoteController = TextEditingController();
  final TextEditingController _sourcesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contextNoteController.dispose();
    _sourcesController.dispose();
    super.dispose();
  }

  Future<void> _submitFactCheck() async {
    final note = _contextNoteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Context note cannot be empty')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final sources = _sourcesController.text
        .split(',')
        .map((source) => source.trim())
        .where((source) => source.isNotEmpty)
        .toList();

    try {
      await FactCheckService.instance.submitFactCheck(
        postId: widget.postId,
        contextNote: note,
        sourceLinks: sources,
      );

      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fact-check note submitted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit fact-check: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.0,
        right: 16.0,
        top: 16.0,
      ),
      child: Center(
        heightFactor: 1,
        child: SizedBox(
          width: 480,
          child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Color(0xFF4FC3F7), size: 24),
              const SizedBox(width: 8),
              Text(
                'Submit Community Note',
                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _contextNoteController,
            decoration: const InputDecoration(
              labelText: 'Context Note',
              hintText: 'Provide additional context or corrections...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            style: GoogleFonts.inter(color: Colors.white),
          ),
          const SizedBox(height: 16.0),
          TextField(
            controller: _sourcesController,
            decoration: const InputDecoration(
              labelText: 'Sources (comma-separated URLs)',
              hintText: 'https://example.com, https://another.com',
              border: OutlineInputBorder(),
            ),
            style: GoogleFonts.inter(color: Colors.white),
          ),
          const SizedBox(height: 24.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 16.0),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFactCheck,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4FC3F7),
                  foregroundColor: const Color(0xFF0F1B2D),
                  minimumSize: const Size(100, 44),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Submit'),
              ),
            ],
          ),
          const SizedBox(height: 16.0),
        ],
      ),
      ),
      ),
      ),
    );
  }
}