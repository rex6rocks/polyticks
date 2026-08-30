/// Custom exceptions for Supabase-related errors.
library;

/// Base class for all Supabase-related exceptions.
abstract class SupabaseException implements Exception {
  final String message;
  final String? details;

  const SupabaseException(this.message, {this.details});

  @override
  String toString() =>
      'SupabaseException: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Thrown when Supabase initialization fails.
class SupabaseInitializationException extends SupabaseException {
  const SupabaseInitializationException(super.message, {super.details});
}

/// Thrown when an authentication-related error occurs.
class SupabaseAuthException extends SupabaseException {
  const SupabaseAuthException(super.message, {super.details});
}

/// Thrown when a network-related error occurs.
class SupabaseNetworkException extends SupabaseException {
  const SupabaseNetworkException(super.message, {super.details});
}

/// Thrown when a database-related error occurs.
class SupabaseDatabaseException extends SupabaseException {
  const SupabaseDatabaseException(super.message, {super.details});
}

/// Thrown when a storage-related error occurs.
class SupabaseStorageException extends SupabaseException {
  const SupabaseStorageException(super.message, {super.details});
}
