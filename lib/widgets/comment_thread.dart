// ─────────────────────────────────────────────
//  Polyticks – Threaded Comment Section
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import 'shared_widgets.dart';

const int _maxIndent = 5;

class CommentNode {
  final Comment comment;
  final List<CommentNode> children;
  const CommentNode({required this.comment, required this.children});
}

/// Build the reply tree from a flat comment list. Unlimited data depth.
List<CommentNode> buildCommentTree(List<Comment> comments) {
  Map<String?, List<Comment>> byParent = {};
  for (final c in comments) {
    byParent.putIfAbsent(c.parentId, () => []).add(c);
  }
  List<CommentNode> build(String? parentId) {
    final list = byParent[parentId] ?? const <Comment>[];
    return list
        .map((c) => CommentNode(comment: c, children: build(c.id)))
        .toList();
  }
  return build(null);
}

int countReplies(CommentNode n) =>
    n.children.fold(0, (acc, c) => acc + 1 + countReplies(c));

class CommentSection extends StatefulWidget {
  final Post post;
  final AppUser currentUser;

  const CommentSection({
    super.key,
    required this.post,
    required this.currentUser,
  });

  @override
  State<CommentSection> createState() => _CommentSectionState();
}

class _CommentSectionState extends State<CommentSection> {
  late List<Comment> _comments;
  final _topLevelCtrl = TextEditingController();

  bool get _canInteract {
    final u = widget.currentUser;
    if (u.isGuest) return false;
    if (u.role == UserRole.janta && u.verificationStatus != 'approved' && !u.isVerified) {
      return false;
    }
    return true;
  }

  bool get _canComment {
    if (!_canInteract) return false;
    final u = widget.currentUser;
    if (u.role == UserRole.janta) return true;
    if (u.role == UserRole.party) return false;
    return u.role == UserRole.partyMember &&
        widget.post.type == PostType.memberTagged &&
        u.partyId == widget.post.partyId;
  }

  @override
  void initState() {
    super.initState();
    _comments = commentsForPost(widget.post.id);
  }

  @override
  void dispose() {
    _topLevelCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() => _comments = commentsForPost(widget.post.id));

  void _addComment(String content, {String? parentId}) {
    if (content.trim().isEmpty || !_canComment) return;
    // Validate reply target belongs to this post
    String? validParent;
    if (parentId != null) {
      final parent = mockComments.cast<Comment?>().firstWhere(
            (c) => c?.id == parentId && c!.postId == widget.post.id,
            orElse: () => null,
          );
      validParent = parent != null ? parentId : null; // orphaned target → top-level
    }
    mockComments.add(Comment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      postId: widget.post.id,
      parentId: validParent,
      authorId: widget.currentUser.id,
      content: content.trim(),
      createdAt: DateTime.now(),
    ));
    _refresh();
    FocusScope.of(context).unfocus();
  }

  void _react(Comment comment, InteractionType type) {
    setState(() {
      if (comment.userInteraction == type) {
        if (type == InteractionType.like) comment.likeCount--;
        if (type == InteractionType.dislike) comment.dislikeCount--;
        comment.userInteraction = InteractionType.none;
      } else {
        if (comment.userInteraction == InteractionType.like) comment.likeCount--;
        if (comment.userInteraction == InteractionType.dislike) comment.dislikeCount--;
        comment.userInteraction = type;
        if (type == InteractionType.like) comment.likeCount++;
        if (type == InteractionType.dislike) comment.dislikeCount++;
      }
    });
  }

  void _reportComment(Comment comment) {
    final ctrl = TextEditingController();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report comment',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Why are you reporting this comment?',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Report submitted for moderation review.'),
                        backgroundColor: AppTheme.emerald,
                      ),
                    );
                  },
                  child: const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tree = buildCommentTree(_comments);
    final replies = _comments.where((c) => c.parentId != null).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Discussion ',
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
            Text('(${_comments.length})'
                '${replies > 0 ? ' · $replies replies' : ''}',
                style: GoogleFonts.inter(
                    fontSize: 13, color: const Color(0xFF7C8DA6))),
          ],
        ),
        const SizedBox(height: 12),
        if (_canComment)
          Row(
            children: [
              UserAvatar(user: widget.currentUser, radius: 15),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _topLevelCtrl,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                  onSubmitted: (v) {
                    _addComment(v);
                    _topLevelCtrl.clear();
                  },
                  decoration: const InputDecoration(
                    hintText: 'Share your perspective…',
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ],
          )
        else
          Text('Commenting is available to citizens and verified party members.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFF64748B))),
        const SizedBox(height: 8),
        if (tree.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('No comments yet. Start the conversation.',
                  style: GoogleFonts.inter(
                      fontSize: 13, color: const Color(0xFF64748B))),
            ),
          )
        else
          ...tree.map((n) => _CommentItem(
                node: n,
                depth: 0,
                section: this,
              )),
      ],
    );
  }
}

class _CommentItem extends StatelessWidget {
  final CommentNode node;
  final int depth;
  final _CommentSectionState section;

  const _CommentItem({
    required this.node,
    required this.depth,
    required this.section,
  });

  void _reply(BuildContext context) async {
    final ctrl = TextEditingController();
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.navyCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reply to ${_authorName(node.comment)}',
                  style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white)),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                autofocus: true,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Write your reply…',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Post reply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitted == true && ctrl.text.trim().isNotEmpty) {
      section._addComment(ctrl.text.trim(), parentId: node.comment.id);
    }
  }

  static String _authorName(Comment c) {
    final author = userById(c.authorId);
    return author?.displayName ?? 'Janta';
  }

  @override
  Widget build(BuildContext context) {
    final comment = node.comment;
    final author = userById(comment.authorId);
    if (author == null) return const SizedBox.shrink();

    final showName =
        author.role != UserRole.janta || section.widget.currentUser.role == UserRole.janta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth > 0 ? 18 : 0, top: 10, bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(user: author, radius: 14),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          showName ? author.displayName : 'Anonymous Citizen',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        RoleBadge(role: author.role, small: true),
                        if (author.partyRole != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: author.partyRole!.isTopTier
                                  ? const Color(0xFFA78BFA).withOpacity(0.15)
                                  : const Color(0xFF7DD3FC).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(author.partyRole!.label,
                                style: GoogleFonts.inter(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: author.partyRole!.isTopTier
                                        ? const Color(0xFFA78BFA)
                                        : const Color(0xFF7DD3FC))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(comment.content,
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFFB0BEC5),
                            height: 1.45)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        InkWell(
                          onTap: section._canInteract
                              ? () => section._react(
                                  comment, InteractionType.like)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(children: [
                              Icon(Icons.thumb_up_alt_outlined,
                                  size: 13,
                                  color: comment.userInteraction ==
                                          InteractionType.like
                                      ? AppTheme.emerald
                                      : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text('${comment.likeCount}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: comment.userInteraction ==
                                              InteractionType.like
                                          ? AppTheme.emerald
                                          : const Color(0xFF7C8DA6))),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: section._canInteract
                              ? () => section._react(
                                  comment, InteractionType.dislike)
                              : null,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Row(children: [
                              Icon(Icons.thumb_down_alt_outlined,
                                  size: 13,
                                  color: comment.userInteraction ==
                                          InteractionType.dislike
                                      ? AppTheme.crimson
                                      : const Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text('${comment.dislikeCount}',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: comment.userInteraction ==
                                              InteractionType.dislike
                                          ? AppTheme.crimson
                                          : const Color(0xFF7C8DA6))),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        if (section._canInteract)
                          InkWell(
                            onTap: () => _reply(context),
                            borderRadius: BorderRadius.circular(6),
                            child: Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text('Reply',
                                  style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF64748B))),
                            ),
                          ),
                        const Spacer(),
                        InkWell(
                          onTap: () => section._reportComment(comment),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(Icons.flag_outlined,
                                size: 14, color: const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Nested replies – visual indent capped at _maxIndent levels
        if (node.children.isNotEmpty && depth < _maxIndent - 1)
          ...node.children.map((child) => _CommentItem(
                node: child,
                depth: depth + 1,
                section: section,
              ))
        else if (node.children.isNotEmpty)
          ...node.children.map((child) => _CommentItem(
                node: child,
                depth: _maxIndent - 1,
                section: section,
              )),
      ],
    );
  }
}
