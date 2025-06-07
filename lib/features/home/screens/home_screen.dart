import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/home_friends_section.dart';
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
    // Initialize HomeProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeProvider>().initialize();
    });
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
                friends: homeProvider.friends,
                isLoading: homeProvider.isLoadingFriends, 
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
                friends: homeProvider.friends,
                isLoading: homeProvider.isLoadingFriends, 
              ),
            ),
          );
        }
      },
    );
  }
}
