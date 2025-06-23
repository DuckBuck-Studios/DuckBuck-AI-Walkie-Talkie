import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/shared_friends_provider.dart';
import '../widgets/home_friends_section.dart';
import '../handlers/fullscreen_photo_handler.dart';
import '../../../core/navigation/app_routes.dart';
import 'dart:io' show Platform;

class HomeScreen extends StatefulWidget {
  final Function(Widget)? onShowFullscreenOverlay;
  final VoidCallback? onHideFullscreenOverlay;
  
  const HomeScreen({
    super.key,
    this.onShowFullscreenOverlay,
    this.onHideFullscreenOverlay,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late FullscreenPhotoHandler _photoHandler;

  @override
  void initState() {
    super.initState();
    
    // Initialize photo handler
    _photoHandler = FullscreenPhotoHandler(
      context: context,
      onShowFullscreenOverlay: widget.onShowFullscreenOverlay,
      onHideFullscreenOverlay: widget.onHideFullscreenOverlay,
    );
    
    // Initialize SharedFriendsProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharedFriendsProvider>().initialize();
    });
  }

  @override
  void dispose() {
    // Optimize memory when leaving home screen
    if (mounted) {
      context.read<SharedFriendsProvider>().optimizeMemory();
    }
    super.dispose();
  }

  void _handleFriendTap(Map<String, dynamic> friend) {
    _photoHandler.showPhotoViewer(friend);
  }

  void _handleAiAgentTap() {
    Navigator.pushNamed(context, AppRoutes.aiAgent);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SharedFriendsProvider>(
      builder: (context, friendsProvider, child) {
        final isIOS = Platform.isIOS;
        final theme = Theme.of(context);
        
        if (isIOS) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: const Text('Home'),
              automaticallyImplyLeading: false,
              backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
              border: null,
            ),
            backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
            child: SafeArea(
              child: HomeFriendsSection(
                friends: friendsProvider.friends, // Use real friends from SharedFriendsProvider
                isLoading: friendsProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
                onAiAgentTap: _handleAiAgentTap,
              ),
            ),
          );
        } else {
          return Scaffold(
            backgroundColor: theme.colorScheme.surface,
            appBar: AppBar(
              title: const Text('Home'),
              automaticallyImplyLeading: false,
              centerTitle: true,
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
            ),
            body: SafeArea(
              child: HomeFriendsSection(
                friends: friendsProvider.friends, // Use real friends from SharedFriendsProvider
                isLoading: friendsProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
                onAiAgentTap: _handleAiAgentTap,
              ),
            ),
          );
        }
      },
    );
  }
}
