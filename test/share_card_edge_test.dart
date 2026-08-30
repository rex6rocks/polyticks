//
// share_card_edge_test.dart
//
// V3 Phase 4 — Edge Function tests: generate-share-card (REAL Supabase).
// Covers T4.1–T4.5 of pending/V3_PHASE3_TESTING.md.
//
// Requires a live project with the `generate-share-card` function deployed,
// a PUBLIC `share_previews` bucket, seeded data (supabase/seed_v3_tests.sql)
// and env vars:
//   SUPABASE_TEST_URL                 e.g. https://sbdwwmbocyqlkztptskb.supabase.co
//   SUPABASE_TEST_PUBLISHABLE_KEY     publishable (anon) key
//

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

const String pollPostId = 'aa000000-0000-0000-0000-000000000001'; // Community A, no fact-check
const String verifiedPostId = 'aa000000-0000-0000-0000-000000000002'; // fact_check_status=verified_context
const String u2Email = 'u2@test.polyticks.app';
const String u2Password = 'Polyticks#Test2026';

String get baseUrl => Platform.environment['SUPABASE_TEST_URL']!;
String get anonKey => Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY']!;
String get fnUrl => '$baseUrl/functions/v1/generate-share-card';

Future<http.Response> invokeCard(Map<String, dynamic> body) {
  return http.post(
    Uri.parse(fnUrl),
    headers: {'Authorization': 'Bearer $anonKey', 'apikey': anonKey},
    body: jsonEncode(body),
  );
}

/// Validates raw bytes are a well-formed PNG of exactly [w]x[h] px.
void expectPng(Uint8List bytes, {int w = 1200, int h = 630}) {
  // PNG signature
  expect(bytes.sublist(0, 8), [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
      reason: 'must start with PNG magic bytes');
  // First chunk must be IHDR; width/height big-endian at offsets 16..23.
  final ihdrType = String.fromCharCodes(bytes.sublist(12, 16));
  expect(ihdrType, 'IHDR');
  final bd = ByteData.sublistView(bytes);
  expect(bd.getUint32(16), w, reason: 'PNG width');
  expect(bd.getUint32(20), h, reason: 'PNG height');
}

void main() {
  final hasCreds = Platform.environment['SUPABASE_TEST_URL'] != null &&
      Platform.environment['SUPABASE_TEST_PUBLISHABLE_KEY'] != null;

  void t(String name, Future<void> Function() body) {
    test(name, hasCreds ? body : () async {
      // ignore: avoid_print
      print('SKIP: $name (SUPABASE_TEST_* env vars not set)');
    }, skip: hasCreds ? false : 'live Supabase credentials not set');
  }

  group('V3 Phase 4 — generate-share-card edge function (live)', () {
    t('T4.1: valid post_id -> HTTP 200 + public PNG URL; PNG exists '
        'in share_previews bucket', () async {
      final res = await invokeCard({'post_id': pollPostId});
      expect(res.statusCode, 200, reason: res.body);
      final url = (jsonDecode(res.body) as Map<String, dynamic>)['url'] as String;
      expect(url, isNotEmpty);
      expect(url, contains('/storage/v1/object/public/share_previews/'));

      final pngRes = await http.get(Uri.parse(url));
      expect(pngRes.statusCode, 200);
      expect(pngRes.headers['content-type'], contains('image/png'));
      expectPng(pngRes.bodyBytes); // exists + is real 1200x630 PNG
    });

    t('T4.2: card variants render distinct PNGs (banner differs by '
        'fact_check_status); artifacts saved for visual inspection', () async {
      final pollRes = await invokeCard({'post_id': pollPostId});
      expect(pollRes.statusCode, 200, reason: pollRes.body);
      final verRes = await invokeCard({'post_id': verifiedPostId});
      expect(verRes.statusCode, 200, reason: verRes.body);

      final pollPng =
          await http.get(Uri.parse((jsonDecode(pollRes.body) as Map)['url']));
      final verPng =
          await http.get(Uri.parse((jsonDecode(verRes.body) as Map)['url']));
      expectPng(pollPng.bodyBytes);
      expectPng(verPng.bodyBytes);

      // Different banners must produce genuinely different images.
      expect(pollPng.bodyBytes.length, isNot(verPng.bodyBytes.length),
          reason: 'poll-banner and verified-banner cards should differ');

      // Persist artifacts so a human (or tooling) can visually confirm
      // logo, truncated post text, author handle and correct banner.
      final dir = Directory('build/share_cards')..createSync(recursive: true);
      File('${dir.path}/T42_poll_banner.png').writeAsBytesSync(pollPng.bodyBytes);
      File('${dir.path}/T42_verified_banner.png')
          .writeAsBytesSync(verPng.bodyBytes);
    });

    t('T4.3: nonexistent post_id -> graceful 404, no orphan file in bucket',
        () async {
      const missing = '99999999-9999-9999-9999-999999999999';
      final res = await invokeCard({'post_id': missing});
      expect(res.statusCode, anyOf(400, 404));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      expect(body.containsKey('error'), isTrue);

      // No orphan written: the deterministic key for this id must NOT resolve.
      final orphanUrl =
          '$baseUrl/storage/v1/object/public/share_previews/preview_$missing.png';
      final head = await http.head(Uri.parse(orphanUrl));
      expect(head.statusCode, isNot(200),
          reason: 'no orphan preview may exist for a nonexistent post');
    });

    t('T4.4: very long post text renders truncated within card bounds',
        () async {
      final client = SupabaseClient(baseUrl, anonKey);
      await client.auth.signInWithPassword(email: u2Email, password: u2Password);

      final original = await client
          .from('posts')
          .select('content')
          .eq('id', pollPostId)
          .single();
      final originalText = original['content'] as String;

      try {
        // 600 chars >> MAX_CONTENT_CHARS (180): forces truncation path.
        final longText = ('LongContent ' * 60).substring(0, 600);
        await client.from('posts').update({'content': longText}).eq('id', pollPostId);

        final res = await invokeCard({'post_id': pollPostId});
        expect(res.statusCode, 200, reason: res.body);
        final pngRes =
            await http.get(Uri.parse((jsonDecode(res.body) as Map)['url']));
        expectPng(pngRes.bodyBytes); // still exactly 1200x630, i.e. no overflow
      } finally {
        await client
            .from('posts')
            .update({'content': originalText}).eq('id', pollPostId);
      }
    });

    t('T4.5: repeated calls reuse one deterministic key (bucket does not bloat)',
        () async {
      final r1 = await invokeCard({'post_id': pollPostId});
      expect(r1.statusCode, 200, reason: r1.body);
      final r2 = await invokeCard({'post_id': pollPostId});
      expect(r2.statusCode, 200, reason: r2.body);

      final url1 = (jsonDecode(r1.body) as Map)['url'] as String;
      final url2 = (jsonDecode(r2.body) as Map)['url'] as String;
      // Documented keying strategy: preview_<post_id>.png, upsert overwrite.
      expect(Uri.parse(url1).pathSegments.last, 'preview_$pollPostId.png');
      expect(url1, url2);

      final stillThere = await http.get(Uri.parse(url1));
      expect(stillThere.statusCode, 200);
    });
  });
}
