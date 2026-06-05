import 'package:flutter/material.dart';
import '../core/user_agent_helper.dart';

class ManageUserAgentsScreen extends StatefulWidget {
  const ManageUserAgentsScreen({super.key});

  @override
  State<ManageUserAgentsScreen> createState() => _ManageUserAgentsScreenState();
}

class _ManageUserAgentsScreenState extends State<ManageUserAgentsScreen> {
  List<UserAgentModel> _agents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    final agents = await UserAgentHelper.getUserAgents();
    setState(() {
      _agents = agents;
      _isLoading = false;
    });
  }

  Future<void> _addAgent() async {
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add User Agent'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name (e.g. My Phone)'),
              ),
              TextField(
                controller: valueController,
                decoration: const InputDecoration(labelText: 'User Agent String'),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final name = nameController.text.trim();
                final value = valueController.text.trim();
                if (name.isNotEmpty && value.isNotEmpty) {
                  Navigator.pop(context, UserAgentModel(name: name, value: value));
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    ).then((newAgent) async {
      if (newAgent != null && newAgent is UserAgentModel) {
        await UserAgentHelper.addAgent(newAgent);
        _loadAgents();
      }
    });
  }

  Future<void> _deleteAgent(int index) async {
    await UserAgentHelper.deleteAgent(index);
    _loadAgents();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage User Agents'),
      ),
      body: ListView.builder(
        itemCount: _agents.length,
        itemBuilder: (context, index) {
          final agent = _agents[index];
          return ListTile(
            title: Text(agent.name),
            subtitle: Text(agent.value, maxLines: 2, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteAgent(index),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAgent,
        child: const Icon(Icons.add),
      ),
    );
  }
}
