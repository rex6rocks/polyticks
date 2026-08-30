import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/services/auth_service.dart';
import 'package:polyticks/config.dart';

void main() {
  group('AuthService - Test Credential OTP Login', () {
    late AuthService authService;

    setUp(() {
      // Force test mode
      AppConfig.forceTestMode = true;
      // Initialize AuthService
      authService = AuthService();
    });

    test('should successfully login with test credentials via OTP', () async {
      // Arrange
      const testPhoneNumber = AuthService.testPhoneNumber;
      const testOtpCode = AuthService.testOtpCode;

      // Act
      await authService.sendOtp(phoneNumber: testPhoneNumber);
      final authResponse = await authService.verifyOtp(
        phoneNumber: testPhoneNumber,
        token: testOtpCode,
      );

      // Assert
      expect(authResponse.user, isNotNull);
      expect(authResponse.user!.id, 'test-user-id');
      expect(authResponse.user!.phone, testPhoneNumber);
      expect(authResponse.session, isNotNull);
      expect(authResponse.session!.accessToken, 'test-access-token');
    });

    test('should fail login with incorrect OTP for test credentials', () async {
      // Arrange
      const testPhoneNumber = AuthService.testPhoneNumber;
      const incorrectOtpCode = '000000';

      // Act
      await authService.sendOtp(phoneNumber: testPhoneNumber);
      
      // For incorrect OTP, _isTestCredential is true, but token is not matching testOtpCode, 
      // so it hits the Supabase check which throws as _supabase is null in test mode.
      // We should expect an Exception here if it's hitting the supabase path.
      
      expect(() async => await authService.verifyOtp(
        phoneNumber: testPhoneNumber,
        token: incorrectOtpCode,
      ), throwsException);
    });
  });
}

// Mock removed as it was unused and broken.
