// ─────────────────────────────────────────────
//  Polyticks – Login Screen
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import 'otp_verification_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  final void Function(AppUser user) onLogin;
  const LoginScreen({super.key, required this.onLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneCtrl =
      TextEditingController(text: '+91 98765 43210');
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _errorMsg = 'Please enter a phone number.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // LIVE MODE: actually send the OTP via Supabase Auth. Requires an SMS
    // provider configured in Supabase (Authentication → Providers → Phone).
    final sent = await SupabaseService.instance.sendOTP(phone);
    if (!mounted) return;
    if (!sent) {
      setState(() {
        _isLoading = false;
        _errorMsg =
            'Could not send the verification code. Check your number and try again.';
      });
      return;
    }
    setState(() => _isLoading = false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationScreen(
          phoneNumber: phone,
          onAuthenticated: (user) {
            Navigator.pop(context);
            widget.onLogin(user);
          },
        ),
      ),
    );
  }

  void _loginAsGuest() {
    final guest = AppUser(
      id: 'guest',
      displayName: 'Guest User',
      role: UserRole.janta,
      avatarColor: '#4ECDC4',
      email: 'guest@polyticks.in',
      isGuest: true,
      isVerified: false,
    );
    widget.onLogin(guest);
  }

  void _loginAsAdmin() {
    final adminAcc = mockAccounts.firstWhere(
        (acc) => acc['user'].role == UserRole.admin);
    _loginAsPersona(adminAcc);
  }

  /// Handles a Quick Demo Persona tap.
  ///
  /// SIMULATION MODE: the persona enters directly with its fixture identity.
  /// LIVE MODE (real Supabase): authenticate the corresponding seeded backend
  /// account first so the app runs with a genuine session — storage RLS and
  /// other policies depend on auth.uid(), which mock ids like 'u3' can never
  /// satisfy. Falls back to a clear error if no backend account exists.
  Future<void> _loginAsPersona(Map<String, dynamic> acc) async {
    final user = acc['user'] as AppUser;
    if (!SupabaseService.instance.isRealSupabase) {
      widget.onLogin(user);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    try {
      await SupabaseService.instance.client!.auth.signInWithPassword(
        email: acc['email'] as String,
        password: acc['password'] as String,
      );
      final authUid = SupabaseService.instance.client!.auth.currentUser!.id;
      final profile =
          await SupabaseService.instance.fetchProfile(authUid, user.phone);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (profile != null) {
        // Bridge persona-specific attributes (party membership, hierarchy
        // role, community) onto the live identity — the profiles table does
        // not model these yet, so otherwise party screens fall back to
        // generic labels like 'Your Party'.
        profile.partyId ??= user.partyId;
        profile.partyRole ??= user.partyRole;
        profile.communityId ??= user.communityId;
        profile.isAnonymous = user.isAnonymous;
        if (user.role != UserRole.janta) profile.role = user.role;
        widget.onLogin(profile);
      } else {
        setState(() => _errorMsg =
            'Backend account for "${user.displayName}" has no profile row. '
            'Ask an admin to seed profiles for ${acc['email']}.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMsg = 'Demo persona "${user.displayName}" has no live backend '
            'account (${acc['email']}). Please log in with your phone number '
            '(OTP) instead.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand Banner ──────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFFFBE0B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00)
                                    .withValues(alpha: 0.35),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('🗳️', style: TextStyle(fontSize: 32)),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Welcome to Polyticks',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Democratic, uncensored political social media with zero-retention identity verification.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: const Color(0xFF94A3B8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Main Card ─────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152342),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFF1E3054), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Phone Label
                        Text(
                          'Phone Number (OTP Verification):',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFCBD5E1),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Phone Input Field
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0A1628),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFF1E3054),
                              width: 1,
                            ),
                          ),
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(
                                Icons.phone_outlined,
                                color: Color(0xFF64748B),
                                size: 18,
                              ),
                              hintText: '+91 98765 43210',
                              hintStyle: TextStyle(color: Color(0xFF475569)),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),

                        if (_errorMsg != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMsg!,
                            style: GoogleFonts.inter(
                              color: AppTheme.crimson,
                              fontSize: 12,
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),

                        // Send OTP Button
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFE55F00)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00)
                                    .withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Send One-Time Password (OTP)',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.arrow_forward_rounded,
                                          size: 16, color: Colors.white),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Divider ───────────────────────────────────
                        Row(
                          children: [
                            const Expanded(
                              child:
                                  Divider(color: Color(0xFF1E3054), height: 1),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'OR ONE-CLICK DEMO PERSONAS',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF64748B),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const Expanded(
                              child:
                                  Divider(color: Color(0xFF1E3054), height: 1),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // ── Quick Demo Personas List ──────────────────
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: mockAccounts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final acc = mockAccounts[index];
                              final user = acc['user'] as AppUser;
                              return _DemoPersonaTile(
                                user: user,
                                onTap: () => _loginAsPersona(acc),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 18),
                        const Divider(color: Color(0xFF1E3054), height: 1),
                        const SizedBox(height: 14),

                        // ── Bottom Links ──────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      SignupScreen(onSignup: widget.onLogin),
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Register New Account →',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFFF6B00),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: _loginAsGuest,
                              child: Text(
                                'Login later',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            TextButton.icon(
                              onPressed: _loginAsAdmin,
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: const Icon(
                                Icons.shield_outlined,
                                size: 14,
                                color: Color(0xFF10B981),
                              ),
                              label: Text(
                                'Admin Queue',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF10B981),
                                ),
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
          ),
        ),
      ),
    );
  }
}

// ── Demo Persona Tile ─────────────────────────────────────────
class _DemoPersonaTile extends StatelessWidget {
  final AppUser user;
  final VoidCallback onTap;

  const _DemoPersonaTile({
    required this.user,
    required this.onTap,
  });

  Color _hexColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    return const Color(0xFF4ECDC4);
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.janta:
        return const Color(0xFF4ECDC4);
      case UserRole.party:
        return const Color(0xFFFF6B6B);
      case UserRole.partyMember:
        return const Color(0xFFFFBE0B);
      case UserRole.admin:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleClr = _roleColor(user.role);
    final initials = user.displayName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2B45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E3054), width: 1),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _hexColor(user.avatarColor),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initials.isEmpty ? '?' : initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Name + Community Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${user.email}${user.communityId != null ? ' · ${user.communityId}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Role Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: roleClr.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: roleClr.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                user.roleLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: roleClr,
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
