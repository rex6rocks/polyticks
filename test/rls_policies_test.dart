//
// rls_policies_test.dart
//
// Integration tests for Row-Level Security (RLS) policies.
//

import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/services/supabase_service.dart';

void main() {
  group('RLS Policies', () {
    late SupabaseService supabaseService;

    setUp(() async {
      supabaseService = SupabaseService.instance;
      await supabaseService.initialize();
    });

    test('Unverified users cannot submit fact-checks', () async {
      // Simulate an unverified user
      await supabaseService.client?.auth.signInAnonymously();

      try {
        await supabaseService.client?.from('fact_checks').insert({
          'post_id': 'test_post_id',
          'user_id': 'unverified_user_id',
          'context_note': 'Test context note',
          'sources': ['https://example.com'],
        });
        fail('Unverified user should not be able to submit a fact-check');
      } catch (e) {
        expect(e.toString(), contains('new row violates row-level security'));
      }
    });

    test('Unverified users cannot vote on fact-checks', () async {
      // Simulate an unverified user
      await supabaseService.client?.auth.signInAnonymously();

      try {
        await supabaseService.client?.from('fact_check_votes').insert({
          'note_id': 'test_note_id',
          'user_id': 'unverified_user_id',
          'vote_type': 'upvote',
        });
        fail('Unverified user should not be able to vote on a fact-check');
      } catch (e) {
        expect(e.toString(), contains('new row violates row-level security'));
      }
    });

    test('Rate-limiting for fact-check submissions', () async {
      // Simulate a verified user
      final user = await supabaseService.client?.auth.signUp(
        email: 'test@example.com',
        password: 'password',
      );
      await supabaseService.client?.from('profiles').update({
        'is_verified': true,
      }).eq('id', user?.user?.id ?? '');

      // Submit 5 fact-checks (limit)
      for (int i = 0; i < 5; i++) {
        await supabaseService.client?.from('fact_checks').insert({
          'post_id': 'test_post_id_$i',
          'user_id': user?.user?.id,
          'context_note': 'Test context note $i',
          'sources': ['https://example.com'],
        });
      }

      // Attempt to submit a 6th fact-check (should fail)
      try {
        await supabaseService.client?.from('fact_checks').insert({
          'post_id': 'test_post_id_6',
          'user_id': user?.user?.id,
          'context_note': 'Test context note 6',
          'sources': ['https://example.com'],
        });
        fail('Rate-limiting should prevent more than 5 submissions per 24 hours');
      } catch (e) {
        expect(e.toString(), contains('new row violates row-level security'));
      }
    });
  });
}