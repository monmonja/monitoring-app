import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../database_helper.dart';
import '../models/domain.dart';
import 'add_edit_domain_screen.dart';

class DomainsTab extends StatefulWidget {
  const DomainsTab({super.key});

  @override
  State<DomainsTab> createState() => _DomainsTabState();
}

class _DomainsTabState extends State<DomainsTab> {
  late Future<List<Domain>> _domainsFuture;

  @override
  void initState() {
    super.initState();
    _refreshDomains();
  }

  void _refreshDomains() {
    setState(() {
      _domainsFuture = DatabaseHelper.instance.readAllDomains();
    });
  }

  Future<void> _navigateToAddEditDomain([Domain? domain]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddEditDomainScreen(domain: domain),
      ),
    );
    _refreshDomains();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Domains')),
      body: FutureBuilder<List<Domain>>(
        future: _domainsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No domains found. Add one!'));
          }

          final domains = snapshot.data!;
          return ListView.builder(
            itemCount: domains.length,
            itemBuilder: (context, index) {
              final domain = domains[index];

              return Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xxs,
                ),
                child: ListTile(
                  title: Text(domain.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(domain.url),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    child: Icon(Icons.language, color: AppColors.primary),
                  ),
                  trailing: Icon(Icons.chevron_right, color: AppColors.textSecondaryLight),
                  onTap: () => _navigateToAddEditDomain(domain),
                  onLongPress: () async {
                     final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Domain'),
                          content: const Text('Are you sure you want to delete this domain and all its watches?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                          ],
                        ),
                      );

                      if (confirm == true && domain.id != null) {
                        await DatabaseHelper.instance.deleteDomain(domain.id!);
                        _refreshDomains();
                      }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToAddEditDomain(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
