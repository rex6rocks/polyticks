// ─────────────────────────────────────────────
//  Polyticks – Supabase Client Singleton Wrapper
// ─────────────────────────────────────────────
//
//  This file provides a singleton wrapper for Supabase client initialization
//  and helper getters for accessing SupabaseClient, auth, storage, and tables.
//
//  Usage:
//    await SupabaseClientWrapper.instance.initialize();
//    final client = SupabaseClientWrapper.instance.client;
//    final auth = SupabaseClientWrapper.instance.auth;
//    final storage = SupabaseClientWrapper.instance.storage;
//    final posts = SupabaseClientWrapper.instance.from('posts');

import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

/// Singleton wrapper for Supabase client initialization and access.
class SupabaseClientWrapper {
  // Singleton instance
  static final SupabaseClientWrapper instance = SupabaseClientWrapper._internal();
  SupabaseClientWrapper._internal();

  // Late-initialized Supabase client
  late SupabaseClient _client;

  /// Whether the Supabase client has been initialized.
  bool _isInitialized = false;

  /// Initialize the Supabase client with environment variables.
  /// Call this once at app startup before using any Supabase features.
  Future<void> initialize() async {
    if (_isInitialized) return;

    const url = AppConfig.supabaseUrl;
    const anonKey = AppConfig.supabaseAnonKey;

    if (url.isEmpty || anonKey.isEmpty) {
      throw Exception(
        'Supabase credentials not configured. Provide SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    await Supabase.initialize(url: url, publishableKey: anonKey);
    _client = Supabase.instance.client;
    _isInitialized = true;
  }

  /// Get the initialized [SupabaseClient].
  /// Throws if not initialized.
  SupabaseClient get client {
    if (!_isInitialized) {
      throw Exception('SupabaseClient not initialized. Call initialize() first.');
    }
    return _client;
  }

  /// Get the Supabase Auth client.
  GoTrueClient get auth {
    if (!_isInitialized) {
      throw Exception('SupabaseClient not initialized. Call initialize() first.');
    }
    return _client.auth;
  }

  /// Get the Supabase Storage client.
  SupabaseStorageClient get storage {
    if (!_isInitialized) {
      throw Exception('SupabaseClient not initialized. Call initialize() first.');
    }
    return _client.storage;
  }

  /// Get a Postgrest client for the specified table.
  /// Example: `instance.from('posts').select()`
  SupabaseQueryBuilder from(String table) {
    if (!_isInitialized) {
      throw Exception('SupabaseClient not initialized. Call initialize() first.');
    }
    return _client.from(table);
  }

  /// Check if the Supabase client is initialized.
  bool get isInitialized => _isInitialized;
}
