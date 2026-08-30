// ─────────────────────────────────────────────
//  Polyticks – OTP Verification Screen
// ─────────────────────────────────────────────
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/models.dart';
import '../../data/mock_data.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';

class OTPVerificationScreen extends StatefulWidget {
  final String phoneNumber;
  final void Function(AppUser user) onAuthenticated;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.onAuthenticated,
  });

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController _otpCtrl =
      TextEditingController(text: '123456');
  bool _isLoading = false;
  String? _errorMsg;

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _autoFill() {
    setState(() {
      _otpCtrl.text = '123456';
      _errorMsg = null;
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length < 4) {
      setState(() => _errorMsg = 'Enter at least 4 digits for the verification code.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    // LIVE MODE: verify the real code against Supabase Auth and load the
    // caller's profile (is_verified drives the ID-verification gate).
    if (SupabaseService.instance.isRealSupabase) {
      final user = await SupabaseService.instance.verifyOTP(
        widget.phoneNumber,
        otp,
      );
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _isLoading = false;
          _errorMsg = 'Invalid or expired code. Please try again.';
        });
        return;
      }
      widget.onAuthenticated(user);
      return;
    }

    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    // SIMULATION MODE: find account by phone number or default to first
    // Janta user / new user
    AppUser user;
    final match = mockAccounts.firstWhere(
      (acc) {
        final u = acc['user'] as AppUser;
        return u.phone == widget.phoneNumber ||
            (u.phone != null &&
                u.phone!.replaceAll(RegExp(r'\s+'), '') ==
                    widget.phoneNumber.replaceAll(RegExp(r'\s+'), ''));
      },
      orElse: () => mockAccounts[0],
    );
    user = match['user'] as AppUser;

    widget.onAuthenticated(user);
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
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back Button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      label: Text(
                        'Change Number',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF152342),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1E3054), width: 1.2),
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
                        // Shield Icon
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C27A).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.shield_outlined,
                                color: Color(0xFF00C27A),
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Title
                        Text(
                          'Enter Verification Code',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '6-digit OTP sent to ${widget.phoneNumber}',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // OTP Input
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
                            controller: _otpCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 6,
                            style: GoogleFonts.firaCode(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 8,
                            ),
                            decoration: const InputDecoration(
                              hintText: '123456',
                              hintStyle: TextStyle(
                                color: Color(0xFF475569),
                                letterSpacing: 8,
                              ),
                              counterText: '',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // Auto-fill Demo Code button
                        Center(
                          child: TextButton.icon(
                            onPressed: _autoFill,
                            icon: const Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: Color(0xFFFF6B00),
                            ),
                            label: Text(
                              'Auto-fill Demo Code (123456)',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFFF6B00),
                              ),
                            ),
                          ),
                        ),

                        if (_errorMsg != null) ...[
                          const SizedBox(height: 10),
                          Text(
                            _errorMsg!,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: AppTheme.crimson,
                              fontSize: 12,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Verify Button
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF6B00), Color(0xFFE55F00)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF6B00).withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                                      const Icon(
                                        Icons.check_circle_outline,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Verify & Sign In',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),
                        const Divider(color: Color(0xFF1E3054), height: 1),
                        const SizedBox(height: 16),

                        // Resend OTP
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Didn't receive code? ",
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Simulated new OTP dispatched (123456)'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Resend OTP',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
