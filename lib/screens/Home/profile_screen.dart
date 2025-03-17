import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../providers/auth_provider.dart' as auth;
import '../../providers/user_provider.dart';
import '../../widgets/animated_background.dart';
import '../../models/user_model.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _showQRCode(BuildContext context, UserModel userModel) {
    final qrData = userModel.uid;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B4513).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Your Profile QR Code',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B4513),
                ),
              ).animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: -0.2, end: 0),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 15,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF8B4513),
                ),
              ).animate()
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                  curve: Curves.easeOutBack,
                ),
              const SizedBox(height: 24),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Color(0xFF8B4513)),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513).withOpacity(0.1),
                  padding: const EdgeInsets.all(12),
                ),
              ).animate()
                .fadeIn(duration: 600.ms)
                .scale(
                  begin: const Offset(0.5, 0.5),
                  end: const Offset(1.0, 1.0),
                  duration: 600.ms,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userModel = Provider.of<auth.AuthProvider>(context).userModel;
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        opacity: 0.03,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Top Bar with back button and title only
                _buildTopBar(context)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
                
                const SizedBox(height: 30),
                
                // Profile Photo Section
                _buildProfilePhoto(userModel)
                    .animate()
                    .scale(
                      delay: 200.ms,
                      duration: 600.ms,
                      begin: const Offset(0.8, 0.8),
                      end: const Offset(1.0, 1.0),
                      curve: Curves.easeOutBack,
                    ),
                
                const SizedBox(height: 24),
                
                // QR and Settings buttons
                _buildActionButtons(context, userModel)
                    .animate()
                    .fadeIn(delay: 300.ms, duration: 400.ms)
                    .slideY(begin: 0.3, end: 0, curve: Curves.easeOut),
                
                const SizedBox(height: 24),
                
                // User Info Cards with stacked animation
                _buildInfoSection(userModel),
                
                const SizedBox(height: 30),
                
                // Logout Button with bounce animation
                _buildLogoutButton(context)
                    .animate()
                    .fadeIn(delay: 900.ms)
                    .scaleXY(
                      begin: 0.5,
                      end: 1.0,
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
          color: const Color(0xFFD4A76A),
        ),
        const Expanded(
          child: Text(
            'Profile',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFD4A76A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, UserModel? userModel) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // QR Code button
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD4A76A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            iconSize: 28,
            icon: const Icon(Icons.qr_code),
            onPressed: () {
              if (userModel != null) {
                _showQRCode(context, userModel);
              }
            },
            color: const Color(0xFFD4A76A),
          ),
        ),
        const SizedBox(width: 20),
        // Settings button
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFD4A76A).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            iconSize: 28,
            icon: const Icon(Icons.settings),
            onPressed: () {
              if (userModel != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              }
            },
            color: const Color(0xFFD4A76A),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePhoto(UserModel? userModel) {
    return Column(
      children: [
        Hero(
          tag: 'profile-photo',
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4A76A),
                width: 3,
              ),
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
              child: userModel?.photoURL != null
                  ? Image.network(
                      userModel!.photoURL!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.person, size: 60, color: Color(0xFFD4A76A)),
                    )
                  : const Icon(Icons.person, size: 60, color: Color(0xFFD4A76A)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userModel?.displayName ?? 'User',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        if (userModel?.email != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              userModel!.email,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoSection(UserModel? userModel) {
    // Create a list of info cards to animate
    final infoCards = [
      _buildInfoCard(
        'Email',
        userModel?.email ?? 'Not provided',
        Icons.email,
      ),
      _buildInfoCard(
        'Phone',
        userModel?.phoneNumber ?? 'Not provided',
        Icons.phone,
      ),
      if (userModel?.dateOfBirth != null)
        _buildInfoCard(
          'Age',
          '${userModel!.age} years',
          Icons.cake,
        ),
      if (userModel?.gender != null)
        _buildInfoCard(
          'Gender',
          _formatGender(userModel!.gender.toString().split('.').last),
          Icons.person_outline,
        ),
      _buildInfoCard(
        'Member Since',
        _formatDate(userModel?.createdAt.toDate()),
        Icons.calendar_today,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8.0, bottom: 12.0),
          child: Text(
            'Personal Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF555555),
            ),
          ),
        ),
        ...infoCards.asMap().entries.map((entry) {
          final index = entry.key;
          final card = entry.value;
          return card.animate()
            .fadeIn(delay: Duration(milliseconds: 200 + (index * 100)))
            .slideY(
              begin: 0.5, 
              end: 0,
              duration: 600.ms,
              curve: Curves.easeOutQuad,
              delay: Duration(milliseconds: 200 + (index * 100)),
            );
        }).toList(),
      ],
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4A76A).withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4A76A).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: const Color(0xFFD4A76A),
              size: 24,
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
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        Provider.of<auth.AuthProvider>(context, listen: false).signOut();
      },
      icon: const Icon(Icons.logout),
      label: const Text('Sign Out'),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFD4A76A),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 3,
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