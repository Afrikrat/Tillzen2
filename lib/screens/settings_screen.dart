import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import 'package:go_router/go_router.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCard(
            context,
            title: 'Store Profile',
            icon: Icons.store,
            children: [
              ListTile(
                title: Text(userProvider.user?.email ?? 'Unknown User'),
                subtitle: Text('Shop ID: ${userProvider.shopId ?? 'N/A'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: 'Manage Staff',
            icon: Icons.admin_panel_settings,
            children: [
              ListTile(
                title: Text('Current Role: ${userProvider.activeRole.name.toUpperCase()}'),
                subtitle: const Text('Tap to switch user'),
                trailing: const Icon(Icons.swap_horiz),
                onTap: () => _showSwitchRoleDialog(context, userProvider),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: 'Cloud Integration',
            icon: Icons.cloud_sync,
            children: [
              ListTile(
                title: const Text('Force Sync to Cloud'),
                subtitle: const Text('Push unsynced receipts to Firebase'),
                trailing: const Icon(Icons.sync),
                onTap: () async {
                  if (userProvider.syncService != null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Starting forced sync...')));
                    await userProvider.syncService!.syncUnsyncedSales();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync completed!')));
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sync service unavailable.')));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCard(
            context,
            title: 'Taxes & Compliance',
            icon: Icons.account_balance,
            children: [
              SwitchListTile(
                title: const Text('Apply Ghana 2026 VAT Act 1151'),
                subtitle: const Text('NHIL 2.5%, GETFund 2.5%, VAT 15%'),
                value: true,
                onChanged: (val) {},
              ),
              SwitchListTile(
                title: const Text('COVID-19 Health Levy (1%)'),
                subtitle: const Text('Abolished effective 2026'),
                value: false,
                onChanged: null,
              ),
            ],
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              userProvider.signOut();
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, {required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }

  void _showSwitchRoleDialog(BuildContext context, UserProvider provider) {
    if (provider.activeRole == UserRole.admin) {
      provider.switchRole(UserRole.cashier);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switched to Cashier mode.')));
    } else {
      final pinCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Enter Admin PIN'),
          content: TextField(
            controller: pinCtrl,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN Code', border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
              onPressed: () {
                final success = provider.switchRole(UserRole.admin, pin: pinCtrl.text);
                Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Switched to Admin mode. ✅')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN! ❌', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                }
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      );
    }
  }
}
