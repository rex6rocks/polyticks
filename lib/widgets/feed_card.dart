import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/fact_check_provider.dart';
import 'interactive_widgets.dart';

class FeedCard extends ConsumerWidget {
  final String postId;
  final String authorName;
  final String handle;
  final String timestamp;
  final String content;
  final String? mediaUrl;

  const FeedCard({
    super.key,
    required this.postId,
    required this.authorName,
    required this.handle,
    required this.timestamp,
    required this.content,
    this.mediaUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // If your class is FactCheckNotifier:
    final AsyncValue<FactCheckState> factCheckStateAsync =
        ref.watch(factCheckNotifierProvider(postId));

    // (Or if your class was named FactCheck, use ref.watch(factCheckProvider(postId)))

    final String displayContent =
        content.length > 280 ? '${content.substring(0, 280)}...' : content;

    return factCheckStateAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
      data: (FactCheckState factCheckState) {
        final List<Widget> children = [];

        // 1. Fact-Check Banner (shown if isBannerVisible is true)
        if (factCheckState.isBannerVisible) {
          children.addAll([
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Colors.orange[50],
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange[800],
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      'This post is under review for accuracy.',
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.orange[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
          ]);
        }

        // 2. Community Note Preview (shown if communityNotePreview is not null)
        if (factCheckState.communityNotePreview != null) {
          children.addAll([
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              color: Colors.blue[50],
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue[800],
                    size: 20.0,
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: Text(
                      factCheckState.communityNotePreview!,
                      style: TextStyle(
                        fontSize: 13.0,
                        color: Colors.blue[900],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8.0),
          ]);
        }

        // 3. Post Card
        children.add(
          Card(
            margin: const EdgeInsets.all(0),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Info
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20.0,
                        backgroundColor: Colors.grey[300],
                      ),
                      const SizedBox(width: 12.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorName,
                              style: const TextStyle(
                                fontSize: 15.0,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2.0),
                            Row(
                              children: [
                                Text(
                                  handle.startsWith('@') ? handle : '@$handle',
                                  style: TextStyle(
                                    fontSize: 14.0,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  '•',
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: Colors.grey[500],
                                  ),
                                ),
                                const SizedBox(width: 6.0),
                                Text(
                                  timestamp,
                                  style: TextStyle(
                                    fontSize: 13.0,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),

                  // Post Content
                  Text(
                    displayContent,
                    style: const TextStyle(fontSize: 15.0),
                  ),
                  const SizedBox(height: 12.0),

                  // Media Preview (if available)
                  if (mediaUrl != null) ...[
                    Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        color: Colors.grey[200],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12.0),
                        child: Image.network(
                          mediaUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 140,
                              alignment: Alignment.center,
                              color: Colors.grey[200],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.broken_image_outlined,
                                      size: 36, color: Colors.grey[500]),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Media unavailable',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12.0),
                  ],

                  const Divider(height: 1, thickness: 0.5),
                  const SizedBox(height: 4.0),

                  // Embedded ReactionRow
                  const ReactionRow(),
                ],
              ),
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        );
      },
    );
  }
}
