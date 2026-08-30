// ─────────────────────────────────────────────
//  Polyticks – Sign-Up Screen
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../theme/app_theme.dart';

class SignupScreen extends StatefulWidget {
  final void Function(AppUser user) onSignup;
  const SignupScreen({super.key, required this.onSignup});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  UserRole _selectedRole = UserRole.janta;
  String? _selectedPartyId;
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMsg;

  static const _roleLabels = {
    UserRole.janta: 'Janta',
    UserRole.party: 'Party',
    UserRole.partyMember: 'Party Member',
  };

  static const _roleDescriptions = {
    UserRole.janta:
        'Citizens who can follow parties, view all content & comment on party posts.',
    UserRole.party:
        'Registered political parties that create public posts and run member polls.',
    UserRole.partyMember:
        'Members affiliated with a single party. Access party polls & tagged posts.',
  };

  Color _roleColor(UserRole r) {
    switch (r) {
      case UserRole.janta:
        return AppTheme.jantaColor;
      case UserRole.party:
        return AppTheme.partyColor;
      case UserRole.partyMember:
        return AppTheme.memberColor;
      case UserRole.admin:
        return AppTheme.adminColor;
    }
  }

  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRole == UserRole.partyMember && _selectedPartyId == null) {
      setState(() => _errorMsg = 'Please select a party to join.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });
    await Future.delayed(const Duration(milliseconds: 900));

    final newUser = AppUser(
      id: 'new_${DateTime.now().millisecondsSinceEpoch}',
      displayName: _nameCtrl.text.trim(),
      role: _selectedRole,
      partyId: _selectedRole == UserRole.partyMember ? _selectedPartyId : null,
      avatarColor: '#4ECDC4',
      email: _emailCtrl.text.trim().toLowerCase(),
    );

    // Add to mock store so the feed works
    mockAccounts.add({
      'email': newUser.email,
      'password': _passwordCtrl.text,
      'user': newUser,
    });

    if (!mounted) return;
    widget.onSignup(newUser);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0D1F3C), AppTheme.deepNavy],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Back button ───────────────────────────────
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 16),

                  // ── Header ────────────────────────────────────
                  Text('Create Account',
                      style: Theme.of(context).textTheme.displayLarge),
                  const SizedBox(height: 4),
                  Text('Join the political conversation',
                      style: Theme.of(context).textTheme.bodyMedium),

                  const SizedBox(height: 32),

                  // ── Role Selector ─────────────────────────────
                  _label('I am signing up as'),
                  const SizedBox(height: 12),
                  Row(
                    children: _roleLabels.entries.map((e) {
                      final selected = _selectedRole == e.key;
                      final color = _roleColor(e.key);
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedRole = e.key;
                              _selectedPartyId = null;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 6),
                            decoration: BoxDecoration(
                              color: selected
                                  ? color.withValues(alpha: 0.15)
                                  : AppTheme.navyLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color:
                                    selected ? color : const Color(0xFF243450),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  e.key == UserRole.janta
                                      ? Icons.people_outline
                                      : e.key == UserRole.party
                                          ? Icons.account_balance_outlined
                                          : Icons.badge_outlined,
                                  color: selected
                                      ? color
                                      : const Color(0xFF64748B),
                                  size: 22,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  e.value,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? color
                                        : const Color(0xFF7C8DA6),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  // ── Role description ──────────────────────────
                  const SizedBox(height: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_selectedRole),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            _roleColor(_selectedRole).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              _roleColor(_selectedRole).withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _roleDescriptions[_selectedRole]!,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _roleColor(_selectedRole),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── Name / Party Name ──────────────────────────
                  _label(_selectedRole == UserRole.party
                      ? 'Party Name'
                      : 'Full Name'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: _selectedRole == UserRole.party
                          ? 'e.g. Bharatiya Rashtriya Morcha'
                          : 'e.g. Arjun Sharma',
                      prefixIcon: Icon(
                        _selectedRole == UserRole.party
                            ? Icons.account_balance_outlined
                            : Icons.person_outline,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty)
                        ? 'This field is required'
                        : null,
                  ),

                  const SizedBox(height: 20),

                  // ── Email ─────────────────────────────────────
                  _label('Email'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon:
                          Icon(Icons.mail_outline, color: Color(0xFF64748B)),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Password ──────────────────────────────────
                  _label('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: Color(0xFF64748B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter a password';
                      if (v.length < 6) return 'Minimum 6 characters';
                      return null;
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Confirm Password ──────────────────────────
                  _label('Confirm Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: '••••••••',
                      prefixIcon:
                          Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                    ),
                    validator: (v) {
                      if (v != _passwordCtrl.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),

                  // ── Party selector (Party Member only) ────────
                  if (_selectedRole == UserRole.partyMember) ...[
                    const SizedBox(height: 24),
                    _label('Select Your Party'),
                    const SizedBox(height: 12),
                    ...mockParties.map((party) {
                      final selected = _selectedPartyId == party.id;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedPartyId = party.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: selected
                                ? AppTheme.memberColor.withValues(alpha: 0.1)
                                : AppTheme.navyLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? AppTheme.memberColor
                                  : const Color(0xFF243450),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(party.logoEmoji,
                                  style: const TextStyle(fontSize: 28)),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(party.name,
                                        style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: selected
                                                ? Colors.white
                                                : const Color(0xFFB0BEC5))),
                                    Text(party.shortName,
                                        style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: const Color(0xFF64748B))),
                                  ],
                                ),
                              ),
                              if (selected)
                                const Icon(Icons.check_circle,
                                    color: AppTheme.memberColor, size: 20),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],

                  if (_errorMsg != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.crimson.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.crimson.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.crimson, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMsg!,
                                style: GoogleFonts.inter(
                                    color: AppTheme.crimson, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // ── Submit ────────────────────────────────────
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signup,
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Text('Create Account'),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account? ',
                          style: GoogleFonts.inter(
                              color: const Color(0xFF7C8DA6), fontSize: 14)),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text('Sign In',
                            style: GoogleFonts.inter(
                                color: AppTheme.saffron,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          color: const Color(0xFF90A4AE),
          fontSize: 13,
          fontWeight: FontWeight.w500));
}
