import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/crashlytics_consent_provider.dart';
import '../../../core/widgets/error_boundary.dart';

/// Screen for managing privacy and data collection settings
class PrivacySettingsScreen extends StatelessWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ErrorBoundary(
      featureName: 'privacy_settings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Privacy Settings'),
        ),
        body: const _PrivacySettingsContent(),
      ),
    );
  }
}

class _PrivacySettingsContent extends StatelessWidget {
  const _PrivacySettingsContent();

  @override
  Widget build(BuildContext context) {
    final crashlyticsConsentProvider = Provider.of<CrashlyticsConsentProvider>(context);
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const ListTile(
          title: Text(
            'Data Collection',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Crash Reporting'),
          subtitle: const Text(
            'Help us improve DuckBuck by automatically sending crash reports. '
            'No personal information is included in these reports.',
          ),
          value: crashlyticsConsentProvider.isEnabled,
          onChanged: (value) => crashlyticsConsentProvider.setConsent(value),
        ),
        const Divider(),
        const ListTile(
          title: Text(
            'Data Usage',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ListTile(
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // Navigate to privacy policy
          },
        ),
        ListTile(
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // Navigate to terms of service
          },
        ),
        const Divider(),
        const ListTile(
          title: Text(
            'Your Data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        ListTile(
          title: const Text('Request Data Download'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          onTap: () {
            // Show data download request flow
          },
        ),
        ListTile(
          title: const Text(
            'Delete All Data',
            style: TextStyle(color: Colors.red),
          ),
          trailing: const Icon(Icons.delete_forever, color: Colors.red),
          onTap: () {
            // Show deletion confirmation
          },
        ),
      ],
    );
  }
}
