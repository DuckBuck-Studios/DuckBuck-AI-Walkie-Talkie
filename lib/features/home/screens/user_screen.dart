import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:rive/rive.dart';
import 'dart:io' show Platform;
import 'dart:math';

import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/home_provider.dart';
import '../../friends/widgets/profile_avatar.dart';

class UserScreen extends StatefulWidget {
  final RelationshipModel relationship;
  final HomeProvider provider;

  const UserScreen({
    super.key,
    required this.relationship,
    required this.provider,
  });

  @override
  State<UserScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserScreen> {
  Artboard? _artboard;
  StateMachineController? _controller;
  SMITrigger? _startTrigger;
  SMITrigger? _idleTrigger;
  SMITrigger? _breakTrigger;
  int _currentState = 0; // 0: idle, 1: start, 2: break
  
  /// Generates a random 6-digit UID
  /// Returns a 6-digit integer between 100000 and 999999
  int _generateRandomUID() {
    final random = Random();
    return 100000 + random.nextInt(900000); // Generates number between 100000-999999
  }
  
  @override
  void initState() {
    super.initState();
    _loadRiveFile();
  }

  void _loadRiveFile() async {
    final data = await RiveFile.asset('assets/main_button.riv');
    final artboard = data.mainArtboard;
    
    var controller = StateMachineController.fromArtboard(
      artboard,
      'State Machine 1', // The name of your state machine
    );
    
    if (controller != null) {
      artboard.addController(controller);
      
      // Get triggers for all states
      _startTrigger = controller.findInput<bool>('Start') as SMITrigger?;
      _idleTrigger = controller.findInput<bool>('Idle') as SMITrigger?;
      _breakTrigger = controller.findInput<bool>('Break') as SMITrigger?;
    }
    
    setState(() {
      _artboard = artboard;
      _controller = controller;
    });
  }

  void _toggleState() {
    switch (_currentState) {
      case 0: // idle -> start
        _startTrigger?.fire();
        setState(() {
          _currentState = 1;
        });
        break;
      case 1: // start -> break
        _breakTrigger?.fire();
        setState(() {
          _currentState = 2;
        });
        break;
      case 2: // break -> idle
        _idleTrigger?.fire();
        setState(() {
          _currentState = 0;
        });
        break;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = widget.provider.getCachedProfile(widget.relationship, currentUserId);

    return Platform.isIOS ? _buildCupertinoPage(context, profile) : _buildMaterialPage(context, profile);
  }

  Widget _buildCupertinoPage(BuildContext context, CachedProfile? profile) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomPadding = screenHeight < 700 ? screenHeight * 0.03 : screenHeight * 0.05;
    
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildProfileHeader(context, profile, true),
            ),
            _buildRiveButton(context, true),
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialPage(BuildContext context, CachedProfile? profile) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final bottomPadding = screenHeight < 700 ? screenHeight * 0.03 : screenHeight * 0.05;
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _buildProfileHeader(context, profile, false),
            ),
            _buildRiveButton(context, false),
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, CachedProfile? profile, bool isIOS) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final screenWidth = mediaQuery.size.width;
    
    // More granular responsive sizing based on screen width
    double avatarRadius;
    double spacingHeight;
    double fontSize;
    double horizontalPadding;
    double topPadding;
    
    if (screenWidth <= 320) {
      // Very small devices (iPhone SE, older Android)
      avatarRadius = 45.0;
      spacingHeight = 12.0;
      fontSize = 20.0;
      horizontalPadding = screenWidth * 0.08;
      topPadding = screenHeight * 0.05;
    } else if (screenWidth <= 375) {
      // Small devices (iPhone 12 mini, iPhone SE 3rd gen)
      avatarRadius = 50.0;
      spacingHeight = 16.0;
      fontSize = 22.0;
      horizontalPadding = screenWidth * 0.1;
      topPadding = screenHeight * 0.08;
    } else if (screenWidth <= 414) {
      // Medium devices (iPhone 11, iPhone 12/13/14/15)
      avatarRadius = 55.0;
      spacingHeight = 18.0;
      fontSize = 24.0;
      horizontalPadding = screenWidth * 0.12;
      topPadding = screenHeight * 0.1;
    } else if (screenWidth <= 428) {
      // Larger phones (iPhone 12/13/14/15 Pro Max)
      avatarRadius = 60.0;
      spacingHeight = 20.0;
      fontSize = 26.0;
      horizontalPadding = screenWidth * 0.15;
      topPadding = screenHeight * 0.12;
    } else {
      // Tablets and very large devices
      avatarRadius = 70.0;
      spacingHeight = 24.0;
      fontSize = 30.0;
      horizontalPadding = screenWidth * 0.2;
      topPadding = screenHeight * 0.15;
    }
    
    // Adjust for screen height constraints
    if (screenHeight < 600) {
      avatarRadius *= 0.85;
      spacingHeight *= 0.75;
      fontSize *= 0.9;
      topPadding *= 0.5;
    } else if (screenHeight < 700) {
      avatarRadius *= 0.95;
      spacingHeight *= 0.9;
      fontSize *= 0.95;
      topPadding *= 0.8;
    }
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: topPadding * 0.1), // Further reduced top padding
            
            // Profile Avatar with responsive sizing
          ProfileAvatar(
            photoURL: profile?.photoURL,
            displayName: profile?.displayName ?? 'Unknown User',
            radius: avatarRadius,
          ),
          
          SizedBox(height: spacingHeight),
          
          // User Name with responsive typography and padding
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth > 428 ? screenWidth * 0.05 : 0,
            ),
            child: Text(
              profile?.displayName ?? 'Unknown User',
              style: isIOS 
                ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    letterSpacing: screenWidth > 428 ? 0.5 : 0,
                  )
                : Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSize,
                    letterSpacing: screenWidth > 428 ? 0.5 : 0,
                  ),
              textAlign: TextAlign.center,
              maxLines: screenWidth <= 320 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          // Flexible spacer to push content upward if needed
          SizedBox(height: topPadding),
        ],
      ),
    );
  }

  Widget _buildRiveButton(BuildContext context, bool isIOS) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    
    // Responsive button sizing - made bigger
    final buttonHeight = screenHeight < 700 ? 170.0 : 200.0;
    final horizontalPadding = screenWidth < 400 ? 30.0 : 40.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: GestureDetector(
        onTap: _toggleState,
        child: Container(
          height: buttonHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: _artboard == null
                ? const Center(child: CircularProgressIndicator())
                : Rive(artboard: _artboard!),
          ),
        ),
      ),
    );
  }
}
