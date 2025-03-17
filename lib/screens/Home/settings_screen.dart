import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../widgets/animated_background.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<auth.AuthProvider>(context).userModel;
    
    if (userModel == null) {
      return const Scaffold(
        body: Center(
          child: Text('Loading user data...'),
        ),
      );
    }
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        opacity: 0.03,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(context),
              
              // Settings content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Edit Profile Section
                      _buildSettingSection(
                        title: 'Edit Profile',
                        icon: Icons.edit,
                        children: [
                          _buildSettingOption(
                            context: context,
                            title: 'Update Display Name',
                            icon: Icons.person,
                            onTap: () => _showUpdateNameDialog(context, userModel),
                            delay: 100,
                          ),
                          _buildSettingOption(
                            context: context,
                            title: 'Update Profile Photo',
                            icon: Icons.photo,
                            onTap: () {
                              // Show photo upload dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Photo update coming soon!')),
                              );
                            },
                            delay: 150,
                          ),
                        ],
                        delay: 0,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Account Section
                      _buildSettingSection(
                        title: 'Account',
                        icon: Icons.account_circle,
                        children: [
                          // Phone number (if missing, show add option)
                          _buildSettingOption(
                            context: context,
                            title: userModel.phoneNumber != null && userModel.phoneNumber!.isNotEmpty 
                                ? 'Phone: ${userModel.phoneNumber}' 
                                : 'Add Phone Number',
                            icon: Icons.phone,
                            onTap: () => _showAddPhoneDialog(context, userModel),
                            delay: 150,
                          ),
                          
                          // Connected providers
                          _buildProvidersList(context, userModel),
                        ],
                        delay: 50,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Preferences Section
                      _buildSettingSection(
                        title: 'Preferences',
                        icon: Icons.tune,
                        children: [
                          _buildNotificationToggle(context, userModel),
                        ],
                        delay: 100,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Subscription Status
                      _buildSettingSection(
                        title: 'Subscription',
                        icon: Icons.card_membership,
                        children: [
                          _buildSubscriptionStatus(context, userModel),
                        ],
                        delay: 150,
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Sign Out Button
                      _buildSignOutButton(context)
                        .animate()
                        .fadeIn(delay: 500.ms)
                        .scale(
                          begin: const Offset(0.8, 0.8),
                          end: const Offset(1.0, 1.0),
                          curve: Curves.easeOutBack,
                        ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFD4A76A).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios),
            onPressed: () => Navigator.pop(context),
            color: const Color(0xFFD4A76A),
          ),
          const Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFFD4A76A),
              ),
            ),
          ),
          const SizedBox(width: 48), // For centering the title
        ],
      ),
    ).animate()
      .fadeIn()
      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad);
  }
  
  // Builds a setting section with title and children
  Widget _buildSettingSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required int delay,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFD4A76A),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF8B4513),
              ),
            ),
          ],
        ).animate()
          .fadeIn(delay: Duration(milliseconds: delay))
          .slideX(begin: -0.2, end: 0, delay: Duration(milliseconds: delay)),
        
        const Divider(color: Color(0xFFD4A76A), height: 24),
        
        ...children,
      ],
    );
  }
  
  // Builds a setting option item
  Widget _buildSettingOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    required int delay,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD4A76A).withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFFD4A76A),
                size: 20,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B4513),
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFD4A76A),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: delay))
      .slideY(begin: 0.2, end: 0, delay: Duration(milliseconds: delay));
  }
  
  // Builds the connected providers list
  Widget _buildProvidersList(BuildContext context, UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4A76A).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Connected Accounts',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B4513),
            ),
          ),
          const SizedBox(height: 12),
          ...userModel.providers.map((provider) {
            IconData providerIcon;
            String providerName;
            
            switch (provider) {
              case AuthProvider.google:
                providerIcon = Icons.search;
                providerName = 'Google';
                break;
              case AuthProvider.apple:
                providerIcon = Icons.apple;
                providerName = 'Apple';
                break;
              case AuthProvider.phone:
                providerIcon = Icons.phone;
                providerName = 'Phone';
                break;
              case AuthProvider.email:
              default:
                providerIcon = Icons.email;
                providerName = 'Email';
                break;
            }
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    providerIcon,
                    color: const Color(0xFF8B4513),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    providerName,
                    style: const TextStyle(
                      color: Color(0xFF8B4513),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 16,
                  ),
                ],
              ),
            ).animate()
              .fadeIn(delay: const Duration(milliseconds: 200))
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
          }).toList(),
        ],
      ),
    ).animate()
      .fadeIn(delay: const Duration(milliseconds: 200))
      .slideY(begin: 0.2, end: 0);
  }
  
  // Notification toggle switch
  Widget _buildNotificationToggle(BuildContext context, UserModel userModel) {
    final bool notificationsEnabled = userModel.getMetadata('notificationsEnabled') ?? true;
    
    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFD4A76A).withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications,
                color: const Color(0xFFD4A76A),
                size: 20,
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Enable Notifications',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B4513),
                  ),
                ),
              ),
              Switch(
                value: notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    // Update user metadata for notifications
                    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
                    if (authProvider.userModel != null) {
                      final updatedUser = authProvider.userModel!.updateMetadata('notificationsEnabled', value);
                      // This will trigger a refresh in the UI
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Notification settings updated')),
                      );
                    }
                  });
                },
                activeColor: const Color(0xFFD4A76A),
              ),
            ],
          ),
        );
      },
    ).animate()
      .fadeIn(delay: const Duration(milliseconds: 250))
      .slideY(begin: 0.2, end: 0);
  }
  
  // Subscription status widget
  Widget _buildSubscriptionStatus(BuildContext context, UserModel userModel) {
    // Check if user has any active subscriptions
    final hasSubscription = userModel.subscriptions != null && 
                            userModel.subscriptions!.isNotEmpty &&
                            userModel.subscriptions!.values.any((sub) => 
                              sub is Map && sub['isActive'] == true);
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFD4A76A).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasSubscription ? Icons.star : Icons.star_border,
                color: hasSubscription ? Colors.amber : Colors.grey,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                hasSubscription ? 'Premium Account' : 'Free Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasSubscription ? Colors.amber.shade800 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasSubscription 
                ? 'Your premium subscription is active.' 
                : 'Upgrade to premium to get more features!',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
            ),
          ),
          if (!hasSubscription) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              child: ElevatedButton(
                onPressed: () {
                  // Show upgrade options dialog
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Upgrade options coming soon!')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A76A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Upgrade Now'),
              ),
            ),
          ],
        ],
      ),
    ).animate()
      .fadeIn(delay: const Duration(milliseconds: 300))
      .slideY(begin: 0.2, end: 0);
  }
  
  // Sign out button
  Widget _buildSignOutButton(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton.icon(
        onPressed: () {
          Provider.of<auth.AuthProvider>(context, listen: false).signOut();
          Navigator.of(context).popUntil((route) => route.isFirst);
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A76A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }
  
  // Dialog to update display name
  void _showUpdateNameDialog(BuildContext context, UserModel userModel) {
    final TextEditingController nameController = TextEditingController(text: userModel.displayName);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Display Name',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  hintText: 'Enter new display name',
                  filled: true,
                  fillColor: const Color(0xFFD4A76A).withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(color: Color(0xFF8B4513)),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      final newName = nameController.text.trim();
                      if (newName.isNotEmpty) {
                        final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
                        if (authProvider.userModel != null) {
                          // Update name in database
                          Provider.of<UserProvider>(context, listen: false).updateDisplayName(newName);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Display name updated')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A76A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Update'),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
  
  // Dialog to add phone number
  void _showAddPhoneDialog(BuildContext context, UserModel userModel) {
    final TextEditingController phoneController = TextEditingController(text: userModel.phoneNumber);
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Phone Number',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 16),
              TextField(
                controller: phoneController,
                decoration: InputDecoration(
                  hintText: 'Enter phone number',
                  filled: true,
                  fillColor: const Color(0xFFD4A76A).withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFFD4A76A)),
                ),
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Color(0xFF8B4513)),
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () { 
                      final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
                      if (authProvider.userModel != null) {
                        // Update phone number in database - for now just show feedback
                        // This would normally update via a service
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Phone number update functionality coming soon')),
                        );
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4A76A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    child: const Text('Update'),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }
} 