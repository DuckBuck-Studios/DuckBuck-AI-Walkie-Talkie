import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/home_friends_section.dart';
import '../handlers/fullscreen_photo_handler.dart'; 
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
    
    // Initialize HomeProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().initialize();
    });
  }

  void _handleFriendTap(Map<String, dynamic> friend) {
    _photoHandler.showPhotoViewer(friend);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
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
                friends: homeProvider.friends, // Use real friends from HomeProvider
                isLoading: homeProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
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
                friends: homeProvider.friends, // Use real friends from HomeProvider
                isLoading: homeProvider.isLoadingFriends, // Use real loading state
                onFriendTap: _handleFriendTap,
              ),
            ),
          );
        }
      },
    );
  }
}
