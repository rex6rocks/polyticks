// ─────────────────────────────────────────────
//  Polyticks – Admin Moderation Queue Screen
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../providers/moderation_provider.dart';
import '../../theme/app_theme.dart';

/// Screen that displays the moderation queue for admins.
/// It allows filtering by urgency, status and a free‑text search.
/// Each queue item can be restored or deleted.
class AdminModerationQueueScreen extends ConsumerStatefulWidget {
  final VoidCallback onLogout;

  const AdminModerationQueueScreen({super.key, required this.onLogout});

  @override
  ConsumerState<AdminModerationQueueScreen> createState() =>
      _AdminModerationQueueScreenState();
}

class _AdminModerationQueueScreenState
    extends ConsumerState<AdminModerationQueueScreen> {
  @override
  Widget build(BuildContext context) {
    final moderationStateAsync = ref.watch(moderationNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        title: Text(
          'Moderation Queue',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.saffron),
            onPressed: () =>
                ref.read(moderationNotifierProvider.notifier).refreshQueue(),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.saffron),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildFilterBar(),
          ),
          // Queue List
          Expanded(
            child: moderationStateAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text(
                  'Error: $error',
                  style: GoogleFonts.inter(color: Colors.white),
                ),
              ),
              data: (state) {
                final filteredQueue = state.filteredQueue;
                if (filteredQueue.isEmpty) {
                  return Center(
                    child: Text(
                      'No items match the current filter.',
                      style: GoogleFonts.inter(color: Colors.white70),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: filteredQueue.length,
                  itemBuilder: (context, index) {
                    final item = filteredQueue[index];
                    return _buildQueueItem(item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the top filter bar (urgency, status, search).
  Widget _buildFilterBar() {
    return Consumer(
      builder: (context, ref, child) {
        final currentFilter = ref.watch(
          moderationNotifierProvider.select(
            (state) => state.value?.filter ?? const ModerationFilter(),
          ),
        );

        return Row(
          children: [
            // Urgency Filter
            Expanded(
              child: DropdownButtonFormField<SlaUrgency?>(
                initialValue: currentFilter.urgencyFilter,
                decoration: InputDecoration(
                  labelText: 'Urgency',
                  labelStyle: GoogleFonts.inter(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppTheme.navyLight,
                ),
                dropdownColor: AppTheme.navyLight,
                style: GoogleFonts.inter(color: Colors.white),
                items: [
                  const DropdownMenuItem<SlaUrgency>(
                    value: null,
                    child: Text('All Urgencies',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ...SlaUrgency.values.map(
                    (urgency) => DropdownMenuItem<SlaUrgency>(
                      value: urgency,
                      child: Text(
                        urgency.toString().split('.').last,
                        style: TextStyle(color: _getUrgencyColor(urgency)),
                      ),
                    ),
                  ),
                ],
                onChanged: (urgency) {
                  // The copyWith method expects a closure returning the new value
                  // to allow lazy evaluation. Wrap the selected urgency in a closure.
                  ref.read(moderationNotifierProvider.notifier).updateFilter(
                        currentFilter.copyWith(urgencyFilter: () => urgency),
                      );
                },
              ),
            ),
            const SizedBox(width: 12),
            // Status Filter
            Expanded(
              child: DropdownButtonFormField<FactCheckStatus?>(
                initialValue: currentFilter.statusFilter,
                decoration: InputDecoration(
                  labelText: 'Status',
                  labelStyle: GoogleFonts.inter(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppTheme.navyLight,
                ),
                dropdownColor: AppTheme.navyLight,
                style: GoogleFonts.inter(color: Colors.white),
                items: [
                  const DropdownMenuItem<FactCheckStatus>(
                    value: null,
                    child: Text('All Statuses',
                        style: TextStyle(color: Colors.white70)),
                  ),
                  ...FactCheckStatus.values.map(
                    (status) => DropdownMenuItem<FactCheckStatus>(
                      value: status,
                      child: Text(
                        status.toString().split('.').last,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
                onChanged: (status) {
                  // Wrap the selected status in a closure for copyWith's expected type.
                  ref.read(moderationNotifierProvider.notifier).updateFilter(
                        currentFilter.copyWith(statusFilter: () => status),
                      );
                },
              ),
            ),
            const SizedBox(width: 12),
            // Search Field
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Search',
                  labelStyle: GoogleFonts.inter(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: AppTheme.navyLight,
                  suffixIcon: const Icon(Icons.search, color: Colors.white70),
                ),
                style: GoogleFonts.inter(color: Colors.white),
                onChanged: (query) {
                  // Wrap the query string in a closure to match copyWith signature.
                  ref.read(moderationNotifierProvider.notifier).updateFilter(
                        currentFilter.copyWith(searchQuery: () => query),
                      );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Builds a single queue item card.
  Widget _buildQueueItem(ModerationQueueItem item) {
    final hoursRemaining = item.slaDeadline.difference(DateTime.now()).inHours;
    final slaText = hoursRemaining <= 0
        ? 'SLA Breached!'
        : '$hoursRemaining hours remaining';

    return Card(
      color: AppTheme.navyLight,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Content
            Text(
              item.postContent,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Author & Reason
            Row(
              children: [
                if (item.authorUsername != null)
                  Text(
                    'by ${item.authorUsername}',
                    style: GoogleFonts.inter(
                        color: Colors.white70, fontSize: 12),
                  ),
                const Spacer(),
                Text(
                  'Reason: ${item.reason}',
                  style:
                      GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // SLA Deadline and Actions
            Row(
              children: [
                Icon(
                  Icons.timer,
                  color: _getUrgencyColor(item.slaUrgency),
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  slaText,
                  style: GoogleFonts.inter(
                    color: _getUrgencyColor(item.slaUrgency),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _showActionDialog(item.postId, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.crimson,
                        side: const BorderSide(color: AppTheme.crimson),
                      ),
                      child: const Text('Delete'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showActionDialog(item.postId, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.saffron,
                        foregroundColor: AppTheme.deepNavy,
                      ),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns a colour based on the urgency level.
  Color _getUrgencyColor(SlaUrgency urgency) {
    // Map the defined SlaUrgency enum values to appropriate colours.
    // The enum (defined in docs/V2_STATE_MANAGEMENT_SPEC.md) includes:
    //   normal, warning, critical, breached
    // Previously this switch referenced non‑existent values (high, medium,
    // low, none) which caused a compilation error. We now handle all valid
    // cases and provide a sensible fallback colour.
    switch (urgency) {
      case SlaUrgency.critical:
        return AppTheme.crimson; // Highest priority SLA breach
      case SlaUrgency.warning:
        return Colors.orange; // Approaching SLA breach
      case SlaUrgency.normal:
        return Colors.yellow; // Within acceptable SLA range
      case SlaUrgency.breached:
        return Colors.grey; // SLA already expired
    }
  }

  /// Shows a dialog to confirm delete or restore actions.
  void _showActionDialog(String postId, bool approveRestore) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.navyLight,
        title: Text(
          approveRestore ? 'Restore Post' : 'Delete Post',
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          approveRestore
              ? 'Are you sure you want to restore this post?'
              : 'Are you sure you want to permanently delete this post?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.white70),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(moderationNotifierProvider.notifier)
                  .resolveReport(postId, approveRestore);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  approveRestore ? AppTheme.saffron : AppTheme.crimson,
              foregroundColor: AppTheme.deepNavy,
            ),
            child: Text(approveRestore ? 'Restore' : 'Delete'),
          ),
        ],
      ),
    );
  }
}
