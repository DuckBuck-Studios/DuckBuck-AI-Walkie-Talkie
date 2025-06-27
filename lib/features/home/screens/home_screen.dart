import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/shared_friends_provider.dart';
import '../widgets/home_friends_section.dart';
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
        _FriendPhotoOverlay(
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

/// Simple fullscreen friend photo overlay
class _FriendPhotoOverlay extends StatelessWidget {
  final Map<String, dynamic> friend;
  final VoidCallback onClose;
  
  const _FriendPhotoOverlay({
    required this.friend,
    required this.onClose,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black,
        child: Center(
          child: Hero(
            tag: 'friend_photo_${friend['displayName'] ?? 'Unknown User'}',
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Large friend photo
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey[800],
                  ),
                  child: ClipOval(
                    child: friend['photoURL'] != null
                        ? Image.network(
                            friend['photoURL'],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.person,
                                size: 150,
                                color: Colors.grey[400],
                              );
                            },
                          )
                        : Icon(
                            Icons.person,
                            size: 150,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
                const SizedBox(height: 24),
                // Friend name
                Text(
                  friend['displayName'] ?? 'Unknown User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                // Tap to close hint
                Text(
                  'Tap anywhere to close',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
