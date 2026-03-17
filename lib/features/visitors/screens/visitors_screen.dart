import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

final _visitorsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getVisitors(buildingId, limit: 50);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class VisitorsScreen extends ConsumerStatefulWidget {
  const VisitorsScreen({super.key});
  @override
  ConsumerState<VisitorsScreen> createState() => _VisitorsScreenState();
}

class _VisitorsScreenState extends ConsumerState<VisitorsScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    final visitorsAsync = ref.watch(_visitorsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Ziyaretçiler' : 'Visitors'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref, isTr),
        icon: const Icon(Icons.person_add),
        label: Text(isTr ? 'Ziyaretçi Ekle' : 'Add Visitor'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: visitorsAsync.when(
        data: (visitors) {
          if (visitors.isEmpty) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_alt_outlined, size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(isTr ? 'Ziyaretçi kaydı yok' : 'No visitor records', style: theme.textTheme.titleMedium),
              ]),
            );
          }

          final filtered = _filter == 'all' ? visitors : visitors.where((v) => v['status'] == _filter).toList();

          return Column(children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _chip(isTr ? 'Tümü' : 'All', 'all', visitors.length),
                const SizedBox(width: 8),
                _chip(isTr ? 'Bekliyor' : 'Pending', 'pending', visitors.where((v) => v['status'] == 'pending').length, AppColors.warning),
                const SizedBox(width: 8),
                _chip(isTr ? 'İçeride' : 'Checked In', 'checked_in', visitors.where((v) => v['status'] == 'checked_in').length, AppColors.success),
                const SizedBox(width: 8),
                _chip(isTr ? 'Çıktı' : 'Checked Out', 'checked_out', visitors.where((v) => v['status'] == 'checked_out').length, AppColors.textSecondary),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(_visitorsProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _VisitorCard(visitor: filtered[i], isTr: isTr, onAction: (action) => _handleAction(ref, filtered[i], action)),
                ),
              ),
            ),
          ]);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Widget _chip(String label, String value, int count, [Color? color]) {
    final chipColor = color ?? AppColors.primary;
    final sel = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? chipColor : chipColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('$label ($count)', style: TextStyle(color: sel ? Colors.white : chipColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Future<void> _handleAction(WidgetRef ref, Map<String, dynamic> visitor, String action) async {
    final api = ref.read(apiClientProvider);
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;
    try {
      if (action == 'checkin') await api.checkInVisitor(buildingId, visitor['id']);
      else if (action == 'checkout') await api.checkOutVisitor(buildingId, visitor['id']);
      else if (action == 'cancel') await api.cancelVisitorPass(buildingId, visitor['id']);
      ref.invalidate(_visitorsProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, bool isTr) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final plateCtrl = TextEditingController();
    final purposeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isTr ? 'Ziyaretçi Kaydı' : 'Register Visitor', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: nameCtrl, decoration: InputDecoration(labelText: isTr ? 'Ziyaretçi Adı *' : 'Visitor Name *', prefixIcon: const Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: isTr ? 'Telefon' : 'Phone', prefixIcon: const Icon(Icons.phone_outlined))),
          const SizedBox(height: 12),
          TextField(controller: plateCtrl, decoration: InputDecoration(labelText: isTr ? 'Araç Plakası' : 'Vehicle Plate', prefixIcon: const Icon(Icons.directions_car_outlined))),
          const SizedBox(height: 12),
          TextField(controller: purposeCtrl, decoration: InputDecoration(labelText: isTr ? 'Ziyaret Amacı' : 'Purpose', prefixIcon: const Icon(Icons.description_outlined))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider);
                if (buildingId == null) return;
                try {
                  await api.createVisitorPass(buildingId, {
                    'visitor_name': nameCtrl.text.trim(),
                    'visitor_phone': phoneCtrl.text.trim(),
                    'visitor_plate': plateCtrl.text.trim(),
                    'purpose': purposeCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(_visitorsProvider);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isTr ? 'Ziyaretçi kaydedildi!' : 'Visitor registered!'), backgroundColor: AppColors.success));
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
                }
              },
              child: Text(isTr ? 'Kaydet' : 'Save'),
            ),
          ),
        ]),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  final Map<String, dynamic> visitor;
  final bool isTr;
  final void Function(String) onAction;

  const _VisitorCard({required this.visitor, required this.isTr, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = visitor['visitor_name'] as String? ?? '';
    final phone = visitor['visitor_phone'] as String? ?? '';
    final plate = visitor['visitor_plate'] as String? ?? '';
    final status = visitor['status'] as String? ?? 'pending';
    final createdBy = visitor['created_by_name'] as String? ?? '';
    final createdAt = visitor['created_at'] as String? ?? '';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'checked_in': statusColor = AppColors.success; statusText = isTr ? 'İçeride' : 'Checked In'; break;
      case 'checked_out': statusColor = AppColors.textSecondary; statusText = isTr ? 'Çıktı' : 'Checked Out'; break;
      case 'cancelled': statusColor = AppColors.error; statusText = isTr ? 'İptal' : 'Cancelled'; break;
      default: statusColor = AppColors.warning; statusText = isTr ? 'Bekliyor' : 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            CircleAvatar(backgroundColor: statusColor.withValues(alpha: 0.12), child: Icon(Icons.person, color: statusColor)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (createdBy.isNotEmpty) Text('${isTr ? "Davet eden" : "Host"}: $createdBy', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 16, children: [
            if (phone.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.phone, size: 14, color: AppColors.textHint), const SizedBox(width: 4), Text(phone, style: theme.textTheme.bodySmall)]),
            if (plate.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.directions_car, size: 14, color: AppColors.textHint), const SizedBox(width: 4), Text(plate, style: theme.textTheme.bodySmall)]),
            if (createdAt.isNotEmpty) Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.access_time, size: 14, color: AppColors.textHint), const SizedBox(width: 4), Text(_fmtDate(createdAt), style: theme.textTheme.bodySmall)]),
          ]),
          if (status == 'pending') ...[
            const Divider(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => onAction('cancel'), icon: const Icon(Icons.close, size: 18), label: Text(isTr ? 'İptal' : 'Cancel'), style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(onPressed: () => onAction('checkin'), icon: const Icon(Icons.login, size: 18), label: Text(isTr ? 'Giriş' : 'Check In'))),
            ]),
          ],
          if (status == 'checked_in') ...[
            const Divider(height: 20),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: () => onAction('checkout'), icon: const Icon(Icons.logout, size: 18), label: Text(isTr ? 'Çıkış Yap' : 'Check Out'))),
          ],
        ]),
      ),
    );
  }

  String _fmtDate(String s) { try { return DateFormat('dd MMM HH:mm').format(DateTime.parse(s)); } catch (_) { return s; } }
}
