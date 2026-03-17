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

final _duesPlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getDuesPlans(buildingId);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

final _duesReportProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return {};
  final response = await api.getDuesReport(buildingId);
  if (response.data['success'] == true && response.data['data'] != null) {
    return response.data['data'] as Map<String, dynamic>;
  }
  return {};
});

final _expensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return [];
  final response = await api.getExpenses(buildingId, limit: 50);
  if (response.data['success'] == true && response.data['data'] != null) {
    return (response.data['data'] as List).cast<Map<String, dynamic>>();
  }
  return [];
});

// ---------------------------------------------------------------------------
// DuesScreen
// ---------------------------------------------------------------------------

class DuesScreen extends ConsumerStatefulWidget {
  const DuesScreen({super.key});

  @override
  ConsumerState<DuesScreen> createState() => _DuesScreenState();
}

class _DuesScreenState extends ConsumerState<DuesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: Text(isTr ? 'Aidat & Finans' : 'Dues & Finance'),
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
            Tab(text: isTr ? 'Özet' : 'Summary'),
            Tab(text: isTr ? 'Aidatlar' : 'Dues'),
            Tab(text: isTr ? 'Giderler' : 'Expenses'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SummaryTab(isTr: isTr),
          _DuesTab(isTr: isTr),
          _ExpensesTab(isTr: isTr),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Summary Tab
// ---------------------------------------------------------------------------

class _SummaryTab extends ConsumerWidget {
  final bool isTr;
  const _SummaryTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(_duesReportProvider);
    final theme = Theme.of(context);

    return reportAsync.when(
      data: (report) {
        if (report.isEmpty) {
          return Center(
            child: Text(isTr ? 'Rapor bulunamadı' : 'No report available'),
          );
        }

        final totalCollected =
            (report['total_collected'] ?? 0).toDouble();
        final totalPending = (report['total_pending'] ?? 0).toDouble();
        final overdue = (report['overdue'] ?? 0).toDouble();
        final collectionRate = (report['collection_rate'] ?? 0).toDouble();
        final payments = (report['recent_payments'] as List?)
                ?.cast<Map<String, dynamic>>() ??
            [];

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_duesReportProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Collection Rate Card
              Card(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        isTr ? 'Tahsilat Oranı' : 'Collection Rate',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: Colors.white70),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${collectionRate.toStringAsFixed(1)}%',
                        style: theme.textTheme.displaySmall
                            ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: collectionRate / 100,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(Colors.white),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Stats Row
              Row(
                children: [
                  Expanded(
                    child: _FinanceStatCard(
                      label: isTr ? 'Toplam Tahsilat' : 'Collected',
                      value: '₺${_formatMoney(totalCollected)}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FinanceStatCard(
                      label: isTr ? 'Bekleyen' : 'Pending',
                      value: '₺${_formatMoney(totalPending)}',
                      icon: Icons.schedule,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _FinanceStatCard(
                      label: isTr ? 'Gecikmiş' : 'Overdue',
                      value: '₺${_formatMoney(overdue)}',
                      icon: Icons.warning_amber_outlined,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Recent Payments
              Text(
                isTr ? 'Son Ödemeler' : 'Recent Payments',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              if (payments.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        isTr ? 'Henüz ödeme yok' : 'No payments yet',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                )
              else
                ...payments.map((p) => _PaymentTile(payment: p, isTr: isTr)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }

  String _formatMoney(double amount) {
    final formatter = NumberFormat('#,##0.00', 'tr_TR');
    return formatter.format(amount);
  }
}

class _FinanceStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _FinanceStatCard({
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final Map<String, dynamic> payment;
  final bool isTr;

  const _PaymentTile({required this.payment, required this.isTr});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = payment['status'] as String? ?? 'pending';
    final amount = (payment['paid_amount'] ?? payment['amount'] ?? 0).toDouble();
    final unitNumber = payment['unit_number'] as String? ?? '';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'paid':
        statusColor = AppColors.success;
        statusText = isTr ? 'Ödendi' : 'Paid';
        break;
      case 'late':
        statusColor = AppColors.error;
        statusText = isTr ? 'Gecikmiş' : 'Late';
        break;
      default:
        statusColor = AppColors.warning;
        statusText = isTr ? 'Bekliyor' : 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              unitNumber,
              style: theme.textTheme.titleSmall?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          '${isTr ? "Daire" : "Unit"} $unitNumber',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          statusText,
          style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
        ),
        trailing: Text(
          '₺${NumberFormat('#,##0.00', 'tr_TR').format(amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dues Tab
// ---------------------------------------------------------------------------

class _DuesTab extends ConsumerWidget {
  final bool isTr;
  const _DuesTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(_duesPlansProvider);
    final theme = Theme.of(context);

    return plansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.payments_outlined,
                    size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(isTr ? 'Henüz aidat planı yok' : 'No dues plans yet',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_duesPlansProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return _DuesPlanCard(plan: plan, isTr: isTr);
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _DuesPlanCard extends ConsumerWidget {
  final Map<String, dynamic> plan;
  final bool isTr;

  const _DuesPlanCard({required this.plan, required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final title = plan['title'] as String? ?? '';
    final amount = (plan['amount'] ?? 0).toDouble();
    final periodMonth = plan['period_month'] ?? 0;
    final periodYear = plan['period_year'] ?? 0;
    final dueDate = plan['due_date'] as String? ?? '';
    final payments =
        (plan['payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final paidCount =
        payments.where((p) => p['status'] == 'paid').length;
    final totalCount = payments.length;

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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.receipt_long,
                      color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        '$periodMonth/$periodYear',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₺${NumberFormat('#,##0.00', 'tr_TR').format(amount)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    if (dueDate.isNotEmpty)
                      Text(
                        '${isTr ? "Son:" : "Due:"} ${_formatDate(dueDate)}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ],
            ),
            if (totalCount > 0) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalCount > 0 ? paidCount / totalCount : 0,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation(AppColors.success),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$paidCount/$totalCount ${isTr ? "ödendi" : "paid"}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  _showPayDialog(context, ref, plan);
                },
                child: Text(isTr ? 'Ödeme Yap' : 'Make Payment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  void _showPayDialog(
      BuildContext context, WidgetRef ref, Map<String, dynamic> plan) {
    final amountController = TextEditingController(
      text: (plan['amount'] ?? 0).toString(),
    );
    final isTr = this.isTr;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isTr ? 'Ödeme Yap' : 'Make Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${plan['title']}',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isTr ? 'Tutar (₺)' : 'Amount (₺)',
                prefixText: '₺ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isTr ? 'İptal' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final amount =
                  double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              final api = ref.read(apiClientProvider);
              final buildingId =
                  ref.read(selectedBuildingIdProvider);
              if (buildingId == null) return;
              try {
                await api.payDues(buildingId, plan['id'], {
                  'paid_amount': amount,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(_duesPlansProvider);
                ref.invalidate(_duesReportProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isTr
                          ? 'Ödeme başarılı!'
                          : 'Payment successful!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${isTr ? "Hata" : "Error"}: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
            child: Text(isTr ? 'Öde' : 'Pay'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expenses Tab
// ---------------------------------------------------------------------------

class _ExpensesTab extends ConsumerWidget {
  final bool isTr;
  const _ExpensesTab({required this.isTr});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(_expensesProvider);
    final theme = Theme.of(context);

    return expensesAsync.when(
      data: (expenses) {
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 56, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(isTr ? 'Henüz gider yok' : 'No expenses yet',
                    style: theme.textTheme.titleMedium),
              ],
            ),
          );
        }

        // Calculate total
        double total = 0;
        for (final e in expenses) {
          total += (e['amount'] ?? 0).toDouble();
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(_expensesProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.error.withValues(alpha: 0.08),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.trending_down,
                          color: AppColors.error, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isTr ? 'Toplam Gider' : 'Total Expenses',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                          Text(
                            '₺${NumberFormat('#,##0.00', 'tr_TR').format(total)}',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...expenses.map((e) => _ExpenseTile(expense: e, isTr: isTr)),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text(e.toString())),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  final Map<String, dynamic> expense;
  final bool isTr;

  const _ExpenseTile({required this.expense, required this.isTr});

  IconData _categoryIcon(String? category) {
    switch (category) {
      case 'electricity':
        return Icons.bolt;
      case 'water':
        return Icons.water_drop;
      case 'gas':
        return Icons.local_fire_department;
      case 'cleaning':
        return Icons.cleaning_services;
      case 'maintenance':
        return Icons.build;
      case 'security':
        return Icons.security;
      case 'elevator':
        return Icons.elevator;
      case 'insurance':
        return Icons.shield;
      default:
        return Icons.receipt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = expense['category'] as String? ?? 'other';
    final amount = (expense['amount'] ?? 0).toDouble();
    final description = expense['description'] as String? ?? '';
    final date = expense['date'] as String? ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.info.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(_categoryIcon(category), color: AppColors.info, size: 22),
        ),
        title: Text(
          description.isNotEmpty ? description : category,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          _formatDate(date),
          style: theme.textTheme.bodySmall
              ?.copyWith(color: AppColors.textSecondary),
        ),
        trailing: Text(
          '₺${NumberFormat('#,##0.00', 'tr_TR').format(amount)}',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.error,
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
