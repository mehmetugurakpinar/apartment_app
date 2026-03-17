import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

enum PostVisibility { building, neighborhood, public_ }

class PollOption {
  final String id;
  final String text;
  final int votes;

  const PollOption({required this.id, required this.text, required this.votes});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String,
      text: json['text'] as String,
      votes: json['votes'] as int? ?? 0,
    );
  }
}

class TimelinePost {
  final String id;
  final String authorName;
  final String? authorAvatar;
  final String content;
  final String? mediaUrl;
  final PostVisibility visibility;
  final int likeCount;
  final int commentCount;
  final int repostCount;
  final bool isLiked;
  final bool isReposted;
  final bool isRepost;
  final String? originalAuthorName;
  final DateTime createdAt;
  // Poll fields
  final bool isPoll;
  final String? pollQuestion;
  final List<PollOption>? pollOptions;
  final String? votedOptionId;
  final int totalPollVotes;

  const TimelinePost({
    required this.id,
    required this.authorName,
    this.authorAvatar,
    required this.content,
    this.mediaUrl,
    required this.visibility,
    required this.likeCount,
    required this.commentCount,
    this.repostCount = 0,
    required this.isLiked,
    this.isReposted = false,
    this.isRepost = false,
    this.originalAuthorName,
    required this.createdAt,
    this.isPoll = false,
    this.pollQuestion,
    this.pollOptions,
    this.votedOptionId,
    this.totalPollVotes = 0,
  });

  factory TimelinePost.fromJson(Map<String, dynamic> json) {
    // Handle poll: API sends "poll" as a nullable object
    final pollData = json['poll'] as Map<String, dynamic>?;
    final pollOpts = pollData != null
        ? (pollData['options'] as List?)
              ?.map((e) => PollOption.fromJson(e as Map<String, dynamic>))
              .toList()
        : (json['poll_options'] as List?)
              ?.map((e) => PollOption.fromJson(e as Map<String, dynamic>))
              .toList();
    final totalVotes =
        pollOpts?.fold<int>(0, (sum, o) => sum + o.votes) ?? 0;

    // Handle media: API sends "media" as an array
    final mediaList = json['media'] as List?;
    final firstMediaUrl = (mediaList != null && mediaList.isNotEmpty)
        ? (mediaList[0] is Map ? mediaList[0]['url'] as String? : mediaList[0] as String?)
        : json['media_url'] as String?;

    return TimelinePost(
      id: json['id'] as String,
      authorName: json['author_name'] as String? ??
          (json['author'] is Map
              ? json['author']['full_name'] as String?
              : null) ??
          'Unknown',
      authorAvatar: json['author_avatar'] as String? ??
          (json['author'] is Map
              ? json['author']['avatar_url'] as String?
              : null),
      content: json['content'] as String? ?? '',
      mediaUrl: firstMediaUrl,
      visibility: _parseVisibility(json['visibility'] as String?),
      likeCount: json['like_count'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      repostCount: json['repost_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isReposted: json['is_reposted'] as bool? ?? false,
      isRepost: json['is_repost'] as bool? ?? false,
      originalAuthorName: json['original_author_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      isPoll: json['type'] == 'poll' ||
          (json['is_poll'] as bool? ?? (pollOpts != null && pollOpts.isNotEmpty)),
      pollQuestion: pollData?['question'] as String? ??
          json['poll_question'] as String?,
      pollOptions: pollOpts,
      votedOptionId: pollData?['voted_option_id'] as String? ??
          json['voted_option_id'] as String?,
      totalPollVotes: totalVotes,
    );
  }

  static PostVisibility _parseVisibility(String? value) {
    switch (value) {
      case 'building':
        return PostVisibility.building;
      case 'neighborhood':
        return PostVisibility.neighborhood;
      case 'public':
        return PostVisibility.public_;
      default:
        return PostVisibility.building;
    }
  }

  TimelinePost copyWith({
    int? likeCount,
    int? repostCount,
    bool? isLiked,
    bool? isReposted,
    List<PollOption>? pollOptions,
    String? votedOptionId,
    int? totalPollVotes,
  }) {
    return TimelinePost(
      id: id,
      authorName: authorName,
      authorAvatar: authorAvatar,
      content: content,
      mediaUrl: mediaUrl,
      visibility: visibility,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount,
      repostCount: repostCount ?? this.repostCount,
      isLiked: isLiked ?? this.isLiked,
      isReposted: isReposted ?? this.isReposted,
      isRepost: isRepost,
      originalAuthorName: originalAuthorName,
      createdAt: createdAt,
      isPoll: isPoll,
      pollQuestion: pollQuestion,
      pollOptions: pollOptions ?? this.pollOptions,
      votedOptionId: votedOptionId ?? this.votedOptionId,
      totalPollVotes: totalPollVotes ?? this.totalPollVotes,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _timelineFeedProvider =
    StateNotifierProvider<_TimelineFeedNotifier, AsyncValue<List<TimelinePost>>>(
  (ref) => _TimelineFeedNotifier(ref),
);

class _TimelineFeedNotifier
    extends StateNotifier<AsyncValue<List<TimelinePost>>> {
  final Ref _ref;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  _TimelineFeedNotifier(this._ref) : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.getTimelineFeed(page: 1, limit: 20);
      final innerData = response.data['data'];
      final items = innerData is Map ? innerData['data'] : innerData;
      final list = (items as List?)
              ?.map((e) => TimelinePost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <TimelinePost>[];
      _hasMore = list.length >= 20;
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    final current = state.valueOrNull ?? [];
    _page++;
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.getTimelineFeed(page: _page, limit: 20);
      final innerData = response.data['data'];
      final items = innerData is Map ? innerData['data'] : innerData;
      final list = (items as List?)
              ?.map((e) => TimelinePost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <TimelinePost>[];
      _hasMore = list.length >= 20;
      state = AsyncValue.data([...current, ...list]);
    } catch (_) {
      _page--;
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = current[idx];
    final newLiked = !post.isLiked;
    final updated = List<TimelinePost>.from(current);
    updated[idx] = post.copyWith(
      isLiked: newLiked,
      likeCount: post.likeCount + (newLiked ? 1 : -1),
    );
    state = AsyncValue.data(updated);

    try {
      final api = _ref.read(apiClientProvider);
      await api.likeTimelinePost(postId);
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> toggleRepost(String postId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = current[idx];
    final newReposted = !post.isReposted;
    final updated = List<TimelinePost>.from(current);
    updated[idx] = post.copyWith(
      isReposted: newReposted,
      repostCount: post.repostCount + (newReposted ? 1 : -1),
    );
    state = AsyncValue.data(updated);

    try {
      final api = _ref.read(apiClientProvider);
      if (newReposted) {
        await api.repostPost(postId);
      } else {
        await api.unrepostPost(postId);
      }
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> votePoll(String postId, String optionId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = current[idx];
    if (post.votedOptionId != null) return; // already voted

    // Optimistic update
    final updatedOptions = post.pollOptions?.map((o) {
      return o.id == optionId
          ? PollOption(id: o.id, text: o.text, votes: o.votes + 1)
          : o;
    }).toList();

    final updated = List<TimelinePost>.from(current);
    updated[idx] = post.copyWith(
      pollOptions: updatedOptions,
      votedOptionId: optionId,
      totalPollVotes: post.totalPollVotes + 1,
    );
    state = AsyncValue.data(updated);

    try {
      final api = _ref.read(apiClientProvider);
      // Use the post id as pollId since polls are tied to posts
      await api.votePoll(postId, optionId);
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class TimelineScreen extends ConsumerWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(_timelineFeedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_rounded),
            tooltip: 'Messages',
            onPressed: () => context.push('/messages'),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search users',
            onPressed: () => context.push('/user-search'),
          ),
        ],
      ),
      body: feedAsync.when(
        loading: () => const _ShimmerFeed(),
        error: (error, _) => _ErrorState(
          message: error.toString(),
          onRetry: () => ref.read(_timelineFeedProvider.notifier).fetch(),
        ),
        data: (posts) {
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                ref.read(_timelineFeedProvider.notifier).fetch(),
            child: _TimelineFeed(posts: posts),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'timeline_fab',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => _showCreatePostSheet(context),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreateTimelinePostSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline feed with infinite scroll
// ---------------------------------------------------------------------------

class _TimelineFeed extends ConsumerStatefulWidget {
  final List<TimelinePost> posts;
  const _TimelineFeed({required this.posts});

  @override
  ConsumerState<_TimelineFeed> createState() => _TimelineFeedState();
}

class _TimelineFeedState extends ConsumerState<_TimelineFeed> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(_timelineFeedProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final userName = authState.user?['full_name'] as String? ?? '';

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: widget.posts.length + 1, // +1 for the create post bar
      itemBuilder: (context, index) {
        if (index == 0) {
          return _CreatePostBar(userName: userName);
        }
        return _TimelinePostCard(post: widget.posts[index - 1]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Create post input bar at top
// ---------------------------------------------------------------------------

class _CreatePostBar extends StatelessWidget {
  final String userName;
  const _CreatePostBar({required this.userName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: theme.colorScheme.surface,
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            child: Text(
              userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => const _CreateTimelinePostSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  "What's on your mind?",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline post card
// ---------------------------------------------------------------------------

class _TimelinePostCard extends ConsumerWidget {
  final TimelinePost post;
  const _TimelinePostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Repost indicator
            if (post.isRepost && post.originalAuthorName != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.repeat_rounded, size: 14, color: AppColors.textHint),
                    const SizedBox(width: 6),
                    Text(
                      '${post.authorName} reposted from ${post.originalAuthorName}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Header: avatar, name, time, visibility badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    post.authorName.isNotEmpty
                        ? post.authorName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            _formatTimeAgo(post.createdAt),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.textHint,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _VisibilityBadge(visibility: post.visibility),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.more_horiz_rounded, size: 20),
                  onPressed: () {},
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppColors.textHint,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Content
            if (post.content.isNotEmpty)
              Text(
                post.content,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),

            // Media placeholder
            if (post.mediaUrl != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: AppColors.textHint,
                  ),
                ),
              ),
            ],

            // Poll
            if (post.isPoll && post.pollOptions != null) ...[
              const SizedBox(height: 12),
              _PollSection(post: post),
            ],

            const SizedBox(height: 12),

            // Like / repost / comment counts
            Row(
              children: [
                if (post.likeCount > 0) ...[
                  const Icon(Icons.thumb_up_rounded,
                      size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${post.likeCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (post.repostCount > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.repeat_rounded,
                      size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '${post.repostCount}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const Spacer(),
                if (post.commentCount > 0)
                  Text(
                    '${post.commentCount} comment${post.commentCount > 1 ? 's' : ''}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),

            const Divider(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: post.isLiked
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    label: 'Like',
                    isActive: post.isLiked,
                    onPressed: () {
                      ref
                          .read(_timelineFeedProvider.notifier)
                          .toggleLike(post.id);
                    },
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: post.isReposted
                        ? Icons.repeat_rounded
                        : Icons.repeat_rounded,
                    label: 'Repost',
                    isActive: post.isReposted,
                    activeColor: Colors.green,
                    onPressed: () {
                      ref
                          .read(_timelineFeedProvider.notifier)
                          .toggleRepost(post.id);
                    },
                  ),
                ),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: 'Comment',
                    isActive: false,
                    onPressed: () {
                      context.push('/timeline/${post.id}');
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Poll section
// ---------------------------------------------------------------------------

class _PollSection extends ConsumerWidget {
  final TimelinePost post;
  const _PollSection({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hasVoted = post.votedOptionId != null;
    final totalVotes = post.totalPollVotes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (post.pollQuestion != null && post.pollQuestion!.isNotEmpty) ...[
          Text(
            post.pollQuestion!,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
        ...post.pollOptions!.map((option) {
          final percentage =
              totalVotes > 0 ? (option.votes / totalVotes * 100) : 0.0;
          final isSelected = post.votedOptionId == option.id;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: hasVoted
                  ? null
                  : () {
                      ref
                          .read(_timelineFeedProvider.notifier)
                          .votePoll(post.id, option.id);
                    },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    width: isSelected ? 1.5 : 1,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Progress bar background
                    if (hasVoted)
                      FractionallySizedBox(
                        widthFactor: percentage / 100,
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.12)
                                : Colors.grey.shade100,
                          ),
                        ),
                      ),
                    // Content
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          if (hasVoted && isSelected)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              option.text,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (hasVoted)
                            Text(
                              '${percentage.round()}%',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '$totalVotes vote${totalVotes != 1 ? 's' : ''}',
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Visibility badge
// ---------------------------------------------------------------------------

class _VisibilityBadge extends StatelessWidget {
  final PostVisibility visibility;
  const _VisibilityBadge({required this.visibility});

  @override
  Widget build(BuildContext context) {
    final (String label, IconData icon) = switch (visibility) {
      PostVisibility.building => ('Building', Icons.apartment_rounded),
      PostVisibility.neighborhood =>
        ('Neighborhood', Icons.location_city_rounded),
      PostVisibility.public_ => ('Public', Icons.public_rounded),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: AppColors.primary),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action button (Like / Comment)
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.isActive,
    this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? (activeColor ?? AppColors.primary) : AppColors.textSecondary;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create timeline post sheet
// ---------------------------------------------------------------------------

class _CreateTimelinePostSheet extends ConsumerStatefulWidget {
  const _CreateTimelinePostSheet();

  @override
  ConsumerState<_CreateTimelinePostSheet> createState() =>
      _CreateTimelinePostSheetState();
}

class _CreateTimelinePostSheetState
    extends ConsumerState<_CreateTimelinePostSheet> {
  final _contentController = TextEditingController();
  PostVisibility _visibility = PostVisibility.building;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final visibilityStr = switch (_visibility) {
        PostVisibility.building => 'building',
        PostVisibility.neighborhood => 'neighborhood',
        PostVisibility.public_ => 'public',
      };
      await api.createTimelinePost({
        'content': content,
        'visibility': visibilityStr,
      });
      if (mounted) Navigator.of(context).pop();
      ref.read(_timelineFeedProvider.notifier).fetch();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create post: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Create Post',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _contentController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: "What's on your mind?",
              alignLabelWithHint: true,
            ),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 14),

          // Visibility selector
          SegmentedButton<PostVisibility>(
            segments: const [
              ButtonSegment(
                value: PostVisibility.building,
                label: Text('Building'),
                icon: Icon(Icons.apartment_rounded, size: 16),
              ),
              ButtonSegment(
                value: PostVisibility.neighborhood,
                label: Text('Area'),
                icon: Icon(Icons.location_city_rounded, size: 16),
              ),
              ButtonSegment(
                value: PostVisibility.public_,
                label: Text('Public'),
                icon: Icon(Icons.public_rounded, size: 16),
              ),
            ],
            selected: {_visibility},
            onSelectionChanged: (set) {
              setState(() => _visibility = set.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(
                theme.textTheme.labelSmall,
              ),
            ),
          ),

          const SizedBox(height: 20),
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Post',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.public_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No posts yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Share something with your community to get started.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error state
// ---------------------------------------------------------------------------

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 56, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shimmer loading skeleton
// ---------------------------------------------------------------------------

class _ShimmerFeed extends StatelessWidget {
  const _ShimmerFeed();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: 4,
        itemBuilder: (_, __) => const _ShimmerPostCard(),
      ),
    );
  }
}

class _ShimmerPostCard extends StatelessWidget {
  const _ShimmerPostCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 13,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 70,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Content lines
            Container(
              width: double.infinity,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 180,
              height: 13,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),
            // Media placeholder
            Container(
              width: double.infinity,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 14),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Container(
                  width: 60,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                Container(
                  width: 80,
                  height: 18,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatTimeAgo(DateTime dateTime) {
  final now = DateTime.now();
  final diff = now.difference(dateTime);

  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}
