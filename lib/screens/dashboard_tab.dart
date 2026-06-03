import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

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
  int? _selectedDomainId; // null means 'All Domains'

  int totalWatches = 0;
  int activeWatches = 0;
  int errorWatches = 0;
  bool isLoading = true;
  bool _isManualChecking = false;
  bool _hasCheckedForDomains = false;

  String _searchQuery = '';
  String _currentFilter = 'All'; // 'All', 'Down Only', 'Warnings'

  final TextEditingController _searchController = TextEditingController();
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
    super.dispose();
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
      _allWatches = watches;
      totalWatches = watches.length;
      activeWatches = active;
      errorWatches = errors;
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
      if (!_isManualChecking) break; // User stopped the check

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
      }

      // Update local state temporarily to show progress safely
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
      await _loadData(); // fully reload from db to ensure everything is synced
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

  Future<void> _shareStatus() async {
    if (_allWatches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No watches to share.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Uptime Status Report');
    buffer.writeln('--------------------');
    buffer.writeln('Total: $totalWatches | Active: $activeWatches | Errors: $errorWatches\n');

    for (var watch in _allWatches) {
      if (!watch.isActive) continue;

      final hasError = watch.lastStatus != null && (watch.lastStatus! < 200 || watch.lastStatus! >= 300);
      final statusString = watch.lastStatus == null ? 'Pending' : (hasError ? 'DOWN' : 'UP');
      buffer.writeln('- ${watch.name} ($statusString)');
      buffer.writeln('  URL: ${watch.url}');
    }

    // ignore: deprecated_member_use
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
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _manualRefresh,
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
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search watches...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                    _applyFilters();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['All', 'Down Only', 'Warnings'].map((filter) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Text(filter),
                                selected: _currentFilter == filter,
                                onSelected: (selected) {
                                  setState(() {
                                    _currentFilter = filter;
                                  });
                                  _applyFilters();
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Watches Status',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if (_isManualChecking)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _isManualChecking = false;
                                });
                              },
                              icon: const Icon(Icons.stop, color: Colors.red),
                              label: const Text('Stop', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_filteredWatches.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16.0),
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
                        color: Colors.black87,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              ),
                              SizedBox(width: 16),
                              Text('Checking watches...', style: TextStyle(color: Colors.white)),
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
      // Single domain view: just list the watches
      return _filteredWatches.map((w) => _buildWatchCard(w)).toList();
    } else {
      // All domains view: group watches by domain
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

      if (hasError && watch.consecutiveFails > 0 && watch.consecutiveFails < 3) {
        statusColor = Colors.orange;
        statusIcon = Icons.warning;
      }
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
