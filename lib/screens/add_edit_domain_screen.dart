import 'package:flutter/material.dart';

import '../core/theme/app_spacing.dart';
import '../database_helper.dart';
import '../models/domain.dart';

class AddEditDomainScreen extends StatefulWidget {
  final Domain? domain;

  const AddEditDomainScreen({super.key, this.domain});

  @override
  State<AddEditDomainScreen> createState() => _AddEditDomainScreenState();
}

class _AddEditDomainScreenState extends State<AddEditDomainScreen> {
  final _formKey = GlobalKey<FormState>();
  late String name;
  late String url;

  @override
  void initState() {
    super.initState();
    name = widget.domain?.name ?? '';
    url = widget.domain?.url ?? '';
  }

  void _saveDomain() async {
    final isValid = _formKey.currentState!.validate();

    if (isValid) {
      _formKey.currentState!.save();
      final domain = Domain(
        id: widget.domain?.id,
        name: name,
        url: url,
      );

      if (widget.domain == null) {
        await DatabaseHelper.instance.createDomain(domain);
      } else {
        await DatabaseHelper.instance.updateDomain(domain);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.domain == null ? 'Add Domain' : 'Edit Domain'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveDomain,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. My Site',
                ),
                validator: (value) =>
                    value != null && value.isEmpty ? 'Name cannot be empty' : null,
                onSaved: (value) => name = value!,
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                initialValue: url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'e.g. https://example.com',
                ),
                validator: (value) =>
                    value != null && value.isEmpty ? 'URL cannot be empty' : null,
                onSaved: (value) => url = value!,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: AppSpacing.lg),
              ElevatedButton.icon(
                onPressed: _saveDomain,
                icon: const Icon(Icons.save),
                label: const Text('Save Domain'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
