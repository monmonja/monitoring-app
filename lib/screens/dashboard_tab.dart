import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../core/ad_banner.dart';
import '../core/notification_helper.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_spacing.dart';
import '../database_helper.dart';
import '../models/domain.dart';
import '../models/watch.dart';
import '../models/watch_log.dart';
import 'add_edit_domain_screen.dart';
import 'add_edit_watch_screen.dart';
import 'watch_detail_screen.dart';

class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  List<Watch> _allWatches = [];
  List<Watch> _filteredWatches = [];
  List<Domain> _domains = [];
  int? _selectedDomainId;

  int totalWatches = 0;
  int activeWatches = 0;
  int errorWatches = 0;
  int warningWatches = 0;
  bool isLoading = true;
  bool _isManualChecking = false;
  bool _hasCheckedForDomains = false;

  String _searchQuery = '';
  String _currentFilter = 'All';
  bool _isSearching = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _stopSearching() {
    setState(() {
      _isSearching = false;
    });
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
    });
    _applyFilters();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);

    final domains = await DatabaseHelper.instance.readAllDomains();

    if (!_hasCheckedForDomains && domains.isEmpty) {
      _hasCheckedForDomains = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _promptCreateDomain();
      });
    } else {
      _hasCheckedForDomains = true;
    }

    List<Watch> watches;
    if (_selectedDomainId == null) {
      watches = await DatabaseHelper.instance.readAllWatches();
    } else {
      watches = await DatabaseHelper.instance.readWatchesForDomain(_selectedDomainId!);
    }

    int errors = 0;
    int active = 0;
    int warnings = 0;
    for (var watch in watches) {
      if (watch.isActive) {
        active++;
        if (watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300)) {
          if (watch.consecutiveFails > 0 && watch.consecutiveFails < 3) {
            warnings++;
          } else {
            errors++;
          }
        }
      }
    }

    setState(() {
      _domains = domains;
      _allWatches = watches;
      totalWatches = watches.length;
      activeWatches = active;
      errorWatches = errors;
      warningWatches = warnings;
      isLoading = false;
    });

    _applyFilters();
  }

  void _applyFilters() {
    List<Watch> temp = _allWatches;

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      temp = temp.where((watch) {
        final domain = _domains.firstWhere((d) => d.id == watch.domainId, orElse: () => const Domain(id: -1, name: '', url: ''));
        return watch.name.toLowerCase().contains(query) ||
               watch.url.toLowerCase().contains(query) ||
               domain.name.toLowerCase().contains(query);
      }).toList();
    }

    if (_currentFilter == 'Down Only') {
      temp = temp.where((watch) {
        return watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300);
      }).toList();
    } else if (_currentFilter == 'Warnings') {
      temp = temp.where((watch) {
        bool isWarning = false;
        if (watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300)) {
          if (watch.consecutiveFails > 0 && watch.consecutiveFails < 3) {
            isWarning = true;
          }
        }
        return isWarning;
      }).toList();
    }

    setState(() {
      _filteredWatches = temp;
    });
  }

  Future<void> _manualRefresh() async {
    if (_isManualChecking) return;
    setState(() => _isManualChecking = true);

    final dbHelper = DatabaseHelper.instance;
    final watchesToCheck = List<Watch>.from(_filteredWatches);

    for (var i = 0; i < watchesToCheck.length; i++) {
      if (!_isManualChecking) break;

      final watch = watchesToCheck[i];
      if (!watch.isActive) continue;

      bool hasError = false;
      String errorMessage = '';
      int? currentStatus;
      int? responseTimeMs;
      final now = DateTime.now();

      try {
        final stopwatch = Stopwatch()..start();

        Map<String, dynamic>? headersMap;
        if (watch.httpHeaders != null) {
          try {
            headersMap = jsonDecode(watch.httpHeaders!);
          } catch (e) {
            // ignore
          }
        }

        final options = Options(
          method: watch.httpMethod,
          headers: headersMap,
        );

        final response = await _dio.request(
          watch.url,
          data: watch.httpBody,
          options: options,
        );

        stopwatch.stop();
        responseTimeMs = stopwatch.elapsedMilliseconds;
        currentStatus = response.statusCode;

        if (response.statusCode == null || response.statusCode! < 200 || response.statusCode! > 299) {
          hasError = true;
          errorMessage = 'Status code is ${response.statusCode}, expected 200-299.';
        } else if (watch.keyword != null && watch.keyword!.isNotEmpty) {
          bool containsKeyword = response.data.toString().contains(watch.keyword!);
          if (watch.checkKeywordAbsence) {
            if (containsKeyword) {
              hasError = true;
              errorMessage = 'Keyword "${watch.keyword!}" was found (configured to alert on presence).';
            }
          } else {
            if (!containsKeyword) {
              hasError = true;
              errorMessage = 'Keyword "${watch.keyword!}" not found.';
            }
          }
        }

        if (!hasError && watch.latencyThreshold != null && responseTimeMs > watch.latencyThreshold!) {
          hasError = true;
          errorMessage = 'Response time ${responseTimeMs}ms exceeded threshold of ${watch.latencyThreshold}ms.';
        }

        if (!hasError && watch.alertOnSslExpiry && watch.url.startsWith('https')) {
          try {
            final uri = Uri.parse(watch.url);
            final socket = await SecureSocket.connect(uri.host, uri.port.toInt() == 0 ? 443 : uri.port,
                timeout: const Duration(seconds: 5));
            final cert = socket.peerCertificate;
            if (cert != null) {
              final expiry = cert.endValidity;
              final daysUntilExpiry = expiry.difference(now).inDays;
              if (daysUntilExpiry <= 14) {
                hasError = true;
                errorMessage = 'SSL Certificate expires in $daysUntilExpiry days.';
              }
            }
            socket.destroy();
          } catch (e) {
            hasError = true;
            errorMessage = 'Failed to check SSL certificate: $e';
          }
        }
      } on DioException catch (e) {
        hasError = true;
        errorMessage = 'Network error: ${e.message}';
        currentStatus = e.response?.statusCode;
      } catch (e) {
        hasError = true;
        errorMessage = 'Failed to connect: $e';
      }

      int updatedFails = hasError ? watch.consecutiveFails + 1 : 0;
      int statusToSave = currentStatus ?? 0;
      if (hasError && statusToSave >= 200 && statusToSave <= 299) {
        statusToSave = -1;
      }

      final updatedWatch = watch.copyWith(
        lastCheckTime: now,
        lastStatus: statusToSave,
        consecutiveFails: updatedFails,
      );

      await dbHelper.update(updatedWatch);

      if (watch.id != null) {
        await dbHelper.createWatchLog(WatchLog(
          watchId: watch.id!,
          timestamp: now,
          status: !hasError,
          statusCode: currentStatus,
          errorMessage: errorMessage.isNotEmpty ? errorMessage : null,
          responseTimeMs: responseTimeMs,
        ));
        await dbHelper.calculateAndSaveUptime(watch.id!);
      }

      if (hasError && updatedFails >= 3) {
        await NotificationHelper.showWatchAlert(
          watch: updatedWatch,
          errorMessage: errorMessage.isNotEmpty ? errorMessage : 'Check failed.',
          statusCode: currentStatus,
        );
      }

      if (mounted) {
        setState(() {
          int index = _filteredWatches.indexWhere((w) => w.id == watch.id);
          if (index != -1) {
            _filteredWatches[index] = updatedWatch;
          }
        });
      }
    }

    if (mounted) {
      setState(() => _isManualChecking = false);
      await _loadData();
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
          ? TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search watches...',
                border: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _applyFilters();
              },
            )
          : _domains.isEmpty
              ? const Text('Dashboard')
              : DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _selectedDomainId,
                    icon: const Icon(Icons.arrow_drop_down),
                    dropdownColor: theme.brightness == Brightness.dark
                        ? AppColors.cardDark
                        : AppColors.cardLight,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
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
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _stopSearching,
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              tooltip: 'Search',
              onPressed: () {
                setState(() {
                  _isSearching = true;
                });
                _searchFocusNode.requestFocus();
              },
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _manualRefresh,
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      Center(
                        child: const AdBanner(adUnitId: 'ca-app-pub-3940256099942544/6300978111'),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _SummaryRow(
                        total: totalWatches.toString(),
                        active: activeWatches.toString(),
                        warnings: warningWatches.toString(),
                        errors: errorWatches.toString(),
                        hasErrors: errorWatches > 0,
                        hasWarnings: warningWatches > 0,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Watches Status',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isManualChecking)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isManualChecking = false;
                                });
                              },
                              icon: const Icon(Icons.stop, color: AppColors.danger),
                              label: const Text('Stop', style: TextStyle(color: AppColors.danger)),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      _FilterChipsRow(
                        currentFilter: _currentFilter,
                        onChanged: (filter) {
                          setState(() {
                            _currentFilter = filter;
                          });
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      if (_filteredWatches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(AppSpacing.md),
                          child: Center(child: Text('No watches found matching criteria.')),
                        )
                      else
                        ..._buildWatchList(),
                    ],
                  ),
                ),
                if (_isManualChecking)
                  Positioned(
                    bottom: 80,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.cardDark
                            : AppColors.cardLight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              SizedBox(width: AppSpacing.md),
                              Text('Checking watches...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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
      return _filteredWatches.map((w) => _WatchCard(w: w)).toList();
    } else {
      final Map<int, List<Watch>> groupedWatches = {};
      for (var watch in _filteredWatches) {
        groupedWatches.putIfAbsent(watch.domainId, () => []).add(watch);
      }

      final List<Widget> widgets = [];
      for (var domain in _domains) {
        final domainWatches = groupedWatches[domain.id];
        if (domainWatches != null && domainWatches.isNotEmpty) {
          widgets.add(
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs, left: 4),
              child: Text(
                domain.name,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ),
          );
          widgets.addAll(domainWatches.map((w) => _WatchCard(w: w)));
        }
      }
      return widgets;
    }
  }
}

class _WatchCard extends StatelessWidget {
  final Watch w;

  const _WatchCard({required this.w});

  @override
  Widget build(BuildContext context) {
    final hasError = w.lastStatus != null && (w.lastStatus! < 200 || w.lastStatus! >= 300);
    final isNeverChecked = w.lastStatus == null;

    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.help_outline;
    if (!isNeverChecked) {
      statusColor = hasError ? AppColors.danger : AppColors.success;
      statusIcon = hasError ? Icons.error : Icons.check_circle;

      if (hasError && w.consecutiveFails > 0 && w.consecutiveFails < 3) {
        statusColor = AppColors.warning;
        statusIcon = Icons.warning;
      }
    }

    String uptimeText = '';
    if (w.uptime7Days != null || w.uptime30Days != null) {
      final u7 = w.uptime7Days != null ? '${w.uptime7Days!.toStringAsFixed(2)}%' : 'N/A';
      final u30 = w.uptime30Days != null ? '${w.uptime30Days!.toStringAsFixed(2)}%' : 'N/A';
      uptimeText = 'Uptime: $u7 (7d) | $u30 (30d)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor, size: 36),
        title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(w.url, maxLines: 1, overflow: TextOverflow.ellipsis),
            if (uptimeText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: Text(
                  uptimeText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => WatchDetailScreen(watch: w),
            ),
          );
          // Refresh handled by caller
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String total;
  final String active;
  final String warnings;
  final String errors;
  final bool hasErrors;
  final bool hasWarnings;

  const _SummaryRow({
    required this.total,
    required this.active,
    required this.warnings,
    required this.errors,
    required this.hasErrors,
    required this.hasWarnings,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SummaryCard(title: 'Total', value: total, color: AppColors.primary)),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(child: _SummaryCard(title: 'Active', value: active, color: AppColors.success)),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: _SummaryCard(
            title: 'Warnings',
            value: warnings,
            color: hasWarnings ? AppColors.warning : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Expanded(
          child: _SummaryCard(
            title: 'Errors',
            value: errors,
            color: hasErrors ? AppColors.danger : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.xxs),
        child: Column(
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
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

class _FilterChipsRow extends StatelessWidget {
  final String currentFilter;
  final ValueChanged<String> onChanged;

  const _FilterChipsRow({
    required this.currentFilter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final options = const ['All', 'Down Only', 'Warnings'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((label) {
          final isSelected = label == currentFilter;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(label),
              selected: isSelected,
              onSelected: (_) => onChanged(label),
            ),
          );
        }).toList(),
      ),
    );
  }
}
