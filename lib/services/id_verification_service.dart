import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:polyticks/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';
import 'image_compressor.dart';

class IDVerificationService {
  IDVerificationService._();

  /// Compresses the image and uploads it to the private bucket,
  /// then updates the profile status.
  ///
  /// V4.0: manual upload is the WEB fallback once DigiLocker is live
  /// (credentials configured). While DigiLocker is deferred (v6), mobile
  /// keeps manual upload as its only path. Simulation mode remains
  /// available for tests / offline development.
  static Future<void> processIDVerification(String userId, File rawFile) async {
    if (SupabaseService.instance.isRealSupabase &&
        !kIsWeb &&
        AppConfig.isDigilockerEnabled) {
      throw UnsupportedError(
          'Manual ID upload is restricted to the web client while instant '
          'DigiLocker verification is enabled. Use DigiLockerVerificationService.');
    }
    try {
      // 1. Compress
      final compressedPath = await ImageCompressor.compressId(rawFile.path);
      final compressedFile = File(compressedPath);

      if (SupabaseService.instance.isRealSupabase &&
          SupabaseService.instance.client != null) {
        // 2. Upload
        final supabase = SupabaseService.instance.client!;
        final path = '$userId/id_verification.jpg';

        await supabase.storage.from('id-verifications').upload(
              path,
              compressedFile,
              fileOptions: const FileOptions(upsert: true),
            );

        // 3. Update profile
        await supabase
            .from('profiles')
            .update({'verification_status': 'pending'}).eq('id', userId);
      }

      debugPrint('ID Verification submitted for user: $userId');
    } catch (e) {
      debugPrint('Error in processIDVerification: $e');
      rethrow;
    }
  }
}
