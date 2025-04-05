import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart'; 
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart'; 
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lottie/lottie.dart'; 
import '../../providers/auth_provider.dart' as auth;
import '../../providers/user_provider.dart';
import '../../models/user_model.dart';
import '../../services/user_service.dart';
import 'setting/settings_screen.dart';
import '../Authentication/welcome_screen.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  final Function(BuildContext)? onBackPressed;
  
  const ProfileScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  final GlobalKey _qrKey = GlobalKey();
  bool _isConnected = true;
  bool _isCheckingConnectivity = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    
    // Initialize animation controller for transitions
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    
    try {
      // Simple connectivity check by trying to get data
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      final success = await userProvider.refreshUserData();
      setState(() => _isConnected = success);
    } catch (e) {
      setState(() => _isConnected = false);
      print('Connectivity error: $e');
    } finally {
    }
  }

  Future<void> _captureAndShareQR() async {
    try {
      // Capture QR code image
      RenderRepaintBoundary boundary = _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/duckbuck_qr_code.png').create();
        await file.writeAsBytes(pngBytes);
        
        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Add me on DuckBuck!',
          subject: 'DuckBuck Profile QR Code'
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing QR code: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showQRCode(BuildContext context, UserModel userModel) {
    // Use UserService to get the Firebase Auth UID (document ID)
    final userService = UserService();
    final userId = userService.currentUserId ?? '';
    
    // Make sure we have a valid Firebase Auth UID 
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate QR code. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Encrypt user ID for QR code
    final qrData = _encryptUserId(userId);
    
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final screenWidth = MediaQuery.of(context).size.width;
    
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.05,
          vertical: 24,
        ),
        child: SingleChildScrollView(
          child: Container(
            width: screenWidth * 0.9,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E8C7),
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
                // Header
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.qr_code,
                        color: Color(0xFF8B4513),
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Your DuckBuck QR Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Share this code with friends to connect',
                    style: TextStyle(
                      fontSize: 14,
                      color: const Color(0xFF8B4513).withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                // QR code
                RepaintBoundary(
                  key: _qrKey,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9F0),
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
                    // Adjust QR size based on screen width and text scale factor
                    child: QrImageView(
                      data: qrData,
                      version: QrVersions.auto,
                      size: textScaleFactor > 1.3 ? 
                        180 / (textScaleFactor > 1.5 ? 1.5 : textScaleFactor) : 
                        200,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF8B4513),
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFFD4A76A),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF8B4513),
                      ),
                      embeddedImage: const AssetImage('assets/app_logo.png'),
                      embeddedImageStyle: QrEmbeddedImageStyle(
                        size: Size(textScaleFactor > 1.3 ? 30 : 40, textScaleFactor > 1.3 ? 30 : 40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Buttons
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Share button on top
                    SizedBox(
                      width: double.infinity, // Make button full width
                      child: ElevatedButton.icon(
                        onPressed: () => _captureAndShareQR(),
                        icon: const Icon(Icons.share, size: 18),
                        label: const Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4A76A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Close button at the bottom
                    SizedBox(
                      width: double.infinity, // Make button full width
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B4513),
                          side: const BorderSide(color: Color(0xFFE6C38D), width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Encrypt the user ID for QR code
  String _encryptUserId(String userId) {
    // Create a prefix to identify our app's QR codes
    const prefix = "DBK:";
    
    // Add a simple timestamp to make each QR code unique
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Combine data
    final dataToEncrypt = "$userId:$timestamp";
    
    // Create a SHA-256 hash as a signature
    final key = 'DuckBuckSecretKey';
    final hmacSha256 = Hmac(sha256, utf8.encode(key));
    final digest = hmacSha256.convert(utf8.encode(dataToEncrypt));
    final signature = digest.toString().substring(0, 8); // Use first 8 chars of hash
    
    // Combine all parts with the signature
    final combinedData = "$prefix$dataToEncrypt:$signature";
    
    // Encode in base64 for compactness
    return base64Encode(utf8.encode(combinedData));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, child) {
        final userModel = userProvider.currentUser;
        
        return Scaffold(
          backgroundColor: Colors.white.withOpacity(0.95),
          extendBodyBehindAppBar: true,
          appBar: AppBar(
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
                print("BACK BUTTON PRESSED");
                // Handle the back navigation with animation
                _animateBackToHome(context);
              },
              splashRadius: 24,
            ),
          ),
          body: _isConnected 
              ? Container(
                  // Plain container instead of DuckBuckAnimatedBackground
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFF5E8C7),
                        Color(0xFFE6C38D),
                      ],
                      stops: [0.5, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    child: RefreshIndicator(
                      color: const Color(0xFFD4A76A),
                      onRefresh: () async {
                        try {
                          await userProvider.refreshUserData();
                        } catch (e) {
                          print('Error refreshing: $e');
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
                            
                            // Profile Photo Section
                            _buildProfilePhoto(userModel),
                            
                            const SizedBox(height: 24),
                            
                            // QR and Settings buttons
                            _buildActionButtons(context, userModel),
                            
                            const SizedBox(height: 24),
                            
                            // User Info Cards
                            _buildInfoSection(userModel),
                            
                            const SizedBox(height: 30),
                            
                            // Logout Button
                            _buildLogoutButton(context),
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
              : _buildNoConnectionView(),
        );
      },
    );
  }

  Widget _buildNoConnectionView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading.json',
            width: 150,
            height: 150,
          ),
          const SizedBox(height: 24),
          const Text(
            'No Internet Connection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B4513),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Check your connection and try again',
            style: TextStyle(
              fontSize: 16,
              color: const Color(0xFF8B4513).withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _checkConnectivity,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A76A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, UserModel? userModel) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // QR Code Button - using ElevatedButton
          ElevatedButton(
            onPressed: () {
              print("QR CODE BUTTON PRESSED");
              if (userModel != null) {
                HapticFeedback.selectionClick();
                _showQRCode(context, userModel);
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: const Color(0xFF8B4513),
              backgroundColor: const Color(0xFFE6C38D),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5, // Higher elevation for better visual cue
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.qr_code,
                  color: Color(0xFF8B4513),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'QR Code',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B4513),
                  ),
                ),
              ],
            ),
          ),
          
          // Settings Button - using ElevatedButton
          ElevatedButton(
            onPressed: () {
              print("SETTINGS BUTTON PRESSED");
              if (userModel != null) {
                HapticFeedback.selectionClick();
                // Replace direct navigation with liquid transition
                _navigateToSettings(context);
              }
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: const Color(0xFF8B4513),
              backgroundColor: const Color(0xFFE6C38D),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 5, // Higher elevation for better visual cue
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.settings,
                  color: Color(0xFF8B4513),
                  size: 32,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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

  Widget _buildProfilePhoto(UserModel? userModel) {
    return Column(
      children: [
        Hero(
          tag: 'profile-photo',
          child: Material(
            color: Colors.transparent,
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
                    ? CachedNetworkImage(
                        imageUrl: userModel!.photoURL!,
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
                        errorWidget: (context, url, error) => Container(
                          color: const Color(0xFFE6C38D).withOpacity(0.3),
                          child: const Icon(Icons.person, size: 60, color: Color(0xFF8B4513)),
                        ),
                      )
                    : Container(
                        color: const Color(0xFFE6C38D).withOpacity(0.3),
                        child: const Icon(Icons.person, size: 60, color: Color(0xFF8B4513)),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userModel?.displayName ?? 'User',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        if (userModel?.email != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              userModel!.email,
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

  Widget _buildInfoSection(UserModel? userModel) {
    // Create a list of info cards without animations
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF8B4513),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
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
          // Using normal list instead of animations on iOS
          ...infoCards,
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

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () async {
          try {
            // Show loading indicator
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4A76A)),
                ),
              ),
            );
  
            // Get the providers
            final userProvider = Provider.of<UserProvider>(context, listen: false);
            final authProvider = Provider.of<auth.AuthProvider>(context, listen: false);
            
            // Set user as offline and clear FCM token
            await userProvider.logout();
            
            // Sign out from Firebase Auth
            await authProvider.signOut();
  
            // Close loading dialog
            if (context.mounted) {
              Navigator.of(context).pop();
            }
  
            // Force navigation to welcome screen with logged out flag
            if (context.mounted) {
              // Clear the entire navigation stack and push welcome screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const WelcomeScreen(loggedOut: true)),
                (route) => false,
              );
            }
          } catch (e) {
            // Close loading dialog if it's still showing
            if (context.mounted) {
              Navigator.of(context).pop();
            }
  
            // Show error message
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error signing out: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        icon: const Icon(Icons.logout),
        label: const Text('Sign Out'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4A76A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 3,
        ),
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

  void _animateBackToHome(BuildContext context) {
    print("Starting back animation");
    // Simple and clean pop that will trigger the reverse animation in the PageRouteBuilder
    if (widget.onBackPressed != null) {
      widget.onBackPressed!(context);
    } else {
      Navigator.of(context).pop();
    }
  }
  
  // Add method for settings navigation with liquid transition
  void _navigateToSettings(BuildContext context) {
    // Use a fixed position for the settings transition
    // This avoids the ripple effect from where the user taps
    final screenSize = MediaQuery.of(context).size;
    final Offset centerOffset = Offset(screenSize.width * 0.85, screenSize.height * 0.15);
    
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Value between 0.0 and 1.0
          final value = animation.value;
          
          // For forward transitions (going to settings)
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
          // For reverse transitions (going back to profile)
          else {
            return Stack(
              children: [
                // The profile screen background (already visible underneath)
                
                // Settings screen with circular hole
                ClipPath(
                  clipper: _HoleClipper(
                    progress: 1.0 - value, // Inverted progress for growing hole
                    centerOffset: centerOffset,
                  ),
                  child: child, // Settings screen
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
}

// Simplified liquid painter for settings transition
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

// Hole clipper for settings transition
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

// Edge effect painter for settings transition
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

