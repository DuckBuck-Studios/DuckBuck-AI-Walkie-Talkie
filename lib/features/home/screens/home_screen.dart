import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/home_provider.dart';
import '../widgets/home_friends_section.dart';
import 'user_profile_screen.dart';
import 'dart:io' show Platform;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => HomeProvider()..initialize(),
      child: const HomeScreenContent(),
    );
  }
}

class HomeScreenContent extends StatelessWidget {
  const HomeScreenContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, homeProvider, child) {
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: Platform.isIOS ? CupertinoColors.systemGroupedBackground.resolveFrom(context) : theme.colorScheme.background,
          appBar: Platform.isIOS ? null : AppBar(
            title: const Text('Home'),
            automaticallyImplyLeading: false,
            elevation: 0,
            backgroundColor: theme.colorScheme.background,
            centerTitle: true,
          ),
          body: Platform.isIOS ? _buildCupertinoBody(context, homeProvider) : _buildMaterialBody(context, homeProvider),
        );
      },
    );
  }

  Widget _buildCupertinoBody(BuildContext context, HomeProvider homeProvider) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Home'),
        automaticallyImplyLeading: false,
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: HomeFriendsSection(
            provider: homeProvider,
            onFriendTap: (context, relationship) {
              // Navigate to friend details or chat
              _showFriendDetails(context, relationship);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialBody(BuildContext context, HomeProvider homeProvider) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: HomeFriendsSection(
          provider: homeProvider,
          onFriendTap: (context, relationship) {
            // Navigate to friend details or chat
            _showFriendDetails(context, relationship);
          },
        ),
      ),
    );
  }

  void _showFriendDetails(BuildContext context, relationship) {
    final homeProvider = Provider.of<HomeProvider>(context, listen: false);
    
    if (Platform.isIOS) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (context) => UserProfileScreen(
            relationship: relationship,
            provider: homeProvider,
          ),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => UserProfileScreen(
            relationship: relationship,
            provider: homeProvider,
          ),
        ),
      );
    }
  }
}
