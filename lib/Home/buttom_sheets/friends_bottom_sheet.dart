import 'package:duckbuck/Home/buttom_sheets/qr_scanner.dart';
import 'package:duckbuck/Home/buttom_sheets/setting/user_profile_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/Home/providers/friend_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';

class FriendsBottomSheet extends StatefulWidget {
  @override
  _FriendsBottomSheetState createState() => _FriendsBottomSheetState();
}

class _FriendsBottomSheetState extends State<FriendsBottomSheet>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _friendUidController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _filteredFriends = [];
  final MobileScannerController _scannerController = MobileScannerController();
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    Provider.of<FriendsProvider>(context, listen: false).initFriendsListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _friendUidController.dispose();
    _searchController.dispose();
    _scannerController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _showUserProfileBottomSheet() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileBottomSheet(),
    );
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _filteredFriends.clear();
      }
    });
  }

  void _filterFriends(String query) {
    final friendsProvider =
        Provider.of<FriendsProvider>(context, listen: false);
    setState(() {
      if (query.isEmpty) {
        _filteredFriends.clear();
      } else {
        _filteredFriends = friendsProvider.friends
            .where((friend) => friend['name']
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
            .toList();

        // Sort by best match
        _filteredFriends.sort((a, b) {
          final aName = a['name'].toString().toLowerCase();
          final bName = b['name'].toString().toLowerCase();
          final query = _searchController.text.toLowerCase();

          // Exact matches first
          if (aName == query && bName != query) return -1;
          if (bName == query && aName != query) return 1;

          // Starts with matches second
          if (aName.startsWith(query) && !bName.startsWith(query)) return -1;
          if (bName.startsWith(query) && !aName.startsWith(query)) return 1;

          // Alphabetical order for remaining matches
          return aName.compareTo(bName);
        });
      }
    });
  }

  void _showAddFriendDialog() {
    HapticFeedback.mediumImpact();
    bool isScanning = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Animate(
          effects: [
            ScaleEffect(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1, 1),
              duration: 400.ms,
              curve: Curves.easeOutExpo,
            ),
            FadeEffect(duration: 300.ms),
          ],
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            backgroundColor: Colors.black,
            elevation: 20,
            child: AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final sineValue = sin(4 * pi * _shakeController.value);
                return Transform.translate(
                  offset: Offset(sineValue * 10, 0),
                  child: child,
                );
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.person_add_alt_1,
                            color: Colors.purple,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Add Friend',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enter your friend\'s UID',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Scanner (conditionally shown)
                    if (isScanning) ...[
                      _buildQRScanner(),
                      const SizedBox(height: 24),
                    ],

                    // UID Input Field with Scan Button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _friendUidController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Enter Friend\'s UID',
                              hintStyle: TextStyle(
                                color: Colors.white.withOpacity(0.3),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const QRScannerScreen(),
                              ),
                            );

                            if (result != null) {
                              setState(() {
                                _friendUidController.text = result;
                              });
                              // Show success feedback
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                      'QR Code scanned successfully'),
                                  backgroundColor: Colors.green.shade900,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.qr_code_scanner,
                            color: Colors.white70,
                          ),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              backgroundColor: Colors.white.withOpacity(0.1),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Consumer<FriendsProvider>(
                            builder: (context, provider, child) {
                              return ElevatedButton(
                                onPressed: provider.isLoading
                                    ? null
                                    : () async {
                                        if (_friendUidController.text
                                            .trim()
                                            .isEmpty) {
                                          _shakeDialog();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                  'Please enter a friend\'s UID'),
                                              backgroundColor:
                                                  Colors.red.shade900,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        HapticFeedback.mediumImpact();

                                        try {
                                          final result =
                                              await provider.sendFriendRequest(
                                            _friendUidController.text.trim(),
                                          );

                                          if (!mounted) return;

                                          if (result.contains('success')) {
                                            HapticFeedback.heavyImpact();
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .check_circle_outline,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(result),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor:
                                                    Colors.green.shade900,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          } else {
                                            HapticFeedback.vibrate();
                                            _shakeDialog();
                                            _friendUidController.clear();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(result),
                                                    ),
                                                  ],
                                                ),
                                                backgroundColor:
                                                    Colors.red.shade900,
                                                behavior:
                                                    SnackBarBehavior.floating,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          HapticFeedback.vibrate();
                                          _shakeDialog();
                                          _friendUidController.clear();
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.error_outline,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Expanded(
                                                    child: Text(
                                                        'Failed to send friend request'),
                                                  ),
                                                ],
                                              ),
                                              backgroundColor:
                                                  Colors.red.shade900,
                                              behavior:
                                                  SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple.shade900,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: provider.isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : const Text(
                                        'Send Request',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
          ),
        ),
      ),
    );
  }

  void _shakeDialog() {
    _shakeController.forward(from: 0.0);
  }

  Widget _buildQRScanner() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: (capture) {
                final List<Barcode> barcodes = capture.barcodes;
                for (final barcode in barcodes) {
                  _friendUidController.text = barcode.rawValue ?? '';
                  Navigator.pop(context);
                  // Show success feedback
                  HapticFeedback.mediumImpact();
                }
              },
            ),
            QRScannerOverlay(
              borderColor: Colors.purple,
              borderRadius: 20,
              borderLength: 30,
              borderWidth: 10,
              cutOutSize: 180,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1, 1),
          duration: 400.ms,
          curve: Curves.easeOutExpo,
        );
  }

  void _showQRCode() {
    final currentUserUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserUid == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(color: Colors.purple.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Your QR Code',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: QrImageView(
                data: currentUserUid,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Scan this code to add me as friend',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 16,
              ),
            ),
          ],
        ).animate().slideY(
              begin: 0.2,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOutExpo,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final friendsProvider = Provider.of<FriendsProvider>(context);

    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 1),
          end: const Offset(0, 0),
          duration: 600.ms,
          curve: Curves.easeOutExpo,
        ),
        FadeEffect(
          duration: 500.ms,
          curve: Curves.easeOut,
        ),
      ],
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            // Drag Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .scale(delay: 200.ms),

            // Top Actions Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _showUserProfileBottomSheet,
                    icon: const Icon(Icons.settings_rounded,
                        color: Colors.white70),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  IconButton(
                    onPressed: _toggleSearch,
                    icon: Icon(
                      _isSearching ? Icons.close : Icons.search,
                      color: Colors.white70,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

            // Search Bar (Animated)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isSearching ? 60 : 0,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    onChanged: _filterFriends,
                    decoration: InputDecoration(
                      hintText: 'Search friends...',
                      hintStyle: TextStyle(color: Colors.white60),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.1),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: Icon(Icons.search, color: Colors.white60),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.white60),
                              onPressed: () {
                                _searchController.clear();
                                _filterFriends('');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

            // Add Friend Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.purple.withOpacity(0.8),
                      Colors.blue.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.purple.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _showAddFriendDialog,
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.person_add_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add Friend',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(
                  begin: 0.2,
                  end: 0,
                  delay: 300.ms,
                  curve: Curves.easeOutExpo,
                ),

            // Custom Tab Bar
            Container(
  margin: const EdgeInsets.symmetric(horizontal: 20),
  height: 50, // Reduced height for a sleeker look
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(0.03),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withOpacity(0.05),
      width: 1,
    ),
  ),
  child: LayoutBuilder(
    builder: (context, constraints) {
      double tabWidth = constraints.maxWidth / 2.2; // Adjust width dynamically

      return TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blue.withOpacity(0.8),
              Colors.purple.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(4),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white38,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14, // Reduced font size for better fit
        ),
        tabs: [
          Tab(
            child: SizedBox(
              width: tabWidth, // Dynamically set width
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_rounded, size: 18), // Slightly smaller icon
                  const SizedBox(width: 6),
                  Text(
                    'Friends',
                    style: TextStyle(
                      fontSize: 14, // Match label size
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Tab(
            child: SizedBox(
              width: tabWidth, // Dynamically set width
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.pending_rounded, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Requests',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (friendsProvider.friendRequests.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        friendsProvider.friendRequests.length.toString(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  ),
).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(
      begin: 0.2,
      end: 0,
      delay: 400.ms,
      curve: Curves.easeOutExpo,
    ),

            // Tab Bar View
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFriendsList(friendsProvider),
                  _buildRequestsList(friendsProvider),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _showQRCode,
                  icon: const Icon(Icons.qr_code),
                  label: const Text('Show My QR Code'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade900,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsList(FriendsProvider friendsProvider) {
    final displayList = _isSearching && _searchController.text.isNotEmpty
        ? _filteredFriends
        : friendsProvider.friends;

    if (displayList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.white24,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No matching friends found' : 'No friends yet',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 18,
              ),
            ),
            if (_isSearching) ...[
              const SizedBox(height: 8),
              Text(
                'Try a different search',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: displayList.length,
      itemBuilder: (context, index) {
        final friend = displayList[index];
        return _buildFriendItem(friend, friendsProvider)
            .animate()
            .fadeIn(delay: (100 * index).ms, duration: 400.ms)
            .slideX(
              begin: 0.2,
              end: 0,
              delay: (100 * index).ms,
              curve: Curves.easeOutExpo,
            );
      },
    );
  }

  Widget _buildRequestsList(FriendsProvider friendsProvider) {
    return Consumer<FriendsProvider>(
      builder: (context, provider, child) {
        if (provider.friendRequests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.pending_actions_outlined,
                  size: 64,
                  color: Colors.white24,
                ),
                SizedBox(height: 16),
                Text(
                  'No pending requests',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          itemCount: provider.friendRequests.length,
          itemBuilder: (context, index) {
            final request = provider.friendRequests[index];
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: ListTile(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: CircleAvatar(
                  radius: 25,
                  backgroundImage: request['photoURL'] != null
                      ? NetworkImage(request['photoURL'])
                      : null,
                  backgroundColor: Colors.white24,
                  child: request['photoURL'] == null
                      ? Text(
                          request['name']?[0]?.toUpperCase() ?? '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                title: Text(
                  request['name'] ?? 'Unknown',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  request['type'] == 'received'
                      ? 'Wants to be your friend'
                      : 'Request sent',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
                trailing: request['type'] == 'received'
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(Icons.check_circle_outline,
                                color: Colors.green),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              provider.acceptFriendRequest(request['uid']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Friend request accepted'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                          ),
                          IconButton(
                            icon:
                                Icon(Icons.cancel_outlined, color: Colors.red),
                            onPressed: () {
                              HapticFeedback.mediumImpact();
                              provider.removeFriend(request['uid']);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Friend request declined'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      )
                    : IconButton(
                        icon: Icon(Icons.cancel_outlined, color: Colors.red),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          provider.removeFriend(request['uid']);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Friend request cancelled'),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFriendOptions(
      Map<String, dynamic> friend, FriendsProvider provider) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Animate(
        effects: [
          SlideEffect(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
            duration: 600.ms,
            curve: Curves.easeOutExpo,
          ),
          FadeEffect(
            duration: 500.ms,
            curve: Curves.easeOut,
          ),
        ],
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.4,
            maxHeight: MediaQuery.of(context).size.height * 0.70,
          ),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .scale(delay: 200.ms),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: friend['photoURL'] != null
                          ? NetworkImage(friend['photoURL'])
                          : null,
                      backgroundColor: Colors.white12,
                      child: friend['photoURL'] == null
                          ? Text(
                              friend['name']?[0]?.toUpperCase() ?? '?',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          friend['name'] ?? 'Unknown',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Friend',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
              const Divider(color: Colors.white10),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  children: [
                    _buildOptionButton(
                      icon: Icons.block_outlined,
                      title: 'Block User',
                      subtitle: 'Prevent any interaction',
                      color: Colors.red,
                      emoji: '🚫',
                      onTap: () =>
                          _showFriendActionDialog('block', friend, provider),
                      delay: 400,
                    ).animate().slideY(
                          begin: 1,
                          end: 0,
                          delay: 400.ms,
                          duration: 500.ms,
                          curve: Curves.easeOutExpo,
                        ),
                    const SizedBox(height: 12),
                    _buildOptionButton(
                      icon: Icons.report_outlined,
                      title: 'Report User',
                      subtitle: 'Report inappropriate behavior',
                      color: Colors.orange,
                      emoji: '⚠️',
                      onTap: () =>
                          _showFriendActionDialog('report', friend, provider),
                      delay: 500,
                    ).animate().slideY(
                          begin: 1,
                          end: 0,
                          delay: 500.ms,
                          duration: 500.ms,
                          curve: Curves.easeOutExpo,
                        ),
                    const SizedBox(height: 12),
                    _buildOptionButton(
                      icon: Icons.person_remove_outlined,
                      title: 'Remove Friend',
                      subtitle: 'Remove from friends list',
                      color: Colors.purple,
                      emoji: '👋',
                      onTap: () =>
                          _showFriendActionDialog('remove', friend, provider),
                      delay: 600,
                    ).animate().slideY(
                          begin: 1,
                          end: 0,
                          delay: 600.ms,
                          duration: 500.ms,
                          curve: Curves.easeOutExpo,
                        ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms, duration: 400.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    delay: 700.ms,
                    curve: Curves.easeOutExpo,
                  ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String emoji,
    required VoidCallback onTap,
    required int delay,
  }) {
    return InkWell(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withOpacity(0.5), width: 2),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  Icon(icon, color: color, size: 22),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color.withOpacity(0.7),
              size: 24,
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms, duration: 400.ms).slideX(
          begin: 0.2,
          end: 0,
          delay: delay.ms,
          curve: Curves.easeOutExpo,
        );
  }

  void _showFriendActionDialog(
      String action, Map<String, dynamic> friend, FriendsProvider provider) {
    Navigator.pop(context); // Close options sheet
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Animate(
        effects: [
          SlideEffect(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
            duration: 600.ms,
            curve: Curves.easeOutExpo,
          ),
          FadeEffect(
            duration: 500.ms,
            curve: Curves.easeOut,
          ),
        ],
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.3,
            maxHeight: MediaQuery.of(context).size.height * 0.5,
          ),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              )
                  .animate()
                  .fadeIn(duration: 400.ms, delay: 200.ms)
                  .scale(delay: 200.ms),

              // Title and Icon
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getActionColor(action).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getActionIcon(action),
                        color: _getActionColor(action),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getActionTitle(action),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${friend['name']}',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _getActionMessage(action, friend['name']),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                    height: 1.5,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const Spacer(),

              // Action Buttons
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () =>
                            _handleAction(action, friend, provider),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor:
                              _getActionColor(action).withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          _getActionButtonText(action),
                          style: TextStyle(
                            color: _getActionColor(action),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(context);
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.white.withOpacity(0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 400.ms),

              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for action dialog
  Color _getActionColor(String action) {
    switch (action) {
      case 'block':
        return Colors.red;
      case 'report':
        return Colors.orange;
      case 'remove':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  IconData _getActionIcon(String action) {
    switch (action) {
      case 'block':
        return Icons.block;
      case 'report':
        return Icons.report_problem;
      case 'remove':
        return Icons.person_remove;
      default:
        return Icons.error_outline;
    }
  }

  String _getActionTitle(String action) {
    switch (action) {
      case 'block':
        return 'Block User';
      case 'report':
        return 'Report User';
      case 'remove':
        return 'Remove Friend';
      default:
        return 'Action';
    }
  }

  String _getActionMessage(String action, String name) {
    switch (action) {
      case 'block':
        return 'Are you sure you want to block $name? You won\'t see their messages or receive any requests from them.';
      case 'report':
        return 'Are you sure you want to report $name? Our team will review your report.';
      case 'remove':
        return 'Are you sure you want to remove $name from your friends list?';
      default:
        return 'Are you sure you want to proceed with this action?';
    }
  }

  String _getActionButtonText(String action) {
    switch (action) {
      case 'block':
        return 'Block User';
      case 'report':
        return 'Submit Report';
      case 'remove':
        return 'Remove Friend';
      default:
        return 'Confirm';
    }
  }

  void _handleAction(
      String action, Map<String, dynamic> friend, FriendsProvider provider) {
    switch (action) {
      case 'block':
        // TODO: Implement block functionality
        break;
      case 'report':
        // TODO: Implement report functionality
        break;
      case 'remove':
        provider.removeFriend(friend['uid']);
        break;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_getActionSuccessMessage(action, friend['name'])),
        backgroundColor: _getActionColor(action),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  String _getActionSuccessMessage(String action, String name) {
    switch (action) {
      case 'block':
        return '$name has been blocked';
      case 'report':
        return 'Report submitted successfully';
      case 'remove':
        return '$name removed from friends';
      default:
        return 'Action completed successfully';
    }
  }

  Widget _buildFriendItem(
      Map<String, dynamic> friend, FriendsProvider friendsProvider) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Hero(
          tag: 'friend-avatar-${friend['uid']}',
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundImage: friend['photoURL'] != null
                  ? NetworkImage(friend['photoURL'])
                  : null,
              backgroundColor: Colors.white24,
              child: friend['photoURL'] == null
                  ? Text(
                      friend['name']?[0]?.toUpperCase() ?? '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        title: Text(
          friend['name'] ?? 'Unknown',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.more_horiz, color: Colors.white70),
          onPressed: () {
            HapticFeedback.mediumImpact();
            _showFriendOptions(friend, friendsProvider);
          },
        ),
      ),
    );
  }
}

class QRScannerOverlay extends StatelessWidget {
  const QRScannerOverlay({
    Key? key,
    this.borderColor = Colors.white,
    this.borderRadius = 0,
    this.borderLength = 40,
    this.borderWidth = 5,
    this.cutOutSize = 250,
  }) : super(key: key);

  final Color borderColor;
  final double borderRadius;
  final double borderLength;
  final double borderWidth;
  final double cutOutSize;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(0.5),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  height: cutOutSize,
                  width: cutOutSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(borderRadius),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: cutOutSize,
            height: cutOutSize,
            decoration: BoxDecoration(
              border: Border.all(color: borderColor, width: borderWidth),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        ),
      ],
    );
  }
}
