import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/relationship_provider.dart';
import '../widgets/friends_list_widget.dart';
import '../widgets/friend_requests_widget.dart';
import '../widgets/search_user_bottom_sheet.dart';
import '../widgets/user_uid_card.dart';
import 'dart:io' show Platform;

/// Production Friends Screen - Real-time friend management with RelationshipProvider
/// Features:
/// - Real-time friends list with pull-to-refresh
/// - Friend requests management (accept/reject)
/// - User search with UID-based lookup
/// - Friend removal with confirmation
/// - Platform-specific design (iOS/Android)
/// - Loading states and error handling
/// 
/// UI Flow: FriendsScreen → RelationshipProvider → RelationshipRepository → Firebase
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> 
    with SingleTickerProviderStateMixin {
  
  // Tab controller for Material Design
  TabController? _tabController;
  int _selectedSegment = 0; // For Cupertino segmented control

  @override
  void initState() {
    super.initState();
    if (!Platform.isIOS) {
      _tabController = TabController(length: 2, vsync: this);
      // Listen to tab controller changes to sync with _selectedSegment
      _tabController?.addListener(() {
        if (_tabController!.indexIsChanging || _tabController!.index != _selectedSegment) {
          setState(() {
            _selectedSegment = _tabController!.index;
          });
        }
      });
    }
    
    // Initialize RelationshipProvider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<RelationshipProvider>();
      provider.initialize();
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  /// Shows search user bottom sheet for finding friends
  void _showSearchBottomSheet() {
    SearchUserBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildCupertinoPage() : _buildMaterialPage();
  }

  /// iOS Cupertino Design Implementation
  Widget _buildCupertinoPage() {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text(
          'Friends',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        border: null,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // Modern Segmented Control for tab switching
                Container(
                  margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey.resolveFrom(context).withAlpha(26), // 0.1 * 255 = ~26
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CupertinoSlidingSegmentedControl<int>(
                    backgroundColor: Colors.transparent,
                    thumbColor: CupertinoColors.systemBackground.resolveFrom(context),
                    groupValue: _selectedSegment,
                    onValueChanged: (int? value) {
                      if (value != null) {
                        setState(() {
                          _selectedSegment = value;
                        });
                      }
                    },
                    children: {
                      0: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_2_fill,
                              size: 16,
                              color: _selectedSegment == 0 
                                  ? CupertinoColors.activeBlue.resolveFrom(context)
                                  : CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Friends',
                              style: TextStyle(
                                fontWeight: _selectedSegment == 0 ? FontWeight.w600 : FontWeight.w500,
                                color: _selectedSegment == 0 
                                    ? CupertinoColors.activeBlue.resolveFrom(context)
                                    : CupertinoColors.secondaryLabel.resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      1: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        child: Consumer<RelationshipProvider>(
                          builder: (context, provider, child) {
                            final requestsCount = provider.pendingRequests.length;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  CupertinoIcons.bell_fill,
                                  size: 16,
                                  color: _selectedSegment == 1 
                                      ? CupertinoColors.activeBlue.resolveFrom(context)
                                      : CupertinoColors.secondaryLabel.resolveFrom(context),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Requests',
                                  style: TextStyle(
                                    fontWeight: _selectedSegment == 1 ? FontWeight.w600 : FontWeight.w500,
                                    color: _selectedSegment == 1 
                                        ? CupertinoColors.activeBlue.resolveFrom(context)
                                        : CupertinoColors.secondaryLabel.resolveFrom(context),
                                  ),
                                ),
                                if (requestsCount > 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.destructiveRed,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      requestsCount.toString(),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                      ),
                    },
                  ),
                ),
                
                // User UID Card
                Consumer<RelationshipProvider>(
                  builder: (context, provider, child) {
                    return UserUidCard(
                      uid: provider.currentUserUid,
                    );
                  },
                ),
                
                // Content based on selected segment
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0.1, 0),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          )),
                          child: child,
                        ),
                      );
                    },
                    child: _selectedSegment == 0 
                        ? const FriendsListWidget(key: ValueKey('friends'))
                        : const FriendRequestsWidget(key: ValueKey('requests')),
                  ),
                ),
              ],
            ),
          ),
          
          // Conditional floating action button - only show in Friends section
          if (_selectedSegment == 0)
            Positioned(
              right: 20,
              bottom: 30,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _showSearchBottomSheet,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.activeBlue.resolveFrom(context).withAlpha(77), // 0.3 * 255 = ~77
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    CupertinoIcons.person_add,
                    color: CupertinoColors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Android Material Design Implementation
  Widget _buildMaterialPage() {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Friends',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          // Modern Segmented Control for Material Design
          Container(
            margin: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withAlpha(77), // 0.3 * 255 = ~77
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.shadow.withAlpha(26), // 0.1 * 255 = ~26
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Friends Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSegment = 0;
                      });
                      _tabController?.animateTo(0);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedSegment == 0
                            ? theme.colorScheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedSegment == 0
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withAlpha(38), // 0.15 * 255 = ~38
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.people,
                            size: 16,
                            color: _selectedSegment == 0
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Friends',
                            style: TextStyle(
                              fontWeight: _selectedSegment == 0 ? FontWeight.w600 : FontWeight.w500,
                              color: _selectedSegment == 0
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Requests Tab
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedSegment = 1;
                      });
                      _tabController?.animateTo(1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      decoration: BoxDecoration(
                        color: _selectedSegment == 1
                            ? theme.colorScheme.surface
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _selectedSegment == 1
                            ? [
                                BoxShadow(
                                  color: theme.colorScheme.shadow.withAlpha(38), // 0.15 * 255 = ~38
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Consumer<RelationshipProvider>(
                        builder: (context, provider, child) {
                          final requestsCount = provider.pendingRequests.length;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications,
                                size: 16,
                                color: _selectedSegment == 1
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Requests',
                                style: TextStyle(
                                  fontWeight: _selectedSegment == 1 ? FontWeight.w600 : FontWeight.w500,
                                  color: _selectedSegment == 1
                                      ? theme.colorScheme.primary
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (requestsCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.error,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    requestsCount.toString(),
                                    style: TextStyle(
                                      color: theme.colorScheme.onError,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // User UID Card
          Consumer<RelationshipProvider>(
            builder: (context, provider, child) {
              return UserUidCard(
                uid: provider.currentUserUid,
              );
            },
          ),
          
          // Content based on selected segment
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    )),
                    child: child,
                  ),
                );
              },
              child: _selectedSegment == 0
                  ? const FriendsListWidget(key: ValueKey('friends'))
                  : const FriendRequestsWidget(key: ValueKey('requests')),
            ),
          ),
        ],
      ),
      // Conditional floating action button - only show in Friends section
      floatingActionButton: _selectedSegment == 0
          ? FloatingActionButton(
              onPressed: _showSearchBottomSheet,
              backgroundColor: theme.colorScheme.primary,
              child: Icon(
                Icons.person_add,
                color: theme.colorScheme.onPrimary,
              ),
            )
          : null,
    );
  }
}
