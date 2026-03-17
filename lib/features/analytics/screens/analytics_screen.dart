import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_localizations.dart';

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

final _analyticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final buildingId = ref.watch(selectedBuildingIdProvider);
  if (buildingId == null) return {};

  // Fetch multiple data sources in parallel
  final results = await Future.wait([
    api.getBuildingDashboard(buildingId),
    api.getDuesReport(buildingId),
    api.getMaintenanceRequests(buildingId, limit: 100),
  ]);

  final dashboard =
      results[0].data['success'] == true ? results[0].data['data'] ?? {} : {};
  final duesReport =
      results[1].data['success'] == true ? results[1].data['data'] ?? {} : {};
  final maintenanceList = results[2].data['success'] == true
      ? (results[2].data['data'] as List?)?.cast<Map<String, dynamic>>() ?? []
      : <Map<String, dynamic>>[];

  return {
    ...dashboard as Map<String, dynamic>,
    'dues_report': duesReport,
    'maintenance_list': maintenanceList,
  };
});

// ---------------------------------------------------------------------------
// AnalyticsScreen
// ---------------------------------------------------------------------------

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isTr = locale.languageCode == 'tr';
    final analyticsAsync = ref.watch(_analyticsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isTr ? 'Dashboard & Analitik' : 'Dashboard & Analytics'),
        leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop()),
      ),
      body: analyticsAsync.when(
        data: (data) {
          if (data.isEmpty) {
            return Center(
                child: Text(isTr ? 'Veri bulunamadı' : 'No data available'));
          }

          final duesReport =
              data['dues_report'] as Map<String, dynamic>? ?? {};
          final maintenanceList = data['maintenance_list']
                  as List<Map<String, dynamic>>? ??
              [];

          final totalCollected =
              (duesReport['total_collected'] ?? 0).toDouble();
          final totalPending =
              (duesReport['total_pending'] ?? 0).toDouble();
          final overdue = (duesReport['overdue'] ?? 0).toDouble();

          // Maintenance stats
          int pending = 0, open = 0, inProgress = 0, resolved = 0;
          for (final req in maintenanceList) {
            switch (req['status']) {
              case 'pending_approval':
                pending++;
                break;
              case 'open':
                open++;
                break;
              case 'in_progress':
                inProgress++;
                break;
              case 'resolved':
              case 'closed':
                resolved++;
                break;
            }
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_analyticsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overview Stats
                _SectionTitle(title: isTr ? 'Genel Bakış' : 'Overview'),
                const SizedBox(height: 12),
                Row(children: [
                  _MiniStat(
                      label: isTr ? 'Toplam Daire' : 'Units',
                      value: '${data['total_units'] ?? 0}',
                      icon: Icons.door_front_door,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  _MiniStat(
                      label: isTr ? 'Üye' : 'Members',
                      value: '${data['total_members'] ?? 0}',
                      icon: Icons.people,
                      color: AppColors.info),
                  const SizedBox(width: 10),
                  _MiniStat(
                      label: isTr ? 'Talepler' : 'Requests',
                      value: '${maintenanceList.length}',
                      icon: Icons.build,
                      color: AppColors.warning),
                ]),

                const SizedBox(height: 24),

                // Financial Pie Chart
                _SectionTitle(
                    title: isTr ? 'Finansal Durum' : 'Financial Overview'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      SizedBox(
                        height: 200,
                        child: PieChart(PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 40,
                          sections: [
                            PieChartSectionData(
                              value: totalCollected,
                              color: AppColors.success,
                              title:
                                  '₺${_formatShort(totalCollected)}',
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              radius: 55,
                            ),
                            PieChartSectionData(
                              value: totalPending > 0 ? totalPending : 0.01,
                              color: AppColors.warning,
                              title:
                                  '₺${_formatShort(totalPending)}',
                              titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                              radius: 50,
                            ),
                            if (overdue > 0)
                              PieChartSectionData(
                                value: overdue,
                                color: AppColors.error,
                                title:
                                    '₺${_formatShort(overdue)}',
                                titleStyle: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white),
                                radius: 50,
                              ),
                          ],
                        )),
                      ),
                      const SizedBox(height: 16),
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _LegendDot(
                                color: AppColors.success,
                                label: isTr ? 'Tahsil Edilen' : 'Collected'),
                            _LegendDot(
                                color: AppColors.warning,
                                label: isTr ? 'Bekleyen' : 'Pending'),
                            _LegendDot(
                                color: AppColors.error,
                                label: isTr ? 'Gecikmiş' : 'Overdue'),
                          ]),
                    ]),
                  ),
                ),

                const SizedBox(height: 24),

                // Maintenance Bar Chart
                _SectionTitle(
                    title: isTr ? 'Bakım Durumu' : 'Maintenance Status'),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      height: 200,
                      child: BarChart(BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: [pending, open, inProgress, resolved]
                                .reduce((a, b) => a > b ? a : b)
                                .toDouble() +
                            2,
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final labels = isTr
                                    ? ['Bekliyor', 'Açık', 'Devam', 'Çözüldü']
                                    : ['Pending', 'Open', 'Active', 'Done'];
                                if (value.toInt() < labels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(labels[value.toInt()],
                                        style: const TextStyle(fontSize: 10)),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _makeBar(0, pending.toDouble(), AppColors.warning),
                          _makeBar(1, open.toDouble(), AppColors.info),
                          _makeBar(2, inProgress.toDouble(), AppColors.primary),
                          _makeBar(3, resolved.toDouble(), AppColors.success),
                        ],
                      )),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Quick Summary Cards
                _SectionTitle(
                    title:
                        isTr ? 'Hızlı İstatistikler' : 'Quick Statistics'),
                const SizedBox(height: 12),
                _SummaryCard(
                  icon: Icons.trending_up,
                  color: AppColors.success,
                  title: isTr ? 'Tahsilat Oranı' : 'Collection Rate',
                  value:
                      '${((duesReport['collection_rate'] ?? 0) as num).toStringAsFixed(1)}%',
                ),
                const SizedBox(height: 8),
                _SummaryCard(
                  icon: Icons.build_circle,
                  color: AppColors.warning,
                  title: isTr
                      ? 'Aktif Bakım Talepleri'
                      : 'Active Maintenance Requests',
                  value: '${pending + open + inProgress}',
                ),
                const SizedBox(height: 8),
                _SummaryCard(
                  icon: Icons.check_circle,
                  color: AppColors.success,
                  title: isTr
                      ? 'Çözülen Talepler'
                      : 'Resolved Requests',
                  value: '$resolved',
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  BarChartGroupData _makeBar(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 28,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ],
    );
  }

  String _formatShort(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    }
    return amount.toStringAsFixed(0);
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600));
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MiniStat(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 8),
            Text(value,
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textSecondary)),
    ]);
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String value;

  const _SummaryCard(
      {required this.icon,
      required this.color,
      required this.title,
      required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500)),
        trailing: Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold, color: color)),
      ),
    );
  }
}
