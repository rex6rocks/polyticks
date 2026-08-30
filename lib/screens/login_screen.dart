import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  String _selectedCountryCode = '+1';
  bool _isLoading = false;

  final List<String> _countryCodes = ['+1', '+91', '+44', '+61', '+81'];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool get _isPhoneValid => _phoneController.text.trim().length >= 7;

  Future<void> _sendOTP() async {
    if (!_isPhoneValid) return;
    setState(() => _isLoading = true);

    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
    setState(() => _isLoading = false);

    final fullPhone = '$_selectedCountryCode ${_phoneController.text.trim()}';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OTPVerificationScreen(phoneNumber: fullPhone),
      ),
    );
  }

  void _handleSendOTP() {
    _sendOTP();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.deepNavy,
              AppTheme.navyCard,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Logo / Title
                  Icon(
                    Icons.how_to_vote,
                    size: 80,
                    color: AppTheme.saffron,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Polyticks',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Subtitle
                  Text(
                    'Enter your phone number to join local discourse',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      color: const Color(0xFF64748B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 48),
                  // Phone Input Row with Country Code Dropdown
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Country Code Dropdown
                      Container(
                        height: 56,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.navyCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF243450),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCountryCode,
                            dropdownColor: AppTheme.navyCard,
                            icon: const Icon(Icons.arrow_drop_down, color: AppTheme.saffron),
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() => _selectedCountryCode = newValue);
                              }
                            },
                            items: _countryCodes.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Phone Number
                      Expanded(
                        child: CustomTextField(
                          controller: _phoneController,
                          hintText: 'Phone number',
                          keyboardType: TextInputType.phone,
                          prefixIcon: Icons.phone,
                          labelText: 'Phone',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Send OTP Button
                  PrimaryButton(
                    label: 'Send OTP',
                    onPressed: _isPhoneValid && !_isLoading ? _handleSendOTP : null,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),
                  // Terms of Service Text (optional UI element)
                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms of Service',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF455A64),
                      ),
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