import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/watch.dart';
import 'add_edit_watch_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
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
        if (watch.lastStatus != null && watch.lastStatus != watch.expectedStatus) {
          errors++;
        }
      }
    }

    setState(() {
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
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(
                    'Total Watches',
                    totalWatches.toString(),
                    Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    'Active Watches',
                    activeWatches.toString(),
                    Colors.green,
                  ),
                  const SizedBox(height: 16),
                  _buildSummaryCard(
                    'Watches with Errors',
                    errorWatches.toString(),
                    errorWatches > 0 ? Colors.red : Colors.grey,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _loadData,
                    child: const Text('Refresh Data'),
                  )
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
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
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
