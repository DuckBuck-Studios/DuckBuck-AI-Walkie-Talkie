import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math; 
import '../../../providers/auth_provider.dart' as auth;
import '../../../providers/user_provider.dart';
import '../../../models/user_model.dart';
import '../../../widgets/animated_background.dart';
import '../../../widgets/phone_auth_popup.dart';
import '../../Authentication/welcome_screen.dart';
import 'blocked_users_screen.dart'; 
import 'package:url_launcher/url_launcher.dart'; 
import 'dart:convert'; 

// Create a global key for Navigator state to use in background operations
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller for transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
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
    
    return WillPopScope(
      onWillPop: () async {
        _animateBackToProfile(context);
        return false;
      },
      child: Scaffold(
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
            onPressed: () => _animateBackToProfile(context),
          ),
        ),
        body: DuckBuckAnimatedBackground(
          opacity: 0.03,
          child: SafeArea(
            child: _buildSettingsContent(context, userModel),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms),
    );
  }

  // Custom back navigation with simple pop - will use the same animation as other screens
  void _animateBackToProfile(BuildContext context) {
    // Simple navigation without animation - the transition is handled by
    // the PageRouteBuilder in home_screen.dart with a fixed animation style
    Navigator.of(context).pop();
  }

  // Navigate to Blocked Users screen with liquid transition
  void _navigateToBlockedUsers(BuildContext context) {
    // Use a fixed position for transition
    final screenSize = MediaQuery.of(context).size;
    final Offset centerOffset = Offset(screenSize.width * 0.85, screenSize.height * 0.5);
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => 
          BlockedUsersScreen(
            onBackPressed: (ctx) => Navigator.of(ctx).pop(),
          ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Value between 0.0 and 1.0
          final value = animation.value;
          
          // For forward transitions (going to blocked users)
          if (animation.status == AnimationStatus.forward || 
              animation.status == AnimationStatus.completed) {
            return Stack(
              children: [
                // The liquid reveal animation
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SimplifiedLiquidPainter(
                      progress: value,
                      fillColor: const Color(0xFFF5E8C7),
                      centerOffset: centerOffset,
                    ),
                  ),
                ),
                // Fade in the actual screen content
                Opacity(
                  opacity: value,
                  child: child,
                ),
              ],
            );
          } 
          // For reverse transitions (going back to settings)
          else {
            return Stack(
              children: [
                // The settings screen background (already visible underneath)
                
                // Blocked users screen with circular hole
                ClipPath(
                  clipper: _HoleClipper(
                    progress: 1.0 - value, // Inverted progress for growing hole
                    centerOffset: centerOffset,
                  ),
                  child: child, // Blocked users screen
                ),
                
                // Wave effects around the hole edge
                if (value > 0.1 && value < 0.9)
                  IgnorePointer(
                    child: CustomPaint(
                      painter: _HoleEdgeEffectPainter(
                        progress: 1.0 - value, // Inverted progress for growing hole
                        color: const Color(0xFFD4A76A).withOpacity(0.3),
                        centerOffset: centerOffset,
                      ),
                    ),
                  ),
              ],
            );
          }
        },
        transitionDuration: const Duration(milliseconds: 700),
        reverseTransitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  // Show delete account confirmation dialog
  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFF5E8C7),
        title: const Text(
          'Delete Account',
          style: TextStyle(
            color: Color(0xFF8B4513), 
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Are you sure you want to delete your account?',
              style: TextStyle(color: Color(0xFF8B4513)),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone. All your data will be permanently deleted, including:',
              style: TextStyle(color: Color(0xFF8B4513)),
            ),
            const SizedBox(height: 8),
            _buildDeleteWarningItem('Your profile information'),
            _buildDeleteWarningItem('All friend connections'),
            _buildDeleteWarningItem('Any messages you\'ve sent'),
            _buildDeleteWarningItem('Your blocked users list'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => _deleteAccount(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    );
  }
  
  // Delete account helper method
  Future<void> _deleteAccount(BuildContext context) async {
    // Close the confirmation dialog
    Navigator.of(context).pop();
    
    // First navigate to WelcomeScreen immediately
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => const WelcomeScreen(accountDeleted: true),
      ),
      (route) => false, // Remove all existing routes from stack
    );
    
    // Now perform the actual account deletion in the background
    try {
      // Get the UserProvider using the saved NavigatorKey context
      if (navigatorKey.currentContext != null) {
        final userProvider = Provider.of<UserProvider>(
          navigatorKey.currentContext!, 
          listen: false
        );
        
        // Attempt to delete the account
        await userProvider.deleteAccount();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting account after navigation: $e');
      }
    }
  }
  
  // Helper method to build warning list items
  Widget _buildDeleteWarningItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: Colors.red.shade800,
              ),
            ),
          ),
        ],
      ),
    );
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
              onTap: () => _navigateToBlockedUsers(context),
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
          
        const SizedBox(height: 24),
        
        // Danger Zone Section
        _buildSettingSection(
          title: 'Danger Zone',
          icon: Icons.warning_amber_rounded,
          children: [
            _buildDangerOption(
              context: context,
              title: 'Delete Account',
              subtitle: 'Permanently delete your account and all data',
              icon: Icons.delete_forever,
              onTap: () => _showDeleteAccountDialog(context),
              delay: 0,
            ),
          ],
          delay: 0,
        ).animate(autoPlay: true)
          .fadeIn(duration: 300.ms, delay: 600.ms)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOutQuad),
        
        const SizedBox(height: 32),
      ],
    );
  }

  // Danger option with red styling
  Widget _buildDangerOption({
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
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.15),
                blurRadius: 8,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: Colors.red.shade200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Colors.red.shade700,
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
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.red.shade800,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.red.shade700.withOpacity(0.7),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.red.shade300,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    ).animate(autoPlay: true)
    .fadeIn(delay: (delay * 1.0).ms)
    .slideY(begin: 0.2, end: 0, delay: (delay * 1.0).ms);
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
            .fadeIn(delay: (100 * index * 1.0).ms)
            .slideX(
              begin: 0.1,
              end: 0,
              delay: (100 * index * 1.0).ms,
              duration: 400.ms,
              curve: Curves.easeOutCubic,
            );
        }),
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



  void _showPhoneAuthDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => PhoneAuthPopup(
        onSubmit: (phoneNumber) {
          final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
          authProvider.updateUserProfile(
            metadata: {'phoneNumber': phoneNumber},
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

  // Helper method to show legal documents
  void _showLegalBottomSheet(BuildContext context, String type) async {
    try {
      // Load legal content
      final String jsonPath = 'assets/legal/$type.json';
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

// Simplified liquid painter for transitions
class _SimplifiedLiquidPainter extends CustomPainter {
  final double progress;
  final Color fillColor;
  final Offset centerOffset;

  _SimplifiedLiquidPainter({
    required this.progress,
    required this.fillColor,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;
    
    final paint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    
    final path = Path()
      ..addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    canvas.drawPath(path, paint);
    
    if (progress > 0.1 && progress < 0.9) {
      final wavePaint = Paint()
        ..color = fillColor.withOpacity(0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8.0;
      
      final wavePath = Path();
      final waveRadius = radius + 15 * math.sin(progress * math.pi * 2);
      wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
      
      canvas.drawPath(wavePath, wavePaint);
    }
  }

  @override
  bool shouldRepaint(_SimplifiedLiquidPainter oldDelegate) => progress != oldDelegate.progress;
}

// Hole clipper for creating circular hole transition
class _HoleClipper extends CustomClipper<Path> {
  final double progress;
  final Offset centerOffset;

  _HoleClipper({
    required this.progress,
    required this.centerOffset,
  });

  @override
  Path getClip(Size size) {
    final path = Path();
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final radius = maxRadius * progress;
    
    // Start with entire screen
    path.addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    
    // Cut out circle
    path.addOval(Rect.fromCircle(center: centerOffset, radius: radius));
    
    // Use evenOdd to make the circle a hole
    path.fillType = PathFillType.evenOdd;
    
    return path;
  }

  @override
  bool shouldReclip(_HoleClipper oldClipper) => 
    progress != oldClipper.progress || centerOffset != oldClipper.centerOffset;
}

// Edge effect painter for liquid transitions
class _HoleEdgeEffectPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Offset centerOffset;

  _HoleEdgeEffectPainter({
    required this.progress,
    required this.color,
    required this.centerOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maxRadius = math.sqrt(size.width * size.width + size.height * size.height);
    final baseRadius = maxRadius * progress;
    
    // Primary wave
    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    
    final wavePath = Path();
    final waveRadius = baseRadius + 12 * math.sin(progress * math.pi * 2);
    wavePath.addOval(Rect.fromCircle(center: centerOffset, radius: waveRadius));
    canvas.drawPath(wavePath, wavePaint);
    
    // Secondary wave
    if (progress > 0.3) {
      final wave2Paint = Paint()
        ..color = color.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      
      final wave2Path = Path();
      final wave2Radius = baseRadius + 24 * math.sin(progress * math.pi * 1.5);
      wave2Path.addOval(Rect.fromCircle(center: centerOffset, radius: wave2Radius));
      canvas.drawPath(wave2Path, wave2Paint);
    }
  }

  @override
  bool shouldRepaint(_HoleEdgeEffectPainter oldDelegate) => 
    progress != oldDelegate.progress;
} 