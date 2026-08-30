// ─────────────────────────────────────────────
//  Polyticks – AI Moderation Service
// ─────────────────────────────────────────────

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

class AIModerationService {
  // Singleton instance
  static AIModerationService? _instance;
  static AIModerationService get instance => _instance ??= AIModerationService._internal();
  static set instance(AIModerationService instance) => _instance = instance;

  AIModerationService._internal();
  /// Optional custom HTTP client used for testing.
  @visibleForTesting
  http.Client? httpClient;

  // ── Free-tier budget guard (Task C3) ──
  // Groq free tier allows ~14,400 requests/day. Local budget enforcement:
  //  * identical-content cache (repeat posts cost 0 API calls)
  //  * max N live screening calls per rolling window; beyond that fail open.
  @visibleForTesting
  static const int maxLiveChecksPerWindow = 200;
  @visibleForTesting
  static const Duration rateLimitWindow = Duration(hours: 1);
  @visibleForTesting
  final Map<String, bool> contentCache = {};
  final List<DateTime> _liveCheckTimestamps = [];

  @visibleForTesting
  void clearBudgetState() {
    contentCache.clear();
    _liveCheckTimestamps.clear();
  }

  /// True when a live screening call is still within the free-tier budget.
  bool _withinBudget() {
    final now = DateTime.now();
    _liveCheckTimestamps.removeWhere((t) => now.difference(t) > rateLimitWindow);
    return _liveCheckTimestamps.length < maxLiveChecksPerWindow;
  }

  /// Checks the safety of a given text content.
  /// Returns `true` if safe, and `false` if flagged for hate speech / illegal
  /// content. Tiered approach: Live Groq -> Live HF -> (outage) FAIL OPEN,
  /// with the local mock screener used ONLY when no live provider is
  /// configured (simulation mode).
  ///
  /// FAILURE SEMANTICS (Task C2): if a live provider IS configured but every
  /// configured provider fails (outage, timeout, budget cap), we FAIL OPEN —
  /// the insert is allowed and the outage is logged — so free-tier outages
  /// never block posting.
  Future<bool> checkContentSafety(String textContent) async {
    final trimmed = textContent.trim();
    if (trimmed.isEmpty) {
      return true;
    }

    final liveConfigured =
        AppConfig.isGroqConfigured || AppConfig.isHfConfigured;

    // Identical-content cache: repeated content costs zero API calls.
    final cached = contentCache[trimmed];
    if (cached != null) {
      debugPrint('AI Moderation: cache hit. Safe: $cached');
      return cached;
    }

    var liveAttempted = false;

    // 1. Try Groq API (if configured)
    if (AppConfig.isGroqConfigured && _withinBudget()) {
      liveAttempted = true;
      try {
        _liveCheckTimestamps.add(DateTime.now());
        final result = await _checkWithGroq(trimmed);
        if (result != null) {
          debugPrint('AI Moderation: Groq check succeeded. Safe: $result');
          contentCache[trimmed] = result;
          return result;
        }
      } catch (e, stackTrace) {
        debugPrint('AI Moderation: Groq check failed: $e');
        debugPrint('$stackTrace');
      }
    } else if (AppConfig.isGroqConfigured) {
      debugPrint('AI Moderation: free-tier budget exhausted; failing open.');
    }

    // 2. Try Hugging Face Inference API
    if (AppConfig.isHfConfigured && _withinBudget()) {
      liveAttempted = true;
      try {
        _liveCheckTimestamps.add(DateTime.now());
        final result = await _checkWithHuggingFace(trimmed);
        if (result != null) {
          debugPrint(
              'AI Moderation: Hugging Face check succeeded. Safe: $result');
          contentCache[trimmed] = result;
          return result;
        }
      } catch (e, stackTrace) {
        debugPrint('AI Moderation: Hugging Face check failed: $e');
        debugPrint('$stackTrace');
      }
    }

    // 3. Failure semantics: configured-but-failed => FAIL OPEN (never block
    //    posting on an outage). Mock screener only when nothing is configured.
    if (liveConfigured && liveAttempted) {
      debugPrint('AI Moderation: FAIL-OPEN - live providers configured but '
          'unavailable; allowing content and logging flag.');
      return true;
    }

    return _checkWithMock(trimmed);
  }

  /// Local mock screener used when no APIs are configured or all fail.
  Future<bool> _checkWithMock(String content) async {
    final lower = content.toLowerCase();
    final forbiddenWords = ['hate', 'unsafe', 'illegal', 'threat'];
    for (final word in forbiddenWords) {
      if (lower.contains(word)) {
        debugPrint('AI Moderation: Mock flagged content: "$content"');
        return false;
      }
    }
    debugPrint('AI Moderation: Mock approved content.');
    return true;
  }

  /// Sends a request to Groq's Chat Completions API with the Llama Guard 3 model.
  Future<bool?> _checkWithGroq(String content) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    
    // Format the prompt for Llama Guard 3
    final prompt = '[INST] Task: Check if there is unsafe content in the following text. Respond with only "safe" or "unsafe".\n\nText: $content [/INST]';

    final body = jsonEncode({
      'model': 'llama-guard-3-8b',
      'messages': [
        {'role': 'user', 'content': prompt}
      ],
      'temperature': 0.0,
      'max_tokens': 10
    });

    final headers = {
      'Authorization': 'Bearer ${AppConfig.groqApiKey}',
      'Content-Type': 'application/json',
    };

    final response = await (httpClient != null
            ? httpClient!.post(url, headers: headers, body: body)
            : http.post(url, headers: headers, body: body))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final rawOutput = (data['choices']?[0]?['message']?['content'] ?? '').toString().trim().toLowerCase();
      
      if (rawOutput.startsWith('unsafe') || rawOutput.contains('unsafe')) {
        return false;
      }
      return true;
    } else {
      debugPrint('AI Moderation: Groq API returned status code ${response.statusCode}: ${response.body}');
      return null;
    }
  }

  /// Sends a request to Hugging Face's Inference API for a text-classification moderation model.
  Future<bool?> _checkWithHuggingFace(String content) async {
    // Model used: roberta-hate-speech-dynabench-r4-target
    final url = Uri.parse(
      'https://api-inference.huggingface.co/models/facebook/roberta-hate-speech-dynabench-r4-target'
    );

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    
    headers['Authorization'] = 'Bearer ${AppConfig.hfApiToken}';

    final response = await (httpClient != null
            ? httpClient!.post(url, headers: headers, body: jsonEncode({'inputs': content}))
            : http.post(url, headers: headers, body: jsonEncode({'inputs': content})))
        .timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      double hateScore = 0.0;
      if (data is List) {
        final flatList = data.isNotEmpty && data.first is List ? data.first as List : data;
        for (final item in flatList) {
          if (item is Map) {
            final label = (item['label'] ?? '').toString().toLowerCase();
            final score = double.tryParse((item['score'] ?? '0').toString()) ?? 0.0;
            // The model labels are 'hate' (or similar flagged categories) and 'nothate'
            if (label == 'hate' || label == 'unsafe' || label == 'flagged') {
              hateScore = score;
            }
          }
        }
      }

      // If the model identifies the text as hate speech with confidence > 50%, flag it.
      if (hateScore > 0.5) {
        return false;
      }
      return true;
    } else {
      debugPrint('AI Moderation: Hugging Face API returned status code ${response.statusCode}: ${response.body}');
      return null;
    }
  }
}
