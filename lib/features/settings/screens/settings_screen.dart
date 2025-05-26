import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../auth/providers/auth_state_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _appVersion = '';
  String _buildNumber = '';
  bool _isLoading = false;
  bool _isDeleting = false;
  UserModel? _cachedUser;
  bool _isLoadingCachedData = true;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadCachedUserData();
  }

  // Load app version information
  Future<void> _loadAppInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          _buildNumber = packageInfo.buildNumber;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _appVersion = 'Unknown';
          _buildNumber = '';
        });
      }
    }
  }

  // Load cached user data for better performance
  Future<void> _loadCachedUserData() async {
    try {
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      final cachedUser = await authProvider.getCurrentUserWithCache();
      if (mounted) {
        setState(() {
          _cachedUser = cachedUser;
          _isLoadingCachedData = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingCachedData = false;
        });
      }
    }
  }

  // Get the appropriate icon based on platform
  Widget _getPlatformIcon(IconData materialIcon, IconData cupertinoIcon, {Color? color}) {
    final bool isIOS = Platform.isIOS;
    return Icon(
      isIOS ? cupertinoIcon : materialIcon,
      color: color,
    );
  }

  // Log the user out using Provider pattern
  Future<void> _handleLogout() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      await authProvider.signOut();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
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
      final authProvider = Provider.of<AuthStateProvider>(context, listen: false);
      await authProvider.deleteUserAccount();
      
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.welcome);
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
    final user = _isDeleting ? _cachedUser : (authProvider.currentUser ?? _cachedUser);
    final bool isIOS = Platform.isIOS;
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.02,
          ),
          children: [
            // Add space from top
            SizedBox(height: screenHeight * 0.03),
            
            // User profile section with better spacing
            Center(
              child: Column(
                children: [
                  // Profile image
                  _isLoadingCachedData
                      ? const CircularProgressIndicator()
                      : (user != null 
                          ? _buildProfileImageWidget(context, user) 
                          : CircleAvatar(
                              radius: screenWidth * 0.12,
                              backgroundColor: AppColors.accentBlue,
                              child: Icon(
                                isIOS ? CupertinoIcons.person : Icons.person, 
                                size: screenWidth * 0.12, 
                                color: Colors.white,
                              ),
                            )),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  // User display name
                  Text(
                    user?.displayName ?? 'Guest User',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: screenWidth * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  // User email if available
                  if (user?.email != null)
                    Padding(
                      padding: EdgeInsets.only(top: screenHeight * 0.005),
                      child: Text(
                        user!.email!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: screenHeight * 0.04),
            const Divider(),
            
            // Account section
            _buildSectionTitle('Account', screenWidth),
            
            // Privacy Settings
            ListTile(
              leading: _getPlatformIcon(
                Icons.privacy_tip_outlined,
                CupertinoIcons.shield,
                color: Colors.blue,
              ),
              title: const Text('Privacy Settings'),
              trailing: _getPlatformIcon(
                Icons.chevron_right,
                CupertinoIcons.chevron_right,
              ),
              onTap: () {
                Navigator.pushNamed(context, '/privacy_settings');
              },
            ),
            
            // Logout option
            ListTile(
              leading: _getPlatformIcon(
                Icons.logout,
                CupertinoIcons.square_arrow_right,
                color: Colors.orange,
              ),
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
                : _getPlatformIcon(
                    Icons.chevron_right,
                    CupertinoIcons.chevron_right,
                  ),
            ),
            
            const Divider(),
            
            // Legal section
            _buildSectionTitle('Legal', screenWidth),
            
            // Privacy Policy
            ListTile(
              leading: _getPlatformIcon(
                Icons.policy_outlined,
                CupertinoIcons.doc_text,
                color: Colors.green,
              ),
              title: const Text('Privacy Policy'),
              trailing: _getPlatformIcon(
                Icons.chevron_right,
                CupertinoIcons.chevron_right,
              ),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.privacyPolicy);
              },
            ),
            
            // Terms of Service
            ListTile(
              leading: _getPlatformIcon(
                Icons.article_outlined,
                CupertinoIcons.doc_plaintext,
                color: Colors.purple,
              ),
              title: const Text('Terms of Service'),
              trailing: _getPlatformIcon(
                Icons.chevron_right,
                CupertinoIcons.chevron_right,
              ),
              onTap: () {
                Navigator.pushNamed(context, AppRoutes.termsOfService);
              },
            ),
            
            const Divider(),
            
            // Danger zone
            _buildSectionTitle('Danger Zone', screenWidth),
            
            // Delete account option
            ListTile(
              leading: _getPlatformIcon(
                Icons.delete_forever,
                CupertinoIcons.delete,
                color: Colors.red,
              ),
              title: const Text(
                'Delete Account', 
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
                : _getPlatformIcon(
                    Icons.chevron_right,
                    CupertinoIcons.chevron_right,
                  ),
            ),
            
            SizedBox(height: screenHeight * 0.06),
            
            // App version at bottom
            Center(
              child: Text(
                'Version $_appVersion ($_buildNumber)',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: Colors.grey[500],
                ),
              ),
            ),
            
            SizedBox(height: screenHeight * 0.02),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build section titles
  Widget _buildSectionTitle(String title, double screenWidth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.w600,
          color: Colors.grey[700],
        ),
      ),
    );
  }
  
  // Helper method to build profile image with error handling and caching
  Widget _buildProfileImageWidget(BuildContext context, UserModel user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isIOS = Platform.isIOS;
    
    if (user.photoURL == null) {
      return CircleAvatar(
        radius: screenWidth * 0.12,
        backgroundColor: AppColors.accentBlue,
        child: Icon(
          isIOS ? CupertinoIcons.person : Icons.person, 
          size: screenWidth * 0.12, 
          color: Colors.white,
        ),
      );
    }
    
    return CircleAvatar(
      radius: screenWidth * 0.12,
      backgroundColor: Colors.grey[300],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(screenWidth * 0.12),
        child: Image.network(
          user.photoURL!,
          width: screenWidth * 0.24,
          height: screenWidth * 0.24,
          fit: BoxFit.cover,
          // Enable caching for better performance
          cacheWidth: (screenWidth * 0.24 * MediaQuery.of(context).devicePixelRatio).round(),
          cacheHeight: (screenWidth * 0.24 * MediaQuery.of(context).devicePixelRatio).round(),
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              isIOS ? CupertinoIcons.person : Icons.person, 
              size: screenWidth * 0.12, 
              color: Colors.white,
            );
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
                strokeWidth: 2,
              ),
            );
          },
        ),
      ),
    );
  }
}
