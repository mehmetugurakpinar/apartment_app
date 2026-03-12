import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _dashboardProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) {
    return {
      'total_units': 0,
      'pending_dues': 0,
      'open_requests': 0,
      'recent_activity': <Map<String, dynamic>>[],
    };
  }
  final response = await api.getBuildingDashboard(buildingId);
  if (response.data['success'] == true && response.data['data'] != null) {
    return response.data['data'] as Map<String, dynamic>;
  }
  throw Exception(response.data['error'] ?? 'Failed to load dashboard');
});

// ---------------------------------------------------------------------------
// HomeScreen
// ---------------------------------------------------------------------------

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _onRefresh() async {
    ref.invalidate(_dashboardProvider);
    // Wait for the provider to re-fetch so the refresh indicator stays visible.
    await ref.read(_dashboardProvider.future);
  }

  // ------ helpers ----------------------------------------------------------

  String _greeting() {
    final isTr = ref.read(localeProvider).languageCode == 'tr';
    final hour = DateTime.now().hour;
    if (hour < 12) return isTr ? 'Günaydın' : 'Good Morning';
    if (hour < 17) return isTr ? 'İyi Günler' : 'Good Afternoon';
    return isTr ? 'İyi Akşamlar' : 'Good Evening';
  }

  String _userName(Map<String, dynamic>? user) {
    if (user == null) return '';
    final fullName = user['full_name'] as String? ?? '';
    final first = fullName.split(' ').firstOrNull ?? '';
    return first;
  }

  String _userInitials(Map<String, dynamic>? user) {
    if (user == null) return '?';
    final fullName = user['full_name'] as String? ?? '';
    final parts = fullName.split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }

  // ------ build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final dashboardAsync = ref.watch(_dashboardProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: _buildAppBar(theme, authState),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _onRefresh,
        child: dashboardAsync.when(
          data: (data) => _buildContent(theme, authState, data),
          loading: () => _buildShimmerContent(theme),
          error: (error, _) => _buildErrorState(theme, error),
        ),
      ),
    );
  }

  // ------ AppBar -----------------------------------------------------------

  PreferredSizeWidget _buildAppBar(ThemeData theme, AuthState authState) {
    return AppBar(
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GestureDetector(
          onTap: () => context.push('/profile'),
          child: CircleAvatar(
            backgroundColor: AppColors.accent,
            child: Text(
              _userInitials(authState.user),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
      title: Text(ref.watch(localeProvider).languageCode == 'tr' ? 'Apartman Yöneticisi' : 'Apartment Manager'),
      actions: [
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => context.push('/profile'),
        ),
      ],
    );
  }

  // ------ Loaded Content ---------------------------------------------------

  Widget _buildContent(
    ThemeData theme,
    AuthState authState,
    Map<String, dynamic> data,
  ) {
    final recentActivity =
        (data['recent_activity'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _WelcomeCard(
          greeting: _greeting(),
          userName: _userName(authState.user),
        ),
        const SizedBox(height: 20),
        _StatsRow(
          totalUnits: data['total_units'] ?? 0,
          pendingDues: data['pending_dues'] ?? 0,
          openRequests: data['open_requests'] ?? 0,
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Quick Actions'),
        const SizedBox(height: 12),
        _QuickActionsRow(onAction: _handleQuickAction),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Recent Activity'),
        const SizedBox(height: 12),
        if (recentActivity.isEmpty)
          _EmptyActivityPlaceholder()
        else
          ...recentActivity.map(
            (item) => _ActivityTile(item: item),
          ),
      ],
    );
  }

  void _handleQuickAction(String action) {
    switch (action) {
      case 'pay_dues':
        context.go('/building');
        break;
      case 'maintenance':
        context.go('/building');
        break;
      case 'write_post':
        context.go('/forum');
        break;
    }
  }

  // ------ Error State ------------------------------------------------------

  Widget _buildErrorState(ThemeData theme, Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 56, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => ref.invalidate(_dashboardProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ------ Shimmer Content --------------------------------------------------

  Widget _buildShimmerContent(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Welcome card skeleton
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          const SizedBox(height: 20),
          // Stats row skeleton
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  height: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Section header skeleton
          Container(
            height: 20,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // Quick actions skeleton
          Row(
            children: List.generate(
              3,
              (_) => Expanded(
                child: Container(
                  height: 88,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Section header skeleton
          Container(
            height: 20,
            width: 140,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),
          // Activity list skeleton
          ...List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Sub-widgets
// ===========================================================================

class _WelcomeCard extends StatelessWidget {
  final String greeting;
  final String userName;

  const _WelcomeCard({required this.greeting, required this.userName});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: AppColors.primary,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting,',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    userName.isNotEmpty ? userName : 'Welcome Back',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your apartment community',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.apartment_rounded,
                size: 40,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  final int totalUnits;
  final int pendingDues;
  final int openRequests;

  const _StatsRow({
    required this.totalUnits,
    required this.pendingDues,
    required this.openRequests,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Total Units',
            value: totalUnits.toString(),
            icon: Icons.door_front_door_outlined,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Pending Dues',
            value: pendingDues.toString(),
            icon: Icons.payments_outlined,
            color: AppColors.warning,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Open Requests',
            value: openRequests.toString(),
            icon: Icons.build_outlined,
            color: AppColors.info,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha:0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  final void Function(String action) onAction;
  const _QuickActionsRow({required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.payments_outlined,
            label: 'Pay Dues',
            color: AppColors.accent,
            onTap: () => onAction('pay_dues'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.build_outlined,
            label: 'Maintenance',
            color: AppColors.primary,
            onTap: () => onAction('maintenance'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.edit_note_outlined,
            label: 'Write Post',
            color: AppColors.info,
            onTap: () => onAction('write_post'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: color.withValues(alpha:0.08),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _EmptyActivityPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        child: Column(
          children: [
            const Icon(
              Icons.history_rounded,
              size: 48,
              color: AppColors.textHint,
            ),
            const SizedBox(height: 12),
            Text(
              'No recent activity',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Activity from your building community will appear here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _ActivityTile extends StatelessWidget {
  final Map<String, dynamic> item;
  const _ActivityTile({required this.item});

  IconData _icon(String? type) {
    switch (type) {
      case 'payment':
        return Icons.payments_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'post':
        return Icons.article_outlined;
      case 'move_in':
        return Icons.login_outlined;
      case 'move_out':
        return Icons.logout_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String? type) {
    switch (type) {
      case 'payment':
        return AppColors.success;
      case 'maintenance':
        return AppColors.warning;
      case 'announcement':
        return AppColors.info;
      case 'post':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final type = item['type'] as String?;
    final color = _iconColor(type);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha:0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_icon(type), color: color, size: 22),
        ),
        title: Text(
          item['title'] as String? ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item['description'] as String? ?? '',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          item['time_ago'] as String? ?? '',
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppColors.textHint,
          ),
        ),
      ),
    );
  }
}
