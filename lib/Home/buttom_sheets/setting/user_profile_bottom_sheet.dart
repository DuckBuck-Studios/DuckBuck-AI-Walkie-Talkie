import 'package:duckbuck/Home/buttom_sheets/setting/404.dart';
import 'package:duckbuck/Home/buttom_sheets/setting/edit_profile.dart';
import 'package:duckbuck/Home/buttom_sheets/setting/legal.dart';
import 'package:duckbuck/Home/buttom_sheets/setting/feedback_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:duckbuck/Home/providers/UserProvider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserProfileBottomSheet extends StatefulWidget {
  const UserProfileBottomSheet({Key? key}) : super(key: key);

  @override
  _UserProfileBottomSheetState createState() => _UserProfileBottomSheetState();
}

class _UserProfileBottomSheetState extends State<UserProfileBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  String _version = '';
  bool _hasAnimated = false; // Flag to track if animation has run

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _getAppVersion();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));

    if (!_hasAnimated) {
      _animationController.forward();
      setState(() {});
    }
  }

  Future<void> _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _version = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  void _showBottomSheet(BuildContext context, String type) {
    _triggerHapticFeedback();

    // We'll implement these bottom sheets next
    switch (type) {
      case 'edit_profile':
        showModalBottomSheet(
          context: context,
          builder: (context) => const EditProfileSheet(),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
        );
        break;
      case 'legal':
        showModalBottomSheet(
          context: context,
          builder: (context) => const LegalSheet(),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
        );
        break;
      case 'feedback':
        showModalBottomSheet(
          context: context,
          builder: (context) => const FeedbackSheet(),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
        );
        break;
      case 'danger':
        showModalBottomSheet(
          context: context,
          builder: (context) => const ErrorSheet(),
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
        );
        break;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _triggerHapticFeedback() {
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final String userName = userProvider.name; // Get name from provider
    final String userImage = userProvider.photoURL;

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle with Shadow
              Container(
                width: 50,
                height: 6,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),

              // Profile Section
              _buildProfileSection(userName, userImage),

              const SizedBox(height: 16),
              Text(
                userName,
                style: const TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),

              const SizedBox(height: 40),

              // Fixed Options Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildProfileOption(
                      icon: Icons.edit,
                      text: 'Edit Profile',
                      color: Colors.blue,
                      onTap: () => _showBottomSheet(context, 'edit_profile'),
                      delay: 0,
                    ),
                    _buildProfileOption(
                      icon: Icons.shield,
                      text: 'Legal',
                      color: Colors.green,
                      onTap: () => _showBottomSheet(context, 'legal'),
                      delay: 100,
                    ),
                    _buildProfileOption(
                      icon: Icons.favorite,
                      text: 'Send Feedback',
                      color: Colors.red,
                      onTap: () => _showBottomSheet(context, 'feedback'),
                      delay: 200,
                    ),
                    _buildProfileOption(
                      icon: Icons.dangerous,
                      text: 'Danger Zone',
                      color: Colors.purple,
                      onTap: () => _showBottomSheet(context, 'danger'),
                      delay: 300,
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // App Info Section
              Container(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'DuckBuck',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version $_version',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(String userName, String userImage) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Hero(
        tag: 'profile-picture',
        child: Animate(
          effects: [
            FadeEffect(
              duration: 600.ms,
              curve: Curves.easeOut,
            ),
            ScaleEffect(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1, 1),
              duration: 600.ms,
              curve: Curves.easeOutExpo,
            ),
          ],
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  spreadRadius: 5,
                  blurRadius: 15,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 60,
              backgroundImage:
                  userImage.isNotEmpty ? NetworkImage(userImage) : null,
              backgroundColor: Colors.white12,
              child: userImage.isEmpty
                  ? Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white.withOpacity(0.7),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileOption({
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
          delay: Duration(milliseconds: delay),
          duration: 600.ms,
          curve: Curves.easeOutExpo,
        ),
        FadeEffect(
          begin: 0,
          end: 1,
          delay: Duration(milliseconds: delay),
          duration: 500.ms,
          curve: Curves.easeOut,
        ),
      ],
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
