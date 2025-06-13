import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:io';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/models/user_model.dart';
import '../../auth/providers/auth_state_provider.dart';
import '../providers/settings_provider.dart';

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

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
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
    return Platform.isIOS ? _buildCupertinoPage(context) : _buildMaterialPage(context);
  }

  Widget _buildMaterialPage(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: theme.colorScheme.surface,
        centerTitle: true,
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, settingsProvider, child) {
          final user = settingsProvider.currentUser;
          final isLoading = settingsProvider.isLoading;
          
          return ListView(
            padding: EdgeInsets.only(
              left: screenWidth * 0.05,
              right: screenWidth * 0.05,
              top: screenHeight * 0.02,
              bottom: 120, // Add bottom padding to avoid floating nav bar
            ),
            children: [
              // Add space from top
              SizedBox(height: screenHeight * 0.03),
              
              // User profile section with better spacing
              Center(
                child: Column(
                  children: [
                    // Profile image
                    isLoading
                        ? const CircularProgressIndicator()
                        : (user != null 
                            ? _buildProfileImageWidget(context, user) 
                            : CircleAvatar(
                                radius: screenWidth * 0.12,
                                backgroundColor: AppColors.accentBlue,
                                child: Icon(
                                  Platform.isIOS ? CupertinoIcons.person : Icons.person, 
                                  size: screenWidth * 0.12, 
                                  color: Colors.white,
                                ),
                              )),
                    SizedBox(height: screenHeight * 0.02),
                    
                    // User display name
                    Text(
                      user?.displayName ?? 'Guest User',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
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
                  )
                )
              : _getPlatformIcon(
                  Icons.chevron_right,
                  CupertinoIcons.chevron_right,
                ),
          ),
          
          SizedBox(height: screenHeight * 0.03), // Reduced from 0.06
          
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
      );
        },
      ),
    );
  }

  Widget _buildCupertinoPage(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Settings'),
        backgroundColor: cupertinoTheme.barBackgroundColor.withAlpha(178), // 0.7 * 255 = ~178
        border: null, // Remove default border for a cleaner look
      ),
      child: SafeArea(
        child: Consumer<SettingsProvider>(
          builder: (context, settingsProvider, child) {
            final user = settingsProvider.currentUser;
            final isLoading = settingsProvider.isLoading;
            
            return ListView(
              padding: EdgeInsets.only(
                left: screenWidth * 0.05,
                right: screenWidth * 0.05,
                top: screenHeight * 0.02,
                bottom: 120, // Add bottom padding to avoid floating nav bar
              ),
              children: [
                // Add space from top
                SizedBox(height: screenHeight * 0.02),
                
                // User profile section with better spacing
                Center(
                  child: Column(
                    children: [
                      // Profile image
                      isLoading
                          ? const CupertinoActivityIndicator()
                          : (user != null 
                              ? _buildProfileImageWidget(context, user) 
                              : CircleAvatar(
                                  radius: screenWidth * 0.12,
                                  backgroundColor: AppColors.accentBlue,
                                  child: Icon(
                                    CupertinoIcons.person, 
                                    size: screenWidth * 0.12, 
                                    color: CupertinoColors.white,
                                  ),
                                )),
                      SizedBox(height: screenHeight * 0.02),
                      
                      // User display name
                      Text(
                        user?.displayName ?? 'Guest User',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.04),
                
                // Account section
                _buildCupertinoSectionHeader('Account'),
                _buildCupertinoListSection([
                  // Privacy Settings
                  _buildCupertinoListTile(
                    icon: CupertinoIcons.shield,
                    iconColor: CupertinoColors.activeBlue,
                    title: 'Privacy Settings',
                    onTap: () {
                      Navigator.pushNamed(context, '/privacy_settings');
                    },
                  ),
                  // Logout option
                  _buildCupertinoListTile(
                    icon: CupertinoIcons.square_arrow_right,
                    iconColor: CupertinoColors.systemOrange,
                    title: 'Logout',
                    onTap: _isLoading ? null : _handleLogout,
                    trailing: _isLoading 
                      ? const CupertinoActivityIndicator() 
                      : const Icon(CupertinoIcons.chevron_right, size: 18),
                  ),
                ]),
                
                SizedBox(height: screenHeight * 0.02),
                
                // Legal section
                _buildCupertinoSectionHeader('Legal'),
                _buildCupertinoListSection([
                  // Privacy Policy
                  _buildCupertinoListTile(
                    icon: CupertinoIcons.doc_text,
                    iconColor: CupertinoColors.systemGreen,
                    title: 'Privacy Policy',
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.privacyPolicy);
                    },
                  ),
                  // Terms of Service
                  _buildCupertinoListTile(
                    icon: CupertinoIcons.doc_plaintext,
                    iconColor: CupertinoColors.systemPurple,
                    title: 'Terms of Service',
                    onTap: () {
                      Navigator.pushNamed(context, AppRoutes.termsOfService);
                    },
                  ),
                ]),
                
                SizedBox(height: screenHeight * 0.02),
                
                // Danger zone
                _buildCupertinoSectionHeader('Danger Zone'),
                _buildCupertinoListSection([
                  // Delete account option
                  _buildCupertinoListTile(
                    icon: CupertinoIcons.delete,
                    iconColor: CupertinoColors.systemRed,
                    title: 'Delete Account',
                    titleColor: CupertinoColors.systemRed,
                    onTap: _isDeleting ? null : _confirmDeleteAccount,
                    trailing: _isDeleting 
                      ? const CupertinoActivityIndicator() 
                      : const Icon(CupertinoIcons.chevron_right, size: 18),
                  ),
                ]),
                
                SizedBox(height: screenHeight * 0.03), // Reduced from 0.06
                
                // App version at bottom
                Center(
                  child: Text(
                    'Version $_appVersion ($_buildNumber)',
                    style: TextStyle(
                      fontSize: screenWidth * 0.035,
                      color: CupertinoColors.systemGrey.resolveFrom(context),
                    ),
                  ),
                ),
                
                SizedBox(height: screenHeight * 0.02),
              ],
            );
          },
        ),
      ),
    );
  }
  
  // Helper method to build section titles for Material design
  Widget _buildSectionTitle(String title, double screenWidth) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: screenWidth * 0.045,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withAlpha(178), // 0.7 * 255 = ~178
        ),
      ),
    );
  }
  
  // Helper methods for Cupertino design
  Widget _buildCupertinoSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      ),
    );
  }

  Widget _buildCupertinoListSection(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildCupertinoListTile({
    required IconData icon, 
    required String title, 
    required VoidCallback? onTap, 
    Color iconColor = CupertinoColors.activeBlue, 
    Color? titleColor, 
    Widget? trailing
  }) {
    trailing ??= const Icon(CupertinoIcons.chevron_right, size: 18);
    
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  color: titleColor ?? CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
  
  // Helper method to build profile image with error handling and caching
  Widget _buildProfileImageWidget(BuildContext context, UserModel user) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bool isIOS = Platform.isIOS;
    
    // User profile image handling
    
    if (user.photoURL == null) {
      // No profile photo available
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
    
    // Check if this is a cached local file path
    final isLocalFile = user.photoURL!.startsWith('file://') || user.photoURL!.startsWith('/');
    
    if (isLocalFile) {
      // Use the cached local file
      final localPath = user.photoURL!.startsWith('file://') 
          ? user.photoURL!.replaceFirst('file://', '') 
          : user.photoURL!;
      
      return CircleAvatar(
        radius: screenWidth * 0.12,
        backgroundColor: Colors.grey[300],
        child: ClipRRect(
          borderRadius: BorderRadius.circular(screenWidth * 0.12),
          child: Image.file(
            File(localPath),
            width: screenWidth * 0.24,
            height: screenWidth * 0.24,
            fit: BoxFit.cover,
            cacheWidth: (screenWidth * 0.24 * MediaQuery.of(context).devicePixelRatio).round(),
            cacheHeight: (screenWidth * 0.24 * MediaQuery.of(context).devicePixelRatio).round(),
            errorBuilder: (context, error, stackTrace) {
              // Fall back to network image if cached file fails
              return _buildNetworkImage(context, user.photoURL!, screenWidth, isIOS);
            },
          ),
        ),
      );
    }
    
    // Use network image for non-cached photos
    return CircleAvatar(
      radius: screenWidth * 0.12,
      backgroundColor: Colors.grey[300],
      child: ClipRRect(
        borderRadius: BorderRadius.circular(screenWidth * 0.12),
        child: _buildNetworkImage(context, user.photoURL!, screenWidth, isIOS),
      ),
    );
  }
  // Helper method to build network image
  Widget _buildNetworkImage(BuildContext context, String imageUrl, double screenWidth, bool isIOS) {
    return Image.network(
      imageUrl,
      width: screenWidth * 0.24,
      height: screenWidth * 0.24,
      fit: BoxFit.cover,
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
          child: isIOS
              ? const CupertinoActivityIndicator()
              : CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  strokeWidth: 2,
                ),
        );
      },
    );
  }
}
