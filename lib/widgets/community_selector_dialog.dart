// ─────────────────────────────────────────────
//  Polyticks – Community Selector Dialog Widget
// ─────────────────────────────────────────────
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

const List<String> defaultCommunitiesList = [
  'Indiranagar Ward #84, Bengaluru',
  'Koramangala 4th Block, Bengaluru',
  'Whitefield RWA, Bengaluru',
  'Connaught Place Ward, New Delhi',
  'Bandra West Ward #5, Mumbai',
  'Jubilee Hills Ward #10, Hyderabad',
  'Anna Nagar Ward #102, Chennai',
  'Salt Lake Sector V, Kolkata',
  'Viman Nagar RWA, Pune',
  'Satellite Ward #12, Ahmedabad',
  'Civil Lines Ward #3, Jaipur',
  'Hazratganj Ward #18, Lucknow',
  'IIT Bombay Campus, Mumbai',
  'DLF Phase 3 RWA, Gurugram',
];

/// Displays a modal bottom sheet allowing users to search and select their community/ward.
Future<String?> showCommunitySelectorDialog(
  BuildContext context, {
  required AppUser currentUser,
  Function(String newCommunityId)? onCommunitySelected,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _CommunitySelectorBottomSheet(
      currentUser: currentUser,
      onCommunitySelected: onCommunitySelected,
    ),
  );
}

class _CommunitySelectorBottomSheet extends StatefulWidget {
  final AppUser currentUser;
  final Function(String newCommunityId)? onCommunitySelected;

  const _CommunitySelectorBottomSheet({
    required this.currentUser,
    this.onCommunitySelected,
  });

  @override
  State<_CommunitySelectorBottomSheet> createState() =>
      __CommunitySelectorBottomSheetState();
}

class __CommunitySelectorBottomSheetState
    extends State<_CommunitySelectorBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _requestController = TextEditingController();
  List<String> _filteredCommunities = List.from(defaultCommunitiesList);
  String? _selectedCommunity;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedCommunity = widget.currentUser.communityId;
    _searchController.addListener(_filterCommunities);
  }

  void _filterCommunities() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCommunities = List.from(defaultCommunitiesList);
      } else {
        _filteredCommunities = defaultCommunitiesList
            .where((c) => c.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCommunities);
    _searchController.dispose();
    _requestController.dispose();
    super.dispose();
  }

  Future<void> _selectCommunity(String community) async {
    setState(() {
      _selectedCommunity = community;
      _isSaving = true;
    });

    // Update locally on AppUser object
    widget.currentUser.communityId = community;

    // Update in Supabase profile or simulation
    await SupabaseService.instance.updateUserCommunity(
      widget.currentUser.id,
      community,
    );

    if (widget.onCommunitySelected != null) {
      widget.onCommunitySelected!(community);
    }

    if (mounted) {
      setState(() => _isSaving = false);
      Navigator.of(context).pop(community);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Community updated to "$community"'),
          backgroundColor: AppTheme.emerald,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRequestCommunityDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Request My Community',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the name of your ward, RWA, or local community:',
              style: GoogleFonts.inter(
                color: const Color(0xFF90A4AE),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _requestController,
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Model Town Ward #12, Delhi',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF607D8B)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.saffron),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFF90A4AE)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.saffron,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              final text = _requestController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Request submitted for "$text". We will notify you once verified!'),
                    backgroundColor: AppTheme.saffron,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                _requestController.clear();
              }
            },
            child: Text(
              'Submit',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppTheme.navyCard.withValues(alpha: 0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.saffron.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.location_city_rounded,
                    color: AppTheme.saffron,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Your Community',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Connect to your hyper-local civic feeds & polls',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF90A4AE),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Search box
            TextField(
              controller: _searchController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search ward, RWA, or locality...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF607D8B),
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF7C8DA6),
                  size: 20,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded,
                            color: Color(0xFF7C8DA6), size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.saffron),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ListView of communities
            Expanded(
              child: _filteredCommunities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.location_off_outlined,
                            color: Color(0xFF607D8B),
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No matching community found',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF90A4AE),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _filteredCommunities.length,
                      separatorBuilder: (context, index) => Divider(
                        color: Colors.white.withValues(alpha: 0.05),
                        height: 1,
                      ),
                      itemBuilder: (context, index) {
                        final community = _filteredCommunities[index];
                        final isSelected = _selectedCommunity == community;

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.saffron.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.roofing_rounded,
                              color: isSelected
                                  ? AppTheme.saffron
                                  : const Color(0xFF7C8DA6),
                              size: 18,
                            ),
                          ),
                          title: Text(
                            community,
                            style: GoogleFonts.inter(
                              color: isSelected ? AppTheme.saffron : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(
                                  Icons.check_circle_rounded,
                                  color: AppTheme.saffron,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF607D8B),
                                  size: 20,
                                ),
                          onTap: _isSaving
                              ? null
                              : () => _selectCommunity(community),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 8),
            Divider(color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 8),

            // "Request my community" text button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Don't see your community?",
                  style: GoogleFonts.inter(
                    color: const Color(0xFF90A4AE),
                    fontSize: 13,
                  ),
                ),
                TextButton.icon(
                  onPressed: _showRequestCommunityDialog,
                  icon: const Icon(
                    Icons.add_location_alt_outlined,
                    size: 16,
                    color: AppTheme.saffron,
                  ),
                  label: Text(
                    'Request My Community',
                    style: GoogleFonts.inter(
                      color: AppTheme.saffron,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
