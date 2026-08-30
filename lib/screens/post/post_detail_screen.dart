// ─────────────────────────────────────────────
//  Polyticks – Post Detail (reading) Screen
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';
import '../../widgets/comment_thread.dart';

class PostDetailScreen extends StatelessWidget {
  final Post post;
  final AppUser currentUser;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.currentUser,
  });

  bool get _canInteract {
    if (currentUser.isGuest) return false;
    if (currentUser.role == UserRole.janta) {
      if (currentUser.verificationStatus != 'approved' && !currentUser.isVerified) {
        return false;
      }
      return true;
    }
    if (currentUser.role == UserRole.party) return false;
    return currentUser.role == UserRole.partyMember &&
        post.type == PostType.memberTagged &&
        currentUser.partyId == post.partyId;
  }


  void _showOptions(BuildContext context) {
    showModalBottomSheet<void>(
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
              leading: const Icon(Icons.flag_outlined, color: AppTheme.gold),
              title: Text('Report post',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Report submitted for moderation review.'),
                  backgroundColor: AppTheme.emerald,
                ));
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.link_outlined, color: Color(0xFF7C8DA6)),
              title: Text('Copy link',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: 'polyticks://post/${post.id}'));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Link copied to clipboard.'),
                ));
              },
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes.clamp(1, 59)}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final party = partyById(post.partyId);
    final comments = commentsForPost(post.id);

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, size: 22),
            onPressed: () => _showOptions(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author header ──
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.navyLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF27354F)),
                  ),
                  child: Text(party?.logoEmoji ?? '👤',
                      style: const TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              party?.name ?? post.authorId ?? 'Citizen Voice',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                          if (party != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppTheme.memberColor.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(party.shortName,
                                  style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.memberColor)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(_timeAgo(post.createdAt),
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              color: const Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),

            // ── Content ──
            if (post.imageEmoji != null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(post.imageEmoji!,
                    style: const TextStyle(fontSize: 64)),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SelectableText(
                post.content,
                style: GoogleFonts.inter(
                  fontSize: 17,
                  height: 1.6,
                  color: const Color(0xFFE7EDF5),
                ),
              ),
            ),

            // ── Engagement row ──
            Container(
              margin: const EdgeInsets.only(top: 24),
              padding: const EdgeInsets.only(bottom: 20),
              decoration: const BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Color(0xFF202C44), width: 1)),
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: _canInteract
                        ? () => post.interaction = post.interaction ==
                                InteractionType.like
                            ? InteractionType.none
                            : InteractionType.like
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(children: [
                        Icon(Icons.thumb_up_alt_outlined,
                            size: 17,
                            color: post.interaction == InteractionType.like
                                ? AppTheme.emerald
                                : const Color(0xFF7C8DA6)),
                        const SizedBox(width: 6),
                        Text('${post.likeCount}',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFFB0BEC5))),
                      ]),
                    ),
                  ),
                  const SizedBox(width: 20),
                  InkWell(
                    onTap: _canInteract
                        ? () => post.interaction = post.interaction ==
                                InteractionType.dislike
                            ? InteractionType.none
                            : InteractionType.dislike
                        : null,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Row(children: [
                        Icon(Icons.thumb_down_alt_outlined,
                            size: 17,
                            color: post.interaction == InteractionType.dislike
                                ? AppTheme.crimson
                                : const Color(0xFF7C8DA6)),
                        const SizedBox(width: 6),
                        Text('${post.dislikeCount}',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: const Color(0xFFB0BEC5))),
                      ]),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chat_bubble_outline,
                      size: 16, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('${comments.length}',
                      style: GoogleFonts.inter(
                          fontSize: 13, color: const Color(0xFFB0BEC5))),
                ],
              ),
            ),

            // ── Threaded discussion ──
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: CommentSection(post: post, currentUser: currentUser),
            ),
          ],
        ),
      ),
    );
  }
}
