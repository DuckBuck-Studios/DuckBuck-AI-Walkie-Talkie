import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import '../providers/crashlytics_consent_provider.dart';
import '../../../core/widgets/error_boundary.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../../../core/navigation/app_routes.dart';
import 'blocked_users_screen.dart';

/// Screen for managing privacy and data collection settings
class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  bool _isDeleting = false;

  // Get the appropriate icon based on platform
  Widget _getPlatformIcon(IconData materialIcon, IconData cupertinoIcon, {Color? color}) {
    final bool isIOS = Platform.isIOS;
    return Icon(
      isIOS ? cupertinoIcon : materialIcon,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ErrorBoundary(
      featureName: 'privacy_settings',
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: const Text('Privacy Settings'),
          backgroundColor: theme.colorScheme.surface,
          elevation: 0,
          leading: IconButton(
            icon: _getPlatformIcon(
              Icons.arrow_back,
              CupertinoIcons.back,
            ),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isDeleting 
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Deleting your account...'),
                  SizedBox(height: 8),
                  Text(
                    'This may take a few moments',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : _PrivacySettingsContent(
              onDeletingStateChange: (isDeleting) {
                setState(() {
                  _isDeleting = isDeleting;
                });
              },
            ),
      ),
    );
  }
}

class _PrivacySettingsContent extends StatelessWidget {
  final Function(bool) onDeletingStateChange;
  
  const _PrivacySettingsContent({
    required this.onDeletingStateChange,
  });

  // Get the appropriate icon based on platform
  Widget _getPlatformIcon(IconData materialIcon, IconData cupertinoIcon, {Color? color}) {
    final bool isIOS = Platform.isIOS;
    return Icon(
      isIOS ? cupertinoIcon : materialIcon,
      color: color,
      size: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final crashlyticsConsentProvider = Provider.of<CrashlyticsConsentProvider>(context);
    final screenWidth = MediaQuery.of(context).size.width;
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Data Collection Section
        ListTile(
          title: Text(
            'Data Collection',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.045,
            ),
          ),
        ),
        !crashlyticsConsentProvider.isInitialized
            ? const ListTile(
                title: Text('Crash Reporting'),
                subtitle: Text('Loading preference...'),
                trailing: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.0),
                ),
              )
            : SwitchListTile(
                title: const Text('Crash Reporting'),
                subtitle: const Text(
                  'Help us improve DuckBuck by automatically sending crash reports. '
                  'No personal information is included in these reports.',
                ),
                value: crashlyticsConsentProvider.isEnabled,
                onChanged: (value) => crashlyticsConsentProvider.setConsent(value),
              ),
        
        const Divider(),
        
        // Your Data Section
        ListTile(
          title: Text(
            'Your Data',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.045,
            ),
          ),
        ),
        ListTile(
          leading: _getPlatformIcon(
            Icons.download_outlined,
            CupertinoIcons.cloud_download,
            color: Colors.blue,
          ),
          title: const Text('Request Data Download'),
          trailing: _getPlatformIcon(
            Icons.arrow_forward_ios,
            CupertinoIcons.chevron_right,
          ),
          onTap: () {
            _showDataDownloadDialog(context);
          },
        ),
        ListTile(
          leading: _getPlatformIcon(
            Icons.delete_forever,
            CupertinoIcons.delete,
            color: Colors.red,
          ),
          title: const Text(
            'Delete All Data',
            style: TextStyle(color: Colors.red),
          ),
          trailing: _getPlatformIcon(
            Icons.arrow_forward_ios,
            CupertinoIcons.chevron_right,
            color: Colors.red,
          ),
          onTap: () {
            _showDeleteDataDialog(context);
          },
        ),
        
        const Divider(),
        
        // Social Privacy Section
        ListTile(
          title: Text(
            'Social Privacy',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: screenWidth * 0.045,
            ),
          ),
        ),
        ListTile(
          leading: _getPlatformIcon(
            Icons.block,
            CupertinoIcons.person_crop_circle_badge_xmark,
            color: Colors.red,
          ),
          title: const Text('Blocked Users'),
          subtitle: const Text('Manage users you\'ve blocked from contacting you'),
          trailing: _getPlatformIcon(
            Icons.arrow_forward_ios,
            CupertinoIcons.chevron_right,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BlockedUsersScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showDataDownloadDialog(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Request Data Download'),
          content: const Text(
            'We will prepare your data for download and send you an email with the download link within 24 hours.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Request'),
              onPressed: () {
                Navigator.pop(context);
                _requestDataDownload(context);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Request Data Download'),
          content: const Text(
            'We will prepare your data for download and send you an email with the download link within 24 hours.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text('Request'),
              onPressed: () {
                Navigator.pop(context);
                _requestDataDownload(context);
              },
            ),
          ],
        ),
      );
    }
  }

  void _showDeleteDataDialog(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete All Data'),
          content: const Text(
            'This will permanently delete all your data from our servers. This action cannot be undone.',
          ),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () {
                Navigator.pop(context);
                _deleteAllData(context);
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete All Data'),
          content: const Text(
            'This will permanently delete all your data from our servers. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context),
            ),
            TextButton(
              child: const Text(
                'Delete',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.pop(context);
                _deleteAllData(context);
              },
            ),
          ],
        ),
      );
    }
  }

  void _requestDataDownload(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Data download request submitted. You will receive an email within 24 hours.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _deleteAllData(BuildContext context) async {
    try {
      // Set deleting state to true before starting the operation
      onDeletingStateChange(true);
      
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      await authProvider.deleteUserAccount();
            
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context, 
          AppRoutes.welcome,
          (route) => false,
        );
      }
    } catch (e) {
      // Reset deleting state in case of error
      onDeletingStateChange(false);
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
