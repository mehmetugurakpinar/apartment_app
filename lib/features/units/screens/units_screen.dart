import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _unitsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getUnits(buildingId);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final _residentsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getResidents(buildingId);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

// ---------------------------------------------------------------------------
// UnitsScreen
// ---------------------------------------------------------------------------

class UnitsScreen extends ConsumerStatefulWidget {
  const UnitsScreen({super.key});

  @override
  ConsumerState<UnitsScreen> createState() => _UnitsScreenState();
}

class _UnitsScreenState extends ConsumerState<UnitsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Daireler & Sakinler' : 'Units & Residents'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: const Icon(Icons.door_front_door_outlined, size: 20),
              text: isTr ? 'Daireler' : 'Units',
            ),
            Tab(
              icon: const Icon(Icons.people_outline, size: 20),
              text: isTr ? 'Sakinler' : 'Residents',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddUnitDialog(context, ref, isTr),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _UnitsTab(isTr: isTr),
          _ResidentsTab(isTr: isTr),
        ],
      ),
    );
  }

  void _showAddUnitDialog(BuildContext context, WidgetRef ref, bool isTr) {
    final numberCtrl = TextEditingController();
    final floorCtrl = TextEditingController();
    final blockCtrl = TextEditingController();
    final areaCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
              isTr ? 'Yeni Daire Ekle' : 'Add New Unit',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: numberCtrl,
                    decoration: InputDecoration(
                      labelText: isTr ? 'Daire No' : 'Unit Number',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: floorCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: isTr ? 'Kat' : 'Floor',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: blockCtrl,
                    decoration: InputDecoration(
                      labelText: isTr ? 'Blok' : 'Block',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: areaCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isTr ? 'Alan (m²)' : 'Area (sqm)',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  if (numberCtrl.text.trim().isEmpty) return;
                  final api = ref.read(apiClientProvider);
                  final buildingId = ref.read(selectedBuildingIdProvider);
                  if (buildingId == null) return;
                  try {
                    await api.createUnit(buildingId, {
                      'unit_number': numberCtrl.text.trim(),
                      'floor':
                          int.tryParse(floorCtrl.text) ?? 0,
                      if (blockCtrl.text.trim().isNotEmpty)
                        'block': blockCtrl.text.trim(),
                      if (areaCtrl.text.trim().isNotEmpty)
                        'area_sqm':
                            double.tryParse(areaCtrl.text) ?? 0,
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_unitsProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isTr
                              ? 'Daire eklendi!'
                              : 'Unit added!'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: Text(isTr ? 'Daire Ekle' : 'Add Unit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Units Tab
// ---------------------------------------------------------------------------

class _UnitsTab extends ConsumerWidget {
  final bool isTr;
  const _UnitsTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unitsAsync = ref.watch(_unitsProvider);
    final theme = Theme.of(context);

    return unitsAsync.when(
      data: (units) {
        if (units.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.door_front_door_outlined,
                    size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(isTr ? 'Henüz daire yok' : 'No units yet',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  isTr
                      ? 'Başlamak için daire ekleyin'
                      : 'Add units to get started',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_unitsProvider),
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: units.length,
            itemBuilder: (context, index) {
              return _UnitCard(unit: units[index], isTr: isTr);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _UnitCard extends StatelessWidget {
  final Map<String, dynamic> unit;
  final bool isTr;

  const _UnitCard({required this.unit, required this.isTr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unitNumber = unit['unit_number'] as String? ?? '';
    final floor = unit['floor'] ?? 0;
    final block = unit['block'] as String? ?? '';
    final status = unit['status'] as String? ?? 'vacant';
    final areaSqm = unit['area_sqm'];
    final ownerName = unit['owner_name'] as String? ?? '';

    final isOccupied = status == 'occupied';
    final statusColor = isOccupied ? AppColors.success : AppColors.warning;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        unitNumber,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '${isTr ? "Kat" : "Floor"} $floor${block.isNotEmpty ? ' • $block' : ''}',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              if (areaSqm != null)
                Text(
                  '$areaSqm m²',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textHint),
                ),
              const Spacer(),
              Text(
                ownerName.isNotEmpty
                    ? ownerName
                    : (isTr ? 'Boş' : 'Vacant'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isOccupied
                      ? AppColors.textPrimary
                      : AppColors.textHint,
                  fontWeight:
                      isOccupied ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Residents Tab
// ---------------------------------------------------------------------------

class _ResidentsTab extends ConsumerWidget {
  final bool isTr;
  const _ResidentsTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final residentsAsync = ref.watch(_residentsProvider);
    final theme = Theme.of(context);

    return residentsAsync.when(
      data: (residents) {
        if (residents.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.people_outline,
                    size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(isTr ? 'Henüz sakin yok' : 'No residents yet',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_residentsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: residents.length,
            itemBuilder: (context, index) {
              return _ResidentTile(
                  resident: residents[index], isTr: isTr);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _ResidentTile extends StatelessWidget {
  final Map<String, dynamic> resident;
  final bool isTr;

  const _ResidentTile({required this.resident, required this.isTr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fullName = resident['full_name'] as String? ?? '';
    final email = resident['email'] as String? ?? '';
    final phone = resident['phone'] as String? ?? '';
    final unitNumber = resident['unit_number'] as String? ?? '';
    final type = resident['type'] as String? ?? 'tenant';
    final avatarUrl = resident['avatar_url'] as String?;

    final initials = fullName.isNotEmpty
        ? fullName
            .split(' ')
            .map((w) => w.isNotEmpty ? w[0] : '')
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl) : null,
          child: avatarUrl == null
              ? Text(initials,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600))
              : null,
        ),
        title: Text(
          fullName,
          style: theme.textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${isTr ? "Daire" : "Unit"} $unitNumber • ${type == 'owner' ? (isTr ? 'Ev Sahibi' : 'Owner') : (isTr ? 'Kiracı' : 'Tenant')}',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (phone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone_outlined,
                    size: 20, color: AppColors.primary),
                onPressed: () {},
                tooltip: phone,
              ),
            IconButton(
              icon: const Icon(Icons.message_outlined,
                  size: 20, color: AppColors.primary),
              onPressed: () {
                final userId = resident['user_id'] as String? ??
                    resident['id'] as String? ??
                    '';
                if (userId.isNotEmpty) {
                  context.push('/users/$userId');
                }
              },
              tooltip: isTr ? 'Mesaj Gönder' : 'Send Message',
            ),
          ],
        ),
      ),
    );
  }
}
