 import 'package:flutter/material.dart'; 
import 'package:provider/provider.dart';  
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../app/providers/auth_provider.dart' as auth;
import '../../app/providers/user_provider.dart';
import '../../app/models/user_model.dart'; 
import '../../app/widgets/animated_background.dart';

class ProfileScreen extends StatefulWidget {
  final Function(BuildContext)? onBackPressed;
  
  const ProfileScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer2<UserProvider, auth.AuthProvider>(
      builder: (context, userProvider, authProvider, child) {
        // Use data from authProvider as the primary source
        final userModel = authProvider.userModel ?? userProvider.currentUser;
        
        if (userModel == null) {
          // If still no user data, show a loading state
          return Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: _buildAppBar(),
            body: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFD4A76A),
              ),
            ),
          );
        }
        
        // Attempt to refresh user data in the background
        WidgetsBinding.instance.addPostFrameCallback((_) {
          userProvider.refreshUserData();
        });
        
        return Scaffold(
          backgroundColor: Colors.transparent,
          extendBodyBehindAppBar: true,
          appBar: _buildAppBar(),
          body: DuckBuckAnimatedBackground(
            opacity: 0.04,
            child: SafeArea(
              child: RefreshIndicator(
                color: const Color(0xFFD4A76A),
                onRefresh: () async {
                  try {
                    await userProvider.refreshUserData();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Failed to refresh. Check your connection.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 30),
                      _buildProfilePhoto(userModel),
                      const SizedBox(height: 24),
                      _buildInfoSection(userModel),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: const Text(
        'My Profile',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Color(0xFF8B4513),
        ),
      ),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF8B4513)),
        onPressed: () {
          if (widget.onBackPressed != null) {
            widget.onBackPressed!(context);
          } else {
            Navigator.of(context).pop();
          }
        },
        splashRadius: 24,
      ),
    );
  }

  Widget _buildProfilePhoto(UserModel userModel) {
    return Column(
      children: [
        Hero(
          tag: 'profile-photo',
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD4A76A), width: 3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A76A).withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(60),
              child: userModel.photoURL != null
                ? CachedNetworkImage(
                    imageUrl: userModel.photoURL!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: const Color(0xFFE6C38D).withOpacity(0.3),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(Color(0xFF8B4513)),
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildDefaultAvatar(),
                  )
                : _buildDefaultAvatar(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userModel.displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        if (userModel.email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              userModel.email,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF8B4513).withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFFE6C38D).withOpacity(0.3),
      child: const Icon(
        Icons.person,
        size: 60,
        color: Color(0xFF8B4513),
      ),
    );
  }

  Widget _buildInfoSection(UserModel userModel) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8C7),
        borderRadius: BorderRadius.circular(16),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Color(0xFF8B4513),
                  size: 20,
                ),
                SizedBox(width: 8),
                Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF8B4513),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: const Color(0xFFD4A76A).withOpacity(0.3)),
          _buildInfoCard('Email', userModel.email, Icons.email),
          _buildInfoCard('Phone', userModel.phoneNumber ?? 'Not provided', Icons.phone),
          if (userModel.dateOfBirth != null)
            _buildInfoCard('Age', '${userModel.age} years', Icons.cake),
          if (userModel.gender != null)
            _buildInfoCard(
              'Gender', 
              _formatGender(userModel.gender.toString().split('.').last),
              Icons.person_outline
            ),
          _buildInfoCard(
            'Member Since',
            _formatDate(userModel.createdAt.toDate()),
            Icons.calendar_today
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9F0),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A76A).withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE6C38D).withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF8B4513),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF8B4513).withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF8B4513),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Unknown';
    
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

