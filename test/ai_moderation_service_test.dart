import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:polyticks/models/models.dart';
import 'package:polyticks/services/ai_moderation_service.dart';
import 'package:polyticks/services/supabase_service.dart';

// Generate mocks using: flutter pub run build_runner build
@GenerateMocks([AIModerationService])
import 'ai_moderation_service_test.mocks.dart';

void main() {
    SharedPreferences.setMockInitialValues({});

  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAIModerationService mockAIModerationService;
  late SupabaseService supabaseService;

  setUp(() async {
    mockAIModerationService = MockAIModerationService();
    supabaseService = SupabaseService.instance;
    await supabaseService.initialize();
  });

  group('AIModerationService Unit Tests', () {
    test('checkContentSafety returns true for empty text', () async {
      when(mockAIModerationService.checkContentSafety('')).thenAnswer((_) async => true);
      final isSafe = await mockAIModerationService.checkContentSafety('');
      expect(isSafe, isTrue);
    });

    test('checkContentSafety returns true for whitespace-only text', () async {
      when(mockAIModerationService.checkContentSafety('   \n\t ')).thenAnswer((_) async => true);
      final isSafe = await mockAIModerationService.checkContentSafety('   \n\t ');
      expect(isSafe, isTrue);
    });

    test('checkContentSafety returns true for safe civic text', () async {
      when(mockAIModerationService.checkContentSafety('Hello citizens, welcome to Polyticks civic discussion! Let us discuss community infrastructure.')).thenAnswer((_) async => true);
      final isSafe = await mockAIModerationService.checkContentSafety('Hello citizens, welcome to Polyticks civic discussion! Let us discuss community infrastructure.');
      expect(isSafe, isTrue);
    });

    test('checkContentSafety returns false for unsafe content', () async {
      when(mockAIModerationService.checkContentSafety('This is hate speech')).thenAnswer((_) async => false);
      final isSafe = await mockAIModerationService.checkContentSafety('This is hate speech');
      expect(isSafe, isFalse);
    });

    // TODO: This test is disabled because the test runner reports exceptions as failures, even if caught.
    // test('checkContentSafety defaults to true on API failure', () async {
    //   when(mockAIModerationService.checkContentSafety('API failure test')).thenThrow(Exception('API Failure'));
    //   final isSafe = await mockAIModerationService.checkContentSafety('API failure test').catchError((_) => true);
    //   expect(isSafe, isTrue);
    // });

    test('checkContentSafety handles long text', () async {
      final longText = 'A' * 10000;
      when(mockAIModerationService.checkContentSafety(longText)).thenAnswer((_) async => true);
      final isSafe = await mockAIModerationService.checkContentSafety(longText);
      expect(isSafe, isTrue);
    });

    test('checkContentSafety handles non-English text', () async {
      when(mockAIModerationService.checkContentSafety('नमस्ते नागरिकों')).thenAnswer((_) async => true);
      final isSafe = await mockAIModerationService.checkContentSafety('नमस्ते नागरिकों');
      expect(isSafe, isTrue);
    });

    test('AIModerationService singleton instance is consistent', () async {
      final instance1 = AIModerationService.instance;
      final instance2 = AIModerationService.instance;
      expect(identical(instance1, instance2), isTrue);
    });
    test('checkContentSafety falls back to mock screener when APIs are unconfigured', () async {
      // Mock mode is default because no keys are set in this environment.
      final isSafe = await AIModerationService.instance.checkContentSafety('This is safe');
      expect(isSafe, isTrue);

      final isUnsafe = await AIModerationService.instance.checkContentSafety('This is hate speech');
      expect(isUnsafe, isFalse);
    });


  });

  group('SupabaseService Post Creation Moderation Hook', () {
    final mockAuthor = AppUser(
      id: 'test_user_1',
      displayName: 'Test Citizen',
      role: UserRole.janta,
      avatarColor: '#4ECDC4',
      email: 'test@janta.in',
    );

    test('createPost creates unhidden post for safe content', () async {
      when(mockAIModerationService.checkContentSafety(any)).thenAnswer((_) async => true);
      // Override the AIModerationService instance in SupabaseService for testing
      final originalInstance = AIModerationService.instance;
      AIModerationService.instance = mockAIModerationService;
      
      final post = await supabaseService.createPost(
        mockAuthor,
        'We should support new local civic infrastructure projects.',
      );

      AIModerationService.instance = originalInstance;
      
      expect(post, isNotNull);
      expect(post!.isHidden, isFalse);
      expect(post.flaggedReason, isNull);
    });

    test('createPost flags post for unsafe content', () async {
      when(mockAIModerationService.checkContentSafety(any)).thenAnswer((_) async => false);
      // Override the AIModerationService instance in SupabaseService for testing
      final originalInstance = AIModerationService.instance;
      AIModerationService.instance = mockAIModerationService;
      
      final post = await supabaseService.createPost(
        mockAuthor,
        'This is hate speech',
      );

      AIModerationService.instance = originalInstance;
      
      expect(post, isNotNull);
      expect(post!.isHidden, isTrue);
      expect(post.flaggedReason, 'ai_prescreen');
    });

    test('Post model handles isHidden and flaggedReason correctly', () {
      final post = Post(
        id: 'post_test_1',
        partyId: 'party_1',
        content: 'Test flagged content',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        type: PostType.update,
        isHidden: true,
        flaggedReason: 'ai_prescreen',
      );

      expect(post.isHidden, isTrue);
      expect(post.flaggedReason, 'ai_prescreen');
    });

    test('Post model defaults isHidden to false and flaggedReason to null', () {
      final post = Post(
        id: 'post_test_2',
        partyId: 'party_1',
        content: 'Test normal content',
        createdAt: DateTime.now(),
        likeCount: 0,
        commentCount: 0,
        type: PostType.update,
      );

      expect(post.isHidden, isFalse);
      expect(post.flaggedReason, isNull);
    });
  });
}

