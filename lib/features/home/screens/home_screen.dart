import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/shared_friends_provider.dart';
import '../widgets/home_friends_section.dart';
import '../widgets/friend_photo_overlay.dart';
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

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    
    // Initialize SharedFriendsProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SharedFriendsProvider>().initialize();
    });
  }

  void _handleFriendTap(Map<String, dynamic> friend) {
    // Show friend photo in fullscreen overlay
    if (widget.onShowFullscreenOverlay != null) {
      widget.onShowFullscreenOverlay!(
        FriendPhotoOverlay(
          friend: friend,
          onClose: () => widget.onHideFullscreenOverlay?.call(),
        ),
      );
    }
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
