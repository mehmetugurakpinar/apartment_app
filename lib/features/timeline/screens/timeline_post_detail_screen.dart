import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import 'timeline_screen.dart';

// ---------------------------------------------------------------------------
// Comment model
// ---------------------------------------------------------------------------

class TimelineComment {
  final String id;
  final String postId;
  final String? parentId;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String body;
  final DateTime createdAt;

  const TimelineComment({
    required this.id,
    required this.postId,
    this.parentId,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    required this.body,
    required this.createdAt,
  });

  factory TimelineComment.fromJson(Map<String, dynamic> json) {
    return TimelineComment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      parentId: json['parent_id'] as String?,
      authorId: json['author_id'] as String,
      authorName: json['author_name'] as String? ?? 'Unknown',
      authorAvatar: json['author_avatar'] as String?,
      body: json['body'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TimelinePostDetailScreen extends ConsumerStatefulWidget {
  final String postId;
  const TimelinePostDetailScreen({super.key, required this.postId});

  @override
  ConsumerState<TimelinePostDetailScreen> createState() =>
      _TimelinePostDetailScreenState();
}

class _TimelinePostDetailScreenState
    extends ConsumerState<TimelinePostDetailScreen> {
  TimelinePost? _post;
  List<TimelineComment> _comments = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _error;
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final postRes = await api.getTimelinePost(widget.postId);
      final postData = postRes.data['data'];
      _post = TimelinePost.fromJson(postData as Map<String, dynamic>);

      final commentsRes = await api.getTimelineComments(widget.postId);
      final commentsData = commentsRes.data['data'];
      _comments = (commentsData as List?)
              ?.map(
                  (e) => TimelineComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _sendComment() async {
    final body = _commentController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.addTimelineComment(widget.postId, {'body': body});
      _commentController.clear();
      await _loadData();
      // Scroll to bottom after adding comment
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send comment: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text(_error!,
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        color: AppColors.primary,
                        child: ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 16),
                          children: [
                            // Post content
                            if (_post != null) _PostHeader(post: _post!),
                            const Divider(height: 1),
                            // Comments header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                              child: Text(
                                'Comments (${_comments.length})',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            // Comments list
                            if (_comments.isEmpty)
                              Padding(
                                padding: const EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'No comments yet. Be the first!',
                                    style:
                                        theme.textTheme.bodyMedium?.copyWith(
                                      color: AppColors.textHint,
                                    ),
                                  ),
                                ),
                              )
                            else
                              ..._comments
                                  .map((c) => _CommentTile(comment: c)),
                          ],
                        ),
                      ),
                    ),
                    // Comment input
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        border: Border(
                          top: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        8,
                        8 + MediaQuery.of(context).viewPadding.bottom,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              decoration: InputDecoration(
                                hintText: 'Write a comment...',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  borderSide:
                                      BorderSide(color: Colors.grey.shade300),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                isDense: true,
                              ),
                              enabled: !_isSending,
                              onSubmitted: (_) => _sendComment(),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: _isSending ? null : _sendComment,
                            icon: _isSending
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                : const Icon(Icons.send_rounded),
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post header widget (shows full post at top)
// ---------------------------------------------------------------------------

class _PostHeader extends StatelessWidget {
  final TimelinePost post;
  const _PostHeader({required this.post});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                child: Text(
                  post.authorName.isNotEmpty
                      ? post.authorName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.authorName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatTime(post.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Content
          if (post.content.isNotEmpty)
            Text(
              post.content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          const SizedBox(height: 12),
          // Stats
          Row(
            children: [
              if (post.likeCount > 0) ...[
                const Icon(Icons.thumb_up_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('${post.likeCount}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
              if (post.repostCount > 0) ...[
                const SizedBox(width: 14),
                const Icon(Icons.repeat_rounded, size: 14, color: Colors.green),
                const SizedBox(width: 4),
                Text('${post.repostCount}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
              if (post.commentCount > 0) ...[
                const SizedBox(width: 14),
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text('${post.commentCount}',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: AppColors.textSecondary)),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// Comment tile
// ---------------------------------------------------------------------------

class _CommentTile extends StatelessWidget {
  final TimelineComment comment;
  const _CommentTile({required this.comment});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = DateTime.now().difference(comment.createdAt);
    final timeStr = diff.inMinutes < 60
        ? '${diff.inMinutes}m'
        : diff.inHours < 24
            ? '${diff.inHours}h'
            : '${diff.inDays}d';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              comment.authorName.isNotEmpty
                  ? comment.authorName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          comment.authorName,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        timeStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    comment.body,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
