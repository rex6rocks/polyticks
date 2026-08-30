import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import '../models/user_profile.dart';

class AuthService {
  SupabaseClient? _supabase;
  UserProfile? currentUser;
  final List<VoidCallback> _listeners = [];

  // Test credentials for development/testing purposes
  static const String testPhoneNumber = '+11234567890';
  static const String testOtpCode = '999999';

  AuthService() {
    if (AppConfig.isSupabaseConfigured) {
      _supabase = Supabase.instance.client;
    }
  }

  /// Checks if the provided phone number matches test credentials
  bool _isTestCredential(String phoneNumber) {
    // Only allow test credentials if Supabase is NOT configured (i.e., in simulation mode)
    return !AppConfig.isSupabaseConfigured && phoneNumber == testPhoneNumber;
  }

  /// Formats a phone number to E.164 standard
  String _formatPhoneNumber(String phoneNumber) {
    // Remove all non-digit characters except leading +
    String digits = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    
    // If the number doesn't start with +, assume it's a US number and prepend +1
    if (!digits.startsWith('+')) {
      digits = '+1$digits';
    }
    
    return digits;
  }

  /// Sends a one-time password (OTP) to the provided phone number.
  /// For test credentials, this method will not send an actual OTP.
  Future<void> sendOtp({required String phoneNumber}) async {
    final formattedPhoneNumber = _formatPhoneNumber(phoneNumber);
    
    if (_isTestCredential(formattedPhoneNumber)) {
      // For test mode, don't actually send OTP - just return
      return;
    }
    
    if (_supabase == null) {
      throw Exception('Supabase is not configured. Cannot send OTP.');
    }
    
    try {
      await _supabase!.auth.signInWithOtp(phone: formattedPhoneNumber);
    } catch (e) {
      throw Exception('Failed to send OTP: ${e.toString()}');
    }
  }

  /// Verifies the OTP sent to the phone number.
  /// For test credentials, bypasses actual Supabase verification and returns a mock auth response.
  Future<AuthResponse> verifyOtp({
    required String phoneNumber,
    required String token,
  }) async {
    final formattedPhoneNumber = _formatPhoneNumber(phoneNumber);
    
    if (_isTestCredential(formattedPhoneNumber) && token == testOtpCode) {
      // Assign a mock UserProfile for testing
      currentUser = UserProfile(
        id: 'test-user-id',
        phone: testPhoneNumber,
        isVerified: false,
        createdAt: DateTime.now(),
      );
      
      // Notify listeners
      _notifyListeners();
      
      // Return a mock auth response for testing
      return AuthResponse(
        user: User(
          id: 'test-user-id',
          email: null,
          phone: testPhoneNumber,
          appMetadata: {'provider': 'phone', 'test_mode': true},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
        ),
        session: Session(
          accessToken: 'test-access-token',
          refreshToken: 'test-refresh-token',
          tokenType: 'bearer',
          user: User(
            id: 'test-user-id',
            email: null,
            phone: testPhoneNumber,
            appMetadata: {'provider': 'phone', 'test_mode': true},
            userMetadata: {},
            aud: 'authenticated',
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          ),
          expiresIn: 3600,
        ),
      );
    }
    
    if (_supabase == null) {
      throw Exception('Supabase is not configured. Cannot verify OTP.');
    }
    
    try {
      return await _supabase!.auth.verifyOTP(
        type: OtpType.sms,
        phone: formattedPhoneNumber,
        token: token,
      );
    } catch (e) {
      throw Exception('Failed to verify OTP: ${e.toString()}');
    }
  }

  /// Terminates the active session and signs the user out.
  Future<void> signOut() async {
    if (_supabase == null) {
      currentUser = null;
      _notifyListeners();
      return;
    }
    
    try {
      await _supabase!.auth.signOut();
      currentUser = null;
      _notifyListeners();
    } catch (e) {
      throw Exception('Failed to sign out: ${e.toString()}');
    }
  }

  /// Queries the 'profiles' table for the current authenticated user's profile.
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    if (_supabase == null) {
      return null;
    }

    final user = _supabase!.auth.currentUser;
    if (user == null) return null;

    try {
      final data = await _supabase!
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return data;
    } catch (e) {
      // Log error or handle appropriately in a real app
      return null;
    }
  }

  /// Adds a listener to be notified when the auth state changes.
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Removes a listener.
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notifies all listeners of auth state changes.
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }
}
