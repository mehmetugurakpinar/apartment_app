import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class ForumCategory {
  final String id;
  final String name;
  final String? icon;

  const ForumCategory({required this.id, required this.name, this.icon});

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
    );
  }
}

class ForumMedia {
  final String id;
  final String url;
  final String type;

  const ForumMedia({required this.id, required this.url, required this.type});

  factory ForumMedia.fromJson(Map<String, dynamic> json) {
    return ForumMedia(
      id: json['id'] as String,
      url: json['url'] as String,
      type: json['type'] as String? ?? 'image',
    );
  }
}

class ForumPost {
  final String id;
  final String title;
  final String body;
  final String authorName;
  final String? authorAvatar;
  final String? categoryId;
  final int upvotes;
  final int downvotes;
  final int commentCount;
  final DateTime createdAt;
  final int? userVote;
  final List<ForumMedia> media;

  const ForumPost({
    required this.id,
    required this.title,
    required this.body,
    required this.authorName,
    this.authorAvatar,
    this.categoryId,
    required this.upvotes,
    required this.downvotes,
    required this.commentCount,
    required this.createdAt,
    this.userVote,
    this.media = const [],
  });

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String? ?? '',
      authorName: json['author_name'] as String? ??
          (json['author'] is Map ? json['author']['full_name'] as String? : null) ??
          'Unknown',
      authorAvatar: json['author_avatar'] as String? ??
          (json['author'] is Map ? json['author']['avatar_url'] as String? : null),
      categoryId: json['category_id'] as String?,
      upvotes: json['upvotes'] as int? ?? 0,
      downvotes: json['downvotes'] as int? ?? 0,
      commentCount: json['comment_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      userVote: json['user_vote'] as int?,
      media: (json['media'] as List?)
              ?.map((e) => ForumMedia.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  ForumPost copyWith({int? upvotes, int? downvotes, int? userVote}) {
    return ForumPost(
      id: id,
      title: title,
      body: body,
      authorName: authorName,
      authorAvatar: authorAvatar,
      categoryId: categoryId,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      commentCount: commentCount,
      createdAt: createdAt,
      userVote: userVote,
      media: media,
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _selectedCategoryProvider = StateProvider<String?>((ref) => null);

final _forumCategoriesProvider =
    FutureProvider.autoDispose<List<ForumCategory>>((ref) async {
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final api = ref.read(apiClientProvider);
  final response = await api.getForumCategories(buildingId);
  final rawData = response.data['data'];
  final items = rawData is Map ? rawData['data'] : rawData;
  final list = (items as List?)
          ?.map((e) => ForumCategory.fromJson(e as Map<String, dynamic>))
          .toList() ??
      <ForumCategory>[];
  return list;
});

final _forumPostsProvider =
    StateNotifierProvider<_ForumPostsNotifier, AsyncValue<List<ForumPost>>>(
  (ref) => _ForumPostsNotifier(ref),
);

class _ForumPostsNotifier extends StateNotifier<AsyncValue<List<ForumPost>>> {
  final Ref _ref;
  int _page = 1;
  bool _hasMore = true;

  _ForumPostsNotifier(this._ref) : super(const AsyncValue.loading()) {
    _ref.listen(selectedBuildingIdProvider, (_, __) => fetch());
    _ref.listen(_selectedCategoryProvider, (_, __) => fetch());
    fetch();
  }

  Future<void> fetch() async {
    final buildingId = _ref.read(selectedBuildingIdProvider);
    if (buildingId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    _page = 1;
    _hasMore = true;
    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      final categoryId = _ref.read(_selectedCategoryProvider);
      final response = await api.getForumPosts(
        buildingId,
        categoryId: categoryId,
        page: 1,
        limit: 20,
      );
      final rawData = response.data['data'];
      final items = rawData is Map ? rawData['data'] : rawData;
      final list = (items as List?)
              ?.map((e) => ForumPost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <ForumPost>[];
      _hasMore = list.length >= 20;
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> loadMore() async {
    final buildingId = _ref.read(selectedBuildingIdProvider);
    if (buildingId == null || !_hasMore) return;
    final current = state.valueOrNull ?? [];
    _page++;
    try {
      final api = _ref.read(apiClientProvider);
      final categoryId = _ref.read(_selectedCategoryProvider);
      final response = await api.getForumPosts(
        buildingId,
        categoryId: categoryId,
        page: _page,
        limit: 20,
      );
      final rawData = response.data['data'];
      final items = rawData is Map ? rawData['data'] : rawData;
      final list = (items as List?)
              ?.map((e) => ForumPost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          <ForumPost>[];
      _hasMore = list.length >= 20;
      state = AsyncValue.data([...current, ...list]);
    } catch (_) {
      _page--;
    }
  }

  Future<void> vote(String postId, int value) async {
    final buildingId = _ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;

    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx == -1) return;

    final post = current[idx];
    final oldVote = post.userVote;

    // Calculate new vote counts
    int newUpvotes = post.upvotes;
    int newDownvotes = post.downvotes;

    // Remove old vote
    if (oldVote == 1) newUpvotes--;
    if (oldVote == -1) newDownvotes--;

    // Toggle: if same vote, remove; otherwise apply new
    final int? newVoteValue;
    if (oldVote == value) {
      newVoteValue = null;
    } else {
      newVoteValue = value;
      if (value == 1) newUpvotes++;
      if (value == -1) newDownvotes++;
    }

    final updated = List<ForumPost>.from(current);
    updated[idx] = post.copyWith(
      upvotes: newUpvotes,
      downvotes: newDownvotes,
      userVote: newVoteValue,
    );
    state = AsyncValue.data(updated);

    try {
      final api = _ref.read(apiClientProvider);
      await api.voteForumPost(buildingId, postId, newVoteValue ?? 0);
    } catch (_) {
      // Revert
      state = AsyncValue.data(current);
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class ForumScreen extends ConsumerWidget {
  const ForumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(_forumPostsProvider);
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    final buildingId = ref.watch(selectedBuildingIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forum'),
      ),
      body: buildingId == null
          ? _NoBuildingForumState(isTr: isTr)
          : Column(
              children: [
                // Category chips
                const _CategoryChipBar(),
                const Divider(height: 1),
                // Posts
                Expanded(
                  child: postsAsync.when(
                    loading: () => const _ShimmerPostList(),
                    error: (error, _) => _ErrorState(
                      message: error.toString(),
                      onRetry: () => ref.read(_forumPostsProvider.notifier).fetch(),
                    ),
                    data: (posts) {
                      if (posts.isEmpty) return const _EmptyState();
                      return RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () =>
                            ref.read(_forumPostsProvider.notifier).fetch(),
                        child: _PostList(posts: posts),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: buildingId != null
          ? FloatingActionButton(
              heroTag: 'forum_fab',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _showCreatePostSheet(context),
              child: const Icon(Icons.edit_rounded),
            )
          : null,
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _CreatePostSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Category chip bar
// ---------------------------------------------------------------------------

class _CategoryChipBar extends ConsumerWidget {
  const _CategoryChipBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(_forumCategoriesProvider);
    final selectedId = ref.watch(_selectedCategoryProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: 56,
      child: categoriesAsync.when(
        loading: () => _shimmerChips(context),
        error: (_, __) => const SizedBox.shrink(),
        data: (categories) {
          if (categories.isEmpty) return const SizedBox.shrink();
          return ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: selectedId == null,
                  onSelected: (_) {
                    ref.read(_selectedCategoryProvider.notifier).state = null;
                  },
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: selectedId == null
                        ? AppColors.primary
                        : theme.textTheme.bodyMedium?.color,
                    fontWeight:
                        selectedId == null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              ...categories.map((cat) {
                final isSelected = selectedId == cat.id;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(cat.name),
                    selected: isSelected,
                    onSelected: (_) {
                      ref.read(_selectedCategoryProvider.notifier).state =
                          isSelected ? null : cat.id;
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.primary
                          : theme.textTheme.bodyMedium?.color,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _shimmerChips(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        children: List.generate(5, (_) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Container(
              width: 80,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Post list with infinite scroll
// ---------------------------------------------------------------------------

class _PostList extends ConsumerStatefulWidget {
  final List<ForumPost> posts;
  const _PostList({required this.posts});

  @override
  ConsumerState<_PostList> createState() => _PostListState();
}

class _PostListState extends ConsumerState<_PostList> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(_forumPostsProvider.notifier).loadMore();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      itemCount: widget.posts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _ForumPostCard(post: widget.posts[index]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Forum post card
// ---------------------------------------------------------------------------

class _ForumPostCard extends ConsumerWidget {
  final ForumPost post;
  const _ForumPostCard({required this.post});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final voteScore = post.upvotes - post.downvotes;

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          // Navigate to post detail
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author row
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      post.authorName.isNotEmpty
                          ? post.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatTimeAgo(post.createdAt),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Title
              Text(
                post.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (post.body.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  post.body,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Media images
              if (post.media.isNotEmpty) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: post.media.length == 1
                      ? Image.network(
                          post.media.first.url,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: Colors.grey.shade200,
                            child: const Center(
                              child: Icon(Icons.broken_image_rounded,
                                  color: AppColors.textHint, size: 40),
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 160,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: post.media.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                post.media[i].url,
                                width: 200,
                                height: 160,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 200,
                                  height: 160,
                                  color: Colors.grey.shade200,
                                  child: const Center(
                                    child: Icon(Icons.broken_image_rounded,
                                        color: AppColors.textHint),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],

              const SizedBox(height: 14),

              // Bottom actions row
              Row(
                children: [
                  // Upvote
                  _VoteButton(
                    icon: Icons.arrow_upward_rounded,
                    isActive: post.userVote == 1,
                    activeColor: AppColors.primary,
                    onPressed: () {
                      ref
                          .read(_forumPostsProvider.notifier)
                          .vote(post.id, 1);
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '$voteScore',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: voteScore > 0
                            ? AppColors.primary
                            : voteScore < 0
                                ? AppColors.error
                                : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  // Downvote
                  _VoteButton(
                    icon: Icons.arrow_downward_rounded,
                    isActive: post.userVote == -1,
                    activeColor: AppColors.error,
                    onPressed: () {
                      ref
                          .read(_forumPostsProvider.notifier)
                          .vote(post.id, -1);
                    },
                  ),

                  const SizedBox(width: 20),

                  // Comments
                  const Icon(
                    Icons.chat_bubble_outline_rounded,
                    size: 18,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const Spacer(),

                  // Time again on the right for quick reference
                  const Icon(
                    Icons.access_time_rounded,
                    size: 14,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimeAgo(post.createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Vote button
// ---------------------------------------------------------------------------

class _VoteButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onPressed;

  const _VoteButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(
          icon,
          size: 20,
          color: isActive ? activeColor : AppColors.textHint,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create post bottom sheet
// ---------------------------------------------------------------------------

class _CreatePostSheet extends ConsumerStatefulWidget {
  const _CreatePostSheet();

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final List<XFile> _selectedImages = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1920);
    if (images.isNotEmpty) {
      setState(() => _selectedImages.addAll(images));
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      if (mounted) {
        final isTr = ref.read(localeProvider).languageCode == 'tr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isTr
                ? 'Başlık ve içerik gereklidir'
                : 'Title and body are required'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;

    setState(() => _isSubmitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.createForumPost(buildingId, {
        'title': title,
        'body': body,
        if (ref.read(_selectedCategoryProvider) != null)
          'category_id': ref.read(_selectedCategoryProvider),
      });

      // Upload images if any
      final postData = response.data['data'];
      final postId = postData is Map ? postData['id'] as String? : null;
      if (postId != null && _selectedImages.isNotEmpty) {
        for (final img in _selectedImages) {
          final file = await MultipartFile.fromFile(img.path,
              filename: img.name);
          await api.uploadForumMedia(buildingId, postId, file);
        }
      }

      if (mounted) Navigator.of(context).pop();
      ref.read(_forumPostsProvider.notifier).fetch();
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
          Builder(builder: (ctx) {
            final isTr = ref.watch(localeProvider).languageCode == 'tr';
            return Text(
              isTr ? 'Gönderi Oluştur' : 'Create Post',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            );
          }),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: ref.watch(localeProvider).languageCode == 'tr' ? 'Başlık' : 'Title',
              hintText: ref.watch(localeProvider).languageCode == 'tr' ? 'Gönderi başlığı girin' : 'Enter post title',
            ),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _bodyController,
            textCapitalization: TextCapitalization.sentences,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: ref.watch(localeProvider).languageCode == 'tr' ? 'İçerik' : 'Body',
              hintText: ref.watch(localeProvider).languageCode == 'tr' ? 'Gönderi içeriğinizi yazın...' : 'Write your post content...',
              alignLabelWithHint: true,
            ),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 14),
          // Image picker
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _isSubmitting ? null : _pickImages,
                icon: const Icon(Icons.image_rounded, size: 18),
                label: Text(ref.watch(localeProvider).languageCode == 'tr'
                    ? 'Görsel Ekle'
                    : 'Add Images'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '${_selectedImages.length} selected',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          if (_selectedImages.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedImages[i].path),
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                      ),
                    ),
                    Positioned(
                      top: 2,
                      right: 2,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedImages.removeAt(i)),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close,
                              size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
// No building state
// ---------------------------------------------------------------------------

class _NoBuildingForumState extends StatelessWidget {
  final bool isTr;
  const _NoBuildingForumState({required this.isTr});

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
                Icons.apartment_rounded,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTr ? 'Henüz bir binaya üye değilsiniz' : 'No building selected',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTr
                  ? 'Forum kullanmak için bir binaya üye olmanız gerekiyor.'
                  : 'You need to be a member of a building to use the forum.',
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
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isTr = ref.watch(localeProvider).languageCode == 'tr';
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
                Icons.forum_outlined,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isTr ? 'Henüz gönderi yok' : 'No posts yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isTr ? 'Bina forumunuzda ilk tartışmayı başlatan siz olun.' : 'Be the first to start a discussion in your building forum.',
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

class _ShimmerPostList extends StatelessWidget {
  const _ShimmerPostList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
      highlightColor: isDark ? Colors.grey.shade700 : Colors.grey.shade100,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        itemCount: 5,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => const _ShimmerPostCard(),
      ),
    );
  }
}

class _ShimmerPostCard extends StatelessWidget {
  const _ShimmerPostCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author row
          Row(
            children: [
              const CircleAvatar(radius: 16, backgroundColor: Colors.white),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 50,
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
          const SizedBox(height: 12),
          // Title
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 8),
          // Body lines
          Container(
            width: double.infinity,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 200,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 14),
          // Actions row
          Row(
            children: [
              Container(
                width: 70,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 50,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ],
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
