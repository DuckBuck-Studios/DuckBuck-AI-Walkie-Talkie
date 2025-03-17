import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/auth_provider.dart';
import '../../providers/friend_provider.dart';
import '../../widgets/animated_background.dart';
import '../../widgets/cool_button.dart';
import 'package:flutter_animate/flutter_animate.dart'; 

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _friendIdController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? _errorMessage;
  String? _successMessage;
  bool _isSearching = false;
  String _searchQuery = '';
  bool _isAddingFriend = false;
  bool _isScanning = false;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    
    // Refresh friend lists when screen appears
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      
      // Check if we have a user and initialize the friend provider
      if (authProvider.userModel != null) {
        print('FriendsScreen: Setting up with user ID: ${authProvider.userModel!.uid}');
        
        // Initialize the friend provider with the current user ID
        friendProvider.initializeFriendStreams(authProvider.userModel!.uid);
        
        // Now refresh the lists
        print('FriendsScreen: Refreshing lists on screen load');
        friendProvider.refreshLists();
        
        // Explicitly check for pending requests
        friendProvider.checkForPendingRequests();
      } else {
        print('FriendsScreen: No user logged in, cannot load friends');
      }
    });
  }
  
  @override
  void dispose() {
    _friendIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFriendDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF8B4513).withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24),
                  Text(
                    'Add a Friend',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF8B4513),
                    ),
                  ).animate().fadeIn().slideY(begin: 0.3),
                  IconButton(
                    icon: Icon(Icons.close, color: const Color(0xFF8B4513).withOpacity(0.6)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _friendIdController,
                decoration: InputDecoration(
                  hintText: 'Enter Friend ID',
                  filled: true,
                  fillColor: const Color(0xFF8B4513).withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: Icon(Icons.tag, color: const Color(0xFF8B4513)),
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.2),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                child: DuckBuckButton(
                  text: 'Scan QR Code',
                  onTap: () {
                    Navigator.pop(context);
                    _showQRScanner();
                  },
                  color: const Color(0xFF8B4513),
                  borderColor: const Color(0xFFD2691E),
                  icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
                ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                child: DuckBuckButton(
                  text: 'Send Friend Request',
                  onTap: () {
                    _sendFriendRequest();
                    Navigator.pop(context);
                  },
                  color: const Color(0xFFD2691E),
                  borderColor: const Color(0xFF8B4513),
                  isLoading: _isAddingFriend,
                  icon: const Icon(Icons.send, color: Colors.white),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 100.ms).shake(),
              if (_successMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    _successMessage!,
                    style: const TextStyle(color: Colors.green, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ).animate().fadeIn(delay: 100.ms).scale(),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.brown.shade800,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Scan Friend QR Code',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: MobileScanner(
                onDetect: (capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      _friendIdController.text = barcode.rawValue!;
                      Navigator.pop(context);
                      _showAddFriendDialog();
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendFriendRequest() async {
    final friendId = _friendIdController.text.trim();
    if (friendId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a friend ID';
      });
      return;
    }

    setState(() {
      _isAddingFriend = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      
      if (authProvider.userModel != null) {
        final currentUserId = authProvider.userModel!.uid;
        print('Sending friend request from $currentUserId to $friendId');
        
        // Make sure the friend provider is initialized
        if (friendProvider.currentUserId == null) {
          print('Initializing friend provider before sending request');
          friendProvider.initializeFriendStreams(currentUserId);
        }
        
        final result = await friendProvider.sendFriendRequest(
          currentUserId, 
          friendId
        );
        
        print('Friend request send result: $result');
        
        // Explicitly refresh the lists to ensure the UI shows the new request
        await friendProvider.refreshLists();
        
        // Also explicitly check for pending requests
        await friendProvider.checkForPendingRequests();
        
        setState(() {
          if (result.contains('successfully')) {
            _successMessage = result;
            _friendIdController.clear();
            
            // Show a snackbar for better user feedback
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Friend request sent successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          } else {
            _errorMessage = result;
          }
        });
      } else {
        setState(() {
          _errorMessage = 'You need to be logged in to send friend requests';
        });
      }
    } catch (e) {
      print('Error in _sendFriendRequest: $e');
      setState(() {
        _errorMessage = 'Failed to send friend request: $e';
      });
    } finally {
      setState(() {
        _isAddingFriend = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final friendProvider = Provider.of<FriendProvider>(context);
    final bool hasFriends = friendProvider.friends.isNotEmpty;
    final bool hasPendingRequests = friendProvider.pendingRequests.isNotEmpty;
    
    // Debug prints to understand what's in the lists
    print('FRIENDS SCREEN - FRIENDS LIST: ${friendProvider.friends.length} items');
    print('FRIENDS SCREEN - PENDING REQUESTS: ${friendProvider.pendingRequests.length} items');
    print('FRIENDS SCREEN - PENDING REQUESTS DATA: ${friendProvider.pendingRequests}');
    
    return Scaffold(
      body: DuckBuckAnimatedBackground(
        opacity: 0.03,
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(context),
              if (!hasFriends && !hasPendingRequests)
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 100,
                            color: const Color(0xFF8B4513).withOpacity(0.3),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Friends Yet',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B4513),
                            ),
                          ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),
                          const SizedBox(height: 12),
                          Text(
                            'Start adding friends using their ID\nor scan their QR code',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: const Color(0xFF8B4513).withOpacity(0.6),
                              height: 1.5,
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
                          const SizedBox(height: 40),
                          SizedBox(
                            width: 300,
                            child: DuckBuckButton(
                              text: 'Add Your First Friend',
                              onTap: _showAddFriendDialog,
                              color: const Color(0xFF8B4513),
                              borderColor: const Color(0xFFD2691E),
                              icon: const Icon(Icons.person_add, color: Colors.white),
                            ),
                          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),
                        ],
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      // Allow user to pull to refresh
                      await friendProvider.refreshLists();
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Always show pending requests section header if there are pending requests
                        if (hasPendingRequests) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.brown.shade100, Colors.brown.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.pending_actions,
                                  color: Colors.brown.shade800,
                                ).animate(
                                  onPlay: (controller) => controller.repeat(reverse: true),
                                ).scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.1, 1.1),
                                  duration: 1.seconds,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Pending Requests (${friendProvider.pendingRequests.length})',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                          ..._buildPendingRequests(friendProvider, authProvider),
                          const SizedBox(height: 24),
                        ],
                        
                        // Always show friends section header if there are friends
                        if (hasFriends) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.brown.shade100, Colors.brown.shade50],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.people,
                                  color: Colors.brown.shade800,
                                ).animate(
                                  onPlay: (controller) => controller.repeat(reverse: true),
                                ).scale(
                                  begin: const Offset(1, 1),
                                  end: const Offset(1.1, 1.1),
                                  duration: 1.seconds,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Friends (${friendProvider.friends.length})',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown.shade800,
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn().slideX(begin: -0.2, end: 0),
                          ..._buildFriendsList(friendProvider, authProvider),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: Colors.brown.shade800,
        child: const Icon(Icons.person_add, color: Colors.white),
      ).animate()
        .fadeIn(delay: 500.ms)
        .scale(begin: const Offset(0.5, 0.5))
        .then()
        .shimmer(duration: 1.seconds, color: Colors.white24),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: _isSearching ? 130 : 70,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.brown.shade800,
            Colors.brown.shade700,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.shade800.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                'My Friends',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ).animate()
                .fadeIn()
                .scale()
                .then()
                .shimmer(duration: 1.seconds, color: Colors.white24),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => setState(() => _isSearching = !_isSearching),
                  icon: Icon(
                    _isSearching ? Icons.close : Icons.search,
                    color: Colors.white,
                  ),
                ),
              ).animate().fadeIn().scale(),
            ],
          ),
          if (_isSearching)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: SizedBox(
                height: 45,
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Search friends...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    prefixIcon: const Icon(Icons.search, color: Colors.white),
                  ),
                  autofocus: true,
                ),
              ),
            ).animate().fadeIn().slideY(begin: -0.2),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  List<Widget> _buildPendingRequests(FriendProvider friendProvider, AuthProvider authProvider) {
    try {
      final requests = friendProvider.pendingRequests;
      
      print('Building pending requests UI - count: ${requests.length}');
      print('All pending requests: $requests');
      
      // Apply search filter if needed
      final filteredRequests = requests.where((request) {
        // Debug print for each request
        print('Filtering pending request: $request');
        
        // Skip invalid requests
        if (request == null || !request.containsKey('uid')) {
          print('Skipping invalid request: $request');
          return false;
        }
        
        // Get the display name using multiple fallbacks
        final name = (request['displayName'] ?? (request['name'] ?? '')).toString().toLowerCase();
        return _searchQuery.isEmpty || name.contains(_searchQuery);
      }).toList();

      if (filteredRequests.isEmpty) {
        print('NO MATCHING PENDING REQUESTS AFTER FILTERING');
        return [];
      }

      print('Building UI for ${filteredRequests.length} pending requests');
      return filteredRequests.map((request) {
        final bool isReceived = request['type'] == 'received';
        final bool isSent = request['type'] == 'sent';
        print('Request type: ${request['type']}, isReceived: $isReceived, isSent: $isSent');
        
        // Get the name with fallbacks
        final String name = request['displayName'] ?? request['name'] ?? 'Unknown User';
        print('Pending request name: $name');
        
        return Slidable(
          key: ValueKey(request['uid']),
          // For received requests - show accept/reject options
          endActionPane: isReceived ? ActionPane(
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) async {
                  if (authProvider.userModel != null) {
                    try {
                      await friendProvider.acceptFriendRequest(
                        authProvider.userModel!.uid,
                        request['uid'],
                      );
                      // Force refresh after accepting
                      await friendProvider.refreshLists();
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Friend request from $name accepted!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error accepting friend request: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error accepting friend request: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                backgroundColor: Colors.brown.shade600,
                foregroundColor: Colors.white,
                icon: Icons.check,
                label: 'Accept',
              ),
              SlidableAction(
                onPressed: (_) async {
                  if (authProvider.userModel != null) {
                    try {
                      await friendProvider.removeFriend(
                        authProvider.userModel!.uid,
                        request['uid'],
                      );
                      // Force refresh after rejecting
                      await friendProvider.refreshLists();
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Friend request from $name rejected'),
                            backgroundColor: Colors.grey,
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error rejecting friend request: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error rejecting friend request: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                backgroundColor: Colors.brown.shade800,
                foregroundColor: Colors.white,
                icon: Icons.close,
                label: 'Reject',
              ),
            ],
          ) : isSent ? ActionPane(
            // For sent requests - show cancel option
            motion: const ScrollMotion(),
            children: [
              SlidableAction(
                onPressed: (_) async {
                  if (authProvider.userModel != null) {
                    try {
                      // Use the same removeFriend method to cancel the request
                      await friendProvider.removeFriend(
                        authProvider.userModel!.uid,
                        request['uid'],
                      );
                      // Force refresh after cancelling
                      await friendProvider.refreshLists();
                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Friend request to $name cancelled'),
                            backgroundColor: Colors.grey,
                          ),
                        );
                      }
                    } catch (e) {
                      print('Error cancelling friend request: $e');
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error cancelling friend request: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                backgroundColor: Colors.brown.shade700,
                foregroundColor: Colors.white,
                icon: Icons.cancel,
                label: 'Cancel',
              ),
            ],
          ) : null,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isReceived ? Colors.brown.shade200 : 
                      isSent ? Colors.brown.shade100 : Colors.brown.shade50,
                width: isReceived ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.brown.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Hero(
                tag: 'friend-avatar-${request['uid']}',
                child: CircleAvatar(
                  radius: 25,
                  backgroundColor: Colors.brown.shade50,
                  backgroundImage: request['photoURL'] != null && request['photoURL'].toString().isNotEmpty
                      ? NetworkImage(request['photoURL'])
                      : null,
                  child: request['photoURL'] == null || request['photoURL'].toString().isEmpty
                      ? Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
                          style: TextStyle(
                            color: Colors.brown.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        )
                      : null,
                ),
              ),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isReceived ? Icons.call_received : Icons.call_made,
                        size: 14,
                        color: Colors.brown.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isReceived ? 'Wants to be your friend' : 'Request sent',
                        style: TextStyle(
                          color: Colors.brown.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isReceived ? 'Swipe left to accept/reject' : 'Swipe left to cancel',
                    style: TextStyle(
                      color: Colors.brown.shade400,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              trailing: Icon(
                isReceived ? Icons.swipe_left : Icons.pending_outlined,
                color: Colors.brown.shade400,
              ),
            ),
          ),
        ).animate()
          .fadeIn(duration: 400.ms, curve: Curves.easeOut)
          .slideY(begin: 0.2, end: 0, duration: 400.ms, curve: Curves.easeOut)
          .then()
          .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 200.ms);
      }).toList();
    } catch (e) {
      print('ERROR BUILDING PENDING REQUESTS: $e');
      return [
        Center(
          child: Text(
            'Error loading pending requests',
            style: TextStyle(color: Colors.red),
          ),
        ),
      ];
    }
  }

  List<Widget> _buildFriendsList(FriendProvider friendProvider, AuthProvider authProvider) {
    final friends = friendProvider.friends.where((friend) {
      final name = (friend['name'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery);
    }).toList();

    if (friends.isEmpty) {
      return [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.people_outline,
                size: 80,
                color: Colors.brown.shade300,
              ),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: TextStyle(
                  fontSize: 20,
                  color: Colors.brown.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add friends using their ID or QR code',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.brown.shade400,
                ),
              ),
            ],
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
      ];
    }

    return friends.asMap().entries.map((entry) {
      final index = entry.key;
      final friend = entry.value;
      
      return Slidable(
        key: ValueKey(friend['uid']),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) async {
                if (authProvider.userModel != null) {
                  try {
                    await friendProvider.removeFriend(
                      authProvider.userModel!.uid,
                      friend['uid'],
                    );
                    // Show success message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Removed ${friend['name'] ?? 'Unknown'} from friends'),
                          backgroundColor: Colors.grey,
                        ),
                      );
                    }
                  } catch (e) {
                    print('Error removing friend: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error removing friend: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              backgroundColor: Colors.brown.shade800,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Remove',
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.brown.shade100,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Hero(
              tag: 'friend-avatar-${friend['uid']}',
              child: CircleAvatar(
                radius: 25,
                backgroundColor: Colors.brown.shade50,
                backgroundImage: friend['photoURL'] != null && friend['photoURL'].toString().isNotEmpty
                    ? NetworkImage(friend['photoURL'])
                    : null,
                child: friend['photoURL'] == null || friend['photoURL'].toString().isEmpty
                    ? Text(
                        friend['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                        style: TextStyle(
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
            ),
            title: Text(
              friend['name'] ?? 'Unknown Friend',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: friend['isOnline'] == true ? Colors.green : Colors.grey,
                      ),
                    ),
                    Text(
                      friend['isOnline'] == true ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: friend['isOnline'] == true ? Colors.green.shade700 : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Swipe left to remove',
                  style: TextStyle(
                    color: Colors.brown.shade400,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            trailing: Icon(
              Icons.swipe_left,
              color: Colors.brown.shade400,
            ),
          ),
        ),
      ).animate(delay: (50 * index).ms)
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOut)
        .then()
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 200.ms);
    }).toList();
  }
} 