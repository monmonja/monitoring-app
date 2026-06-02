import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../database_helper.dart';
import '../models/domain.dart';
import '../models/watch.dart';
import 'add_edit_domain_screen.dart';
import 'add_edit_watch_screen.dart';
import 'watch_detail_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Watch> _watches = [];
  List<Domain> _domains = [];
  int? _selectedDomainId; // null means 'All Domains'

  int totalWatches = 0;
  int activeWatches = 0;
  int errorWatches = 0;
  bool isLoading = true;
  bool _hasCheckedForDomains = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    // Load domains
    final domains = await DatabaseHelper.instance.readAllDomains();

    if (!_hasCheckedForDomains && domains.isEmpty) {
      _hasCheckedForDomains = true;
      // Prompt user to create a domain on first load if none exist
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptCreateDomain();
      });
    } else {
      _hasCheckedForDomains = true;
    }

    // Load watches based on selection
    List<Watch> watches;
    if (_selectedDomainId == null) {
      watches = await DatabaseHelper.instance.readAllWatches();
    } else {
      watches = await DatabaseHelper.instance.readWatchesForDomain(_selectedDomainId!);
    }

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
      _domains = domains;
      _watches = watches;
      totalWatches = watches.length;
      activeWatches = active;
      errorWatches = errors;
      isLoading = false;
    });
  }

  Future<void> _promptCreateDomain() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Welcome!'),
        content: const Text('To get started, you need to create a Domain to group your watches.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AddEditDomainScreen(),
                ),
              ).then((_) => _loadData());
            },
            child: const Text('Create Domain'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareStatus() async {
    if (_watches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No watches to share.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Uptime Status Report');
    buffer.writeln('--------------------');
    buffer.writeln('Total: $totalWatches | Active: $activeWatches | Errors: $errorWatches\n');

    for (var watch in _watches) {
      if (!watch.isActive) continue;

      final hasError = watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300);
      final statusString = watch.lastStatus == null ? 'Pending' : (hasError ? 'DOWN' : 'UP');
      buffer.writeln('- ${watch.name} ($statusString)');
      buffer.writeln('  URL: ${watch.url}');
    }

    await Share.share(buffer.toString(), subject: 'System Uptime Status Report');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _domains.isEmpty
          ? const Text('Dashboard')
          : DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedDomainId,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
                dropdownColor: Theme.of(context).primaryColor,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('All Domains'),
                  ),
                  ..._domains.map((domain) {
                    return DropdownMenuItem<int?>(
                      value: domain.id,
                      child: Text(domain.name),
                    );
                  }),
                ],
                onChanged: (int? newValue) {
                  setState(() {
                    _selectedDomainId = newValue;
                  });
                  _loadData();
                },
              ),
            ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Status',
            onPressed: _shareStatus,
          ),
        ],
      ),
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
                    ..._buildWatchList(),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_domains.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Please create a domain first.')),
            );
            return;
          }
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

  List<Widget> _buildWatchList() {
    if (_selectedDomainId != null) {
      // Single domain view: just list the watches
      return _watches.map((w) => _buildWatchCard(w)).toList();
    } else {
      // All domains view: group watches by domain
      final Map<int, List<Watch>> groupedWatches = {};
      for (var watch in _watches) {
        groupedWatches.putIfAbsent(watch.domainId, () => []).add(watch);
      }

      final List<Widget> widgets = [];
      for (var domain in _domains) {
        final domainWatches = groupedWatches[domain.id];
        if (domainWatches != null && domainWatches.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
              child: Text(
                domain.name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ),
          );
          widgets.addAll(domainWatches.map((w) => _buildWatchCard(w)));
        }
      }
      return widgets;
    }
  }

  Widget _buildWatchCard(Watch watch) {
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
