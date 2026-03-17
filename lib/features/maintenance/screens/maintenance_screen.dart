import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _maintenanceProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getMaintenanceRequests(buildingId, limit: 50);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

// ---------------------------------------------------------------------------
// MaintenanceScreen
// ---------------------------------------------------------------------------

class MaintenanceScreen extends ConsumerStatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  ConsumerState<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends ConsumerState<MaintenanceScreen> {
  String _statusFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    final requestsAsync = ref.watch(_maintenanceProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Bakım Talepleri' : 'Maintenance Requests'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRequestDialog(context, ref, isTr),
        icon: const Icon(Icons.add),
        label: Text(isTr ? 'Yeni Talep' : 'New Request'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: requestsAsync.when(
        data: (requests) {
          if (requests.isEmpty) {
            return _buildEmptyState(theme, isTr);
          }

          final filtered = _statusFilter == 'all'
              ? requests
              : requests
                  .where((r) => r['status'] == _statusFilter)
                  .toList();

          return Column(
            children: [
              // Status filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _FilterChip(
                      label: isTr ? 'Tümü' : 'All',
                      isSelected: _statusFilter == 'all',
                      onTap: () => setState(() => _statusFilter = 'all'),
                      count: requests.length,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: isTr ? 'Bekliyor' : 'Pending',
                      isSelected: _statusFilter == 'pending_approval',
                      onTap: () => setState(
                          () => _statusFilter = 'pending_approval'),
                      count: requests
                          .where((r) => r['status'] == 'pending_approval')
                          .length,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: isTr ? 'Açık' : 'Open',
                      isSelected: _statusFilter == 'open',
                      onTap: () =>
                          setState(() => _statusFilter = 'open'),
                      count: requests
                          .where((r) => r['status'] == 'open')
                          .length,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: isTr ? 'Devam Ediyor' : 'In Progress',
                      isSelected: _statusFilter == 'in_progress',
                      onTap: () =>
                          setState(() => _statusFilter = 'in_progress'),
                      count: requests
                          .where((r) => r['status'] == 'in_progress')
                          .length,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: isTr ? 'Çözüldü' : 'Resolved',
                      isSelected: _statusFilter == 'resolved',
                      onTap: () =>
                          setState(() => _statusFilter = 'resolved'),
                      count: requests
                          .where((r) => r['status'] == 'resolved')
                          .length,
                      color: AppColors.success,
                    ),
                  ],
                ),
              ),
              // Requests list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(_maintenanceProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _MaintenanceCard(
                        request: filtered[index],
                        isTr: isTr,
                        onStatusChange: (status) =>
                            _updateStatus(ref, filtered[index], status),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme, bool isTr) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.build_outlined,
                size: 40, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            isTr ? 'Bakım talebi yok' : 'No maintenance requests',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            isTr
                ? 'Her şey yolunda! Tamir gereken bir şey varsa talep oluşturun.'
                : 'All clear! Create a request if something needs fixing.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(
      WidgetRef ref, Map<String, dynamic> request, String action) async {
    final api = ref.read(apiClientProvider);
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;
    try {
      if (action == 'approve') {
        await api.approveMaintenanceRequest(buildingId, request['id']);
      } else if (action == 'reject') {
        await api.rejectMaintenanceRequest(buildingId, request['id']);
      } else {
        await api.updateMaintenanceRequest(
            buildingId, request['id'], {'status': action});
      }
      ref.invalidate(_maintenanceProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCreateRequestDialog(
      BuildContext context, WidgetRef ref, bool isTr) {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    String priority = 'normal';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                isTr ? 'Yeni Bakım Talebi' : 'New Maintenance Request',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: isTr ? 'Başlık' : 'Title',
                  hintText:
                      isTr ? 'Sorun kısaca ne?' : 'What is the issue?',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isTr ? 'Açıklama' : 'Description',
                  hintText: isTr
                      ? 'Detaylı açıklama...'
                      : 'Detailed description...',
                ),
              ),
              const SizedBox(height: 12),
              Text(isTr ? 'Öncelik' : 'Priority',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  _PriorityChip(
                    label: isTr ? 'Düşük' : 'Low',
                    color: AppColors.low,
                    isSelected: priority == 'low',
                    onTap: () =>
                        setSheetState(() => priority = 'low'),
                  ),
                  _PriorityChip(
                    label: isTr ? 'Normal' : 'Normal',
                    color: AppColors.normal,
                    isSelected: priority == 'normal',
                    onTap: () =>
                        setSheetState(() => priority = 'normal'),
                  ),
                  _PriorityChip(
                    label: isTr ? 'Yüksek' : 'High',
                    color: AppColors.high,
                    isSelected: priority == 'high',
                    onTap: () =>
                        setSheetState(() => priority = 'high'),
                  ),
                  _PriorityChip(
                    label: isTr ? 'Acil' : 'Emergency',
                    color: AppColors.emergency,
                    isSelected: priority == 'emergency',
                    onTap: () =>
                        setSheetState(() => priority = 'emergency'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    final api = ref.read(apiClientProvider);
                    final buildingId =
                        ref.read(selectedBuildingIdProvider);
                    if (buildingId == null) return;
                    try {
                      await api.createMaintenanceRequest(buildingId, {
                        'title': titleController.text.trim(),
                        'description': descController.text.trim(),
                        'priority': priority,
                      });
                      if (ctx.mounted) Navigator.pop(ctx);
                      ref.invalidate(_maintenanceProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isTr
                                ? 'Talep oluşturuldu!'
                                : 'Request created!'),
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
                  child: Text(isTr ? 'Talebi Gönder' : 'Submit Request'),
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
// Sub-Widgets
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int count;
  final Color? color;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : chipColor,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.3)
                      : chipColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: isSelected ? Colors.white : chipColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PriorityChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityChip({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? color : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? color : Colors.grey.shade300,
      ),
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final bool isTr;
  final void Function(String action) onStatusChange;

  const _MaintenanceCard({
    required this.request,
    required this.isTr,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = request['title'] as String? ?? '';
    final description = request['description'] as String? ?? '';
    final status = request['status'] as String? ?? 'pending_approval';
    final priority = request['priority'] as String? ?? 'normal';
    final createdAt = request['created_at'] as String? ?? '';
    final createdBy = request['created_by_name'] as String? ?? '';

    final statusInfo = _getStatusInfo(status);
    final priorityInfo = _getPriorityInfo(priority);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: priorityInfo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(priorityInfo.icon,
                      color: priorityInfo.color, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      if (createdBy.isNotEmpty)
                        Text(createdBy,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: TextStyle(
                      color: statusInfo.color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.access_time,
                    size: 14, color: AppColors.textHint),
                const SizedBox(width: 4),
                Text(
                  _formatDate(createdAt),
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: AppColors.textHint),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityInfo.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    priorityInfo.label,
                    style: TextStyle(
                      color: priorityInfo.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            // Action buttons based on status
            if (status == 'pending_approval') ...[
              const Divider(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => onStatusChange('reject'),
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(isTr ? 'Reddet' : 'Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => onStatusChange('approve'),
                      icon: const Icon(Icons.check, size: 18),
                      label: Text(isTr ? 'Onayla' : 'Approve'),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'open') ...[
              const Divider(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => onStatusChange('in_progress'),
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: Text(isTr ? 'Başla' : 'Start Work'),
                ),
              ),
            ],
            if (status == 'in_progress') ...[
              const Divider(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onStatusChange('resolved'),
                  icon: const Icon(Icons.check_circle, size: 18),
                  label: Text(isTr ? 'Çözüldü' : 'Mark Resolved'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  _StatusInfo _getStatusInfo(String status) {
    switch (status) {
      case 'pending_approval':
        return _StatusInfo(
          label: isTr ? 'Onay Bekliyor' : 'Pending',
          color: AppColors.warning,
        );
      case 'open':
        return _StatusInfo(
          label: isTr ? 'Açık' : 'Open',
          color: AppColors.info,
        );
      case 'in_progress':
        return _StatusInfo(
          label: isTr ? 'Devam Ediyor' : 'In Progress',
          color: AppColors.primary,
        );
      case 'resolved':
        return _StatusInfo(
          label: isTr ? 'Çözüldü' : 'Resolved',
          color: AppColors.success,
        );
      case 'closed':
        return _StatusInfo(
          label: isTr ? 'Kapatıldı' : 'Closed',
          color: AppColors.textSecondary,
        );
      default:
        return _StatusInfo(label: status, color: AppColors.textSecondary);
    }
  }

  _PriorityInfo _getPriorityInfo(String priority) {
    switch (priority) {
      case 'emergency':
        return _PriorityInfo(
          label: isTr ? 'Acil' : 'Emergency',
          color: AppColors.emergency,
          icon: Icons.error,
        );
      case 'high':
        return _PriorityInfo(
          label: isTr ? 'Yüksek' : 'High',
          color: AppColors.high,
          icon: Icons.priority_high,
        );
      case 'normal':
        return _PriorityInfo(
          label: isTr ? 'Normal' : 'Normal',
          color: AppColors.normal,
          icon: Icons.remove_circle_outline,
        );
      case 'low':
        return _PriorityInfo(
          label: isTr ? 'Düşük' : 'Low',
          color: AppColors.low,
          icon: Icons.arrow_downward,
        );
      default:
        return _PriorityInfo(
          label: priority,
          color: AppColors.textSecondary,
          icon: Icons.help_outline,
        );
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy HH:mm').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _StatusInfo {
  final String label;
  final Color color;
  _StatusInfo({required this.label, required this.color});
}

class _PriorityInfo {
  final String label;
  final Color color;
  final IconData icon;
  _PriorityInfo(
      {required this.label, required this.color, required this.icon});
}
