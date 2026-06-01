import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/watch.dart';
import 'add_edit_watch_screen.dart';
import 'watch_detail_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Watch> _watches = [];
  int totalWatches = 0;
  int activeWatches = 0;
  int errorWatches = 0;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    final watches = await DatabaseHelper.instance.readAllWatches();

    int errors = 0;
    int active = 0;
    for (var watch in watches) {
      if (watch.isActive) {
        active++;
        if (watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300)) {
          errors++;
        }
      }
    }

    setState(() {
      _watches = watches;
      totalWatches = watches.length;
      activeWatches = active;
      errorWatches = errors;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSummaryCard('Total', totalWatches.toString(), Colors.blue),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard('Active', activeWatches.toString(), Colors.green),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSummaryCard('Errors', errorWatches.toString(), errorWatches > 0 ? Colors.red : Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Watches Status',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_watches.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No watches configured.')),
                    )
                  else
                    ..._watches.map((watch) {
                      final hasError = watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300);
                      final isNeverChecked = watch.lastStatus == null;

                      Color statusColor = Colors.grey;
                      IconData statusIcon = Icons.help_outline;
                      if (!isNeverChecked) {
                        statusColor = hasError ? Colors.red : Colors.green;
                        statusIcon = hasError ? Icons.error : Icons.check_circle;
                      }

                      return Card(
                        child: ListTile(
                          leading: Icon(statusIcon, color: statusColor, size: 36),
                          title: Text(watch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(watch.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => WatchDetailScreen(watch: watch),
                              ),
                            );
                            _loadData();
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddEditWatchScreen(),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
