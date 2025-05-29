import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/relationship_model.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/friends_provider.dart';
import '../widgets/error_state_widget.dart';
import '../widgets/add_friend_dialog.dart';
import '../widgets/remove_friend_dialog.dart';
import '../widgets/sections/friends_section.dart';
import '../widgets/sections/pending_section.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentIndex = _tabController.index;
        });
      }
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FriendsProvider>().initialize();
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        title: Text(
          'Friends',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        automaticallyImplyLeading: false, // Removes back button
        elevation: 0,
        backgroundColor: AppColors.backgroundBlack,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _buildTabBar(),
        ),
      ),
      body: Consumer<FriendsProvider>(
        builder: (context, provider, child) {
          if (provider.isLoadingSummary) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
              ),
            );
          }

          if (provider.error != null) {
            return ErrorStateWidget(provider: provider);
          }

          return TabBarView(
            controller: _tabController,
            children: [
              // Friends Tab
              RefreshIndicator(
                color: AppColors.accentTeal,
                backgroundColor: AppColors.surfaceBlack,
                onRefresh: () => provider.refreshAll(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: FriendsSection(
                    provider: provider, 
                    showRemoveFriendDialog: _showRemoveFriendDialog,
                  ),
                ),
              ),
              
              // Pending Requests Tab (Outgoing + Incoming)
              RefreshIndicator(
                color: AppColors.accentPurple,
                backgroundColor: AppColors.surfaceBlack,
                onRefresh: () => provider.refreshAll(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: PendingSection(provider: provider),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _currentIndex == 0 ? _buildAddFriendButton() : null,
    );
  }

  Widget _buildAddFriendButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [AppColors.accentBlue, AppColors.accentTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => _showAddFriendDialog(context),
        backgroundColor: Colors.transparent,
        elevation: 0,
        tooltip: 'Add Friend',
        child: const Icon(
          Icons.person_add,
          color: Colors.black,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    final List<String> tabTitles = ['Friends', 'Pending'];
    final List<Color> tabColors = [
      AppColors.accentTeal,
      AppColors.accentPurple,
    ];
    final List<IconData> tabIcons = [
      Icons.people,      // Friends
      Icons.pending,     // Pending
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        // Remove the tab indicator to make it cleaner
        indicator: const BoxDecoration(
          // Transparent indicator
          color: Colors.transparent,
        ),
        labelColor: AppColors.textPrimary, // Use text primary color instead of black
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold),
        tabs: List.generate(
          tabTitles.length,
          (index) => Tab(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    tabIcons[index],
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(tabTitles[index]),
                  Consumer<FriendsProvider>(
                    builder: (context, provider, _) {
                      int count = 0;
                      if (index == 0) count = provider.friendsCount;
                      if (index == 1) count = provider.incomingCount + provider.outgoingCount;

                      if (count > 0) {
                        return Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _currentIndex == index ? tabColors[index].withOpacity(0.2) : tabColors[index],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count.toString(),
                            style: TextStyle(
                              color: _currentIndex == index ? tabColors[index] : Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFriendDialog(BuildContext context) {
    final provider = Provider.of<FriendsProvider>(context, listen: false);
    AddFriendDialog.show(context, provider);
  }

  void _showRemoveFriendDialog(BuildContext context, RelationshipModel relationship) {
    final provider = Provider.of<FriendsProvider>(context, listen: false);
    RemoveFriendDialog.show(context, relationship, provider);
  }
}
