import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../../providers/friend_provider.dart';
import '../../widgets/animated_background.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

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
        title: const Text('Unblock User'),
        content: Text('Are you sure you want to unblock $displayName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A76A),
              foregroundColor: Colors.white,
            ),
            child: const Text('Unblock'),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4A76A)),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Loading blocked users...',
                            style: TextStyle(color: Color(0xFF8B4513)),
                          ),
                        ],
                      ),
                    )
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
        color: const Color(0xFFD4A76A).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button - make tap target larger on small screens
          SizedBox(
            width: isSmallScreen ? 44 : 48,
            height: isSmallScreen ? 44 : 48,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              iconSize: isSmallScreen ? 20 : 24,
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pop(context),
              color: const Color(0xFFD4A76A),
            ),
          ),
          Expanded(
            child: Text(
              'Blocked Users',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSmallScreen ? 20 : 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFD4A76A),
              ),
            ),
          ),
          // Maintain symmetry with a placeholder of the same size as the back button
          SizedBox(width: isSmallScreen ? 44 : 48),
        ],
      ),
    ).animate()
      .fadeIn()
      .slideY(begin: -0.2, end: 0, curve: Curves.easeOutQuad);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.block,
            size: 72,
            color: Color(0xFFD4A76A),
          ).animate()
            .fadeIn()
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
          const SizedBox(height: 16),
          const Text(
            'No Blocked Users',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF8B4513),
            ),
          ).animate()
            .fadeIn(delay: 200.ms)
            .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 8),
          const Text(
            'You haven\'t blocked any users yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ).animate()
            .fadeIn(delay: 300.ms)
            .slideY(begin: 0.2, end: 0),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _loadBlockedUsers,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4A76A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ).animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.2, end: 0),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade400,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ).animate()
                .fadeIn(delay: 500.ms)
                .slideY(begin: 0.2, end: 0),
            ],
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
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ).animate().fadeIn(),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'An error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
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
                ),
              ).animate().fadeIn(delay: 400.ms),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8B4513),
                  side: const BorderSide(color: Color(0xFFD4A76A)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ).animate().fadeIn(delay: 500.ms),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
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
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFD4A76A).withOpacity(0.2),
                        backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                        child: photoURL == null 
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: const TextStyle(color: Color(0xFF8B4513)),
                              ) 
                            : null,
                      ),
                      title: Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B4513),
                        ),
                      ),
                      subtitle: Text(
                        'Blocked on $blockDate',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.block,
                        color: Colors.red,
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Reason: $blockReason',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _unblockUser(userId, displayName),
                            icon: const Icon(Icons.person_remove, size: 18),
                            label: const Text('Unblock User'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFD4A76A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ).animate()
            .fadeIn(delay: Duration(milliseconds: 100 * index))
            .slideY(begin: 0.2, end: 0, delay: Duration(milliseconds: 100 * index));
        },
      ),
    );
  }
} 