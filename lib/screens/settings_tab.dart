import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';


import '../core/theme/app_colors.dart';
import '../core/theme/theme_manager.dart';
import '../database_helper.dart';

class SettingsTab extends StatefulWidget {
  final ThemeManager themeManager;

  const SettingsTab({super.key, required this.themeManager});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  double _batteryMultiplier = 1.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _batteryMultiplier = prefs.getDouble('battery_multiplier') ?? 1.0;
      _isLoading = false;
    });
  }

  Future<void> _saveBatteryMultiplier(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('battery_multiplier', value);
    setState(() {
      _batteryMultiplier = value;
    });
  }

  Future<void> _exportData() async {
    try {
      final jsonString = await DatabaseHelper.instance.exportData();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Please select an output file:',
        fileName: 'watches_export.json',
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsString(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Export successful to $outputFile!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  Future<void> _importData() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result != null) {
        File file = File(result.files.single.path!);
        final jsonString = await file.readAsString();

        await DatabaseHelper.instance.importData(jsonString);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Import successful!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isDark = widget.themeManager.isDarkMode;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Data Management', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file),
            title: const Text('Export Data'),
            subtitle: const Text('Save your watches configuration to a file'),
            onTap: _exportData,
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Import Data'),
            subtitle: const Text('Load watches configuration from a file (overwrites existing)'),
            onTap: _importData,
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Power & Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.battery_saver),
            title: const Text('Battery Saver Multiplier'),
            subtitle: const Text('Multiply check intervals when battery is <20% or in battery saver mode.'),
            trailing: DropdownButton<double>(
              value: _batteryMultiplier,
              items: const [
                DropdownMenuItem(value: 0.5, child: Text('0.5x')),
                DropdownMenuItem(value: 1.0, child: Text('1x (Default)')),
                DropdownMenuItem(value: 2.0, child: Text('2x')),
                DropdownMenuItem(value: 3.0, child: Text('3x')),
                DropdownMenuItem(value: 4.0, child: Text('4x')),
                DropdownMenuItem(value: 5.0, child: Text('5x')),
              ],
              onChanged: (value) {
                if (value != null) {
                  _saveBatteryMultiplier(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
