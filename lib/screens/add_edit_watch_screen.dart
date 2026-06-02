import 'package:flutter/material.dart';
import '../database_helper.dart';
import '../models/watch.dart';
import '../models/domain.dart';

class AddEditWatchScreen extends StatefulWidget {
  final Watch? watch;

  const AddEditWatchScreen({super.key, this.watch});

  @override
  State<AddEditWatchScreen> createState() => _AddEditWatchScreenState();
}

class _AddEditWatchScreenState extends State<AddEditWatchScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late String _url;
  late int _intervalMinutes;
  String? _keyword;
  int? _selectedDomainId;
  List<Domain> _domains = [];
  bool _isLoadingDomains = true;

  bool _checkKeywordAbsence = false;
  bool _alertOnSslExpiry = false;
  String? _latencyThreshold;

  @override
  void initState() {
    super.initState();
    _name = widget.watch?.name ?? '';
    _url = widget.watch?.url ?? 'https://';
    _intervalMinutes = widget.watch?.intervalMinutes ?? 15;
    _keyword = widget.watch?.keyword;
    _selectedDomainId = widget.watch?.domainId;
    _checkKeywordAbsence = widget.watch?.checkKeywordAbsence ?? false;
    _alertOnSslExpiry = widget.watch?.alertOnSslExpiry ?? false;
    _latencyThreshold = widget.watch?.latencyThreshold?.toString();
    _loadDomains();
  }

  Future<void> _loadDomains() async {
    final domains = await DatabaseHelper.instance.readAllDomains();
    setState(() {
      _domains = domains;
      _isLoadingDomains = false;
      if (_selectedDomainId == null && _domains.isNotEmpty) {
        _selectedDomainId = _domains.first.id;
      }
    });
  }

  Future<void> _saveForm() async {
    final isValid = _formKey.currentState!.validate();
    if (!isValid) return;

    _formKey.currentState!.save();

    if (_selectedDomainId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a domain')),
      );
      return;
    }

    final watch = Watch(
      id: widget.watch?.id,
      domainId: _selectedDomainId!,
      name: _name,
      url: _url,
      intervalMinutes: _intervalMinutes,
      expectedStatus: 200, // Legacy field, kept for DB compatibility, but always 200
      keyword: _keyword?.isEmpty == true ? null : _keyword,
      lastStatus: widget.watch?.lastStatus,
      lastCheckTime: widget.watch?.lastCheckTime,
      isActive: widget.watch?.isActive ?? true,
      checkKeywordAbsence: _checkKeywordAbsence,
      alertOnSslExpiry: _alertOnSslExpiry,
      latencyThreshold: _latencyThreshold != null && _latencyThreshold!.isNotEmpty ? int.tryParse(_latencyThreshold!) : null,
      consecutiveFails: widget.watch?.consecutiveFails ?? 0,
    );

    if (widget.watch == null) {
      await DatabaseHelper.instance.create(watch);
    } else {
      await DatabaseHelper.instance.update(watch);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.watch == null ? 'Add Watch' : 'Edit Watch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveForm,
          ),
        ],
      ),
      body: _isLoadingDomains
          ? const Center(child: CircularProgressIndicator())
          : _domains.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('No domains available.'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Go back and create a domain'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Domain'),
                          initialValue: _selectedDomainId,
                          items: _domains.map((domain) {
                            return DropdownMenuItem<int>(
                              value: domain.id,
                              child: Text(domain.name),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedDomainId = value;
                            });
                          },
                          validator: (value) => value == null ? 'Please select a domain' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                    value != null && value.isEmpty ? 'Please enter a name' : null,
                onSaved: (value) => _name = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _url,
                decoration: const InputDecoration(labelText: 'URL'),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a URL';
                  }
                  if (!Uri.parse(value).isAbsolute) {
                    return 'Please enter a valid absolute URL (e.g. https://...)';
                  }
                  return null;
                },
                onSaved: (value) => _url = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _intervalMinutes.toString(),
                decoration: const InputDecoration(labelText: 'Interval (minutes)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || int.tryParse(value) == null || int.parse(value) <= 0) {
                    return 'Please enter a valid positive integer';
                  }
                  return null;
                },
                onSaved: (value) => _intervalMinutes = int.parse(value!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _keyword,
                decoration: const InputDecoration(labelText: 'Keyword to search in Body (Optional)'),
                onSaved: (value) => _keyword = value,
              ),
              SwitchListTile(
                title: const Text('Alert if Keyword is FOUND'),
                subtitle: const Text('By default, we alert if the keyword is MISSING.'),
                value: _checkKeywordAbsence,
                onChanged: (val) {
                  setState(() => _checkKeywordAbsence = val);
                },
              ),
              const Divider(),
              const Text('Advanced Settings', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _latencyThreshold,
                decoration: const InputDecoration(labelText: 'Latency Alert Threshold (ms) (Optional)'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty && int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
                onSaved: (value) => _latencyThreshold = value,
              ),
              SwitchListTile(
                title: const Text('Alert on SSL Expiry'),
                subtitle: const Text('Alert if SSL cert expires in < 14 days'),
                value: _alertOnSslExpiry,
                onChanged: (val) {
                  setState(() => _alertOnSslExpiry = val);
                },
              ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: _saveForm,
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
