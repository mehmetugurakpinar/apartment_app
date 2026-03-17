import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/widgets/map_location_picker.dart';

// ===========================================================================
// Providers
// ===========================================================================

/// Tracks the current user's role in the selected building.
/// Returns 'resident' by default if role cannot be determined.
final _memberRoleProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return 'resident';
  final authState = ref.read(authStateProvider);
  final currentUserId = authState.user?['id'] as String?;
  if (currentUserId == null) return 'resident';
  try {
    final response = await api.getMembers(buildingId);
    if (response.data['success'] == true) {
      final members = (response.data['data'] as List<dynamic>?) ?? [];
      for (final m in members) {
        if (m['id'] == currentUserId) {
          return (m['role'] as String?) ?? 'resident';
        }
      }
    }
  } catch (_) {}
  // Fallback: check global role
  final globalRole = authState.user?['role'] as String? ?? 'resident';
  return globalRole;
});

final _membersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getMembers(buildingId);
  if (response.data['success'] == true) {
    return ((response.data['data'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();
  }
  throw Exception(response.data['error'] ?? 'Failed to load members');
});

final _unitsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getUnits(buildingId);
  if (response.data['success'] == true) {
    return ((response.data['data'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();
  }
  throw Exception(response.data['error'] ?? 'Failed to load units');
});

final _duesProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return {'summary': {}, 'plans': []};

  // Fetch report and plans in parallel
  final results = await Future.wait([
    api.getDuesReport(buildingId),
    api.getDuesPlans(buildingId),
  ]);

  final reportResp = results[0];
  final plansResp = results[1];

  Map<String, dynamic> summary = {};
  List<dynamic> plans = [];

  if (reportResp.data['success'] == true && reportResp.data['data'] != null) {
    final r = reportResp.data['data'] as Map<String, dynamic>;
    summary = {
      'total_collected': r['total_paid'] ?? 0,
      'total_pending': r['total_pending'] ?? 0,
      'total_overdue': (r['late_count'] ?? 0) > 0 ? r['total_pending'] : 0,
    };
  }

  if (plansResp.data['success'] == true && plansResp.data['data'] != null) {
    final d = plansResp.data['data'];
    if (d is List) {
      plans = d;
    } else if (d is Map && d.containsKey('data') && d['data'] is List) {
      plans = d['data'] as List;
    }
  }

  return {'summary': summary, 'plans': plans};
});

final _maintenanceProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getMaintenanceRequests(buildingId);
  if (response.data['success'] == true) {
    final responseData = response.data['data'];
    // Paginated response: data is wrapped in { data: [...], page, limit, total }
    if (responseData is Map && responseData.containsKey('data')) {
      return (responseData['data'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];
    }
    // Fallback: direct list
    if (responseData is List) {
      return responseData.cast<Map<String, dynamic>>();
    }
    return [];
  }
  throw Exception(response.data['error'] ?? 'Failed to load maintenance');
});

final _vendorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getVendors(buildingId);
  if (response.data['success'] == true) {
    return ((response.data['data'] as List<dynamic>?) ?? [])
        .cast<Map<String, dynamic>>();
  }
  throw Exception(response.data['error'] ?? 'Failed to load vendors');
});

// ===========================================================================
// BuildingScreen
// ===========================================================================

class BuildingScreen extends ConsumerStatefulWidget {
  const BuildingScreen({super.key});

  @override
  ConsumerState<BuildingScreen> createState() => _BuildingScreenState();
}

class _BuildingScreenState extends ConsumerState<BuildingScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  List<String> get _tabs {
    final isTr = ref.read(localeProvider).languageCode == 'tr';
    return isTr
        ? ['Daireler', 'Finans', 'Bakım', 'Tedarikçiler', 'Üyeler']
        : ['Units', 'Finances', 'Maintenance', 'Vendors', 'Members'];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool _isManager(String role) =>
      role == 'super_admin' || role == 'building_manager';

  void _onFabPressed() {
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) {
      _showAddBuildingSheet();
      return;
    }

    switch (_tabController.index) {
      case 0:
        _showAddUnitSheet();
        break;
      case 1:
        _showCreateDuesPlanSheet();
        break;
      case 2:
        _showCreateMaintenanceSheet();
        break;
      case 3:
        _showAddVendorSheet();
        break;
      case 4:
        _showInviteUserSheet();
        break;
    }
  }

  // ------ Add Building Sheet -----------------------------------------------

  void _showAddBuildingSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddBuildingSheet(
        onCreated: (buildingId) {
          ref.read(selectedBuildingIdProvider.notifier).state = buildingId;
        },
      ),
    );
  }

  // ------ Add Unit Sheet ---------------------------------------------------

  void _showAddUnitSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddUnitSheet(
        onSuccess: () => ref.invalidate(_unitsProvider),
      ),
    );
  }

  // ------ Create Dues Plan Sheet -------------------------------------------

  void _showCreateDuesPlanSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateDuesPlanSheet(
        onSuccess: () => ref.invalidate(_duesProvider),
      ),
    );
  }

  // ------ Create Maintenance Sheet -----------------------------------------

  void _showCreateMaintenanceSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateMaintenanceSheet(
        onSuccess: () => ref.invalidate(_maintenanceProvider),
      ),
    );
  }

  // ------ Add Vendor Sheet -------------------------------------------------

  void _showAddVendorSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddVendorSheet(
        onSuccess: () => ref.invalidate(_vendorsProvider),
      ),
    );
  }

  // ------ Invite User Sheet ------------------------------------------------

  void _showInviteUserSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _InviteUserSheet(),
    );
  }

  // ------ FAB label --------------------------------------------------------

  String get _fabLabel {
    final isTr = ref.read(localeProvider).languageCode == 'tr';
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return isTr ? 'Bina Ekle' : 'Add Building';
    switch (_tabController.index) {
      case 0:
        return isTr ? 'Daire Ekle' : 'Add Unit';
      case 1:
        return isTr ? 'Aidat Ekle' : 'Add Due';
      case 2:
        return isTr ? 'Yeni Talep' : 'New Request';
      case 3:
        return isTr ? 'Tedarikçi Ekle' : 'Add Vendor';
      case 4:
        return isTr ? 'Davet Et' : 'Invite';
      default:
        return isTr ? 'Ekle' : 'Add';
    }
  }

  IconData get _fabIcon {
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return Icons.add_business_outlined;
    switch (_tabController.index) {
      case 0:
        return Icons.door_front_door_outlined;
      case 1:
        return Icons.payments_outlined;
      case 2:
        return Icons.build_outlined;
      case 3:
        return Icons.store_outlined;
      case 4:
        return Icons.person_add_outlined;
      default:
        return Icons.add;
    }
  }

  // ------ build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final buildingId = ref.watch(selectedBuildingIdProvider);
    final roleAsync = ref.watch(_memberRoleProvider);
    final role = roleAsync.valueOrNull ?? 'resident';
    final isManager = _isManager(role);

    // Determine if FAB should be shown
    // - No building: always show (to add building)
    // - Tabs 0,1,3 (Units, Finances, Vendors): only managers
    // - Tab 2 (Maintenance): all members can create requests
    // - Tab 4 (Members): only managers (to invite)
    final showFab = buildingId == null ||
        _tabController.index == 2 ||
        isManager;

    return Scaffold(
      appBar: AppBar(
        title: Text(ref.watch(localeProvider).languageCode == 'tr' ? 'Bina' : 'Building'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: buildingId == null
          ? _NoBuildingState(onAddBuilding: _showAddBuildingSheet)
          : TabBarView(
              controller: _tabController,
              children: [
                _UnitsTab(isManager: isManager),
                _FinancesTab(isManager: isManager),
                _MaintenanceTab(isManager: isManager),
                _VendorsTab(isManager: isManager),
                _MembersTab(isManager: isManager),
              ],
            ),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: _onFabPressed,
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black87,
              icon: Icon(_fabIcon),
              label: Text(_fabLabel),
            )
          : null,
    );
  }
}

// ===========================================================================
// No Building Selected State
// ===========================================================================

class _NoBuildingState extends StatelessWidget {
  final VoidCallback onAddBuilding;

  const _NoBuildingState({required this.onAddBuilding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha:0.08),
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
              'No building selected',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a new building or select an existing one to manage units, finances, and more.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAddBuilding,
              icon: const Icon(Icons.add_business_outlined),
              label: const Text('Add Building'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Shared shimmer builder
// ===========================================================================

Widget _shimmerList({int itemCount = 5, double itemHeight = 80}) {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, __) => Container(
        height: itemHeight,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    ),
  );
}

Widget _shimmerCardsAndList() {
  return Shimmer.fromColors(
    baseColor: Colors.grey.shade300,
    highlightColor: Colors.grey.shade100,
    child: ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Summary cards skeleton
        Row(
          children: List.generate(
            3,
            (_) => Expanded(
              child: Container(
                height: 80,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        // List items skeleton
        ...List.generate(
          4,
          (_) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildError(Object error, VoidCallback onRetry) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

// ===========================================================================
// Units Tab
// ===========================================================================

class _UnitsTab extends ConsumerWidget {
  final bool isManager;
  const _UnitsTab({this.isManager = false});

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'occupied':
        return AppColors.success;
      case 'vacant':
        return AppColors.warning;
      case 'maintenance':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  void _deleteUnit(BuildContext context, WidgetRef ref, String unitId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Unit'),
        content: const Text('Are you sure you want to delete this unit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider)!;
                await api.deleteUnit(buildingId, unitId);
                ref.invalidate(_unitsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Unit deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(_unitsProvider);
    final theme = Theme.of(context);

    return unitsAsync.when(
      data: (units) {
        if (units.isEmpty) {
          return const _EmptyTabState(
            icon: Icons.door_front_door_outlined,
            title: 'No units yet',
            subtitle: 'Add units to your building to get started.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_unitsProvider);
            await ref.read(_unitsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: units.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final unit = units[index];
              final status = unit['status'] as String? ?? 'unknown';
              final statusColor = _statusColor(status);

              return Card(
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      unit['unit_number']?.toString() ?? '#',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    'Unit ${unit['unit_number'] ?? ''}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Floor ${unit['floor'] ?? '-'}${unit['block'] != null ? '  |  Block ${unit['block']}' : ''}${unit['area_sqm'] != null ? '  |  ${unit['area_sqm']} sqm' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: isManager
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteUnit(context, ref, unit['id'] as String);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      color: AppColors.error, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style:
                                          TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status[0].toUpperCase() + status.substring(1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: statusColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        );
      },
      loading: () => _shimmerList(),
      error: (e, _) => _buildError(e, () => ref.invalidate(_unitsProvider)),
    );
  }
}

// ===========================================================================
// Finances Tab
// ===========================================================================

class _FinancesTab extends ConsumerWidget {
  final bool isManager;
  const _FinancesTab({this.isManager = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final duesAsync = ref.watch(_duesProvider);
    final theme = Theme.of(context);

    return duesAsync.when(
      data: (data) {
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        final plans = (data['plans'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_duesProvider);
            await ref.read(_duesProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              // Summary cards
              Row(
                children: [
                  Expanded(
                    child: _FinanceSummaryCard(
                      label: 'Total Collected',
                      value: _formatCurrency(summary['total_collected']),
                      icon: Icons.account_balance_wallet_outlined,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FinanceSummaryCard(
                      label: 'Total Pending',
                      value: _formatCurrency(summary['total_pending']),
                      icon: Icons.schedule_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FinanceSummaryCard(
                      label: 'Overdue',
                      value: _formatCurrency(summary['total_overdue']),
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Dues Plans',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              if (plans.isEmpty)
                const _EmptyTabState(
                  icon: Icons.payments_outlined,
                  title: 'No dues plans',
                  subtitle: 'Create a dues plan to start collecting.',
                )
              else
                ...plans.map((plan) => _DuesTile(
                      plan: plan,
                      isManager: isManager,
                      onDeleted: () => ref.invalidate(_duesProvider),
                    )),
            ],
          ),
        );
      },
      loading: () => _shimmerCardsAndList(),
      error: (e, _) => _buildError(e, () => ref.invalidate(_duesProvider)),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0';
    final num amount = value is num ? value : 0;
    if (amount >= 1000) {
      return '\$${(amount / 1000).toStringAsFixed(1)}k';
    }
    return '\$${amount.toStringAsFixed(0)}';
  }
}

class _FinanceSummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FinanceSummaryCard({
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(
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

class _DuesTile extends ConsumerWidget {
  final Map<String, dynamic> plan;
  final bool isManager;
  final VoidCallback? onDeleted;
  const _DuesTile({required this.plan, this.isManager = false, this.onDeleted});

  void _deletePlan(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Dues Plan'),
        content: const Text('Are you sure you want to delete this dues plan?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider)!;
                await api.deleteDuesPlan(buildingId, plan['id'] as String);
                onDeleted?.call();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dues plan deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditDuesPlanSheet(
        plan: plan,
        onSuccess: () => onDeleted?.call(),
      ),
    );
  }

  void _showPaySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _PayDuesSheet(
        plan: plan,
        onSuccess: () => onDeleted?.call(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paidCount = plan['paid_count'] ?? 0;
    final totalCount = plan['total_count'] ?? 1;
    final progress = totalCount > 0 ? paidCount / totalCount : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['title'] as String? ?? 'Dues',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '\$${plan['amount'] ?? 0}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                if (isManager) ...[
                  const SizedBox(width: 4),
                  PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    iconSize: 20,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          _showEditSheet(context, ref);
                          break;
                        case 'pay':
                          _showPaySheet(context, ref);
                          break;
                        case 'delete':
                          _deletePlan(context, ref);
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined,
                                color: AppColors.primary, size: 20),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'pay',
                        child: Row(
                          children: [
                            Icon(Icons.payment_outlined,
                                color: AppColors.success, size: 20),
                            SizedBox(width: 8),
                            Text('Record Payment',
                                style: TextStyle(color: AppColors.success)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                color: AppColors.error, size: 20),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: AppColors.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Due: ${plan['due_date'] ?? '-'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$paidCount / $totalCount paid',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.toDouble(),
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Maintenance Tab
// ===========================================================================

class _MaintenanceTab extends ConsumerWidget {
  final bool isManager;
  const _MaintenanceTab({this.isManager = false});

  Color _priorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'emergency':
        return AppColors.emergency;
      case 'high':
        return AppColors.high;
      case 'normal':
        return AppColors.normal;
      case 'low':
        return AppColors.low;
      default:
        return AppColors.textSecondary;
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending_approval':
      case 'pending approval':
        return AppColors.accent;
      case 'open':
        return AppColors.info;
      case 'in_progress':
      case 'in progress':
        return AppColors.warning;
      case 'resolved':
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  void _approveRequest(BuildContext context, WidgetRef ref, String reqId) async {
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      await api.approveMaintenanceRequest(buildingId, reqId);
      ref.invalidate(_maintenanceProvider);
      if (context.mounted) {
        final isTr = ref.read(localeProvider).languageCode == 'tr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isTr ? 'Talep onaylandı' : 'Request approved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _rejectRequest(BuildContext context, WidgetRef ref, String reqId) async {
    final isTr = ref.read(localeProvider).languageCode == 'tr';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTr ? 'Talebi Reddet' : 'Reject Request'),
        content: Text(isTr
            ? 'Bu bakım talebini reddetmek istediğinizden emin misiniz?'
            : 'Are you sure you want to reject this maintenance request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTr ? 'İptal' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider)!;
                await api.rejectMaintenanceRequest(buildingId, reqId);
                ref.invalidate(_maintenanceProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isTr ? 'Talep reddedildi' : 'Request rejected')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(isTr ? 'Reddet' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _deleteRequest(BuildContext context, WidgetRef ref, String reqId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Request'),
        content: const Text('Are you sure you want to delete this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider)!;
                await api.deleteMaintenanceRequest(buildingId, reqId);
                ref.invalidate(_maintenanceProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showChangeStatusSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangeStatusSheet(
        request: req,
        onSuccess: () => ref.invalidate(_maintenanceProvider),
      ),
    );
  }

  void _showEditMaintenanceSheet(BuildContext context, WidgetRef ref, Map<String, dynamic> req) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditMaintenanceSheet(
        request: req,
        onSuccess: () => ref.invalidate(_maintenanceProvider),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maintenanceAsync = ref.watch(_maintenanceProvider);
    final theme = Theme.of(context);

    return maintenanceAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return const _EmptyTabState(
            icon: Icons.build_outlined,
            title: 'No maintenance requests',
            subtitle: 'All clear! Create a request if something needs fixing.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_maintenanceProvider);
            await ref.read(_maintenanceProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final req = requests[index];
              final priority = req['priority'] as String? ?? 'normal';
              final status = req['status'] as String? ?? 'open';
              final priorityColor = _priorityColor(priority);
              final statusColor = _statusColor(status);

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              req['title'] as String? ?? '',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildChip(
                            label: priority,
                            color: priorityColor,
                            theme: theme,
                          ),
                          if (isManager) ...[
                            const SizedBox(width: 4),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                              onSelected: (value) {
                                final reqId = req['id'] as String;
                                switch (value) {
                                  case 'approve':
                                    _approveRequest(context, ref, reqId);
                                    break;
                                  case 'reject':
                                    _rejectRequest(context, ref, reqId);
                                    break;
                                  case 'status':
                                    _showChangeStatusSheet(context, ref, req);
                                    break;
                                  case 'edit':
                                    _showEditMaintenanceSheet(context, ref, req);
                                    break;
                                  case 'delete':
                                    _deleteRequest(context, ref, reqId);
                                    break;
                                }
                              },
                              itemBuilder: (_) => [
                                if (status == 'pending_approval') ...[
                                  const PopupMenuItem(
                                    value: 'approve',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_outline,
                                            color: AppColors.success, size: 20),
                                        SizedBox(width: 8),
                                        Text('Approve',
                                            style: TextStyle(color: AppColors.success)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'reject',
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel_outlined,
                                            color: AppColors.error, size: 20),
                                        SizedBox(width: 8),
                                        Text('Reject',
                                            style: TextStyle(color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                                if (status != 'pending_approval')
                                  const PopupMenuItem(
                                    value: 'status',
                                    child: Row(
                                      children: [
                                        Icon(Icons.swap_horiz,
                                            color: AppColors.info, size: 20),
                                        SizedBox(width: 8),
                                        Text('Change Status'),
                                      ],
                                    ),
                                  ),
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_outlined,
                                          color: AppColors.primary, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_outline,
                                          color: AppColors.error, size: 20),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style: TextStyle(color: AppColors.error)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                      if (req['description'] != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          req['description'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildChip(
                            label: status.replaceAll('_', ' '),
                            color: statusColor,
                            theme: theme,
                          ),
                          const Spacer(),
                          if (req['created_by_name'] != null)
                            Text(
                              req['created_by_name'] as String,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          if (req['created_at'] != null) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.schedule,
                                size: 14, color: AppColors.textHint),
                            const SizedBox(width: 4),
                            Text(
                              _formatDate(req['created_at']),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Approve/Reject buttons for managers on pending requests
                      if (isManager && status == 'pending_approval') ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () =>
                                  _rejectRequest(context, ref, req['id'] as String),
                              icon: const Icon(Icons.close, size: 16),
                              label: Text(ref.read(localeProvider).languageCode == 'tr'
                                  ? 'Reddet'
                                  : 'Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: () =>
                                  _approveRequest(context, ref, req['id'] as String),
                              icon: const Icon(Icons.check, size: 16),
                              label: Text(ref.read(localeProvider).languageCode == 'tr'
                                  ? 'Onayla'
                                  : 'Approve'),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => _shimmerList(),
      error: (e, _) =>
          _buildError(e, () => ref.invalidate(_maintenanceProvider)),
    );
  }

  Widget _buildChip({
    required String label,
    required Color color,
    required ThemeData theme,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label[0].toUpperCase() + label.substring(1),
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return dateStr.toString();
    }
  }
}

// ===========================================================================
// Vendors Tab
// ===========================================================================

class _VendorsTab extends ConsumerWidget {
  final bool isManager;
  const _VendorsTab({this.isManager = false});

  void _deleteVendor(BuildContext context, WidgetRef ref, String vendorId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor'),
        content: const Text('Are you sure you want to delete this vendor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider)!;
                await api.deleteVendor(buildingId, vendorId);
                ref.invalidate(_vendorsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vendor deleted')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendorsAsync = ref.watch(_vendorsProvider);
    final theme = Theme.of(context);

    return vendorsAsync.when(
      data: (vendors) {
        if (vendors.isEmpty) {
          return const _EmptyTabState(
            icon: Icons.store_outlined,
            title: 'No vendors yet',
            subtitle: 'Add vendors to manage your building services.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_vendorsProvider);
            await ref.read(_vendorsProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: vendors.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final vendor = vendors[index];
              final category =
                  vendor['category'] as String? ?? 'General';

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha:0.12),
                    child: Icon(
                      _vendorIcon(category),
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    vendor['name'] as String? ?? 'Vendor',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (vendor['email'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          vendor['email'] as String,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha:0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              category,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (vendor['rating'] != null &&
                              (vendor['rating'] as num) > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.star, size: 14, color: AppColors.accent),
                            const SizedBox(width: 2),
                            Text(
                              '${vendor['rating']}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: isManager
                      ? PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'delete') {
                              _deleteVendor(context, ref, vendor['id'] as String);
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline,
                                      color: AppColors.error, size: 20),
                                  SizedBox(width: 8),
                                  Text('Delete',
                                      style: TextStyle(color: AppColors.error)),
                                ],
                              ),
                            ),
                          ],
                        )
                      : (vendor['phone'] != null
                          ? IconButton(
                              icon: const Icon(Icons.phone_outlined, size: 20),
                              color: AppColors.primary,
                              onPressed: () {
                                // TODO: launch phone dialer
                              },
                            )
                          : null),
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
      loading: () => _shimmerList(),
      error: (e, _) =>
          _buildError(e, () => ref.invalidate(_vendorsProvider)),
    );
  }

  IconData _vendorIcon(String type) {
    switch (type.toLowerCase()) {
      case 'plumbing':
        return Icons.plumbing;
      case 'electrical':
        return Icons.electrical_services;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'security':
        return Icons.security;
      case 'landscaping':
        return Icons.yard_outlined;
      case 'elevator':
        return Icons.elevator_outlined;
      case 'hvac':
        return Icons.ac_unit;
      case 'painting':
        return Icons.format_paint;
      default:
        return Icons.handyman;
    }
  }
}

// ===========================================================================
// Members Tab
// ===========================================================================

class _MembersTab extends ConsumerWidget {
  final bool isManager;
  const _MembersTab({this.isManager = false});

  String _roleLabel(String? role) {
    switch (role) {
      case 'super_admin':
        return 'Super Admin';
      case 'building_manager':
        return 'Manager';
      case 'resident':
        return 'Resident';
      case 'security':
        return 'Security';
      default:
        return role ?? 'Unknown';
    }
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'super_admin':
        return AppColors.error;
      case 'building_manager':
        return AppColors.primary;
      case 'security':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  void _removeMember(BuildContext context, WidgetRef ref, String userId, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text('Are you sure you want to remove $name from this building?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider)!;
                await api.removeMember(buildingId, userId);
                ref.invalidate(_membersProvider);
                ref.invalidate(_memberRoleProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$name removed from building')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(_membersProvider);
    final theme = Theme.of(context);
    final authState = ref.read(authStateProvider);
    final currentUserId = authState.user?['id'] as String?;

    return membersAsync.when(
      data: (members) {
        if (members.isEmpty) {
          return const _EmptyTabState(
            icon: Icons.people_outlined,
            title: 'No members',
            subtitle: 'Invite users to join your building.',
          );
        }
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            ref.invalidate(_membersProvider);
            await ref.read(_membersProvider.future);
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: members.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              final memberId = member['id'] as String? ?? '';
              final name = member['full_name'] as String? ?? 'Unknown';
              final email = member['email'] as String? ?? '';
              final role = member['role'] as String? ?? 'resident';
              final isCurrentUser = memberId == currentUserId;
              final roleColor = _roleColor(role);

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.12),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: roleColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isCurrentUser)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.info.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'You',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.info,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        email,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: roleColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _roleLabel(role),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: roleColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  trailing: (isManager && !isCurrentUser)
                      ? IconButton(
                          icon: const Icon(Icons.person_remove_outlined,
                              color: AppColors.error),
                          onPressed: () =>
                              _removeMember(context, ref, memberId, name),
                        )
                      : null,
                  isThreeLine: true,
                ),
              );
            },
          ),
        );
      },
      loading: () => _shimmerList(),
      error: (e, _) =>
          _buildError(e, () => ref.invalidate(_membersProvider)),
    );
  }
}

// ===========================================================================
// Shared Widgets
// ===========================================================================

class _EmptyTabState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyTabState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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

// ===========================================================================
// Bottom sheet handle + title helper
// ===========================================================================

class _SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SheetHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
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
        Row(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ===========================================================================
// Add Building Bottom Sheet
// ===========================================================================

class _AddBuildingSheet extends ConsumerStatefulWidget {
  final void Function(String buildingId) onCreated;

  const _AddBuildingSheet({required this.onCreated});

  @override
  ConsumerState<_AddBuildingSheet> createState() => _AddBuildingSheetState();
}

class _AddBuildingSheetState extends ConsumerState<_AddBuildingSheet> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _totalUnitsController = TextEditingController();
  bool _submitting = false;
  LatLng? _selectedLocation;
  bool _showMap = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _totalUnitsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final city = _cityController.text.trim();
    final totalUnits = int.tryParse(_totalUnitsController.text.trim()) ?? 0;

    if (name.isEmpty || address.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name, address, and city are required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (totalUnits < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Total units must be at least 1.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.createBuilding({
        'name': name,
        'address': address,
        'city': city,
        'total_units': totalUnits,
        if (_selectedLocation != null) 'latitude': _selectedLocation!.latitude,
        if (_selectedLocation != null) 'longitude': _selectedLocation!.longitude,
      });

      if (response.data['success'] == true) {
        final buildingData = response.data['data'] as Map<String, dynamic>;
        final buildingId = buildingData['id'] as String;
        if (mounted) Navigator.of(context).pop();
        widget.onCreated(buildingId);
      } else {
        throw Exception(response.data['error'] ?? 'Failed to create building');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            icon: Icons.add_business_outlined,
            title: 'Add Building',
          ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Building Name',
              hintText: 'e.g. Sunset Apartments',
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Address',
              hintText: 'e.g. 123 Main Street',
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _cityController,
            decoration: const InputDecoration(
              labelText: 'City',
              hintText: 'e.g. Istanbul',
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _totalUnitsController,
            decoration: const InputDecoration(
              labelText: 'Total Units',
              hintText: 'e.g. 24',
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          // Location picker toggle
          InkWell(
            onTap: () => setState(() => _showMap = !_showMap),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.map_outlined,
                    color: _selectedLocation != null
                        ? AppColors.primary
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedLocation != null
                          ? 'Location: ${_selectedLocation!.latitude.toStringAsFixed(4)}, ${_selectedLocation!.longitude.toStringAsFixed(4)}'
                          : 'Select Location on Map (optional)',
                      style: TextStyle(
                        color: _selectedLocation != null
                            ? AppColors.textPrimary
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Icon(
                    _showMap
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.grey.shade600,
                  ),
                ],
              ),
            ),
          ),
          if (_showMap) ...[
            const SizedBox(height: 10),
            MapLocationPicker(
              initialLocation: _selectedLocation,
              onLocationSelected: (loc) {
                setState(() => _selectedLocation = loc);
              },
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Building',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      ),
    );
  }
}

// ===========================================================================
// Add Unit Bottom Sheet
// ===========================================================================

class _AddUnitSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _AddUnitSheet({required this.onSuccess});

  @override
  ConsumerState<_AddUnitSheet> createState() => _AddUnitSheetState();
}

class _AddUnitSheetState extends ConsumerState<_AddUnitSheet> {
  final _blockController = TextEditingController();
  final _floorController = TextEditingController();
  final _unitNumberController = TextEditingController();
  final _areaSqmController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _blockController.dispose();
    _floorController.dispose();
    _unitNumberController.dispose();
    _areaSqmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final unitNumber = _unitNumberController.text.trim();
    final floor = int.tryParse(_floorController.text.trim());

    if (unitNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unit number is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (floor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Floor is required and must be a number.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      final block = _blockController.text.trim();
      final areaSqm = double.tryParse(_areaSqmController.text.trim());

      await api.createUnit(buildingId, {
        'unit_number': unitNumber,
        'floor': floor,
        if (block.isNotEmpty) 'block': block,
        if (areaSqm != null) 'area_sqm': areaSqm,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            icon: Icons.door_front_door_outlined,
            title: 'Add Unit',
          ),
          TextField(
            controller: _unitNumberController,
            decoration: const InputDecoration(
              labelText: 'Unit Number *',
              hintText: 'e.g. 101',
            ),
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _floorController,
            decoration: const InputDecoration(
              labelText: 'Floor *',
              hintText: 'e.g. 1',
            ),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _blockController,
            decoration: const InputDecoration(
              labelText: 'Block (optional)',
              hintText: 'e.g. A',
            ),
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _areaSqmController,
            decoration: const InputDecoration(
              labelText: 'Area (sqm) (optional)',
              hintText: 'e.g. 85.5',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
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

// ===========================================================================
// Create Dues Plan Bottom Sheet
// ===========================================================================

class _CreateDuesPlanSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _CreateDuesPlanSheet({required this.onSuccess});

  @override
  ConsumerState<_CreateDuesPlanSheet> createState() =>
      _CreateDuesPlanSheetState();
}

class _CreateDuesPlanSheetState extends ConsumerState<_CreateDuesPlanSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _periodMonthController = TextEditingController();
  final _periodYearController = TextEditingController();
  final _dueDateController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _periodMonthController.text = now.month.toString();
    _periodYearController.text = now.year.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _periodMonthController.dispose();
    _periodYearController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now,
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dueDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final periodMonth = int.tryParse(_periodMonthController.text.trim());
    final periodYear = int.tryParse(_periodYearController.text.trim());
    final dueDate = _dueDateController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amount must be greater than 0.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (periodMonth == null || periodMonth < 1 || periodMonth > 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Period month must be between 1 and 12.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (periodYear == null || periodYear < 2020) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Period year must be 2020 or later.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (dueDate.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Due date is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;

      await api.createDuesPlan(buildingId, {
        'title': title,
        'amount': amount,
        'period_month': periodMonth,
        'period_year': periodYear,
        'due_date': dueDate,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            icon: Icons.payments_outlined,
            title: 'Create Dues Plan',
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. March 2026 Maintenance Fee',
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amountController,
            decoration: const InputDecoration(
              labelText: 'Amount *',
              hintText: 'e.g. 250.00',
              prefixText: '\$ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _periodMonthController,
                  decoration: const InputDecoration(
                    labelText: 'Period Month *',
                    hintText: '1-12',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _periodYearController,
                  decoration: const InputDecoration(
                    labelText: 'Period Year *',
                    hintText: '2026',
                  ),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  enabled: !_submitting,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _dueDateController,
            decoration: InputDecoration(
              labelText: 'Due Date *',
              hintText: 'YYYY-MM-DD',
              suffixIcon: IconButton(
                icon: const Icon(Icons.calendar_today_outlined, size: 20),
                onPressed: _submitting ? null : _pickDueDate,
              ),
            ),
            readOnly: true,
            onTap: _submitting ? null : _pickDueDate,
            enabled: !_submitting,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Create Plan',
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

// ===========================================================================
// Create Maintenance Request Bottom Sheet
// ===========================================================================

class _CreateMaintenanceSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _CreateMaintenanceSheet({required this.onSuccess});

  @override
  ConsumerState<_CreateMaintenanceSheet> createState() =>
      _CreateMaintenanceSheetState();
}

class _CreateMaintenanceSheetState
    extends ConsumerState<_CreateMaintenanceSheet> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPriority = 'normal';
  bool _submitting = false;

  static const _priorities = ['low', 'normal', 'high', 'emergency'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'emergency':
        return AppColors.emergency;
      case 'high':
        return AppColors.high;
      case 'normal':
        return AppColors.normal;
      case 'low':
        return AppColors.low;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Title is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;

      await api.createMaintenanceRequest(buildingId, {
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'priority': _selectedPriority,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            icon: Icons.build_outlined,
            title: 'New Maintenance Request',
          ),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Title *',
              hintText: 'e.g. Leaking pipe in basement',
            ),
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the issue in detail...',
              alignLabelWithHint: true,
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 3,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          Text(
            'Priority',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _priorities.map((priority) {
              final isSelected = _selectedPriority == priority;
              final color = _priorityColor(priority);
              return ChoiceChip(
                label: Text(
                  priority[0].toUpperCase() + priority.substring(1),
                ),
                selected: isSelected,
                onSelected: _submitting
                    ? null
                    : (_) => setState(() => _selectedPriority = priority),
                selectedColor: color.withValues(alpha:0.2),
                labelStyle: TextStyle(
                  color: isSelected ? color : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
                side: BorderSide(
                  color: isSelected ? color : Colors.grey.shade300,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Submit Request',
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

// ===========================================================================
// Add Vendor Bottom Sheet
// ===========================================================================

class _AddVendorSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _AddVendorSheet({required this.onSuccess});

  @override
  ConsumerState<_AddVendorSheet> createState() => _AddVendorSheetState();
}

class _AddVendorSheetState extends ConsumerState<_AddVendorSheet> {
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _submitting = false;

  static const _categories = [
    'Plumbing',
    'Electrical',
    'Cleaning',
    'Security',
    'Landscaping',
    'Elevator',
    'HVAC',
    'Painting',
    'General',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vendor name is required.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      final category = _categoryController.text.trim();
      final phone = _phoneController.text.trim();
      final email = _emailController.text.trim();

      await api.createVendor(buildingId, {
        'name': name,
        if (category.isNotEmpty) 'category': category,
        if (phone.isNotEmpty) 'phone': phone,
        if (email.isNotEmpty) 'email': email,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            icon: Icons.store_outlined,
            title: 'Add Vendor',
          ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Vendor Name *',
              hintText: 'e.g. ABC Plumbing Services',
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          DropdownMenu<String>(
            controller: _categoryController,
            label: const Text('Category'),
            hintText: 'Select a category',
            expandedInsets: EdgeInsets.zero,
            enabled: !_submitting,
            inputDecorationTheme: Theme.of(context).inputDecorationTheme,
            dropdownMenuEntries: _categories
                .map((cat) => DropdownMenuEntry(value: cat, label: cat))
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              hintText: 'e.g. +90 555 123 4567',
            ),
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            enabled: !_submitting,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              hintText: 'e.g. contact@vendor.com',
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !_submitting,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save',
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

// ===========================================================================
// Invite User Sheet
// ===========================================================================

class _InviteUserSheet extends ConsumerStatefulWidget {
  const _InviteUserSheet();

  @override
  ConsumerState<_InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends ConsumerState<_InviteUserSheet> {
  final _emailCtrl = TextEditingController();
  String _selectedRole = 'resident';
  bool _loading = false;
  List<Map<String, dynamic>> _invitations = [];
  bool _loadingInvitations = true;

  @override
  void initState() {
    super.initState();
    _loadInvitations();
  }

  Future<void> _loadInvitations() async {
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.getInvitations(buildingId);
      if (response.data['success'] == true) {
        final data = response.data['data'];
        if (data is List) {
          setState(() {
            _invitations = data.cast<Map<String, dynamic>>();
            _loadingInvitations = false;
          });
        } else if (data is Map && data.containsKey('data')) {
          setState(() {
            _invitations =
                (data['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];
            _loadingInvitations = false;
          });
        } else {
          setState(() => _loadingInvitations = false);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInvitations = false);
    }
  }

  Future<void> _sendInvitation() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;
    final isTr = ref.read(localeProvider).languageCode == 'tr';

    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final response = await api.inviteUser(buildingId, {
        'email': email,
        'role': _selectedRole,
      });
      if (response.data['success'] == true) {
        _emailCtrl.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isTr ? 'Davet gönderildi' : 'Invitation sent successfully')),
          );
        }
        _loadInvitations();
      } else {
        final error = response.data['error'] ?? 'Unknown error';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(error.toString().contains('already has a manager')
                  ? (isTr ? 'Bu binanın zaten bir yöneticisi var.' : error.toString())
                  : error.toString()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('already has a manager')) {
          msg = isTr ? 'Bu binanın zaten bir yöneticisi var. Bir binanın yalnızca 1 yöneticisi olabilir.' : 'This building already has a manager.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 12),
              Text(
                isTr ? 'Kullanıcı Davet Et' : 'Invite User',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _emailCtrl,
            decoration: InputDecoration(
              labelText: isTr ? 'E-posta Adresi' : 'Email Address',
              prefixIcon: const Icon(Icons.email_outlined),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            decoration: InputDecoration(
              labelText: isTr ? 'Rol' : 'Role',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: const OutlineInputBorder(),
            ),
            items: [
              DropdownMenuItem(
                value: 'resident',
                child: Text(isTr ? 'Sakin' : 'Resident'),
              ),
              DropdownMenuItem(
                value: 'building_admin',
                child: Text(isTr ? 'Bina Yöneticisi' : 'Building Admin'),
              ),
              DropdownMenuItem(
                value: 'doorman',
                child: Text(isTr ? 'Kapıcı' : 'Doorman'),
              ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _selectedRole = v);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _loading ? null : _sendInvitation,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(
                isTr ? 'Davet Gönder' : 'Send Invitation',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          if (_invitations.isNotEmpty || _loadingInvitations) ...[
            const SizedBox(height: 24),
            Text(
              isTr ? 'Gönderilen Davetler' : 'Sent Invitations',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            if (_loadingInvitations)
              const Center(child: CircularProgressIndicator())
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _invitations.length,
                  itemBuilder: (context, index) {
                    final inv = _invitations[index];
                    final status = inv['status'] ?? 'pending';
                    final email = inv['email'] ?? '';
                    final role = (inv['role'] ?? 'resident') as String;
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        status == 'accepted'
                            ? Icons.check_circle
                            : status == 'expired'
                                ? Icons.timer_off
                                : Icons.hourglass_empty,
                        color: status == 'accepted'
                            ? Colors.green
                            : status == 'expired'
                                ? Colors.red
                                : Colors.orange,
                        size: 20,
                      ),
                      title:
                          Text(email, style: const TextStyle(fontSize: 14)),
                      subtitle: Text(
                        '${role.replaceAll('_', ' ')} • $status',
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ===========================================================================
// Change Maintenance Status Bottom Sheet
// ===========================================================================

class _ChangeStatusSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onSuccess;

  const _ChangeStatusSheet({required this.request, required this.onSuccess});

  @override
  ConsumerState<_ChangeStatusSheet> createState() => _ChangeStatusSheetState();
}

class _ChangeStatusSheetState extends ConsumerState<_ChangeStatusSheet> {
  late String _selectedStatus;
  bool _submitting = false;

  static const _statuses = ['open', 'in_progress', 'resolved', 'closed'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.request['status'] as String? ?? 'open';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.info;
      case 'in_progress':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.textSecondary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed':
        return 'Closed';
      default:
        return status;
    }
  }

  Future<void> _submit() async {
    if (_selectedStatus == (widget.request['status'] as String? ?? 'open')) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      final reqId = widget.request['id'] as String;

      await api.updateMaintenanceRequest(buildingId, reqId, {
        'status': _selectedStatus,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SheetHeader(
            icon: Icons.swap_horiz,
            title: 'Change Status',
          ),
          Text(
            widget.request['title'] as String? ?? '',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ...(_statuses.map((status) {
            final isSelected = _selectedStatus == status;
            final color = _statusColor(status);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: _submitting ? null : () => setState(() => _selectedStatus = status),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? color.withValues(alpha: 0.08) : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _statusLabel(status),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? color : null,
                          ),
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: color, size: 22),
                    ],
                  ),
                ),
              ),
            );
          })),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Update Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Edit Maintenance Request Bottom Sheet
// ===========================================================================

class _EditMaintenanceSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> request;
  final VoidCallback onSuccess;

  const _EditMaintenanceSheet({required this.request, required this.onSuccess});

  @override
  ConsumerState<_EditMaintenanceSheet> createState() => _EditMaintenanceSheetState();
}

class _EditMaintenanceSheetState extends ConsumerState<_EditMaintenanceSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late String _selectedPriority;
  bool _submitting = false;

  static const _priorities = ['low', 'normal', 'high', 'emergency'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.request['title'] as String? ?? '');
    _descriptionController = TextEditingController(text: widget.request['description'] as String? ?? '');
    _selectedPriority = widget.request['priority'] as String? ?? 'normal';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'emergency':
        return AppColors.emergency;
      case 'high':
        return AppColors.high;
      case 'normal':
        return AppColors.normal;
      case 'low':
        return AppColors.low;
      default:
        return AppColors.textSecondary;
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      final reqId = widget.request['id'] as String;
      final description = _descriptionController.text.trim();

      await api.updateMaintenanceRequest(buildingId, reqId, {
        'title': title,
        if (description.isNotEmpty) 'description': description,
        'priority': _selectedPriority,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(
              icon: Icons.edit_outlined,
              title: 'Edit Request',
            ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Leaking pipe in basement',
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the issue in detail...',
                alignLabelWithHint: true,
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
              enabled: !_submitting,
            ),
            const SizedBox(height: 14),
            Text(
              'Priority',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _priorities.map((priority) {
                final isSelected = _selectedPriority == priority;
                final color = _priorityColor(priority);
                return ChoiceChip(
                  label: Text(priority[0].toUpperCase() + priority.substring(1)),
                  selected: isSelected,
                  onSelected: _submitting
                      ? null
                      : (_) => setState(() => _selectedPriority = priority),
                  selectedColor: color.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? color : AppColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                  side: BorderSide(
                    color: isSelected ? color : Colors.grey.shade300,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Edit Dues Plan Bottom Sheet
// ===========================================================================

class _EditDuesPlanSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onSuccess;

  const _EditDuesPlanSheet({required this.plan, required this.onSuccess});

  @override
  ConsumerState<_EditDuesPlanSheet> createState() => _EditDuesPlanSheetState();
}

class _EditDuesPlanSheetState extends ConsumerState<_EditDuesPlanSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _periodMonthController;
  late final TextEditingController _periodYearController;
  late final TextEditingController _dueDateController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.plan['title'] as String? ?? '');
    _amountController = TextEditingController(text: '${widget.plan['amount'] ?? ''}');
    _periodMonthController = TextEditingController(text: '${widget.plan['period_month'] ?? ''}');
    _periodYearController = TextEditingController(text: '${widget.plan['period_year'] ?? ''}');

    // Parse due_date - handle both timestamp and date format
    String dueDate = '';
    final rawDate = widget.plan['due_date'];
    if (rawDate != null) {
      try {
        final dt = DateTime.parse(rawDate.toString());
        dueDate = '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      } catch (_) {
        dueDate = rawDate.toString();
      }
    }
    _dueDateController = TextEditingController(text: dueDate);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _periodMonthController.dispose();
    _periodYearController.dispose();
    _dueDateController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      _dueDateController.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    final periodMonth = int.tryParse(_periodMonthController.text.trim());
    final periodYear = int.tryParse(_periodYearController.text.trim());
    final dueDate = _dueDateController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title is required.'), backgroundColor: AppColors.error),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      final planId = widget.plan['id'] as String;

      final data = <String, dynamic>{
        'title': title,
        'amount': amount,
      };
      if (periodMonth != null) data['period_month'] = periodMonth;
      if (periodYear != null) data['period_year'] = periodYear;
      if (dueDate.isNotEmpty) data['due_date'] = dueDate;

      await api.updateDuesPlan(buildingId, planId, data);

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(
              icon: Icons.edit_outlined,
              title: 'Edit Dues Plan',
            ),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. March 2026 Maintenance Fee',
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                hintText: 'e.g. 250.00',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _periodMonthController,
                    decoration: const InputDecoration(
                      labelText: 'Period Month',
                      hintText: '1-12',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    enabled: !_submitting,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _periodYearController,
                    decoration: const InputDecoration(
                      labelText: 'Period Year',
                      hintText: '2026',
                    ),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    enabled: !_submitting,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _dueDateController,
              decoration: InputDecoration(
                labelText: 'Due Date',
                hintText: 'YYYY-MM-DD',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today_outlined, size: 20),
                  onPressed: _submitting ? null : _pickDueDate,
                ),
              ),
              readOnly: true,
              onTap: _submitting ? null : _pickDueDate,
              enabled: !_submitting,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================================
// Pay Dues (Record Payment) Bottom Sheet
// ===========================================================================

class _PayDuesSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> plan;
  final VoidCallback onSuccess;

  const _PayDuesSheet({required this.plan, required this.onSuccess});

  @override
  ConsumerState<_PayDuesSheet> createState() => _PayDuesSheetState();
}

class _PayDuesSheetState extends ConsumerState<_PayDuesSheet> {
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String? _selectedUnitId;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _amountController.text = '${widget.plan['amount'] ?? ''}';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a unit.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount must be greater than 0.'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final api = ref.read(apiClientProvider);
      final buildingId = ref.read(selectedBuildingIdProvider)!;
      final planId = widget.plan['id'] as String;
      final notes = _notesController.text.trim();

      await api.payDues(buildingId, planId, {
        'unit_id': _selectedUnitId,
        'paid_amount': amount,
        if (notes.isNotEmpty) 'notes': notes,
      });

      if (mounted) Navigator.of(context).pop();
      widget.onSuccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment recorded'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final unitsAsync = ref.watch(_unitsProvider);

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SheetHeader(
              icon: Icons.payment_outlined,
              title: 'Record Payment',
            ),
            Text(
              widget.plan['title'] as String? ?? 'Dues',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            // Unit selector
            unitsAsync.when(
              data: (units) {
                if (units.isEmpty) {
                  return const Text('No units available.');
                }
                return DropdownButtonFormField<String>(
                  value: _selectedUnitId,
                  decoration: const InputDecoration(
                    labelText: 'Unit *',
                    prefixIcon: Icon(Icons.door_front_door_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: units.map((unit) {
                    final unitId = unit['id'] as String;
                    final unitNumber = unit['unit_number']?.toString() ?? '';
                    final block = unit['block'] as String?;
                    final floor = unit['floor'];
                    final label = 'Unit $unitNumber${block != null ? ' (Block $block)' : ''}${floor != null ? ' - Floor $floor' : ''}';
                    return DropdownMenuItem(value: unitId, child: Text(label));
                  }).toList(),
                  onChanged: _submitting ? null : (v) => setState(() => _selectedUnitId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load units: $e'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount *',
                hintText: 'e.g. 250.00',
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              enabled: !_submitting,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'e.g. Paid via bank transfer',
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              enabled: !_submitting,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Record Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
