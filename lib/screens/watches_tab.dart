import 'package:flutter/material.dart';

import '../database_helper.dart';
import '../models/watch.dart';
import 'add_edit_watch_screen.dart';

class WatchesTab extends StatefulWidget {
  const WatchesTab({super.key});

  @override
  State<WatchesTab> createState() => _WatchesTabState();
}

class _WatchesTabState extends State<WatchesTab> {
  late Future<List<Watch>> _watchesFuture;

  @override
  void initState() {
    super.initState();
    _refreshWatches();
  }

  void _refreshWatches() {
    setState(() {
      _watchesFuture = DatabaseHelper.instance.readAllWatches();
    });
  }

  Future<void> _navigateToAddEditWatch([Watch? watch]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditWatchScreen(watch: watch),
      ),
    );
    _refreshWatches();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Watches')),
      body: FutureBuilder<List<Watch>>(
        future: _watchesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No watches found. Add one!'));
          }

          final watches = snapshot.data!;
          return ListView.builder(
            itemCount: watches.length,
            itemBuilder: (context, index) {
              final watch = watches[index];
              final hasError = watch.lastStatus != null &&
                  (watch.lastStatus! < 200 || watch.lastStatus! >= 300);

              return ListTile(
                title: Text(watch.name),
                subtitle: Text(watch.url),
                leading: CircleAvatar(
                  backgroundColor: hasError ? Colors.red : Colors.green,
                  child: Icon(
                    hasError ? Icons.error : Icons.check,
                    color: Colors.white,
                  ),
                ),
                trailing: Switch(
                  value: watch.isActive,
                  onChanged: (value) async {
                    await DatabaseHelper.instance.update(watch.copyWith(isActive: value));
                    _refreshWatches();
                  },
                ),
                onTap: () => _navigateToAddEditWatch(watch),
                onLongPress: () async {
                   final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Watch'),
                        content: const Text('Are you sure you want to delete this watch?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                        ],
                      ),
                    );

                    if (confirm == true && watch.id != null) {
                      await DatabaseHelper.instance.delete(watch.id!);
                      _refreshWatches();
                    }
                },
              );
            },
          );
        },
      ),
    );
  }
}
