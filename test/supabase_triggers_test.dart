//
// supabase_triggers_test.dart
//
// Integration tests for Supabase triggers.
//
// Environment Variables Required:
// - SUPABASE_TEST_URL: Supabase project URL for testing.
// - SUPABASE_TEST_PUBLISHABLE_KEY: Supabase publishable key for testing.
//

import 'dart:io'; // For accessing environment variables.
import 'package:flutter_test/flutter_test.dart';
import 'package:polyticks/services/supabase_service.dart';

void main() {
  group('Supabase Triggers', () {
    late SupabaseService supabaseService;

    setUp(() async {
      // Load Supabase credentials from environment variables.
      final supabaseUrl = Platform.environment['SUPABASE_TEST_URL'];
      final supabaseKey = Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY'];

      if (supabaseUrl == null || supabaseKey == null) {
        throw Exception(
          'Supabase test credentials not found. '
          'Set SUPABASE_TEST_URL and SUPABASE_TEST_PUBLISHABLE_KEY environment variables.',
        );
      }

      supabaseService = SupabaseService.instance;
      await supabaseService.initialize(
        url: supabaseUrl,
        publishableKey: supabaseKey,
      );
    });

    test('evaluate_post_dislike_threshold triggers fact_check_status update', () async {
      // Simulate 25+ votes with >60% dislikes
      final postId = 'test_post_id';
      final totalVotes = 25;
      final dislikes = 16; // 64% dislikes

      // Insert test post
      await supabaseService.client?.from('posts').insert({
        'id': postId,
        'content': 'Test post content',
        'fact_check_status': 'none',
      });

      // Insert votes
      for (int i = 0; i < totalVotes; i++) {
        await supabaseService.client?.from('reactions').insert({
          'post_id': postId,
          'user_id': 'user_$i',
          'reaction_type': i < dislikes ? 'dislike' : 'like',
        });
      }

      // Wait for trigger to execute
      await Future.delayed(const Duration(seconds: 2));

      // Verify fact_check_status is updated
      final post = await supabaseService.client
          ?.from('posts')
          .select()
          .eq('id', postId)
          .single();

      expect(post?['fact_check_status'], 'under_review');
    });

    test('recalculate_fact_check_votes triggers post status update', () async {
      // Simulate a fact-check note with 10+ upvotes
      final postId = 'test_post_id';
      final noteId = 'test_note_id';

      // Insert test post
      await supabaseService.client?.from('posts').insert({
        'id': postId,
        'content': 'Test post content',
        'fact_check_status': 'under_review',
      });

      // Insert test note
      await supabaseService.client?.from('fact_checks').insert({
        'id': noteId,
        'post_id': postId,
        'user_id': 'user_1',
        'context_note': 'Test context note',
        'sources': ['https://example.com'],
        'upvotes': 0,
        'downvotes': 0,
      });

      // Insert 10 upvotes
      for (int i = 0; i < 10; i++) {
        await supabaseService.client?.from('fact_check_votes').insert({
          'note_id': noteId,
          'user_id': 'user_$i',
          'vote_type': 'upvote',
        });
      }

      // Wait for trigger to execute
      await Future.delayed(const Duration(seconds: 2));

      // Verify post status is updated
      final post = await supabaseService.client
          ?.from('posts')
          .select()
          .eq('id', postId)
          .single();

      expect(post?['fact_check_status'], 'verified_context');
    });
  });
}
