// ─────────────────────────────────────────────
//  Polyticks – Admin Verification Console
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'admin_moderation_queue_screen.dart';

class AdminConsoleScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const AdminConsoleScreen({super.key, required this.onLogout});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pending = [];
  String _message = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _message = '';
    });
    final items =
        await SupabaseService.instance.getPendingVerifications();
    if (!mounted) return;
    setState(() {
      _pending = items;
      _isLoading = false;
    });
  }

  Future<void> _decide(Map<String, dynamic> item, bool approve) async {
    final id = item['id'] as String;
    if (approve) {
      await SupabaseService.instance.approveVerification(id);
    } else {
      await SupabaseService.instance.rejectVerification(id);
    }
    if (!mounted) return;
    setState(() {
      _pending.removeWhere((p) => p['id'] == id);
      _message = approve
          ? 'Verified ${item['username']} and purged their ID document.'
          : 'Rejected ${item['username']} and purged their ID document.';
    });
    // Auto-clear message after a few seconds.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _message.isNotEmpty) {
        setState(() => _message = '');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        backgroundColor: AppTheme.deepNavy,
        title: Text('Admin Verification Console',
            style: GoogleFonts.inter(
                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_outlined, color: AppTheme.saffron),
            tooltip: 'Moderation Queue',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    AdminModerationQueueScreen(onLogout: widget.onLogout),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.saffron),
            onPressed: _load,
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.saffron),
            onPressed: widget.onLogout,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.saffron));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            '${_pending.length} pending verification${_pending.length == 1 ? '' : 's'}',
            style: GoogleFonts.inter(
                color: const Color(0xFF90A4AE), fontSize: 13),
          ),
        ),
        if (_message.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.saffron.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_message,
                  style: GoogleFonts.inter(
                      color: AppTheme.saffron, fontSize: 13)),
            ),
          ),
        Expanded(
          child: _pending.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.inbox_outlined,
                          color: Color(0xFF64748B), size: 56),
                      const SizedBox(height: 12),
                      Text('No pending verifications',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF7C8DA6), fontSize: 15)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pending.length,
                  itemBuilder: (ctx, i) => _buildCard(_pending[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final imageUrl = item['imageUrl'] as String? ?? '';
    return Card(
      color: AppTheme.navyCard,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.saffron.withValues(alpha: 0.15),
                  child: Text(
                    (item['username'] as String? ?? '?')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: GoogleFonts.inter(
                        color: AppTheme.saffron, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['username'] as String? ?? 'User',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: Colors.white)),
                      Text(item['phone'] as String? ?? '',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF7C8DA6), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 120,
                    width: double.infinity,
                    color: AppTheme.navyLight,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: Color(0xFF64748B)),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 80,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.navyLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Center(
                  child: Text('Simulation mode: ID image held locally',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decide(item, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.crimson,
                      side: const BorderSide(color: AppTheme.crimson),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _decide(item, true),
                    child: const Text('Approve'),
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
