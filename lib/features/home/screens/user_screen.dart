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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground,
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _buildProfileHeader(context, profile, true),
              ),
            ),
            _buildRiveButton(context, true),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialPage(BuildContext context, CachedProfile? profile) {
    final theme = Theme.of(context);
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
              child: Center(
                child: _buildProfileHeader(context, profile, false),
              ),
            ),
            _buildRiveButton(context, false),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, CachedProfile? profile, bool isIOS) {
    return Column(
      children: [
        // Large Profile Avatar at the top center
        ProfileAvatar(
          photoURL: profile?.photoURL,
          displayName: profile?.displayName ?? 'Unknown User',
          radius: 60,
        ),
        const SizedBox(height: 24),
        
        // User Name under the photo
        Text(
          profile?.displayName ?? 'Unknown User',
          style: isIOS 
            ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              )
            : Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildRiveButton(BuildContext context, bool isIOS) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40.0),
      child: GestureDetector(
        onTap: _toggleState,
        child: Container(
          height: 160,
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
