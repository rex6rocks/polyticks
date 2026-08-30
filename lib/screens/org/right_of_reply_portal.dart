// ─────────────────────────────────────────────
//  Polyticks V4.0 – Right-of-Reply Portal (B11)
// ─────────────────────────────────────────────
//
//  Paid-org portal: lists posts authored by the org that are under fact-check
//  scrutiny (under_review / disputed) and lets the org publish, revise, or
//  withdraw an official statement. Tier-gated (Gold/Platinum) — enforced by
//  RLS on `right_of_replies` (migration 10) and mirrored as UX here.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/exceptions.dart';
import '../../models/models.dart';
import '../../services/right_of_reply_service.dart';
import '../../theme/app_theme.dart';

class RightOfReplyPortal extends StatefulWidget {
  final AppUser currentUser;
  const RightOfReplyPortal({super.key, required this.currentUser});

  @override
  State<RightOfReplyPortal> createState() => _RightOfReplyPortalState();
}

class _RightOfReplyPortalState extends State<RightOfReplyPortal> {
  List<DisputedPost> _disputes = [];
  bool _loading = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final disputes = await RightOfReplyService.fetchOpenDisputes(
        widget.currentUser.id);
    if (!mounted) return;
    setState(() {
      _disputes = disputes;
      _loading = false;
    });
  }

  Future<void> _openComposer(DisputedPost dispute) async {
    final controller = TextEditingController();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navyCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Official Statement',
              style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Published under your organization\u2019s verified identity. '
            'Visible to everyone on the post.',
            style: GoogleFonts.inter(color: Color(0xFF7C8DA6), fontSize: 12),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            maxLines: 5,
            maxLength: 2000,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText:
                  'Provide your official response with sources where possible…',
              hintStyle:
                  GoogleFonts.inter(color: Color(0xFF64748B), fontSize: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Publish'),
            ),
          ]),
        ]),
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await RightOfReplyService.submitReply(
        orgId: widget.currentUser.id,
        postId: dispute.post.id,
        statement: controller.text,
      );
      if (!mounted) return;
      setState(() => _message = 'Official statement published.');
      await _load();
    } on PolyticksDomainException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.userFriendlyMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(DisputedPost dispute) async {
    setState(() => _busy = true);
    try {
      await RightOfReplyService.withdrawReply(
        orgId: widget.currentUser.id,
        postId: dispute.post.id,
      );
      if (!mounted) return;
      setState(() => _message = 'Statement withdrawn.');
      await _load();
    } on PolyticksDomainException catch (e) {
      if (!mounted) return;
      setState(() => _message = e.userFriendlyMessage);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        foregroundColor: Colors.white,
        title: Text('Right of Reply',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.saffron))
          : RefreshIndicator(
              color: AppTheme.saffron,
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(20), children: [
                Text(
                  'Respond officially to fact-checks on your organization\u2019s '
                  'content. Statements appear publicly beside the community note.',
                  style: GoogleFonts.inter(
                      color: const Color(0xFF7C8DA6), fontSize: 12.5, height: 1.6),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 10),
                  Text(_message!,
                      style: GoogleFonts.inter(
                          color: AppTheme.saffron, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                if (_disputes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 60),
                    child: Column(children: [
                      const Icon(Icons.verified_outlined,
                          color: Color(0xFF7C8DA6), size: 52),
                      const SizedBox(height: 12),
                      Text('No open fact-checks',
                          style: GoogleFonts.inter(
                              color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        'Posts flagged by the community will appear here.',
                        style: GoogleFonts.inter(
                            color: const Color(0xFF7C8DA6), fontSize: 12.5),
                      ),
                    ]),
                  )
                else
                  ..._disputes.map((d) => _disputeCard(d)),
              ]),
            ).animate().fadeIn(duration: 250.ms),
    );
  }

  Widget _disputeCard(DisputedPost d) {
    final isDisputed = d.dbStatus == 'disputed';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDisputed
                ? AppTheme.crimson.withValues(alpha: 0.5)
                : const Color(0xFF243450)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (isDisputed ? AppTheme.crimson : Colors.orangeAccent)
                  .withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isDisputed ? 'DISPUTED' : 'UNDER REVIEW',
                style: GoogleFonts.inter(
                    color: isDisputed ? AppTheme.crimson : Colors.orangeAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5)),
          ),
          if (d.hasReply) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle_rounded,
                color: Colors.greenAccent.withValues(alpha: 0.8), size: 15),
            const SizedBox(width: 4),
            Text('Statement published',
                style: GoogleFonts.inter(
                    color: Colors.greenAccent, fontSize: 11)),
          ],
        ]),
        const SizedBox(height: 10),
        Text(d.post.content,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 13.5, height: 1.5)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: ElevatedButton(
              onPressed: _busy ? null : () => _openComposer(d),
              child: Text(d.hasReply ? 'Revise Statement' : 'Respond Officially'),
            ),
          ),
          if (d.hasReply) ...[
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _withdraw(d),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.crimson,
                  side: BorderSide(color: AppTheme.crimson.withValues(alpha: 0.6))),
              child: const Text('Withdraw'),
            ),
          ],
        ]),
      ]),
    );
  }
}
