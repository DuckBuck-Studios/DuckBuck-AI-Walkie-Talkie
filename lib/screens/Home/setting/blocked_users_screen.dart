import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'dart:async'; 
import '../../../providers/friend_provider.dart';
import '../../../widgets/animated_background.dart';

class BlockedUsersScreen extends StatefulWidget {
  final Function(BuildContext)? onBackPressed;
  
  const BlockedUsersScreen({
    super.key,
    this.onBackPressed,
  });

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _blockedUsers = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Add listener to handle network connectivity changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadBlockedUsers();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  Future<void> _loadBlockedUsers() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get the friend provider and load blocked users
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      
      // Debugging information
      print("Loading blocked users, provider has ${friendProvider.blockedUsers.length} blocked users");
      
      // Make sure the provider is initialized
      if (!friendProvider.isInitializing) {
        // The provider already loads blocked users through its streams
        // Just get the current list
        setState(() {
          _blockedUsers = List.from(friendProvider.blockedUsers);
          _isLoading = false;
        });
        
        print("Blocked users loaded: ${_blockedUsers.length}");
        
        // Force a refresh if the list is empty - there might be a stream not set up yet
        if (_blockedUsers.isEmpty) {
          // Show retry options if the list is still empty after trying to load
          try {
            // This will force refresh data from Firestore with a timeout
            await friendProvider.initialize().timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException('Network request timed out. Please check your connection.');
              }
            );
            
            if (mounted) {
              setState(() {
                _blockedUsers = List.from(friendProvider.blockedUsers);
                _isLoading = false;
              });
            }
            print("After re-init, blocked users count: ${_blockedUsers.length}");
          } catch (e) {
            print("Error during provider initialization: $e");
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = e is TimeoutException 
                    ? 'Network request timed out. Please check your connection and try again.' 
                    : 'Could not load blocked users: ${e.toString()}';
              });
            }
          }
        }
      } else {
        // If still initializing, wait for it to complete with a timeout
        print("Provider is initializing, waiting...");
        
        try {
          // Wait for initialization with timeout
          await Future.delayed(const Duration(seconds: 5))
              .timeout(const Duration(seconds: 10), onTimeout: () {
            throw TimeoutException('Network request timed out during initialization.');
          });
          
          if (mounted) {
            _loadBlockedUsers();
          }
        } catch (e) {
          print("Initialization timeout: $e");
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = e is TimeoutException
                  ? 'Network request timed out. Please check your connection and try again.'
                  : 'Error loading data: ${e.toString()}';
            });
          }
        }
      }
    } catch (e) {
      print("Error loading blocked users: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is TimeoutException
              ? 'Network request timed out. Please check your connection and try again.'
              : 'Failed to load blocked users: ${e.toString()}';
        });
      }
    }
  }

  Future<void> _unblockUser(String userId, String displayName) async {
    // Show a confirmation dialog
    final shouldUnblock = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFF5E8C7),
        title: const Text(
          'Unblock User',
          style: TextStyle(color: Color(0xFF8B4513), fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to unblock $displayName?',
          style: const TextStyle(color: Color(0xFF8B4513)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A76A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Unblock'),
          ),
        ],
      ).animate().fadeIn(duration: 300.ms).scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        curve: Curves.easeOutBack,
      ),
    ) ?? false;

    if (!shouldUnblock) return;
    
    print("Starting to unblock user: $userId, $displayName");

    // Show loading state
    setState(() => _isLoading = true);

    // Show loading snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Unblocking user...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF8B4513),
        ),
      );
    }

    try {
      // Call the service to unblock the user with timeout
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      print("Calling unblockUser on provider for userId: $userId");
      
      final result = await friendProvider.unblockUser(userId)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Network request timed out while trying to unblock user.');
      });
      
      print("Unblock result: $result");

      if (mounted) {
        if (result['success'] == true) {
          // Haptic feedback
          HapticFeedback.mediumImpact();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Unblocked $displayName successfully'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
          
          // Wait a brief moment to ensure the Firestore changes are reflected
          await Future.delayed(const Duration(milliseconds: 500));
          
          // Refresh the list
          _loadBlockedUsers();
        } else {
          // Haptic feedback for error
          HapticFeedback.vibrate();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 12),
                  Text('Failed to unblock user: ${result['error'] ?? 'Unknown error'}'),
                ],
              ),
              backgroundColor: Colors.red,
            ),
          );
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print("Error in unblockUser: $e");
      if (mounted) {
        // Handle specific timeout errors
        final errorMessage = e is TimeoutException
            ? 'Network timeout. Please check your connection and try again.'
            : 'Error unblocking user: $e';
            
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  // Handle back button press with custom transition if provided
  void _handleBackPress() {
    if (widget.onBackPressed != null) {
      widget.onBackPressed!(context);
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5E8C7),
        elevation: 0,
        title: const Text(
          'Blocked Users',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF8B4513)),
          onPressed: _handleBackPress,
        ),
      ),
      body: DuckBuckAnimatedBackground(
        opacity: 0.03,
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              _buildTopBar(context),
              
              // Content
              Expanded(
                child: _isLoading 
                  ? _buildLoadingView()
                  : _errorMessage != null
                      ? _buildErrorView()
                      : _blockedUsers.isEmpty
                          ? _buildEmptyState()
                          : _buildBlockedUsersList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    // Get screen dimensions and safe area for responsive layout
    final double screenWidth = MediaQuery.of(context).size.width;
    final EdgeInsets safePadding = MediaQuery.of(context).padding;
    final bool isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.only(
        left: 8, 
        right: 8, 
        top: 16,
        bottom: 16
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF5E8C7), // Using warmGheeColor from AnimatedBackground
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        // Remove the black shadow/filter
      ),
      child: Row(
        children: [
          // Standard back button for all platforms
          SizedBox(
            width: isSmallScreen ? 44 : 48,
            height: isSmallScreen ? 44 : 48,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              iconSize: isSmallScreen ? 20 : 24,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              color: const Color(0xFF8B4513), // Updated to match theme
            ),
          ),
          Expanded(
            child: Text(
              'Blocked Users',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF8B4513), // Updated to match theme
              ),
            ),
          ),
          // Maintain symmetry with a placeholder of the same size as the back button
          SizedBox(width: isSmallScreen ? 44 : 48),
        ],
      ),
    ).animate(autoPlay: true)
      .fadeIn(duration: 300.ms)
      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad, duration: 300.ms);
  }

  Widget _buildLoadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 150,
            width: 150,
            child: Lottie.asset(
              'assets/animations/loading1.json',
              animate: true,
              repeat: true,
            ),
          ).animate(autoPlay: true)
            .fadeIn(duration: 400.ms)
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              curve: Curves.easeOutBack,
              duration: 600.ms,
            ),
          const SizedBox(height: 16),
          const Text(
            'Loading blocked users...',
            style: TextStyle(
              color: Color(0xFF8B4513),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ).animate(autoPlay: true)
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.2, end: 0, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFE6C38D).withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.block,
              size: 60,
              color: Color(0xFFD4A76A),
            ),
          ).animate(autoPlay: true)
            .fadeIn()
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              curve: Curves.easeOutBack,
              duration: 600.ms,
            ),
          const SizedBox(height: 24),
          const Text(
            'No Blocked Users',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B4513),
            ),
          ).animate(autoPlay: true)
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 12),
          const Text(
            'You haven\'t blocked any users',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF8B4513),
              fontWeight: FontWeight.w400,
            ),
          ).animate(autoPlay: true)
            .fadeIn(delay: 300.ms)
            .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _loadBlockedUsers,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A76A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ).animate(autoPlay: true)
            .fadeIn(delay: 400.ms)
            .slideY(begin: 0.2, end: 0)
            .shimmer(
              duration: 1.seconds,
              delay: 600.ms,
              color: Colors.white.withOpacity(0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEEEE),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
          ).animate(autoPlay: true)
            .fadeIn()
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              curve: Curves.easeOutBack,
            ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF8B4513),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadBlockedUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A76A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ).animate(autoPlay: true)
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.2, end: 0)
                .shimmer(
                  duration: 1.seconds,
                  delay: 600.ms,
                  color: Colors.white.withOpacity(0.5),
                ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B4513),
                  side: const BorderSide(color: Color(0xFFD4A76A)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ).animate(autoPlay: true)
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.2, end: 0),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlockedUsersList() {
    return RefreshIndicator(
      onRefresh: _loadBlockedUsers,
      color: const Color(0xFFD4A76A),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _blockedUsers.length,
        itemBuilder: (context, index) {
          final user = _blockedUsers[index];
          final userId = user['id'] as String;
          final displayName = user['displayName'] as String? ?? 'Unknown User';
          final photoURL = user['photoURL'] as String?;
          final blockReason = user['blockReason'] as String? ?? 'Manual block';
          final blockDate = user['blockedAt'] != null 
              ? (user['blockedAt'] as DateTime).toString().split(' ')[0]
              : 'Unknown date';
              
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF5E8C7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD4A76A).withOpacity(0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Material(
                color: Colors.transparent,
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD4A76A),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFD4A76A).withOpacity(0.2),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: photoURL != null 
                              ? Image.network(
                                  photoURL,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    color: const Color(0xFFE6C38D).withOpacity(0.5),
                                    child: Center(
                                      child: Text(
                                        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: Color(0xFF8B4513),
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              : Container(
                                  color: const Color(0xFFE6C38D).withOpacity(0.5),
                                  child: Center(
                                    child: Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        color: Color(0xFF8B4513),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 14,
                                color: Color(0xFF8B4513),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Blocked on $blockDate',
                                style: TextStyle(
                                  color: const Color(0xFF8B4513).withOpacity(0.7),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Color(0xFF8B4513),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Reason: $blockReason',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: const Color(0xFF8B4513).withOpacity(0.7),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.block,
                          color: Colors.red,
                          size: 20,
                        ),
                      ),
                    ),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFE6C38D),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _unblockUser(userId, displayName),
                            icon: const Icon(Icons.person_remove_alt_1, size: 18),
                            label: const Text('Unblock User'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4A76A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            ),
                          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                            .shimmer(
                              duration: 2.seconds,
                              color: Colors.white.withOpacity(0.2),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate(autoPlay: true)
            .fadeIn(delay: Duration(milliseconds: 100 * index))
            .slideY(
              begin: 0.2,
              end: 0,
              delay: Duration(milliseconds: 100 * index),
              duration: 600.ms,
              curve: Curves.easeOutQuint,
            );
        },
      ),
    );
  }
} 