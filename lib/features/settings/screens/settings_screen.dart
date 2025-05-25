import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../auth/providers/auth_state_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthServiceInterface _authService = serviceLocator<AuthServiceInterface>();
  String _appVersion = '';
  String _buildNumber = '';
  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  // Load app version information
  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = 'Unknown';
        _buildNumber = '';
      });
    }
  }

  // Log the user out using Provider pattern
  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      // Use the AuthStateProvider's signOut method instead of direct auth service call
      // This ensures proper cleanup of FCM tokens and other state
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      await authProvider.signOut();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log out: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Delete user account with confirmation
  Future<void> _confirmDeleteAccount() async {
    final bool isIOS = Platform.isIOS;
    bool shouldDelete = false;

    if (isIOS) {
      await showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action cannot be undone. All your data will be permanently deleted. '
            'Are you sure you want to delete your account?'
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
                shouldDelete = true;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    } else {
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action cannot be undone. All your data will be permanently deleted. '
            'Are you sure you want to delete your account?'
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
                shouldDelete = true;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      );
    }

    if (shouldDelete) {
      _deleteAccount();
    }
  }

  // Actual account deletion process
  Future<void> _deleteAccount() async {
    setState(() => _isDeleting = true);
    
    try {
      await _authService.deleteUserAccount();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthStateProvider>(context);
    final user = authProvider.currentUser;
    final bool isIOS = Platform.isIOS;
    
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // User profile photo with error handling
        Center(
          child: user != null ? _buildProfileImageWidget(context, user) : const CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.accentBlue,
            child: Icon(Icons.person, size: 50, color: Colors.white),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // User display name
        Text(
          user?.displayName ?? 'Guest User',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        
        // User email if available
        if (user?.email != null)
          Text(
            user!.email!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16, 
              color: Colors.grey[600],
            ),
          ),
          
        const SizedBox(height: 30),
        const Divider(),
        
        // Logout option
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.orange),
          title: const Text('Logout'),
          onTap: _isLoading ? null : _handleLogout,
          trailing: _isLoading 
            ? SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isIOS ? CupertinoColors.activeBlue : Colors.blue
                  ),
                )
              )
            : Icon(isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right),
        ),
        
        const Divider(),
        
        // Delete account option
        ListTile(
          leading: const Icon(Icons.delete_forever, color: Colors.red),
          title: const Text('Delete Account', 
            style: TextStyle(color: Colors.red),
          ),
          onTap: _isDeleting ? null : _confirmDeleteAccount,
          trailing: _isDeleting 
            ? SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                )
              )
            : Icon(isIOS ? CupertinoIcons.chevron_right : Icons.chevron_right),
        ),
        
        const SizedBox(height: 40),
        
        // App version at bottom
        Center(
          child: Text(
            'Version $_appVersion ($_buildNumber)',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ),
      ],
    );
  }
  
  // Helper method to build profile image with error handling
  Widget _buildProfileImageWidget(BuildContext context, UserModel user) {
    if (user.photoURL == null) {
      return const CircleAvatar(
        radius: 50,
        backgroundColor: AppColors.accentBlue,
        child: Icon(Icons.person, size: 50, color: Colors.white),
      );
    }
    
    return CircleAvatar(
      radius: 50,
      backgroundColor: Colors.grey[300],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(50),
        child: Image.network(
          user.photoURL!,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('Error loading profile image: $error');
            return const Icon(Icons.person, size: 50, color: Colors.white);
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
