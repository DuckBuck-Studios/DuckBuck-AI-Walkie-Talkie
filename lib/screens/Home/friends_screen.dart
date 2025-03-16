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
        final result = await friendProvider.sendFriendRequest(
          authProvider.userModel!.uid, 
          friendId
        );
        
        setState(() {
          if (result.contains('successfully')) {
            _successMessage = result;
            _friendIdController.clear();
          } else {
            _errorMessage = result;
          }
        });
      }
    } catch (e) {
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
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (hasPendingRequests) ...[
                        Row(
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
                              'Pending Requests',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                            ),
                          ],
                        ).animate().fadeIn().slideX(begin: -0.2),
                        const SizedBox(height: 12),
                        ..._buildPendingRequests(friendProvider, authProvider),
                        const SizedBox(height: 24),
                      ],
                      
                      if (hasFriends) ...[
                        Row(
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
                              'Friends',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                            ),
                          ],
                        ).animate().fadeIn().slideX(begin: -0.2),
                        const SizedBox(height: 12),
                        ..._buildFriendsList(friendProvider, authProvider),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: hasFriends || hasPendingRequests ? FloatingActionButton(
        onPressed: _showAddFriendDialog,
        backgroundColor: Colors.brown.shade800,
        child: const Icon(Icons.person_add, color: Colors.white),
      ).animate()
        .fadeIn(delay: 500.ms)
        .scale(begin: const Offset(0.5, 0.5))
        .then()
        .shimmer(duration: 1.seconds, color: Colors.white24) : null,
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
              const SizedBox(width: 40),
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
    final requests = friendProvider.pendingRequests.where((request) {
      final name = (request['name'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery);
    }).toList();

    if (requests.isEmpty) return [];

    return requests.map((request) {
      final bool isReceived = request['type'] == 'received';
      
      return Slidable(
        key: ValueKey(request['uid']),
        endActionPane: isReceived ? ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                if (authProvider.userModel != null) {
                  friendProvider.acceptFriendRequest(
                    authProvider.userModel!.uid,
                    request['uid'],
                  );
                }
              },
              backgroundColor: Colors.brown.shade600,
              foregroundColor: Colors.white,
              icon: Icons.check,
              label: 'Accept',
            ),
            SlidableAction(
              onPressed: (_) {
                if (authProvider.userModel != null) {
                  friendProvider.removeFriend(
                    authProvider.userModel!.uid,
                    request['uid'],
                  );
                }
              },
              backgroundColor: Colors.brown.shade800,
              foregroundColor: Colors.white,
              icon: Icons.close,
              label: 'Reject',
            ),
          ],
        ) : null,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isReceived ? Colors.brown.shade200 : Colors.brown.shade100,
              width: 1,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.brown.shade50,
              child: Text(
                request['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                style: TextStyle(
                  color: Colors.brown.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              request['name'] ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              isReceived ? 'Wants to be your friend' : 'Request sent',
              style: TextStyle(
                color: Colors.brown.shade600,
              ),
            ),
            trailing: Icon(
              isReceived ? Icons.swipe_left : Icons.pending_outlined,
              color: Colors.brown.shade400,
            ),
          ),
        ),
      ).animate().fadeIn().slideX(begin: 0.2, end: 0);
    }).toList();
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

    return friends.map((friend) {
      return Slidable(
        key: ValueKey(friend['uid']),
        endActionPane: ActionPane(
          motion: const ScrollMotion(),
          children: [
            SlidableAction(
              onPressed: (_) {
                if (authProvider.userModel != null) {
                  friendProvider.removeFriend(
                    authProvider.userModel!.uid,
                    friend['uid'],
                  );
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
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.brown.shade50,
              child: Text(
                friend['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                style: TextStyle(
                  color: Colors.brown.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              friend['name'] ?? 'Unknown Friend',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
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
            trailing: Icon(
              Icons.swipe_left,
              color: Colors.brown.shade400,
            ),
          ),
        ),
      ).animate().fadeIn().slideX(begin: 0.2, end: 0);
    }).toList();
  }
} 