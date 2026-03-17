import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

final _packagesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getPackages(buildingId, limit: 50);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key});
  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    final packagesAsync = ref.watch(_packagesProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Kargo & Paketler' : 'Packages & Deliveries'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context, ref, isTr),
        icon: const Icon(Icons.add),
        label: Text(isTr ? 'Kargo Ekle' : 'Add Package'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: packagesAsync.when(
        data: (packages) {
          if (packages.isEmpty) {
            return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.inventory_2_outlined, size: 56, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(isTr ? 'Kargo kaydı yok' : 'No packages', style: theme.textTheme.titleMedium),
            ]));
          }

          final filtered = _filter == 'all' ? packages : packages.where((p) => p['status'] == _filter).toList();
          final waitingCount = packages.where((p) => p['status'] == 'waiting').length;

          return Column(children: [
            // Stats bar
            if (waitingCount > 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.inventory, color: AppColors.warning, size: 24),
                  const SizedBox(width: 10),
                  Text('$waitingCount ${isTr ? "kargo teslim bekliyor" : "packages awaiting pickup"}',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, color: AppColors.warning)),
                ]),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                _chip(isTr ? 'Tümü' : 'All', 'all', packages.length),
                const SizedBox(width: 8),
                _chip(isTr ? 'Bekliyor' : 'Waiting', 'waiting', waitingCount, AppColors.warning),
                const SizedBox(width: 8),
                _chip(isTr ? 'Bildirildi' : 'Notified', 'notified', packages.where((p) => p['status'] == 'notified').length, AppColors.info),
                const SizedBox(width: 8),
                _chip(isTr ? 'Teslim' : 'Picked Up', 'picked_up', packages.where((p) => p['status'] == 'picked_up').length, AppColors.success),
              ]),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => ref.invalidate(_packagesProvider),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) => _PackageCard(pkg: filtered[i], isTr: isTr, onAction: (a) => _handleAction(ref, filtered[i], a)),
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
        decoration: BoxDecoration(color: sel ? chipColor : chipColor.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
        child: Text('$label ($count)', style: TextStyle(color: sel ? Colors.white : chipColor, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Future<void> _handleAction(WidgetRef ref, Map<String, dynamic> pkg, String action) async {
    final api = ref.read(apiClientProvider);
    final buildingId = ref.read(selectedBuildingIdProvider);
    if (buildingId == null) return;
    try {
      if (action == 'pickup') await api.pickUpPackage(buildingId, pkg['id']);
      else if (action == 'notify') await api.notifyPackageRecipient(buildingId, pkg['id']);
      ref.invalidate(_packagesProvider);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    }
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref, bool isTr) {
    final carrierCtrl = TextEditingController();
    final trackingCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),
          Text(isTr ? 'Kargo Kaydı' : 'Register Package', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          TextField(controller: carrierCtrl, decoration: InputDecoration(labelText: isTr ? 'Kargo Firması' : 'Carrier', prefixIcon: const Icon(Icons.local_shipping_outlined))),
          const SizedBox(height: 12),
          TextField(controller: trackingCtrl, decoration: InputDecoration(labelText: isTr ? 'Takip Numarası' : 'Tracking Number', prefixIcon: const Icon(Icons.qr_code))),
          const SizedBox(height: 12),
          TextField(controller: descCtrl, decoration: InputDecoration(labelText: isTr ? 'Açıklama' : 'Description', prefixIcon: const Icon(Icons.description_outlined))),
          const SizedBox(height: 12),
          TextField(controller: notesCtrl, decoration: InputDecoration(labelText: isTr ? 'Not' : 'Notes', prefixIcon: const Icon(Icons.note_outlined))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final api = ref.read(apiClientProvider);
                final buildingId = ref.read(selectedBuildingIdProvider);
                if (buildingId == null) return;
                try {
                  await api.createPackage(buildingId, {
                    'carrier': carrierCtrl.text.trim(),
                    'tracking_number': trackingCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'notes': notesCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  ref.invalidate(_packagesProvider);
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isTr ? 'Kargo kaydedildi!' : 'Package registered!'), backgroundColor: AppColors.success));
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

class _PackageCard extends StatelessWidget {
  final Map<String, dynamic> pkg;
  final bool isTr;
  final void Function(String) onAction;

  const _PackageCard({required this.pkg, required this.isTr, required this.onAction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final carrier = pkg['carrier'] as String? ?? '';
    final tracking = pkg['tracking_number'] as String? ?? '';
    final description = pkg['description'] as String? ?? '';
    final recipient = pkg['recipient_name'] as String? ?? '';
    final status = pkg['status'] as String? ?? 'waiting';
    final receivedAt = pkg['received_at'] as String? ?? '';

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case 'notified': statusColor = AppColors.info; statusText = isTr ? 'Bildirildi' : 'Notified'; statusIcon = Icons.notifications_active; break;
      case 'picked_up': statusColor = AppColors.success; statusText = isTr ? 'Teslim Alındı' : 'Picked Up'; statusIcon = Icons.check_circle; break;
      default: statusColor = AppColors.warning; statusText = isTr ? 'Bekliyor' : 'Waiting'; statusIcon = Icons.hourglass_empty;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.inventory_2, color: statusColor, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(carrier.isNotEmpty ? carrier : (description.isNotEmpty ? description : (isTr ? 'Kargo' : 'Package')),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              if (tracking.isNotEmpty) Text('# $tracking', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
              if (recipient.isNotEmpty) Text('${isTr ? "Alıcı" : "To"}: $recipient', style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Icon(statusIcon, color: statusColor, size: 20),
              Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
            ]),
          ]),
          if (receivedAt.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.access_time, size: 14, color: AppColors.textHint),
              const SizedBox(width: 4),
              Text('${isTr ? "Alınma" : "Received"}: ${_fmtDate(receivedAt)}', style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textHint)),
            ]),
          ],
          if (status == 'waiting') ...[
            const Divider(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => onAction('notify'), icon: const Icon(Icons.notifications_outlined, size: 18), label: Text(isTr ? 'Bildir' : 'Notify'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton.icon(onPressed: () => onAction('pickup'), icon: const Icon(Icons.check, size: 18), label: Text(isTr ? 'Teslim Et' : 'Pick Up'))),
            ]),
          ],
          if (status == 'notified') ...[
            const Divider(height: 20),
            SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: () => onAction('pickup'), icon: const Icon(Icons.check, size: 18), label: Text(isTr ? 'Teslim Et' : 'Pick Up'), style: FilledButton.styleFrom(backgroundColor: AppColors.success))),
          ],
        ]),
      ),
    );
  }

  String _fmtDate(String s) { try { return DateFormat('dd MMM HH:mm').format(DateTime.parse(s)); } catch (_) { return s; } }
}
