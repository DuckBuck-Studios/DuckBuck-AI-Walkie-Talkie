import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:rive/rive.dart';
import 'dart:io' show Platform;
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
    
    // Match responsive sizing with call_screen.dart
    double avatarRadius;
    double spacingHeight;
    double fontSize;
    double horizontalPadding;
    double topPadding;
    
    if (screenWidth <= 320) {
      avatarRadius = 60.0;
      spacingHeight = 16.0;
      fontSize = 22.0;
      horizontalPadding = screenWidth * 0.08;
      topPadding = screenHeight * 0.08;
    } else if (screenWidth <= 375) {
      avatarRadius = 70.0;
      spacingHeight = 20.0;
      fontSize = 24.0;
      horizontalPadding = screenWidth * 0.1;
      topPadding = screenHeight * 0.1;
    } else if (screenWidth <= 414) {
      avatarRadius = 80.0;
      spacingHeight = 24.0;
      fontSize = 26.0;
      horizontalPadding = screenWidth * 0.12;
      topPadding = screenHeight * 0.12;
    } else if (screenWidth <= 428) {
      avatarRadius = 90.0;
      spacingHeight = 28.0;
      fontSize = 28.0;
      horizontalPadding = screenWidth * 0.15;
      topPadding = screenHeight * 0.15;
    } else {
      avatarRadius = 100.0;
      spacingHeight = 32.0;
      fontSize = 32.0;
      horizontalPadding = screenWidth * 0.2;
      topPadding = screenHeight * 0.18;
    }
    
    // Adjust for screen height constraints
    if (screenHeight < 600) {
      avatarRadius *= 0.8;
      spacingHeight *= 0.7;
      fontSize *= 0.85;
      topPadding *= 0.5;
    } else if (screenHeight < 700) {
      avatarRadius *= 0.9;
      spacingHeight *= 0.85;
      fontSize *= 0.9;
      topPadding *= 0.7;
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Top section with profile info in same position as call_screen.dart
          Expanded(
            flex: 3,
            child: Container(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: topPadding * 0.3), // Same position as call_screen
                  
                  // Profile Avatar with same sizing as call_screen
                  ProfileAvatar(
                    photoURL: profile?.photoURL,
                    displayName: profile?.displayName ?? 'Unknown User',
                    radius: avatarRadius,
                  ),
                  
                  SizedBox(height: spacingHeight),
                  
                  // User Name with same styling and position as call_screen
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
                        : TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: fontSize,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            letterSpacing: screenWidth > 428 ? 0.5 : 0,
                          ),
                      textAlign: TextAlign.center,
                      maxLines: screenWidth <= 320 ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
