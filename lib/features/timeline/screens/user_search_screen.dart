import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Model
// ---------------------------------------------------------------------------

class UserSearchResult {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final bool isFollowing;
  final int followerCount;
  final int followingCount;

  const UserSearchResult({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.isFollowing,
    required this.followerCount,
    required this.followingCount,
  });

  factory UserSearchResult.fromJson(Map<String, dynamic> json) {
    return UserSearchResult(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unknown',
      avatarUrl: json['avatar_url'] as String?,
      isFollowing: json['is_following'] as bool? ?? false,
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
    );
  }

  UserSearchResult copyWith({bool? isFollowing, int? followerCount}) {
    return UserSearchResult(
      id: id,
      fullName: fullName,
      avatarUrl: avatarUrl,
      isFollowing: isFollowing ?? this.isFollowing,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final _userSearchProvider =
    StateNotifierProvider<_UserSearchNotifier, AsyncValue<List<UserSearchResult>>>(
  (ref) => _UserSearchNotifier(ref),
);

class _UserSearchNotifier
    extends StateNotifier<AsyncValue<List<UserSearchResult>>> {
  final Ref _ref;

  _UserSearchNotifier(this._ref) : super(const AsyncValue.data([]));

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      state = const AsyncValue.data([]);
      return;
    }

    state = const AsyncValue.loading();
    try {
      final api = _ref.read(apiClientProvider);
      final response = await api.searchUsers(query.trim());
      final data = response.data['data'];
      final items = data is List ? data : <dynamic>[];
      final users = items
          .map((e) => UserSearchResult.fromJson(e as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(users);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFollow(String userId) async {
    final current = state.valueOrNull ?? [];
    final idx = current.indexWhere((u) => u.id == userId);
    if (idx == -1) return;

    final user = current[idx];
    final newFollowing = !user.isFollowing;
    final updated = List<UserSearchResult>.from(current);
    updated[idx] = user.copyWith(
      isFollowing: newFollowing,
      followerCount: user.followerCount + (newFollowing ? 1 : -1),
    );
    state = AsyncValue.data(updated);

    try {
      final api = _ref.read(apiClientProvider);
      if (newFollowing) {
        await api.followUser(userId);
      } else {
        await api.unfollowUser(userId);
      }
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(_userSearchProvider.notifier).search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resultsAsync = ref.watch(_userSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Find People'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(_userSearchProvider.notifier).search('');
                          setState(() {});
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (v) {
                setState(() {}); // Update clear button visibility
                _onSearchChanged(v);
              },
            ),
          ),

          // Results
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
              error: (e, _) => Center(
                child: Text('Error: $e',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: AppColors.error)),
              ),
              data: (users) {
                if (_searchController.text.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded,
                            size: 64,
                            color: AppColors.textHint.withValues(alpha: 0.5)),
                        const SizedBox(height: 16),
                        Text(
                          'Search for people to follow',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: AppColors.textHint,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      'No users found',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppColors.textHint,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) =>
                      _UserSearchTile(user: users[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// User tile
// ---------------------------------------------------------------------------

class _UserSearchTile extends ConsumerWidget {
  final UserSearchResult user;
  const _UserSearchTile({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
        child: Text(
          user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        user.fullName,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '${user.followerCount} follower${user.followerCount != 1 ? 's' : ''}',
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: SizedBox(
        width: 100,
        child: FilledButton(
          onPressed: () {
            ref.read(_userSearchProvider.notifier).toggleFollow(user.id);
          },
          style: FilledButton.styleFrom(
            backgroundColor:
                user.isFollowing ? Colors.grey.shade200 : AppColors.primary,
            foregroundColor:
                user.isFollowing ? AppColors.textPrimary : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            user.isFollowing ? 'Following' : 'Follow',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
