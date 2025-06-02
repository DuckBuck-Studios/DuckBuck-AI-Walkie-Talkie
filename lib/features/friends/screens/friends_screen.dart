import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

import '../../../core/models/relationship_model.dart';
import '../providers/friends_provider.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/add_friend_dialog.dart';
import '../widgets/remove_friend_dialog.dart';
import '../widgets/sections/friends_section.dart';
import '../widgets/sections/pending_section.dart';
import '../widgets/friend_tile.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  // For Material TabBar
  TabController? _materialTabController;
  // For CupertinoSegmentedControl and general tab tracking
  int _currentSegment = 0; 

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) {
      _materialTabController = TabController(length: 2, vsync: this);
      _materialTabController!.addListener(() {
        if (!_materialTabController!.indexIsChanging) {
          setState(() {
            _currentSegment = _materialTabController!.index;
          });
        }
      });
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().initialize();
    });
  }
  
  @override
  void dispose() {
    _materialTabController?.dispose();
    super.dispose();
  }

  void _showAddFriendDialog(BuildContext context) {
    final provider = Provider.of<FriendsProvider>(context, listen: false);
    AddFriendDialog.show(context, provider);
  }

  void _showRemoveFriendDialog(BuildContext context, RelationshipModel relationship) {
    final provider = Provider.of<FriendsProvider>(context, listen: false);
    RemoveFriendDialog.show(context, relationship, provider);
  }

  void _showBlockUserDialog(BuildContext context, RelationshipModel relationship) {
    final provider = Provider.of<FriendsProvider>(context, listen: false);
    FriendsSection.showBlockFriendDialog(context, relationship, provider);
  }

  void _copyUserIdToClipboard(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final uid = authService.currentUser?.uid;
    
    if (uid != null) {
      Clipboard.setData(ClipboardData(text: uid));
      
      // Show confirmation based on platform
      if (Platform.isIOS) {
        showCupertinoDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('ID Copied'),
            content: const Text('Your user ID has been copied to clipboard.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                child: const Text('OK'),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildFriendsList(BuildContext context, FriendsProvider provider) {
    return FriendsSection(
      provider: provider,
      showRemoveFriendDialog: _showRemoveFriendDialog,
      showBlockUserDialog: _showBlockUserDialog, // Pass the block user dialog handler
    );
  }

  Widget _buildPendingList(BuildContext context, FriendsProvider provider) {
    return PendingSection(provider: provider);
  }

  // Get the current user ID
  String? _getUserId() {
    final authService = serviceLocator<AuthServiceInterface>();
    return authService.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildCupertinoPage(context) : _buildMaterialPage(context);
  }

  Widget _buildMaterialPage(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          'Friends',
          style: TextStyle(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [],
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: theme.colorScheme.background,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildMaterialTabBar(context, theme),
        ),
      ),
      body: Consumer<FriendsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingSummary) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: List.generate(
                  5, // Show 5 skeleton tiles
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: FriendTileSkeleton(isIOS: false),
                  ),
                ),
              ),
            );
          }
          if (provider.error != null) {
            return ErrorStateWidget(provider: provider);
          }
          
          final userId = _getUserId();
          
          return Column(
            children: [
              // User ID display section
              if (userId != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your User ID:',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userId,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy ID',
                          onPressed: () => _copyUserIdToClipboard(context),
                          style: IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // TabBarView with friends and pending lists
              Expanded(
                child: TabBarView(
                  controller: _materialTabController,
                  children: [
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _buildFriendsList(context, provider),
                    ),
                    SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: _buildPendingList(context, provider),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _currentSegment == 0 ? _buildMaterialAddFriendButton(context, theme) : null,
    );
  }

  Widget _buildMaterialTabBar(BuildContext context, ThemeData theme) {
    final List<String> tabTitles = ['Friends', 'Pending'];
    final List<IconData> tabIcons = [Icons.people, Icons.pending_actions];
    final provider = context.watch<FriendsProvider>();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest, 
        borderRadius: BorderRadius.circular(25),
      ),
      child: TabBar(
        controller: _materialTabController,
        onTap: (index) {
          setState(() {
            _currentSegment = index;
          });
        },
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: theme.colorScheme.secondaryContainer, 
        ),
        indicatorPadding: const EdgeInsets.all(4),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: theme.colorScheme.onSecondaryContainer,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        splashBorderRadius: BorderRadius.circular(25),
        tabs: List.generate(
          tabTitles.length,
          (index) => Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(tabIcons[index], size: 18),
                const SizedBox(width: 8),
                Text(tabTitles[index]),
                Builder(builder: (context) {
                  int count = 0;
                  // Only show count for pending requests (index 1), not for friends (index 0)
                  if (index == 1) count = provider.incomingCount + provider.outgoingCount;
                  if (count > 0) {
                    return Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _currentSegment == index 
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          color: _currentSegment == index
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onPrimaryContainer,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialAddFriendButton(BuildContext context, ThemeData theme) {
    return FloatingActionButton(
      onPressed: () => _showAddFriendDialog(context),
      backgroundColor: theme.colorScheme.primary,
      foregroundColor: theme.colorScheme.onPrimary,
      tooltip: 'Add Friend',
      child: const Icon(Icons.person_add, size: 28),
    );
  }

  Widget _buildCupertinoPage(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    final provider = context.watch<FriendsProvider>();

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Friends'),
        trailing: _currentSegment == 0 
          ? CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.person_add),
              onPressed: () => _showAddFriendDialog(context),
            )
          : null,
        backgroundColor: cupertinoTheme.barBackgroundColor.withOpacity(0.7),
        border: null, // Remove default border for a cleaner look with segmented control below
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: CupertinoSlidingSegmentedControl<int>(
                backgroundColor: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                thumbColor: cupertinoTheme.primaryColor,
                groupValue: _currentSegment,
                onValueChanged: (int? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _currentSegment = newValue;
                    });
                  }
                },
                children: {
                  0: _buildCupertinoSegment(context, 'Friends', CupertinoIcons.group, 0, 0), // No count for friends
                  1: _buildCupertinoSegment(context, 'Pending', CupertinoIcons.hourglass, provider.incomingCount + provider.outgoingCount, 1),
                },
              ),
            ),
            
            // User ID display section
            Builder(builder: (context) {
              final userId = _getUserId();
              if (userId != null) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemFill.resolveFrom(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your User ID:',
                                style: TextStyle(
                                  color: CupertinoColors.label.resolveFrom(context),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                userId,
                                style: TextStyle(
                                  color: CupertinoColors.label.resolveFrom(context),
                                  fontSize: 14,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(10),
                          borderRadius: BorderRadius.circular(8),
                          color: cupertinoTheme.primaryColor.withOpacity(0.1),
                          onPressed: () => _copyUserIdToClipboard(context),
                          child: const Icon(CupertinoIcons.doc_on_doc),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (provider.isLoadingSummary) {
                    return Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: List.generate(
                          5, // Show 5 skeleton tiles
                          (index) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: FriendTileSkeleton(isIOS: true),
                          ),
                        ),
                      ),
                    );
                  }
                  if (provider.error != null) {
                    return ErrorStateWidget(provider: provider);
                  }
                  Widget content;
                  if (_currentSegment == 0) {
                    content = _buildFriendsList(context, provider);
                  } else {
                    content = _buildPendingList(context, provider);
                  }
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 0), // Sections handle their own padding
                    child: content,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCupertinoSegment(BuildContext context, String title, IconData icon, int count, int segmentValue) {
    final bool isActive = _currentSegment == segmentValue;
    final cupertinoTheme = CupertinoTheme.of(context);
    
    Color textColor = isActive 
        ? CupertinoColors.white 
        : cupertinoTheme.primaryColor;
    if ( CupertinoTheme.brightnessOf(context) == Brightness.dark && isActive) {
        textColor = CupertinoColors.black; // Ensure contrast on dark thumb
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(color: textColor)),
          if (count > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isActive 
                    ? CupertinoColors.white.withOpacity(0.3)
                    : cupertinoTheme.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: textColor,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
