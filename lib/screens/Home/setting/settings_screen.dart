import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../providers/auth_provider.dart' as auth;
import '../../../providers/user_provider.dart';
import '../../../models/user_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/phone_auth_popup.dart';
import '../../onboarding/profile_photo_preview_screen.dart';
import 'blocked_users_screen.dart';

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
                            subtitle: userModel.displayName,
                            icon: Icons.person,
                            onTap: () => _showUpdateNameDialog(context, userModel),
                            delay: 100,
                          ),
                          _buildSettingOption(
                            context: context,
                            title: 'Update Profile Photo',
                            subtitle: 'Change your profile picture',
                            icon: Icons.photo_camera,
                            onTap: () => _showUpdatePhotoDialog(context, userModel),
                            delay: 200,
                          ),
                          _buildSettingOption(
                            context: context,
                            title: 'Update Date of Birth',
                            subtitle: userModel.dateOfBirth != null 
                                ? _formatDate(userModel.dateOfBirth!) 
                                : 'Not set',
                            icon: Icons.cake,
                            onTap: () => _showUpdateDateOfBirthDialog(context, userModel),
                            delay: 300,
                          ),
                          _buildSettingOption(
                            context: context,
                            title: 'Update Gender',
                            subtitle: userModel.gender != null 
                                ? _formatGender(userModel.gender.toString().split('.').last)
                                : 'Not set',
                            icon: Icons.person_outline,
                            onTap: () => _showUpdateGenderDialog(context, userModel),
                            delay: 400,
                          ),
                        ],
                        delay: 100,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Account Section
                      _buildSettingSection(
                        title: 'Account',
                        icon: Icons.account_circle,
                        children: [
                          _buildSettingOption(
                            context: context,
                            title: userModel.phoneNumber != null && userModel.phoneNumber!.isNotEmpty 
                                ? 'Phone: ${userModel.phoneNumber}' 
                                : 'Add Phone Number',
                            icon: Icons.phone,
                            onTap: () => _showPhoneAuthDialog(context),
                            delay: 500,
                          ),
                          _buildProvidersList(context, userModel),
                        ],
                        delay: 200,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Privacy Section
                      _buildSettingSection(
                        title: 'Privacy',
                        icon: Icons.lock,
                        children: [
                          _buildSettingOption(
                            context: context,
                            title: 'Blocked Users',
                            subtitle: 'Manage users you\'ve blocked',
                            icon: Icons.block,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
                            ),
                            delay: 600,
                          ),
                          _buildPrivacyToggle(
                            context: context,
                            title: 'Show Social Links',
                            subtitle: 'Display your social media profiles',
                            icon: Icons.share,
                            value: userModel.getMetadata('showSocialLinks') ?? true,
                            onChanged: (value) => _updatePrivacySetting(context, 'showSocialLinks', value),
                            delay: 700,
                          ),
                          _buildPrivacyToggle(
                            context: context,
                            title: 'Show Online Status',
                            subtitle: 'Let others see when you\'re online',
                            icon: Icons.visibility,
                            value: userModel.getMetadata('showOnlineStatus') ?? true,
                            onChanged: (value) => _updatePrivacySetting(context, 'showOnlineStatus', value),
                            delay: 800,
                          ),
                          _buildPrivacyToggle(
                            context: context,
                            title: 'Show Last Seen',
                            subtitle: 'Display your last active time',
                            icon: Icons.access_time,
                            value: userModel.getMetadata('showLastSeen') ?? true,
                            onChanged: (value) => _updatePrivacySetting(context, 'showLastSeen', value),
                            delay: 900,
                          ),
                        ],
                        delay: 400,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Preferences Section
                      _buildSettingSection(
                        title: 'Preferences',
                        icon: Icons.tune,
                        children: [
                          _buildNotificationToggle(context, userModel),
                        ],
                        delay: 500,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Subscription Status
                      _buildSettingSection(
                        title: 'Subscription',
                        icon: Icons.card_membership,
                        children: [
                          _buildSubscriptionStatus(context, userModel),
                        ],
                        delay: 600,
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
    // Get screen dimensions and safe area for responsive layout
    final double screenWidth = MediaQuery.of(context).size.width;
    final EdgeInsets safePadding = MediaQuery.of(context).padding;
    final bool isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.only(
        left: 8, 
        right: 8, 
        top: 16 + safePadding.top, // Account for safe area at top
        bottom: 16
      ),
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
          // Back button - make tap target larger on small screens
          SizedBox(
            width: isSmallScreen ? 44 : 48,
            height: isSmallScreen ? 44 : 48,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              iconSize: isSmallScreen ? 20 : 24,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              color: const Color(0xFFD4A76A),
            ),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD4A76A),
              ),
            ),
          ),
          // Maintain symmetry with a placeholder of the same size as the back button
          SizedBox(width: isSmallScreen ? 44 : 48),
        ],
      ),
    ).animate()
      .fadeIn()
      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad);
  }

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
  
  Widget _buildSettingOption({
    required BuildContext context,
    required String title,
    String? subtitle,
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
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
                onChanged: (value) async {
                  setState(() {
                    // Update user metadata for notifications
                    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
                    if (authProvider.userModel != null) {
                      final updatedUser = authProvider.userModel!.updateMetadata('notificationsEnabled', value);
                      // Update in Firestore
                      authProvider.updateUserProfile(
                        metadata: updatedUser.metadata,
                      );
                      // Show feedback
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(value ? 'Notifications enabled' : 'Notifications disabled'),
                          backgroundColor: const Color(0xFFD4A76A),
                        ),
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

  Widget _buildSubscriptionStatus(BuildContext context, UserModel userModel) {
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

  Widget _buildPrivacyToggle({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
    required int delay,
  }) {
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
            icon,
            color: const Color(0xFFD4A76A),
            size: 20,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B4513),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFD4A76A),
          ),
        ],
      ),
    ).animate()
      .fadeIn(delay: Duration(milliseconds: delay))
      .slideY(begin: 0.2, end: 0, delay: Duration(milliseconds: delay));
  }

  void _updatePrivacySetting(BuildContext context, String key, bool value) {
    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
    if (authProvider.userModel != null) {
      final updatedUser = authProvider.userModel!.updateMetadata(key, value);
      authProvider.updateUserProfile(
        metadata: updatedUser.metadata,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${key.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toLowerCase()} ${value ? 'enabled' : 'disabled'}'),
          backgroundColor: const Color(0xFFD4A76A),
        ),
      );
    }
  }

  void _showPhoneAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PhoneAuthPopup(
        onSubmit: (countryCode, phoneNumber) {
          final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
          authProvider.updateUserProfile(
            metadata: {'phoneNumber': '$countryCode$phoneNumber'},
          );
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Phone number updated'),
              backgroundColor: Color(0xFFD4A76A),
            ),
          );
        },
      ),
    );
  }

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
                        authProvider.updateUserProfile(
                          displayName: newName,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Display name updated'),
                            backgroundColor: Color(0xFFD4A76A),
                          ),
                        );
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

  void _showUpdateDateOfBirthDialog(BuildContext context, UserModel userModel) {
    DateTime selectedDate = userModel.dateOfBirth ?? DateTime.now().subtract(const Duration(days: 365 * 18));
    
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
                'Update Date of Birth',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: CalendarDatePicker(
                  initialDate: selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365 * 100)),
                  lastDate: DateTime.now().subtract(const Duration(days: 365 * 13)),
                  onDateChanged: (date) {
                    selectedDate = date;
                  },
                ),
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
                      authProvider.updateUserProfile(
                        dateOfBirth: selectedDate,
                      );
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Date of birth updated'),
                          backgroundColor: Color(0xFFD4A76A),
                        ),
                      );
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

  void _showUpdateGenderDialog(BuildContext context, UserModel userModel) {
    Gender? selectedGender = userModel.gender;
    
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
                'Update Gender',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 16),
              Column(
                children: Gender.values.map((gender) {
                  return RadioListTile<Gender>(
                    title: Text(_formatGender(gender.toString().split('.').last)),
                    value: gender,
                    groupValue: selectedGender,
                    onChanged: (value) {
                      selectedGender = value;
                    },
                  );
                }).toList(),
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
                      if (selectedGender != null) {
                        final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
                        authProvider.updateUserProfile(
                          gender: selectedGender,
                        );
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Gender updated'),
                            backgroundColor: Color(0xFFD4A76A),
                          ),
                        );
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

  void _showUpdatePhotoDialog(BuildContext context, UserModel userModel) {
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
                'Update Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ).animate().fadeIn().slideY(begin: -0.2, end: 0),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildPhotoOption(
                    context,
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () => _pickImage(context, userModel, ImageSource.camera),
                  ),
                  _buildPhotoOption(
                    context,
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onTap: () => _pickImage(context, userModel, ImageSource.gallery),
                  ),
                ],
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
                ],
              ).animate().fadeIn(delay: 200.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFD4A76A).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFFD4A76A),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8B4513),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(BuildContext context, UserModel userModel, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        Navigator.pop(context); // Close the photo options dialog
        
        // Navigate to preview screen
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfilePhotoPreviewScreen(
                imagePath: image.path,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June', 
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
  
  String _formatGender(String gender) {
    if (gender.isEmpty) return 'Not specified';
    return gender[0].toUpperCase() + gender.substring(1).toLowerCase();
  }
} 