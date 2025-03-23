import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/cool_button.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/add_friend_popup.dart';

class FriendScreen extends StatefulWidget {
  const FriendScreen({Key? key}) : super(key: key);

  @override
  State<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends State<FriendScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearchBar = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  Future<void> _initializeProvider() async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Enhanced card ui styling
  BoxDecoration _getCardDecoration({bool isRequest = false}) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isRequest 
            ? [const Color(0xFF472222), const Color(0xFF2C1810)]
            : [const Color(0xFF3C1F1F), const Color(0xFF2C1810)],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.2),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
      border: Border.all(
        color: const Color(0xFFD4A76A).withOpacity(0.3),
        width: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // Main content
              Column(
                children: [
                  // Bottom sheet-like header from top
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3C1F1F).withOpacity(0.9),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(30),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Drag handle
                        Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Friends',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _showSearchBar ? Icons.close : Icons.search,
                                color: Colors.white,
                              ),
                              onPressed: () {
                                setState(() {
                                  if (_showSearchBar) {
                                    _searchQuery = '';
                                    _searchController.clear();
                                  }
                                  _showSearchBar = !_showSearchBar;
                                });
                              },
                            ),
                          ],
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: _showSearchBar ? 80 : 0,
                          child: SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: Column(
                              children: [
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _searchController,
                                  onChanged: (value) => setState(() => _searchQuery = value),
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    hintText: 'Search friends...',
                                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                                    suffixIcon: _searchQuery.isNotEmpty 
                                      ? IconButton(
                                          icon: const Icon(Icons.close, color: Colors.white),
                                          onPressed: () {
                                            setState(() {
                                              _searchQuery = '';
                                              _searchController.clear();
                                            });
                                          },
                                        ) 
                                      : null,
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.1),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate(
                          target: _showSearchBar ? 1 : 0,
                        ).fade(
                          begin: 0,
                          end: 1,
                          duration: 300.ms,
                        ).slideY(
                          begin: -0.2,
                          end: 0,
                          duration: 300.ms,
                          curve: Curves.easeOutCubic,
                        ),
                        // Add Friend Button below the header
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 16),
                          child: DuckBuckButton(
                            text: 'Add Friend',
                            onTap: _showAddFriendOptions,
                            color: const Color(0xFF2C1810),
                            borderColor: const Color(0xFFD4A76A),
                            icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
                          ),
                        ).animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(
                            begin: -0.2,
                            end: 0,
                            duration: 400.ms,
                            curve: Curves.easeOutCubic,
                          ),
                      ],
                    ),
                  ),

                  // Friends list
                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFFD4A76A),
                            ),
                          )
                        : Consumer<FriendProvider>(
                            builder: (context, friendProvider, child) {
                              final incomingRequests = friendProvider.incomingRequests;
                              final outgoingRequests = friendProvider.outgoingRequests;
                              final friends = friendProvider.friends;

                              final filteredFriends = friends.where((friend) {
                                final name = friend['displayName']?.toString().toLowerCase() ?? '';
                                return name.contains(_searchQuery.toLowerCase());
                              }).toList();

                              final hasPendingRequests = incomingRequests.isNotEmpty || outgoingRequests.isNotEmpty;

                              return ListView(
                                padding: const EdgeInsets.only(
                                  left: 16, 
                                  right: 16, 
                                  bottom: 100
                                ),
                                children: [
                                  // Pending Requests Section
                                  if (hasPendingRequests) ...[
                                    const Text(
                                      'Pending Requests',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ).animate()
                                      .fadeIn(duration: 400.ms)
                                      .slideX(begin: -0.1, end: 0, duration: 400.ms),
                                    const SizedBox(height: 8),
                                    
                                    // Incoming Requests
                                    if (incomingRequests.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Incoming',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      ...incomingRequests.map((request) => _buildRequestCard(
                                        context,
                                        request,
                                        isIncoming: true,
                                      ).animate().slideX(
                                        begin: -1,
                                        end: 0,
                                        duration: 400.ms,
                                        curve: Curves.easeOutBack,
                                      )),
                                    ],

                                    // Outgoing Requests
                                    if (outgoingRequests.isNotEmpty) ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 8),
                                        child: Text(
                                          'Outgoing',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ),
                                      ...outgoingRequests.map((request) => _buildRequestCard(
                                        context,
                                        request,
                                        isIncoming: false,
                                      ).animate().slideX(
                                        begin: 1,
                                        end: 0,
                                        duration: 400.ms,
                                        curve: Curves.easeOutBack,
                                      )),
                                    ],
                                    const SizedBox(height: 24),
                                  ],

                                  // Friends Section
                                  if (!hasPendingRequests || filteredFriends.isNotEmpty) ...[
                                    const Text(
                                      'Friends',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ).animate()
                                      .fadeIn(duration: 400.ms)
                                      .slideX(begin: -0.1, end: 0, duration: 400.ms),
                                    const SizedBox(height: 8),
                                    if (filteredFriends.isNotEmpty) 
                                      ...filteredFriends.map((friend) => _buildFriendCard(
                                        context,
                                        friend,
                                      ).animate().slideX(
                                        begin: 1,
                                        end: 0,
                                        duration: 400.ms,
                                        curve: Curves.easeOutBack,
                                      ))
                                    else if (!hasPendingRequests)
                                      _buildEmptyState(),
                                  ],
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6, // 60% of screen height
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated empty friends illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFD4A76A).withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A76A).withOpacity(0.1),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.people_outline,
              size: 60,
              color: Colors.white70,
            ),
          ).animate()
            .fadeIn(duration: 600.ms)
            .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1.0, 1.0),
              duration: 800.ms,
              curve: Curves.elasticOut,
            ),
          const SizedBox(height: 24),
          const Text(
            'No friends yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ).animate()
            .fadeIn(delay: 300.ms, duration: 500.ms)
            .slideY(begin: 0.2, end: 0, duration: 500.ms),
          const SizedBox(height: 12),
          const Text(
            'Add friends to see them here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ).animate()
            .fadeIn(delay: 500.ms, duration: 500.ms),
          const SizedBox(height: 32),
          // Animated add friend button
          DuckBuckButton(
            text: 'Add Friend',
            onTap: _showAddFriendOptions,
            color: const Color(0xFF2C1810),
            borderColor: const Color(0xFFD4A76A),
            width: 200,
            icon: const Icon(Icons.person_add, color: Colors.white, size: 20),
          ).animate()
            .fadeIn(delay: 700.ms, duration: 500.ms)
            .shimmer(
              duration: 1500.ms,
              delay: 1500.ms,
              color: Colors.white.withOpacity(0.2),
            ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request, {bool isIncoming = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _getCardDecoration(isRequest: true),
      child: Slidable(
        endActionPane: isIncoming ? ActionPane(
          motion: const ScrollMotion(),
          extentRatio: 0.6,
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                _acceptFriendRequest(request['id']);
              },
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.check,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(0),
                topRight: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
              label: 'Accept',
            ),
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                _declineFriendRequest(request['id']);
              },
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.close,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(0),
                bottomLeft: Radius.circular(0),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              label: 'Decline',
            ),
          ],
        ) : null,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD4A76A), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A76A).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: request['photoURL'] != null
                  ? CachedNetworkImage(
                      imageUrl: request['photoURL'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFD4A76A),
                          strokeWidth: 2,
                        ),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    )
                  : const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          title: Text(
            request['displayName'] ?? 'Unknown User',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            isIncoming ? 'Sent you a friend request' : 'Friend request sent',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          trailing: !isIncoming ? IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () {
              HapticFeedback.mediumImpact();
              _cancelFriendRequest(request['id']);
            },
          ) : null,
        ),
      ),
    );
  }

  Widget _buildFriendCard(BuildContext context, Map<String, dynamic> friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: _getCardDecoration(),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                HapticFeedback.mediumImpact();
                _showFriendOptions(context, friend);
              },
              backgroundColor: const Color(0xFFD4A76A),
              foregroundColor: Colors.white,
              icon: Icons.more_vert,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
              label: 'More',
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4A76A), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4A76A).withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: friend['photoURL'] != null
                      ? CachedNetworkImage(
                          imageUrl: friend['photoURL'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFD4A76A),
                              strokeWidth: 2,
                            ),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            color: Colors.white,
                            size: 24,
                          ),
                        )
                      : const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),
              if (friend['isOnline'] == true)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.5),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            friend['displayName'] ?? 'Unknown User',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            friend['isOnline'] == true ? 'Online' : 'Offline',
            style: TextStyle(
              color: friend['isOnline'] == true 
                ? Colors.green.withOpacity(0.9) 
                : Colors.white.withOpacity(0.7),
            ),
          ),
          onTap: () {
            HapticFeedback.selectionClick();
            // View friend profile or some other action
          },
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .slideX(
        begin: 0.05,
        end: 0,
        duration: 400.ms,
        curve: Curves.easeOut,
      );
  }

  void _showAddFriendOptions() {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (context) => const AddFriendPopup(),
    ).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        if (result.containsKey('success') && result['success'] == true) {
          HapticFeedback.mediumImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Friend request sent successfully'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        } else if (result.containsKey('error')) {
          HapticFeedback.vibrate(); // Stronger vibration for error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error']),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    });
  }

  void _showFriendOptions(BuildContext context, Map<String, dynamic> friend) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3C1F1F), Color(0xFF2C1810)],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: const Color(0xFFD4A76A).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Friend info header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFD4A76A), width: 2),
                    ),
                    child: ClipOval(
                      child: friend['photoURL'] != null
                          ? CachedNetworkImage(
                              imageUrl: friend['photoURL'],
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFFD4A76A),
                                  strokeWidth: 2,
                                ),
                              ),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 24,
                              ),
                            )
                          : const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 24,
                            ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend['displayName'] ?? 'Unknown User',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          friend['isOnline'] == true ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: friend['isOnline'] == true 
                              ? Colors.green.withOpacity(0.9) 
                              : Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const Divider(color: Colors.white12, height: 20),
            
            // Options
            _buildOptionTile(
              icon: Icons.block,
              iconColor: Colors.red,
              title: 'Block User',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                _showConfirmationDialog(
                  title: 'Block User',
                  content: 'Are you sure you want to block this user? You will no longer see their activity or receive calls from them.',
                  confirmLabel: 'Block',
                  confirmColor: Colors.red,
                  onConfirm: () => _blockUser(friend['id']),
                );
              },
            ),
            
            _buildOptionTile(
              icon: Icons.person_remove,
              iconColor: Colors.orange,
              title: 'Remove Friend',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                _showConfirmationDialog(
                  title: 'Remove Friend',
                  content: 'Are you sure you want to remove this friend?',
                  confirmLabel: 'Remove',
                  confirmColor: Colors.orange,
                  onConfirm: () => _removeFriend(friend['id']),
                );
              },
            ),
            
            _buildOptionTile(
              icon: Icons.report,
              iconColor: Colors.grey,
              title: 'Report User',
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pop(context);
                _showReportDialog(context, friend['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      onTap: onTap,
    ).animate()
      .fadeIn(duration: 300.ms)
      .slideX(begin: 0.05, end: 0, duration: 300.ms);
  }

  void _showConfirmationDialog({
    required String title,
    required String content,
    required String confirmLabel,
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    HapticFeedback.selectionClick();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF3C1F1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFFD4A76A).withOpacity(0.3),
            width: 1,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          content,
          style: TextStyle(color: Colors.white.withOpacity(0.9)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(
              confirmLabel,
              style: TextStyle(color: confirmColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, String userId) {
    HapticFeedback.selectionClick();
    final TextEditingController reasonController = TextEditingController();
    final FocusNode focusNode = FocusNode();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          backgroundColor: const Color(0xFF3C1F1F),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: const Color(0xFFD4A76A).withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.report_problem,
                        color: Colors.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Report User',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Please provide details about why you are reporting this user. Reporting will also block this user. This information will be reviewed by our moderation team.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                // Report reason selection
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C2F2F).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: focusNode.hasFocus 
                          ? const Color(0xFFD4A76A) 
                          : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: reasonController,
                    focusNode: focusNode,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter reason for reporting',
                      hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                      contentPadding: const EdgeInsets.all(16),
                      border: InputBorder.none,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(height: 24),
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: isSubmitting 
                          ? null 
                          : () {
                              HapticFeedback.selectionClick();
                              Navigator.pop(context);
                            },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: isSubmitting 
                              ? Colors.white30 
                              : Colors.white70,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    DuckBuckButton(
                      text: isSubmitting ? 'Submitting...' : 'Report & Block',
                      onTap: isSubmitting || reasonController.text.trim().isEmpty
                          ? () {} // Empty callback when disabled
                          : () async {
                              HapticFeedback.mediumImpact();
                              setState(() => isSubmitting = true);
                              
                              final reason = reasonController.text.trim();
                              
                              // Show loading indicator
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Row(
                                      children: [
                                        SizedBox(
                                          width: 20, 
                                          height: 20, 
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          )
                                        ),
                                        SizedBox(width: 12),
                                        Text('Reporting and blocking user...'),
                                      ],
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                    duration: const Duration(seconds: 1),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    margin: const EdgeInsets.all(10),
                                  ),
                                );
                              }
                              
                              final success = await _reportUser(userId, reason);
                              
                              if (context.mounted) {
                                Navigator.pop(context);
                                
                                if (success) {
                                  HapticFeedback.mediumImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.check_circle, color: Colors.white),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'User has been reported and blocked successfully'
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.purple,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.all(10),
                                    ),
                                  );
                                  
                                  // Force refresh the friend lists
                                  final friendProvider = Provider.of<FriendProvider>(context, listen: false);
                                  await friendProvider.initialize();
                                  
                                } else {
                                  HapticFeedback.vibrate();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(Icons.error_outline, color: Colors.white),
                                          SizedBox(width: 12),
                                          Text('Failed to report and block user'),
                                        ],
                                      ),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      margin: const EdgeInsets.all(10),
                                    ),
                                  );
                                }
                              }
                            },
                      color: isSubmitting || reasonController.text.trim().isEmpty
                          ? const Color(0xFF5C2F2F).withOpacity(0.5)
                          : const Color(0xFF5C2F2F),
                      borderColor: const Color(0xFFD4A76A),
                      width: 150,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _sendFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final result = await friendProvider.sendFriendRequestWithValidation(userId);
    final success = result['success'] == true;
    
    if (success) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }
    return success;
  }

  Future<bool> _acceptFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final result = await friendProvider.acceptFriendRequest(userId);
    final success = result['success'] == true;
    
    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend request accepted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to accept friend request'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
    return success;
  }

  Future<bool> _declineFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final result = await friendProvider.declineFriendRequest(userId);
    final success = result['success'] == true;
    
    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend request declined'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to decline friend request'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
    return success;
  }

  Future<bool> _removeFriend(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final result = await friendProvider.removeFriend(userId);
    final success = result['success'] == true;
    
    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend removed'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to remove friend'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
    return success;
  }

  Future<bool> _blockUser(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    
    // Show loading indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
            ),
            SizedBox(width: 12),
            Text('Blocking user...'),
          ],
        ),
        backgroundColor: Colors.purple.shade700,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
    
    final result = await friendProvider.blockUser(userId);
    final success = result['success'] == true;
    
    if (success) {
      HapticFeedback.mediumImpact();
      if (mounted) {
        final wasFriend = result['wasFriend'] == true;
        final message = wasFriend 
            ? 'User blocked and removed from friends'
            : 'User blocked successfully';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.block, color: Colors.white),
                const SizedBox(width: 12),
                Text(message),
              ],
            ),
            backgroundColor: Colors.purple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } else {
      HapticFeedback.vibrate();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Text(result['error'] ?? 'Could not block user'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    }
    return success;
  }

  Future<bool> _reportUser(String userId, String reason) async {
    try {
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      final result = await friendProvider.reportUser(userId, reason);
      return result['success'] == true;
    } catch (e) {
      debugPrint('Error reporting user: $e');
      return false;
    }
  }

  Future<bool> _cancelFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    final result = await friendProvider.cancelFriendRequest(userId);
    final success = result['success'] == true;
    
    if (success) {
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Friend request canceled'),
          backgroundColor: Colors.grey,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to cancel friend request'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(10),
        ),
      );
    }
    return success;
  }
} 
