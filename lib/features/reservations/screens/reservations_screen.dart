import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

final _areasProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getCommonAreas(buildingId);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final _reservationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getReservations(buildingId, limit: 50);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class ReservationsScreen extends ConsumerStatefulWidget {
  const ReservationsScreen({super.key});
  @override
  ConsumerState<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends ConsumerState<ReservationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() { super.initState(); _tabController = TabController(length: 2, vsync: this); }
  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Ortak Alanlar' : 'Common Areas'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white, unselectedLabelColor: Colors.white70, indicatorColor: Colors.white,
          tabs: [
            Tab(text: isTr ? 'Alanlar' : 'Areas'),
            Tab(text: isTr ? 'Rezervasyonlar' : 'Reservations'),
          ],
        ),
      ),
      body: TabBarView(controller: _tabController, children: [
        _AreasTab(isTr: isTr),
        _ReservationsTab(isTr: isTr),
      ]),
    );
  }
}

class _AreasTab extends ConsumerWidget {
  final bool isTr;
  const _AreasTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final areasAsync = ref.watch(_areasProvider);
    final theme = Theme.of(context);

    return areasAsync.when(
      data: (areas) {
        if (areas.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.meeting_room_outlined, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(isTr ? 'Ortak alan tanımlı değil' : 'No common areas defined', style: theme.textTheme.titleMedium),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_areasProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: areas.length,
            itemBuilder: (ctx, i) => _AreaCard(area: areas[i], isTr: isTr, onReserve: () => _showReserveDialog(context, ref, areas[i], isTr)),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  void _showReserveDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> area, bool isTr) {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay startTime = const TimeOfDay(hour: 10, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 12, minute: 0);
    int guestCount = 1;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Text('${isTr ? "Rezervasyon" : "Reserve"}: ${area['name']}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(controller: titleCtrl, decoration: InputDecoration(labelText: isTr ? 'Başlık' : 'Title')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(DateFormat('dd MMM yyyy').format(selectedDate)),
                onPressed: () async {
                  final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
                  if (d != null) setSheetState(() => selectedDate = d);
                },
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(
                child: Text('${isTr ? "Başla" : "Start"}: ${startTime.format(ctx)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: startTime);
                  if (t != null) setSheetState(() => startTime = t);
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton(
                child: Text('${isTr ? "Bitiş" : "End"}: ${endTime.format(ctx)}'),
                onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: endTime);
                  if (t != null) setSheetState(() => endTime = t);
                },
              )),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Text(isTr ? 'Misafir: ' : 'Guests: ', style: Theme.of(context).textTheme.bodyMedium),
              IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () { if (guestCount > 1) setSheetState(() => guestCount--); }),
              Text('$guestCount', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setSheetState(() => guestCount++)),
            ]),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final api = ref.read(apiClientProvider);
                  final buildingId = ref.read(selectedBuildingIdProvider);
                  if (buildingId == null) return;
                  final start = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, startTime.hour, startTime.minute);
                  final end = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, endTime.hour, endTime.minute);
                  try {
                    await api.createReservation(buildingId, {
                      'common_area_id': area['id'],
                      'title': titleCtrl.text.trim(),
                      'start_time': start.toIso8601String(),
                      'end_time': end.toIso8601String(),
                      'guest_count': guestCount,
                      'notes': notesCtrl.text.trim(),
                    });
                    if (ctx.mounted) Navigator.pop(ctx);
                    ref.invalidate(_reservationsProvider);
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isTr ? 'Rezervasyon oluşturuldu!' : 'Reservation created!'), backgroundColor: AppColors.success));
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                  }
                },
                child: Text(isTr ? 'Rezervasyon Yap' : 'Book Now'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  final Map<String, dynamic> area;
  final bool isTr;
  final VoidCallback onReserve;

  const _AreaCard({required this.area, required this.isTr, required this.onReserve});

  IconData _areaIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('spor') || n.contains('gym')) return Icons.fitness_center;
    if (n.contains('havuz') || n.contains('pool')) return Icons.pool;
    if (n.contains('toplantı') || n.contains('meeting')) return Icons.meeting_room;
    if (n.contains('barbekü') || n.contains('bbq')) return Icons.outdoor_grill;
    if (n.contains('çocuk') || n.contains('play')) return Icons.child_care;
    if (n.contains('sauna')) return Icons.hot_tub;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = area['name'] as String? ?? '';
    final description = area['description'] as String? ?? '';
    final capacity = area['capacity'] ?? 0;
    final openTime = area['open_time'] as String? ?? '08:00';
    final closeTime = area['close_time'] as String? ?? '22:00';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(_areaIcon(name), color: AppColors.primary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (description.isNotEmpty) Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ])),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.access_time, size: 14, color: AppColors.textHint),
            const SizedBox(width: 4),
            Text('$openTime - $closeTime', style: theme.textTheme.bodySmall),
            const SizedBox(width: 16),
            if (capacity > 0) ...[
              Icon(Icons.people, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('${isTr ? "Kapasite" : "Capacity"}: $capacity', style: theme.textTheme.bodySmall),
            ],
          ]),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(onPressed: onReserve, icon: const Icon(Icons.event_available, size: 18), label: Text(isTr ? 'Rezervasyon Yap' : 'Book Now')),
          ),
        ]),
      ),
    );
  }
}

class _ReservationsTab extends ConsumerWidget {
  final bool isTr;
  const _ReservationsTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resAsync = ref.watch(_reservationsProvider);
    final theme = Theme.of(context);

    return resAsync.when(
      data: (reservations) {
        if (reservations.isEmpty) {
          return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.event_busy, size: 56, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(isTr ? 'Rezervasyon yok' : 'No reservations', style: theme.textTheme.titleMedium),
          ]));
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_reservationsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reservations.length,
            itemBuilder: (ctx, i) => _ReservationTile(res: reservations[i], isTr: isTr),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _ReservationTile extends StatelessWidget {
  final Map<String, dynamic> res;
  final bool isTr;
  const _ReservationTile({required this.res, required this.isTr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final areaName = res['area_name'] as String? ?? '';
    final userName = res['user_name'] as String? ?? '';
    final title = res['title'] as String? ?? areaName;
    final status = res['status'] as String? ?? 'pending';
    final startTime = res['start_time'] as String? ?? '';
    final endTime = res['end_time'] as String? ?? '';

    Color statusColor;
    switch (status) {
      case 'approved': statusColor = AppColors.success; break;
      case 'rejected': statusColor = AppColors.error; break;
      case 'cancelled': statusColor = AppColors.textSecondary; break;
      default: statusColor = AppColors.warning;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.event, color: statusColor, size: 22),
        ),
        title: Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$areaName${userName.isNotEmpty ? " • $userName" : ""}', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          if (startTime.isNotEmpty) Text(_fmtRange(startTime, endTime), style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textHint)),
        ]),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Text(status.toUpperCase(), style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  String _fmtRange(String start, String end) {
    try {
      final s = DateTime.parse(start);
      final e = DateTime.parse(end);
      return '${DateFormat('dd MMM HH:mm').format(s)} - ${DateFormat('HH:mm').format(e)}';
    } catch (_) { return '$start - $end'; }
  }
}
