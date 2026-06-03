import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../core/ad_banner.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../database_helper.dart';
import '../models/watch.dart';
import '../models/watch_log.dart';
import 'add_edit_watch_screen.dart';

class WatchDetailScreen extends StatefulWidget {
  final Watch watch;

  const WatchDetailScreen({super.key, required this.watch});

  @override
  State<WatchDetailScreen> createState() => _WatchDetailScreenState();
}

class _WatchDetailScreenState extends State<WatchDetailScreen> {
  late Watch _currentWatch;
  List<WatchLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentWatch = widget.watch;
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    if (_currentWatch.id != null) {
      final logs = await DatabaseHelper.instance.readWatchLogs(_currentWatch.id!);
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshWatch() async {
    if (_currentWatch.id != null) {
      final updatedWatch = await DatabaseHelper.instance.readWatch(_currentWatch.id!);
      if (updatedWatch != null) {
        setState(() {
          _currentWatch = updatedWatch;
        });
        _loadLogs();
      }
    }
  }

  Future<void> _toggleIsActive(bool value) async {
    final updatedWatch = _currentWatch.copyWith(isActive: value);
    await DatabaseHelper.instance.update(updatedWatch);
    setState(() {
      _currentWatch = updatedWatch;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasError = _currentWatch.lastStatus != null &&
        (_currentWatch.lastStatus! < 200 || _currentWatch.lastStatus! >= 300);
    final statusColor = hasError ? AppColors.danger : AppColors.success;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentWatch.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => AddEditWatchScreen(watch: _currentWatch),
                ),
              );
              _refreshWatch();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: SwitchListTile(
                      title: const Text('Monitoring Active', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Pause or resume monitoring for this watch'),
                      value: _currentWatch.isActive,
                      onChanged: _toggleIsActive,
                      secondary: Icon(
                        _currentWatch.isActive ? Icons.play_circle : Icons.pause_circle,
                        color: _currentWatch.isActive ? AppColors.success : AppColors.textSecondaryLight,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        children: [
                          _DetailRow(label: 'URL', value: _currentWatch.url),
                          _DetailRow(label: 'Interval', value: '${_currentWatch.intervalMinutes} minutes'),
                          _DetailRow(label: 'Expected Status', value: '200-299'),
                          _DetailRow(label: 'Keyword (Optional)', value: _currentWatch.keyword ?? 'None'),
                          _DetailRow(
                            label: 'Last Status',
                            value: _currentWatch.lastStatus == null
                                ? 'Never checked'
                                : (_currentWatch.lastStatus == -1
                                    ? 'Keyword Failed (-1)'
                                    : _currentWatch.lastStatus.toString()),
                            valueColor: statusColor,
                          ),
                          _DetailRow(
                            label: 'Last Checked',
                            value: _currentWatch.lastCheckTime != null
                                ? DateFormat('yyyy-MM-dd HH:mm').format(_currentWatch.lastCheckTime!)
                                : 'Never',
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '31-Day History',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _HistoryChart(logs: _logs),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Response Time (Last 50)',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _ResponseTimeChart(logs: _logs),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Recent Logs',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _LogList(logs: _logs),
                  const SizedBox(height: AppSpacing.md),
                  const AdBanner(adUnitId: 'ca-app-pub-3940256099942544/6300978111'),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryChart extends StatelessWidget {
  final List<WatchLog> logs;

  const _HistoryChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final Map<DateTime, bool> dailyStatus = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 31; i++) {
      final day = today.subtract(Duration(days: 30 - i));
      dailyStatus[day] = true;
    }

    final Map<DateTime, bool> actualDailyStatus = {};
    for (final log in logs) {
      final logDay = DateTime(log.timestamp.year, log.timestamp.month, log.timestamp.day);
      if (actualDailyStatus[logDay] == null || actualDailyStatus[logDay] == true) {
        actualDailyStatus[logDay] = log.status;
      }
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 31,
        itemBuilder: (context, index) {
          final day = today.subtract(Duration(days: 30 - index));
          final hasLogs = actualDailyStatus.containsKey(day);
          final status = actualDailyStatus[day];

          Color color = Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.borderLight;
          if (hasLogs) {
            color = status == true ? AppColors.success : AppColors.danger;
          }

          return Tooltip(
            message: DateFormat('MMM d').format(day),
            child: Container(
              width: 10,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResponseTimeChart extends StatelessWidget {
  final List<WatchLog> logs;

  const _ResponseTimeChart({required this.logs});

  @override
  Widget build(BuildContext context) {
    final recentLogsWithTime = logs.where((l) => l.responseTimeMs != null)
        .toList().reversed.take(50).toList().reversed.toList();

    if (recentLogsWithTime.isEmpty) {
      return const Text('No response time data available yet.');
    }

    final List<FlSpot> spots = [];
    double maxTime = 0;

    for (int i = 0; i < recentLogsWithTime.length; i++) {
      final timeMs = recentLogsWithTime[i].responseTimeMs!.toDouble();
      if (timeMs > maxTime) maxTime = timeMs;
      spots.add(FlSpot(i.toDouble(), timeMs));
    }

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(right: AppSpacing.md),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Theme.of(context).dividerTheme.color ?? Colors.grey[300]!,
                strokeWidth: 0.5,
              ),
            ),
            titlesData: FlTitlesData(
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    if (value == 0) return const Text('');
                    return Text('${value.toInt()}ms', style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
            ),
            borderData: FlBorderData(show: true),
            minX: 0,
            maxX: spots.isNotEmpty ? spots.last.x : 0,
            minY: 0,
            maxY: maxTime * 1.2,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  final List<WatchLog> logs;

  const _LogList({required this.logs});

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return const Text('No logs available.');
    }

    final recentLogs = logs.reversed.take(50).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentLogs.length,
      itemBuilder: (context, index) {
        final log = recentLogs[index];
        return ListTile(
          dense: true,
          leading: Icon(
            log.status ? Icons.check_circle : Icons.error,
            color: log.status ? AppColors.success : AppColors.danger,
          ),
          title: Text(DateFormat('yyyy-MM-dd HH:mm').format(log.timestamp)),
          subtitle: Text(
            log.status
                ? 'Status: ${log.statusCode}${log.responseTimeMs != null ? " • ${log.responseTimeMs}ms" : ""}'
                : 'Error: ${log.errorMessage ?? "Status ${log.statusCode}"}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
