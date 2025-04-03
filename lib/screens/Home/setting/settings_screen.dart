import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import '../../../providers/auth_provider.dart' as auth;
import '../../../providers/user_provider.dart';
import '../../../models/user_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/phone_auth_popup.dart';
import '../../onboarding/profile_photo_preview_screen.dart';
import 'blocked_users_screen.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:convert';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

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
      extendBodyBehindAppBar: true, // Extend body behind AppBar for gradient
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF8B4513)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: DuckBuckAnimatedBackground(
        opacity: 0.03,
        child: SafeArea(
          child: _buildSettingsContent(context, userModel),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSettingsContent(BuildContext context, UserModel userModel) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Add a settings icon at the top with Hero animation
          const SizedBox(height: 20),
          Hero(
            tag: 'settings-button',
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6C38D).withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings,
                  color: Color(0xFF8B4513),
                  size: 40,
                ),
              ),
            ),
          ).animate(autoPlay: true).scale(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1.0, 1.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
          ),
          const SizedBox(height: 30),
          
          // Settings sections
          _buildAllSettingSections(context, userModel),
        ],
      ),
    );
  }

  Widget _buildAllSettingSections(BuildContext context, UserModel userModel) {
    return Column(
      children: [
        // Account Section (moved to the top)
        _buildSettingSection(
          title: 'Account',
          icon: Icons.person,
          children: [
            _buildSettingOption(
              context: context,
              title: 'Edit Profile',
              subtitle: 'Update your profile details',
              icon: Icons.edit,
              onTap: () => _showUpdateNameDialog(context, userModel),
              delay: 0,
            ),
            _buildSettingOption(
              context: context,
              title: 'Change Phone Number',
              subtitle: userModel.phoneNumber ?? 'Add a phone number',
              icon: Icons.phone,
              onTap: () => _showPhoneAuthDialog(context),
              delay: 0,
            ),
          ],
          delay: 0,
        ).animate(autoPlay: true)
          .fadeIn(duration: 300.ms, delay: 100.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        
        const SizedBox(height: 24),
        
        // Subscription Status
        _buildSettingSection(
          title: 'Subscription',
          icon: Icons.card_membership,
          children: [
            _buildSubscriptionStatus(context, userModel),
          ],
          delay: 0,
        ).animate(autoPlay: true)
          .fadeIn(duration: 300.ms, delay: 200.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const BlockedUsersScreen()),
                );
              },
              delay: 0,
            ),
            _buildPrivacyToggle(
              context: context,
              title: 'Show Social Links',
              subtitle: 'Display your social media profiles',
              icon: Icons.share,
              value: userModel.getMetadata('showSocialLinks') ?? true,
              onChanged: (value) => _updatePrivacySetting(context, 'showSocialLinks', value),
              delay: 0,
            ),
            _buildPrivacyToggle(
              context: context,
              title: 'Show Online Status',
              subtitle: 'Let others see when you\'re online',
              icon: Icons.visibility,
              value: userModel.getMetadata('showOnlineStatus') ?? true,
              onChanged: (value) => _updatePrivacySetting(context, 'showOnlineStatus', value),
              delay: 0,
            ),
            _buildPrivacyToggle(
              context: context,
              title: 'Show Last Seen',
              subtitle: 'Display your last active time',
              icon: Icons.access_time,
              value: userModel.getMetadata('showLastSeen') ?? true,
              onChanged: (value) => _updatePrivacySetting(context, 'showLastSeen', value),
              delay: 0,
            ),
          ],
          delay: 0,
        ).animate(autoPlay: true)
          .fadeIn(duration: 300.ms, delay: 300.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        
        const SizedBox(height: 24),
        
        // Help & Support Section
        _buildSettingSection(
          title: 'Help & Support',
          icon: Icons.help_outline,
          children: [
            _buildSettingOption(
              context: context,
              title: 'Contact Support',
              subtitle: 'Get help with your account',
              icon: Icons.support_agent,
              onTap: () => _contactSupport(context),
              delay: 0,
            ),
            _buildSettingOption(
              context: context,
              title: 'FAQs',
              subtitle: 'Frequently asked questions',
              icon: Icons.question_answer,
              onTap: () => _showFAQs(context),
              delay: 0,
            ),
          ],
          delay: 0,
        ).animate(autoPlay: true)
          .fadeIn(duration: 300.ms, delay: 400.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        
        const SizedBox(height: 24),
        
        // About Section
        _buildSettingSection(
          title: 'About',
          icon: Icons.info_outline,
          children: [
            _buildSettingOption(
              context: context,
              title: 'Terms of Service',
              subtitle: 'Read our terms and conditions',
              icon: Icons.description,
              onTap: () => _showLegalBottomSheet(context, 'terms_of_service'),
              delay: 0,
            ),
            _buildSettingOption(
              context: context,
              title: 'Privacy Policy',
              subtitle: 'Learn how we handle your data',
              icon: Icons.privacy_tip,
              onTap: () => _showLegalBottomSheet(context, 'privacy_policy'),
              delay: 0,
            ),
            _buildAppVersionInfo(),
          ],
          delay: 0,
        ).animate(autoPlay: true)
          .fadeIn(duration: 300.ms, delay: 500.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        
        const SizedBox(height: 32),
      ],
    );
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
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6C38D).withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF8B4513),
                size: 18,
              ),
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
        ),
        
        Divider(color: const Color(0xFFD4A76A).withOpacity(0.7), height: 24),
        
        // Apply staggered animation to each item within the section
        ...children.asMap().entries.map((entry) {
          final index = entry.key;
          final child = entry.value;
          
          return child.animate(autoPlay: true)
            .fadeIn(delay: Duration(milliseconds: 100 * index))
            .slideX(
              begin: 0.1,
              end: 0,
              delay: Duration(milliseconds: 100 * index),
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
        }).toList(),
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
            color: const Color(0xFFF5E8C7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4A76A).withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6C38D).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF8B4513),
                  size: 20,
                ),
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
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF8B4513).withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: const Color(0xFF8B4513),
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProvidersList(BuildContext context, UserModel userModel) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8C7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A76A).withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
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
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6C38D).withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      providerIcon,
                      color: const Color(0xFF8B4513),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
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
            ).animate(autoPlay: true)
              .fadeIn(delay: const Duration(milliseconds: 200))
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1));
          }).toList(),
        ],
      ),
    ).animate(autoPlay: true)
      .fadeIn(delay: const Duration(milliseconds: 200))
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
        color: hasSubscription ? const Color(0xFFFFF8E1) : const Color(0xFFF5E8C7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A76A).withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: hasSubscription ? Border.all(
          color: Colors.amber.shade300,
          width: 1,
        ) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasSubscription 
                      ? Colors.amber.withOpacity(0.2)
                      : const Color(0xFFE6C38D).withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasSubscription ? Icons.star : Icons.star_border,
                  color: hasSubscription ? Colors.amber.shade700 : const Color(0xFF8B4513),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                hasSubscription ? 'Premium Account' : 'Free Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: hasSubscription ? Colors.amber.shade800 : const Color(0xFF8B4513),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasSubscription 
                ? 'Your premium subscription is active.' 
                : 'Upgrade to premium to get more features!',
            style: TextStyle(
              fontSize: 14,
              color: hasSubscription ? Colors.amber.shade800 : const Color(0xFF8B4513).withOpacity(0.7),
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
                  elevation: 2,
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
    ).animate(autoPlay: true)
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
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final bool isActuallyOnline = userProvider.actualIsOnline;
    
    // Add visual cue for online status if this is the online status toggle
    final bool isOnlineStatusToggle = title.contains('Online Status');
    final bool isLastSeenToggle = title.contains('Last Seen');
    
    String statusInfo = '';
    if (isOnlineStatusToggle) {
      statusInfo = isActuallyOnline 
          ? (value ? 'Others can see you\'re online' : 'You appear offline to others')
          : 'You are currently offline';
    } else if (isLastSeenToggle && !value) {
      statusInfo = 'Others cannot see when you were last active';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8C7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A76A).withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6C38D).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF8B4513),
                    size: 20,
                  ),
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
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF8B4513).withOpacity(0.7),
                        ),
                      ),
                      if (statusInfo.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          statusInfo,
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: isActuallyOnline && isOnlineStatusToggle && !value 
                                ? Colors.red.shade700 
                                : const Color(0xFF8B4513).withOpacity(0.6),
                          ),
                        ),
                      ],
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
          ),
        ],
      ),
    ).animate(autoPlay: true)
    .fadeIn(delay: Duration(milliseconds: delay))
    .slideY(begin: 0.2, end: 0, delay: Duration(milliseconds: delay));
  }

  void _updatePrivacySetting(BuildContext context, String key, bool value) {
    final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
    if (authProvider.userModel != null) {
      final updatedUser = authProvider.userModel!.updateMetadata(key, value);
      
      // Update Firebase database status settings specifically for online status and last seen
      if (key == 'showOnlineStatus' || key == 'showLastSeen') {
        final userProvider = Provider.of<UserProvider>(context, listen: false);
        userProvider.updatePrivacySettings(key, value);
      }
      
      // Update in Firestore
      authProvider.updateUserProfile(
        metadata: updatedUser.metadata,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_formatSettingName(key)} ${value ? 'enabled' : 'disabled'}'),
          backgroundColor: const Color(0xFFD4A76A),
        ),
      );
    }
  }
  
  String _formatSettingName(String key) {
    // Convert camelCase to sentence case
    final result = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)!.toLowerCase()}'
    );
    return result[0].toUpperCase() + result.substring(1);
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
              ).animate(autoPlay: true).fadeIn().slideY(begin: -0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 200.ms),
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
              ).animate(autoPlay: true).fadeIn().slideY(begin: -0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 200.ms),
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
              ).animate(autoPlay: true).fadeIn().slideY(begin: -0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 200.ms),
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
              ).animate(autoPlay: true).fadeIn().slideY(begin: -0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
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
              ).animate(autoPlay: true).fadeIn(delay: 200.ms),
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

  // Helper method to show legal documents
  void _showLegalBottomSheet(BuildContext context, String type) async {
    try {
      // Load legal content
      final String jsonPath = 'assets/legal/${type}.json';
      String jsonString = await DefaultAssetBundle.of(context).loadString(jsonPath);
      final Map<String, dynamic> data = json.decode(jsonString);
      
      final String url = type == 'terms_of_service' 
          ? 'https://duckbuck.in/terms' 
          : 'https://duckbuck.in/privacy';
      
      // Get screen metrics for responsive sizing
      final screenSize = MediaQuery.of(context).size; 
      final isSmallScreen = screenSize.width < 360;
      
      // Check if context is still valid
      if (!context.mounted) return;
      
      // Create a GlobalKey for the action button to ensure we have a valid context
      final GlobalKey buttonKey = GlobalKey();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext modalContext) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(
                      color: Colors.brown.shade200.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and close button
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['title'],
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.brown.shade800),
                            onPressed: () => Navigator.pop(modalContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last Updated: ${data['lastUpdated']}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.brown.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: data['sections'].length,
                          itemBuilder: (context, index) {
                            final section = data['sections'][index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section['title'],
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    section['content'],
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.brown.shade900,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Read Full Button
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          key: buttonKey,
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4A76A),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Close the modal first
                                Navigator.pop(modalContext);
                                
                                // Then attempt to launch URL
                                _launchBrowserUrl(url);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Read Full ${type == 'terms_of_service' ? 'Terms' : 'Privacy Policy'}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.open_in_new,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    } catch (e) {
      debugPrint("Error showing terms bottom sheet: $e");
    }
  }

  // Helper method to launch URLs
  Future<void> _launchBrowserUrl(String url) async {
    // Add a small delay to avoid animation controller errors
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      // Convert URL to URI
      final Uri uri = Uri.parse(url);
      
      // Different handling for Android vs iOS
      if (Platform.isAndroid) {
        // For Android: Try to explicitly use https scheme with fallbacks
        // This addresses the "component name null" issue
        final androidUrl = uri.toString();
        final httpsUrl = androidUrl.startsWith('https://') 
            ? androidUrl 
            : androidUrl.replaceFirst('http://', 'https://');
        
        debugPrint("Attempting to launch: $httpsUrl");
        
        // Try the Intent approach first for Chrome
        bool launched = await launchUrl(
          Uri.parse(httpsUrl),
          mode: LaunchMode.externalNonBrowserApplication,
        );
        
        // If that fails, try the universal link approach
        if (!launched) {
          launched = await launchUrl(
            Uri.parse(httpsUrl),
            mode: LaunchMode.externalApplication,
          );
        }
        
        // Last resort: try a generic browser fallback
        if (!launched) {
          final fallbackUri = Uri.parse('https://www.google.com');
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        }
      } else {
        // For iOS: standard approach works fine
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("Error launching URL: $e");
      
      // Try a last-resort approach with a common browser
      try {
        final fallbackUri = Uri.parse('https://www.google.com');
        await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Silently fail if even the fallback doesn't work
      }
    }
  }

  // Helper methods for new features
  void _contactSupport(BuildContext context) {
    // Show a dialog or navigate to support screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Text('For support, please email us at support@duckbuck.app'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showFAQs(BuildContext context) {
    // Show FAQs in a dialog or navigate to FAQs screen
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Frequently Asked Questions'),
        content: const Text('FAQs will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAppVersionInfo() {
    const version = '1.0.0';
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8C7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A76A).withOpacity(0.15),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE6C38D).withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.system_update,
              color: Color(0xFF8B4513),
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'App Version',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFF8B4513),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'v$version',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF8B4513).withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 