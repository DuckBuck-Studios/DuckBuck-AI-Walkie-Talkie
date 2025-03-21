import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.white70,
            ),
            const SizedBox(height: 24),
            const Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Add friends to see them here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .scale(
        begin: const Offset(0.8, 0.8),
        end: const Offset(1.0, 1.0),
        duration: 600.ms,
        curve: Curves.easeOutBack,
      );
  }

  Widget _buildRequestCard(BuildContext context, Map<String, dynamic> request, {bool isIncoming = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Slidable(
        endActionPane: isIncoming ? ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _acceptFriendRequest(request['id']),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: Icons.check,
              label: 'Accept',
            ),
            SlidableAction(
              onPressed: (_) => _declineFriendRequest(request['id']),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.close,
              label: 'Decline',
            ),
          ],
        ) : null,
        child: ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: ClipOval(
              child: request['photoURL'] != null
                  ? CachedNetworkImage(
                      imageUrl: request['photoURL'],
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: const Color(0xFFD4A76A),
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
            onPressed: () => _cancelFriendRequest(request['id']),
          ) : null,
        ),
      ),
    );
  }

  Widget _buildFriendCard(BuildContext context, Map<String, dynamic> friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => _showFriendOptions(context, friend),
              backgroundColor: const Color(0xFFD4A76A),
              foregroundColor: Colors.white,
              icon: Icons.more_vert,
              label: 'More',
            ),
          ],
        ),
        child: ListTile(
          leading: Stack(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
                child: ClipOval(
                  child: friend['photoURL'] != null
                      ? CachedNetworkImage(
                          imageUrl: friend['photoURL'],
                          fit: BoxFit.cover,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(
                              color: const Color(0xFFD4A76A),
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
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
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
            ),
          ),
          subtitle: Text(
            friend['isOnline'] == true ? 'Online' : 'Offline',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddFriendOptions() {
    showDialog(
      context: context,
      builder: (context) => const AddFriendPopup(),
    );
  }

  void _showFriendOptions(BuildContext context, Map<String, dynamic> friend) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF3C1F1F),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.block, color: Colors.red),
              title: const Text('Block User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _blockUser(friend['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: Colors.orange),
              title: const Text('Remove Friend', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _removeFriend(friend['id']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report, color: Colors.grey),
              title: const Text('Report User', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context, friend['id']);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context, String userId) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF3C1F1F),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Report User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter reason for reporting',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                  filled: true,
                  fillColor: const Color(0xFF5C2F2F).withOpacity(0.5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  DuckBuckButton(
                    text: 'Submit',
                    onTap: () {
                      final reason = reasonController.text.trim();
                      if (reason.isNotEmpty) {
                        _reportUser(userId, reason);
                        Navigator.pop(context);
                      }
                    },
                    color: const Color(0xFF5C2F2F),
                    borderColor: const Color(0xFFD4A76A),
                    width: 100,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.sendFriendRequest(userId);
  }

  Future<void> _acceptFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.acceptFriendRequest(userId);
  }

  Future<void> _declineFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.declineFriendRequest(userId);
  }

  Future<void> _removeFriend(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.removeFriend(userId);
  }

  Future<void> _blockUser(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.blockUser(userId);
  }

  Future<void> _reportUser(String userId, String reason) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.reportUser(userId, reason);
  }

  Future<void> _cancelFriendRequest(String userId) async {
    final friendProvider = Provider.of<FriendProvider>(context, listen: false);
    await friendProvider.cancelFriendRequest(userId);
  }
} 
