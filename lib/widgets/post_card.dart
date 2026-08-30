// ─────────────────────────────────────────────
//  Polyticks – Post Card Widget
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../services/report_service.dart';
import 'org_tier_badge.dart';
import 'official_reply_banner.dart';
import 'community_notes_section.dart';
import '../widgets/submit_fact_check_modal.dart';
import 'shared_widgets.dart';
import 'poll_widget.dart';
import '../screens/post/post_detail_screen.dart';
import '../screens/party/party_profile_screen.dart';
import '../screens/auth/verification_status_screen.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final AppUser currentUser;
  final VoidCallback? onPartyTap;
  final Poll? poll;

  const PostCard({
    super.key,
    required this.post,
    required this.currentUser,
    this.onPartyTap,
    this.poll,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _showComments = false;
  final _commentCtrl = TextEditingController();
  late List<Comment> _comments;

  @override
  void initState() {
    super.initState();
    _comments = commentsForPost(widget.post.id);
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  bool get _canInteract {
    final u = widget.currentUser;
    if (u.isGuest) return false;
    if (u.role == UserRole.janta && u.verificationStatus != 'approved' && !u.isVerified) {
      return false;
    }
    return true;
  }

  bool get _canLike {
    if (!_canInteract) return false;
    final u = widget.currentUser;
    if (u.role == UserRole.janta) return true;
    if (u.role == UserRole.party) return false;
    if (u.role == UserRole.partyMember) {
      // Members may like/dislike any party's posts (polls remain gated).
      return true;
    }
    return false;
  }

  bool get _canComment {
    if (!_canInteract) return false;
    final u = widget.currentUser;
    if (u.role == UserRole.janta) return true;
    if (u.role == UserRole.party) return false;
    if (u.role == UserRole.partyMember) {
      // Members may comment on any party's posts (polls remain gated).
      return true;
    }
    return false;
  }

  void _toggleInteraction(InteractionType type) {
    if (!_canLike) return;
    setState(() {
      if (widget.post.interaction == type) {
        widget.post.interaction = InteractionType.none;
      } else {
        widget.post.interaction = type;
      }
    });
  }

  /// Opens the account verification status screen (re-apply on rejection).
  void _openVerificationStatusScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationStatusScreen(
          currentUser: widget.currentUser,
          onChanged: () {},
        ),
      ),
    );
  }

  /// Opens the party profile page when the party avatar/name in the post
  /// header is tapped. Falls back to internal navigation when the parent
  /// doesn't supply an [PostCard.onPartyTap] callback.
  void _openPartyPage() {
    if (widget.onPartyTap != null) {
      widget.onPartyTap!();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartyProfileScreen(
          partyId: widget.post.partyId,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _showPostOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_note, color: AppTheme.saffron),
              title: Text(
                'Add Community Note / Context',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Help fact-check or provide verified sources',
                style: GoogleFonts.inter(color: const Color(0xFF7C8DA6), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                // A2 gate: only ID-verified citizens may submit Community
                // Notes. Unverified users get a verification prompt instead.
                final user = widget.currentUser;
                final verified = user.isVerified ||
                    user.role == UserRole.admin ||
                    user.role == UserRole.partyMember;
                if (!verified) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Only ID-verified citizens can add Community Notes. '
                        'Tap to check your verification status.',
                      ),
                      action: SnackBarAction(
                        label: 'VIEW STATUS',
                        textColor: AppTheme.saffron,
                        onPressed: () => _openVerificationStatusScreen(),
                      ),
                    ),
                  );
                  return;
                }
                showDialog(
                  context: context,
                  // Dialog instead of bottom sheet: the sheet layout delegate
                  // forces child width == incoming maxWidth and crashes when the
                  // web view reports unbounded width.
                  builder: (_) => Dialog(
                    backgroundColor: const Color(0xFF152342),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: SubmitFactCheckModal(
                      postId: widget.post.id,
                      currentUserId: widget.currentUser.id,
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppTheme.crimson),
              title: Text(
                'Report Post',
                style: GoogleFonts.inter(color: AppTheme.crimson, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Flag for misinformation, harassment, or policy violation',
                style: GoogleFonts.inter(color: const Color(0xFF7C8DA6), fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showReportDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog() {
    String selectedReason = 'Misinformation / Fake News';
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: AppTheme.navyCard,
          title: Text(
            'Report Content',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                dropdownColor: AppTheme.navyLight,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.navyLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'Misinformation / Fake News', child: Text('Misinformation / Fake News')),
                  DropdownMenuItem(value: 'Hate Speech or Harassment', child: Text('Hate Speech or Harassment')),
                  DropdownMenuItem(value: 'Impersonation or Bot Activity', child: Text('Impersonation or Bot Activity')),
                  DropdownMenuItem(value: 'Illegal / Dangerous Content', child: Text('Illegal / Dangerous Content')),
                ],
                onChanged: (val) => setDlgState(() => selectedReason = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Additional details (optional)...',
                  hintStyle: GoogleFonts.inter(color: Colors.grey, fontSize: 12),
                  filled: true,
                  fillColor: AppTheme.navyLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await ReportService.submitReport(
                  postId: widget.post.id,
                  userId: widget.currentUser.id,
                  reason: selectedReason,
                  comment: commentCtrl.text.trim(),
                );
                navigator.pop();
                if (!mounted) return;
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Report submitted for moderator review.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.crimson),
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _editPost() {
    final editCtrl = TextEditingController(text: widget.post.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title:
            Text('Edit Post', style: GoogleFonts.inter(color: Colors.white)),
        content: TextField(
          controller: editCtrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Edit your post...',
            filled: true,
            fillColor: AppTheme.navyLight,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              if (editCtrl.text.trim().isNotEmpty &&
                  editCtrl.text != widget.post.content) {
                setState(() {
                  widget.post.editHistory.add(widget.post.content);
                  widget.post.content = editCtrl.text.trim();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _submitComment() {
    if (_commentCtrl.text.trim().isEmpty) return;
    setState(() {
      final newComment = Comment(
        id: 'new_${DateTime.now().millisecondsSinceEpoch}',
        postId: widget.post.id,
        authorId: widget.currentUser.id,
        content: _commentCtrl.text.trim(),
        createdAt: DateTime.now(),
      );
      _comments.add(newComment);
      mockComments.add(newComment);
      _commentCtrl.clear();
    });
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final party = partyById(widget.post.partyId);

    final isTagged = widget.post.type == PostType.memberTagged;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
            post: widget.post,
            currentUser: widget.currentUser,
          ),
        ),
      ),
      child: Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openPartyPage,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.navyLight,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFF1E3054), width: 1),
                    ),
                    child: Center(
                      child: Text(
                          party?.logoEmoji ?? widget.post.imageEmoji ?? '👤',
                          style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      GestureDetector(
                        onTap: _openPartyPage,
                        child: Text(
                          party?.name ?? 'Citizen Voice (Janta)',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // V4.0 B12: paid-org verification badge (Gold/Platinum).
                      if (party != null) ...[
                        const SizedBox(width: 6),
                        FutureOrgTierBadge(orgId: party.id, compact: true),
                      ],
                      Row(
                        children: [
                          Text(
                            _timeAgo(widget.post.createdAt),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                          if (isTagged) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.memberColor
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '👥 Members',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.memberColor,
                                ),
                              ),
                            ),
                          ],
                          if (widget.post.editHistory.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AppTheme.navyCard,
                                    title: Text('Edit History',
                                        style: GoogleFonts.inter(
                                            color: Colors.white)),
                                    content: SizedBox(
                                      width: double.maxFinite,
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount:
                                            widget.post.editHistory.length,
                                        itemBuilder: (ctx, i) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 12),
                                          child: Text(
                                            widget.post.editHistory[i],
                                            style: GoogleFonts.inter(
                                                color: Colors.white70,
                                                fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    actions: [
                                      TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: const Text('Close')),
                                    ],
                                  ),
                                );
                              },
                              child: Text(
                                '(Edited)',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppTheme.saffron,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (party != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.partyColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      party.shortName,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.partyColor,
                      ),
                    ),
                  ),
                if (widget.currentUser.role == UserRole.party &&
                    widget.post.partyId == widget.currentUser.partyId)
                  IconButton(
                    icon: const Icon(Icons.edit_rounded,
                        color: Colors.grey, size: 18),
                    onPressed: _editPost,
                  ),
                IconButton(
                  icon: const Icon(Icons.more_horiz,
                      color: Colors.white60, size: 20),
                  onPressed: _showPostOptions,
                ),
              ],
            ),
          ),

          // ── V4.0 B11: published Right-of-Reply statement ────────
          if (party != null &&
              (widget.post.factCheckStatus == FactCheckStatus.underReview ||
                  widget.post.factCheckStatus == FactCheckStatus.disputed))
            OfficialReplyBanner(postId: widget.post.id),

          // ── Fact-Check / Community Note Warnings ───────
          if (widget.post.factCheckStatus == FactCheckStatus.underReview ||
              widget.post.factCheckStatus == FactCheckStatus.verifiedContext)
            CommunityNotesSection(
              postId: widget.post.id,
              viewerCanVote: widget.currentUser.isVerified ||
                  widget.currentUser.role == UserRole.admin,
            ),
          if (widget.post.factCheckStatus == FactCheckStatus.underReview)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE65100).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9800), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This post is currently under review for factual accuracy.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFFFFB74D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (widget.post.factCheckStatus == FactCheckStatus.verifiedContext ||
              widget.post.factCheckContext != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF42A5F5).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF64B5F6), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Community Note',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF90CAF9),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.post.factCheckContext ?? 'Additional context added by verified contributors.',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white, height: 1.4),
                  ),
                  if (widget.post.factCheckSources.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Sources: ${widget.post.factCheckSources.join(', ')}',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF90CAF9)),
                    ),
                  ],
                ],
              ),
            ),

          // ── Content ──────────────────────────────────
          if (widget.post.imageEmoji != null)
            Container(
              width: double.infinity,
              height: 140,
              color: AppTheme.navyLight,
              child: Center(
                child: Text(widget.post.imageEmoji!,
                    style: const TextStyle(fontSize: 72)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              widget.post.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
                height: 1.55,
              ),
            ),
          ),

          if (widget.poll != null) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PollWidget(
                poll: widget.poll!,
                currentUser: widget.currentUser,
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: Color(0xFF1E3054)),

          // ── Actions ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Like
                _ActionButton(
                  icon: widget.post.interaction == InteractionType.like
                      ? Icons.thumb_up
                      : Icons.thumb_up_alt_outlined,
                  label: _formatCount(widget.post.likeCount +
                      (widget.post.interaction == InteractionType.like
                          ? 1
                          : 0)),
                  color: widget.post.interaction == InteractionType.like
                      ? AppTheme.emerald
                      : const Color(0xFF64748B),
                  enabled: _canLike,
                  onTap: () => _toggleInteraction(InteractionType.like),
                ),
                // Dislike
                _ActionButton(
                  icon: widget.post.interaction == InteractionType.dislike
                      ? Icons.thumb_down
                      : Icons.thumb_down_alt_outlined,
                  label: _formatCount(widget.post.dislikeCount +
                      (widget.post.interaction == InteractionType.dislike
                          ? 1
                          : 0)),
                  color: widget.post.interaction == InteractionType.dislike
                      ? AppTheme.crimson
                      : const Color(0xFF64748B),
                  enabled: _canLike,
                  onTap: () => _toggleInteraction(InteractionType.dislike),
                ),
                // Comment
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label:
                      _formatCount(widget.post.commentCount + _comments.length),
                  color: const Color(0xFF64748B),
                  enabled:
                      _canComment || widget.currentUser.role == UserRole.janta,
                  onTap: () => setState(() => _showComments = !_showComments),
                ),
                // Share
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  color: const Color(0xFF64748B),
                  enabled: true,
                  onTap: () async {
                    // T5.1 payload spec (projectLevelAgent.md Task 3.3):
                    // "Check out this local poll on Polyticks: [Post Title]...
                    // Read more: https://polyticks.app/post/{post_id}"
                    final String postTitle = widget.post.content.length > 50
                        ? widget.post.content.substring(0, 50)
                        : widget.post.content;
                    final String shareUrl =
                        'https://polyticks.app/post/${widget.post.id}';
                    final box = context.findRenderObject() as RenderBox?;
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            'Check out this local poll on Polyticks: $postTitle... Read more: $shareUrl',
                        sharePositionOrigin:
                            box!.localToGlobal(Offset.zero) & box.size,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ── No-permission notice ──────────────────────
          if (!_canLike &&
              !_canComment &&
              widget.currentUser.role != UserRole.janta)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E3054), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline,
                        size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.currentUser.role == UserRole.party
                            ? 'Parties cannot interact with posts directly.'
                            : 'Only members of ${party?.name ?? 'this party'} can interact with this post.',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Comments Section ──────────────────────────
          if (_showComments) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFF1E3054)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Existing comments
                  ..._comments.map((c) => _CommentTile(
                        comment: c,
                        viewerRole: widget.currentUser.role,
                      )),

                  // Input (only if can comment)
                  if (_canComment) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        UserAvatar(user: widget.currentUser, radius: 16),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: _commentCtrl,
                            style: GoogleFonts.inter(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Add a comment…',
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.send_rounded,
                                    color: AppTheme.saffron, size: 18),
                                onPressed: _submitComment,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
      ),
    );
  }
}

// ── Action button ─────────────────────────────
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.inter(
                      color: color, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Comment tile ──────────────────────────────
class _CommentTile extends StatelessWidget {
  final Comment comment;
  final UserRole viewerRole;

  const _CommentTile({required this.comment, required this.viewerRole});

  @override
  Widget build(BuildContext context) {
    final author = userById(comment.authorId);
    if (author == null) return const SizedBox.shrink();

    final showName =
        author.role != UserRole.janta || viewerRole == UserRole.janta;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(user: author, radius: 14),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      showName ? author.displayName : 'Janta',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    RoleBadge(role: author.role, small: true),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.content,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFB0BEC5),
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
