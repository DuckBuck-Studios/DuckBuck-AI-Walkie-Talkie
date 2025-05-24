import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Changed to return ListView directly for embedding
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const CircleAvatar(
          radius: 40,
          child: Icon(Icons.person, size: 40),
        ),
        const SizedBox(height: 20),
        const Text(
          'User Name (Demo)', // Simplified for demo
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.account_circle), // Changed Icon
          title: const Text('Profile (Demo)'), // Simplified
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Demo action
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile (Demo) tapped')),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.color_lens), // Changed Icon
          title: const Text('Appearance (Demo)'), // Simplified
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Demo action
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Appearance (Demo) tapped')),
            );
          },
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline), // Changed Icon
          title: const Text('About App (Demo)'), // Simplified
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // Demo action
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('About App (Demo) tapped')),
            );
          },
        ),
        const Divider(),
        // Removed Logout ListTile as per request to remove signout from home, keeping settings simpler
      ],
    );
  }
}
