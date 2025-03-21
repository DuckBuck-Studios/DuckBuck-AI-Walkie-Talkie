import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/friend_provider.dart';
import '../services/friend_service.dart';
import 'cool_button.dart';

class AddFriendPopup extends StatefulWidget {
  const AddFriendPopup({Key? key}) : super(key: key);

  @override
  State<AddFriendPopup> createState() => _AddFriendPopupState();
}

class _AddFriendPopupState extends State<AddFriendPopup> with SingleTickerProviderStateMixin {
  bool _showScanner = false;
  late TabController _tabController;
  final PageController _pageController = PageController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _pageController.animateToPage(
          _tabController.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    // Auto-open scanner when tab is switched to scan QR
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        setState(() => _showScanner = true);
      }
    });
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: _showScanner 
            ? MediaQuery.of(context).size.height * 0.8
            : MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          color: const Color(0xFF3C1F1F),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showScanner ? 'Scan QR Code' : 'Add Friend',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ).animate()
                    .fadeIn(duration: 300.ms)
                    .slideX(begin: -0.1, end: 0, duration: 300.ms),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white),
                    ),
                    onPressed: () {
                      if (_showScanner) {
                        setState(() => _showScanner = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),

            if (_showScanner)
              // QR Scanner View
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Stack(
                      children: [
                        MobileScanner(
                          controller: MobileScannerController(),
                          onDetect: (capture) {
                            final List<Barcode> barcodes = capture.barcodes;
                            if (barcodes.isNotEmpty) {
                              final String? code = barcodes.first.rawValue;
                              if (code != null) {
                                setState(() => _showScanner = false);
                                _processScannedCode(code);
                              }
                            }
                          },
                        ),
                        // Scanner overlay
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFD4A76A),
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ).animate(
                            onPlay: (controller) => controller.repeat(),
                          ).shimmer(
                            duration: 1500.ms,
                            color: Colors.white.withOpacity(0.5),
                          ),
                        ),
                        // Scanner message
                        Positioned(
                          bottom: 30,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3C1F1F).withOpacity(0.7),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0xFFD4A76A).withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: const Text(
                                'Scan your friend\'s QR code',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // Main Content
              Expanded(
                child: Column(
                  children: [
                    // Tab Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFFD4A76A),
                                Color(0xFFB38B5D),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.5),
                          labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 16,
                          ),
                          tabs: [
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.qr_code_scanner,
                                    size: 20,
                                    color: _tabController.index == 0 
                                        ? Colors.white 
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Scan QR'),
                                ],
                              ),
                            ),
                            Tab(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.person_search,
                                    size: 20,
                                    color: _tabController.index == 1 
                                        ? Colors.white 
                                        : Colors.white.withOpacity(0.5),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Search ID'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Page View
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          _tabController.animateTo(index);
                        },
                        children: [
                          // Scan QR Content
                          _buildScanQRContent(),
                          
                          // Search ID Content
                          const SearchUserView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        duration: 400.ms,
        curve: Curves.easeOutBack,
      );
  }

  Widget _buildScanQRContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // QR Code Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFD4A76A).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.qr_code_scanner,
                size: 60,
                color: Color(0xFFD4A76A),
              ),
            ).animate()
              .fadeIn(duration: 600.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1.0, 1.0),
                duration: 600.ms,
                curve: Curves.elasticOut,
              ),
              
            const SizedBox(height: 24),
            
            const Text(
              'Scan your friend\'s QR code to add them',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.white,
              ),
            ).animate()
              .fadeIn(delay: 200.ms, duration: 400.ms),
            
            const SizedBox(height: 36),
            
            // Open Scanner Button
            DuckBuckButton(
              text: 'Open Scanner',
              onTap: () => setState(() => _showScanner = true),
              color: const Color(0xFF2C1810),
              borderColor: const Color(0xFFD4A76A),
              width: 200,
              icon: const Icon(Icons.camera_alt, color: Colors.white),
            ).animate()
              .fadeIn(delay: 400.ms, duration: 400.ms)
              .slideY(delay: 400.ms, begin: 0.2, end: 0, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  void _processScannedCode(String code) {
    showDialog(
      context: context,
      builder: (context) => SearchUserPopup(initialSearchId: code),
    );
  }
}

// Search User View inside TabView
class SearchUserView extends StatelessWidget {
  const SearchUserView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final TextEditingController searchController = TextEditingController();
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // User ID Input
          TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter User ID',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              prefixIcon: const Icon(
                Icons.person_search,
                color: Color(0xFFD4A76A),
              ),
            ),
          ).animate()
            .fadeIn(duration: 400.ms)
            .slideX(begin: -0.1, end: 0, duration: 400.ms),
            
          const SizedBox(height: 36),
          
          // Search Button
          DuckBuckButton(
            text: 'Search User',
            onTap: () {
              final userId = searchController.text.trim();
              if (userId.isNotEmpty) {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder: (context) => SearchUserPopup(initialSearchId: userId),
                );
              }
            },
            color: const Color(0xFF2C1810),
            borderColor: const Color(0xFFD4A76A),
            width: 200,
            icon: const Icon(Icons.search, color: Colors.white),
          ).animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(delay: 200.ms, begin: 0.2, end: 0, duration: 400.ms),
        ],
      ),
    );
  }
}

// Search User Popup for displaying results
class SearchUserPopup extends StatefulWidget {
  final String? initialSearchId;
  
  const SearchUserPopup({
    Key? key,
    this.initialSearchId,
  }) : super(key: key);

  @override
  State<SearchUserPopup> createState() => _SearchUserPopupState();
}

class _SearchUserPopupState extends State<SearchUserPopup> {
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic>? _foundUser;
  bool _isLoading = false;
  bool _isSendingRequest = false;
  FriendRequestStatus? _requestStatus;

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchId != null && widget.initialSearchId!.isNotEmpty) {
      _searchController.text = widget.initialSearchId!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchUser(widget.initialSearchId!);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchUser(String uid) async {
    if (uid.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foundUser = null;
      _requestStatus = null;
    });

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        final friendProvider = Provider.of<FriendProvider>(context, listen: false);
        final requestStatus = await friendProvider.getFriendRequestStatus(uid);
        final isFriend = await friendProvider.isFriend(uid);
        final isBlocked = await friendProvider.isUserBlocked(uid);

        if (isBlocked) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Cannot add blocked user'),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            );
          }
          return;
        }

        if (isFriend) {
          setState(() {
            _requestStatus = FriendRequestStatus.accepted;
          });
        } else if (requestStatus != null) {
          setState(() {
            _requestStatus = requestStatus;
          });
        }

        setState(() {
          _foundUser = userDoc.data()!;
          _foundUser!['id'] = userDoc.id;
          _isLoading = false;
        });
      } else {
        setState(() {
          _foundUser = null;
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User not found'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching user: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_foundUser == null) return;

    setState(() => _isSendingRequest = true);

    try {
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      final success = await friendProvider.sendFriendRequest(_foundUser!['id']);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Friend request sent successfully'),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
          setState(() {
            _requestStatus = FriendRequestStatus.pending;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to send friend request'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending friend request: ${e.toString()}'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSendingRequest = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF3C1F1F),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with back button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Search User',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ).animate()
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: -0.1, end: 0, duration: 300.ms),
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Search Field - only show if no user found yet
            if (_foundUser == null || _isLoading)
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter user ID',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.person_search,
                    color: Color(0xFFD4A76A),
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: () => _searchUser(_searchController.text.trim()),
                  ),
                ),
              ).animate()
                .fadeIn(duration: 400.ms)
                .slideY(begin: 0.1, end: 0, duration: 400.ms),

            const SizedBox(height: 20),

            // Loading Indicator
            if (_isLoading)
              const Center(
                child: SizedBox(
                  height: 200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFFD4A76A),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Searching...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (_foundUser != null)
              _buildUserCard()
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, end: 0, duration: 600.ms)
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 600.ms),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        duration: 400.ms,
        curve: Curves.easeOutBack,
      );
  }

  Widget _buildUserCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810).withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD4A76A).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // User info section
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Profile Photo
                Hero(
                  tag: 'user-photo-${_foundUser!['id']}',
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFD4A76A),
                        width: 2,
                      ),
                      image: _foundUser!['photoURL'] != null
                          ? DecorationImage(
                              image: NetworkImage(_foundUser!['photoURL']),
                              fit: BoxFit.cover,
                            )
                          : null,
                      color: _foundUser!['photoURL'] == null
                          ? const Color(0xFFD4A76A).withOpacity(0.3)
                          : null,
                    ),
                    child: _foundUser!['photoURL'] == null
                        ? const Icon(Icons.person, size: 40, color: Colors.white)
                        : null,
                  ),
                ),
                
                const SizedBox(width: 20),
                
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _foundUser!['displayName'] ?? 'Unknown User',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _foundUser!['id'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Request Status
                      if (_requestStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_requestStatus!),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getStatusText(_requestStatus!),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Divider
          Divider(color: Colors.white.withOpacity(0.1), height: 1),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (_requestStatus == null)
                  // Send Request Button
                  Expanded(
                    child: DuckBuckButton(
                      text: _isSendingRequest ? 'Sending...' : 'Send Request',
                      onTap: _isSendingRequest 
                        ? () {} // Empty function when loading
                        : () { _sendFriendRequest(); },
                      color: const Color(0xFF2C1810),
                      borderColor: const Color(0xFFD4A76A),
                      isLoading: _isSendingRequest,
                    ),
                  )
                else
                  // Status Info Text
                  Expanded(
                    child: Center(
                      child: Text(
                        _getActionText(_requestStatus!),
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(width: 12),
                
                // Close Button
                DuckBuckButton(
                  text: 'Close',
                  onTap: () => Navigator.pop(context),
                  color: Colors.grey.withOpacity(0.3),
                  borderColor: Colors.grey,
                  width: 100,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return Colors.orange;
      case FriendRequestStatus.accepted:
        return Colors.green;
      case FriendRequestStatus.declined:
        return Colors.red;
      case FriendRequestStatus.blocked:
        return Colors.grey;
    }
  }

  String _getStatusText(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'Request Pending';
      case FriendRequestStatus.accepted:
        return 'Friends';
      case FriendRequestStatus.declined:
        return 'Request Declined';
      case FriendRequestStatus.blocked:
        return 'Blocked';
    }
  }
  
  String _getActionText(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'Friend request already sent';
      case FriendRequestStatus.accepted:
        return 'You are already friends';
      case FriendRequestStatus.declined:
        return 'Your request was declined';
      case FriendRequestStatus.blocked:
        return 'This user is blocked';
    }
  }
} 