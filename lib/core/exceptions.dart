// ─────────────────────────────────────────────
//  Polyticks – Core Domain Exceptions & RLS Mapper
// ─────────────────────────────────────────────

import 'package:supabase_flutter/supabase_flutter.dart';

abstract class PolyticksDomainException implements Exception {
  final String message;
  final String userFriendlyMessage;
  final String? code;

  const PolyticksDomainException({
    required this.message,
    required this.userFriendlyMessage,
    this.code,
  });

  @override
  String toString() => '$runtimeType: $message (Code: $code)';
}

class VerificationRequiredException extends PolyticksDomainException {
  const VerificationRequiredException({
    super.message = 'Action restricted to verified civic accounts.',
    super.userFriendlyMessage = 'Only ID-verified citizens can submit Community Notes or vote on factual accuracy. Please complete ID verification in your profile.',
    super.code = 'RLS_UNVERIFIED_ACCOUNT',
  });
}

class RateLimitExceededException extends PolyticksDomainException {
  const RateLimitExceededException({
    super.message = 'Exceeded 5 fact-check submissions in a 24-hour window.',
    super.userFriendlyMessage = 'You have reached the maximum limit of 5 fact-check submissions for today. Please try again tomorrow.',
    super.code = 'RLS_RATE_LIMIT_EXCEEDED',
  });
}

class DuplicateVoteException extends PolyticksDomainException {
  const DuplicateVoteException({
    super.message = 'User has already recorded a vote for this fact-check note.',
    super.userFriendlyMessage = 'You have already voted on this context note.',
    super.code = 'DB_DUPLICATE_VOTE',
  });
}

class AdminPrivilegeRequiredException extends PolyticksDomainException {
  const AdminPrivilegeRequiredException({
    super.message = 'Action restricted to Polyticks System Administrators.',
    super.userFriendlyMessage = 'Access denied. Administrator privileges are required to view moderation reports.',
    super.code = 'RLS_ADMIN_RESTRICTED',
  });
}

class UnknownSecurityException extends PolyticksDomainException {
  const UnknownSecurityException({
    required super.message,
    super.userFriendlyMessage = 'Security policy check failed. Please check your account permissions.',
    super.code = 'RLS_SECURITY_VIOLATION',
  });
}

/// V4.0 — raised when the DigiLocker automated verification flow fails
/// (edge function error, state mismatch, provider rejection, or the flow
/// being disabled / unavailable on the current platform).
class DigiLockerFlowException extends PolyticksDomainException {
  const DigiLockerFlowException({
    required super.message,
    super.userFriendlyMessage =
        'DigiLocker verification could not be completed. Please try again, or use manual ID upload.',
    super.code = 'DIGILOCKER_FLOW_FAILED',
  });
}

/// V4.0 — raised when the paid-org subscription flow fails
/// (checkout/cancel errors, duplicate live subscription, missing plan).
class SubscriptionException extends PolyticksDomainException {
  const SubscriptionException({
    required super.message,
    required super.userFriendlyMessage,
    super.code = 'SUB_FLOW_FAILED',
  });
}

/// V4.0 B11 — raised when the Right-of-Reply flow fails
/// (tier gate, length validation, submit/withdraw errors).
class RightOfReplyException extends PolyticksDomainException {
  const RightOfReplyException({
    required super.message,
    required super.userFriendlyMessage,
    super.code = 'ROR_FLOW_FAILED',
  });
}

class RlsExceptionMapper {
  static PolyticksDomainException mapPostgrestException(PostgrestException exception) {
    final code = exception.code;
    final details = (exception.details?.toString() ?? '').toLowerCase();
    final message = exception.message.toLowerCase();

    // 1. Check for Unique Constraint Violation (Double Vote)
    if (code == '23505' || message.contains('uq_one_vote_per_user_per_fact_check')) {
      return const DuplicateVoteException();
    }

    // 2. Check for RLS Policy Violations (Postgres 42501)
    if (code == '42501') {
      // Check if it's the 5-per-24h rate limit rule
      if (details.contains('fact_check_rate_limit_ok') || 
          message.contains('rate_limit') ||
          details.contains('fact_checks_insert_verified_only')) {
        return const RateLimitExceededException();
      }

      // Check if it's an unverified user attempting verification-gated actions
      if (details.contains('is_verified_submitter') ||
          message.contains('fact_checks') ||
          message.contains('fact_check_votes')) {
        return const VerificationRequiredException();
      }

      // Check if it's admin reports access
      if (message.contains('reports') || details.contains('admin')) {
        return const AdminPrivilegeRequiredException();
      }

      return UnknownSecurityException(message: exception.message);
    }

    return UnknownSecurityException(message: exception.message);
  }
}
