import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: const Text('Monitoring Active', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Pause or resume monitoring for this watch'),
                    value: _currentWatch.isActive,
                    onChanged: _toggleIsActive,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const Divider(),
                  _buildDetailRow('URL', _currentWatch.url),
                  _buildDetailRow('Interval', '${_currentWatch.intervalMinutes} minutes'),
                  _buildDetailRow('Expected Status', '200-299'),
                  _buildDetailRow('Keyword (Optional)', _currentWatch.keyword ?? 'None'),
                  _buildDetailRow(
                      'Last Status',
                      _currentWatch.lastStatus == null
                          ? 'Never checked'
                          : (_currentWatch.lastStatus == -1 ? 'Keyword Failed (-1)' : _currentWatch.lastStatus.toString()),
                      color: _currentWatch.lastStatus == null
                          ? Colors.grey
                          : ((_currentWatch.lastStatus! >= 200 && _currentWatch.lastStatus! < 300) ? Colors.green : Colors.red)),
                  _buildDetailRow(
                      'Last Checked',
                      _currentWatch.lastCheckTime != null
                          ? DateFormat('yyyy-MM-dd HH:mm').format(_currentWatch.lastCheckTime!)
                          : 'Never'),
                  const SizedBox(height: 24),
                  const Text(
                    '31-Day History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildHistoryChart(),
                  const SizedBox(height: 24),
                  const Text(
                    'Response Time (Last 50)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  _buildResponseTimeChart(),
                  const SizedBox(height: 24),
                  const Text(
                    'Recent Logs',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildLogList(),
                ],
              ),
            ),
    );
  }

  Widget _buildResponseTimeChart() {
    final recentLogsWithTime = _logs.where((l) => l.responseTimeMs != null).toList().reversed.take(50).toList().reversed.toList();
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
        padding: const EdgeInsets.only(right: 16.0),
        child: LineChart(
          LineChartData(
            gridData: FlGridData(show: true),
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
            maxY: maxTime * 1.2, // Give it some headroom
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: Colors.blue,
                barWidth: 2,
                dotData: FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: Colors.blue.withValues(alpha: 0.1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryChart() {
    // Group logs by day
    final Map<DateTime, bool> dailyStatus = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (int i = 0; i < 31; i++) {
      final day = today.subtract(Duration(days: 30 - i));
      dailyStatus[day] = true; // Assume success initially, or absent if no logs
    }

    // A day is considered failure if there's any failure log in that day
    final Map<DateTime, bool> actualDailyStatus = {};
    for (final log in _logs) {
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

          Color color = Colors.grey[300]!; // No data
          if (hasLogs) {
            color = status == true ? Colors.green : Colors.red;
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

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return const Text('No logs available.');
    }

    // Show only the latest 50 logs reversed
    final recentLogs = _logs.reversed.take(50).toList();

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
            color: log.status ? Colors.green : Colors.red,
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
