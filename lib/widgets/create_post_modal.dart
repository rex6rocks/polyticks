// ─────────────────────────────────────────────
//  Polyticks – Create Post Modal
// ─────────────────────────────────────────────
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

class CreatePostModal extends StatefulWidget {
  final AppUser currentUser;
  final VoidCallback onPostCreated;

  const CreatePostModal({
    super.key,
    required this.currentUser,
    required this.onPostCreated,
  });

  @override
  State<CreatePostModal> createState() => _CreatePostModalState();
}

class _CreatePostModalState extends State<CreatePostModal> {
  final TextEditingController _contentController = TextEditingController();
  ChannelType _selectedChannel = ChannelType.broader;
  String? _selectedEmoji = '📢';
  bool _isSubmitting = false;

  final List<String> _emojiOptions = ['📢', '🏥', '🛡️', '📜', '🌊', '⚡', '🪔', '🗳️'];

  @override
  void initState() {
    super.initState();
    if (widget.currentUser.communityId != null) {
      _selectedChannel = ChannelType.hyperLocal;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Party? get _userParty {
    if (widget.currentUser.partyId == null) return null;
    return partyById(widget.currentUser.partyId!);
  }

  Future<void> _submitPost() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter post content'),
          backgroundColor: AppTheme.amber,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final post = await SupabaseService.instance.createPost(
        widget.currentUser,
        text,
        imageEmoji: _selectedEmoji,
        channelType: _selectedChannel,
        communityId: widget.currentUser.communityId,
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (post != null) {
        Navigator.pop(context);
        widget.onPostCreated();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  post.isHidden
                      ? 'Post submitted and flagged for pre-screen review'
                      : 'Post published successfully!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: post.isHidden ? AppTheme.amber : const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to publish post. Please try again.'),
            backgroundColor: AppTheme.crimson,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppTheme.crimson,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            padding: const EdgeInsets.only(
              top: 16,
              left: 20,
              right: 20,
              bottom: 20,
            ),
            decoration: BoxDecoration(
              color: AppTheme.navyCard.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Handle ─────────────────────────────
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Header Title (Fixed Top Bar) ───────
                Row(
                  children: [
                    Text(
                      'Create New Post',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF7C8DA6)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // ── Scrollable Body Content ───────────
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── REPRESENTATION BANNER (Strict Enforcement) ───
                        _buildRepresentationBanner(),

                        const SizedBox(height: 16),

                        // ── Feed Channel Selector ───────────────
                        Text(
                          'Publishing Channel',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF90A4AE),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _ChannelChoiceTile(
                                title: 'Hyper-Local',
                                subtitle: widget.currentUser.communityId ?? 'Local Ward',
                                icon: Icons.roofing_rounded,
                                isSelected: _selectedChannel == ChannelType.hyperLocal,
                                onTap: () {
                                  setState(() => _selectedChannel = ChannelType.hyperLocal);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ChannelChoiceTile(
                                title: 'Broader Feed',
                                subtitle: 'National Channel',
                                icon: Icons.public_rounded,
                                isSelected: _selectedChannel == ChannelType.broader,
                                onTap: () {
                                  setState(() => _selectedChannel = ChannelType.broader);
                                },
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── Content Input Field ────────────────
                        TextField(
                          controller: _contentController,
                          maxLines: 4,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: 'Share your news, opinion, or official update...',
                            hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B)),
                            filled: true,
                            fillColor: AppTheme.navyLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                color: Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: AppTheme.saffron,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Visual Badge Attachment Picker ──────
                        Row(
                          children: [
                            Text(
                              'Topic Badge:',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF90A4AE),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _emojiOptions.map((emoji) {
                                    final isSelected = _selectedEmoji == emoji;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _selectedEmoji = isSelected ? null : emoji;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(right: 8),
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? AppTheme.saffron.withValues(alpha: 0.25)
                                              : AppTheme.navyLight,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected
                                                ? AppTheme.saffron
                                                : Colors.white.withValues(alpha: 0.08),
                                          ),
                                        ),
                                        child: Text(emoji, style: const TextStyle(fontSize: 18)),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ── Submit Button ──────────────────────
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitPost,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.saffron,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.black,
                                    ),
                                  )
                                : Text(
                                    'Publish Post',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Builds representation header strictly governed by role requirements:
  /// - Janta: No option to add party representation (fixed Janta/Citizen indicator).
  /// - Party Member: Only allowed to represent their own party (fixed party indicator, no options given).
  /// - Party: Cannot represent anyone as they ARE the party (fixed Party entity indicator).
  Widget _buildRepresentationBanner() {
    final role = widget.currentUser.role;
    final party = _userParty;

    if (role == UserRole.janta) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.saffron.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.saffron.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.saffron,
              child: Icon(Icons.person_rounded, size: 16, color: Colors.black),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posting as Citizen (Janta)',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'No party representation (Individual citizen voice)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.saffron,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.saffron),
          ],
        ),
      );
    } else if (role == UserRole.partyMember) {
      final partyName = party?.name ?? 'Your Party';
      final logoEmoji = party?.logoEmoji ?? '👥';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.memberColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.memberColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(logoEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Representing: $partyName',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Affiliated Party Member (Fixed to your registered party)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.memberColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.lock_outline_rounded, size: 16, color: AppTheme.memberColor),
          ],
        ),
      );
    } else {
      // UserRole.party
      final partyName = party?.name ?? widget.currentUser.displayName;
      final logoEmoji = party?.logoEmoji ?? '🏛️';

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.partyColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.partyColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(logoEmoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Posting as $partyName',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Official Party Account (Cannot represent external entities)',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.partyColor,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.verified_rounded, size: 16, color: AppTheme.partyColor),
          ],
        ),
      );
    }
  }
}

class _ChannelChoiceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelChoiceTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.saffron.withValues(alpha: 0.15)
              : AppTheme.navyLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppTheme.saffron
                : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.saffron : const Color(0xFF7C8DA6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFFCFD8DC),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: isSelected ? AppTheme.saffron : const Color(0xFF7C8DA6),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to launch the CreatePostModal sheet
void showCreatePostModal(BuildContext context, {required AppUser currentUser, required VoidCallback onPostCreated}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => CreatePostModal(
      currentUser: currentUser,
      onPostCreated: onPostCreated,
    ),
  );
}
