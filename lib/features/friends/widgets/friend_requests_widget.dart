import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../shared/providers/shared_friends_provider.dart';
import 'empty_state_widget.dart';
import 'dart:io' show Platform;

/// Production-level widget for displaying friend requests with real-time updates
/// 
/// Features:
/// - Real-time updates from SharedFriendsProvider
/// - Accept/reject request functionality
/// - Platform-specific design (iOS/Android)
/// - Loading states and error handling
/// - Optimistic UI updates
/// - Unified caching and offline support
/// 
/// This widget handles all friend request interactions and automatically
/// updates when requests are accepted, rejected, or new ones arrive.
class FriendRequestsWidget extends StatelessWidget {
  const FriendRequestsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SharedFriendsProvider>(
      builder: (context, friendsProvider, child) {
        // Handle loading state
        if (friendsProvider.isLoadingPendingRequests && 
            friendsProvider.pendingRequests.isEmpty) {
          return _buildLoadingState();
        }

        // Handle error state
        if (friendsProvider.error != null && 
            friendsProvider.pendingRequests.isEmpty) {
          return _buildErrorState(context, friendsProvider);
        }

        // Build requests list (even if empty)
        return _buildRequestsList(context, friendsProvider);
      },
    );
  }

  /// Builds the loading state with platform-specific indicators
  Widget _buildLoadingState() {
    if (Platform.isIOS) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 16),
      );
    } else {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
  }

  /// Builds the error state with retry functionality
  Widget _buildErrorState(BuildContext context, SharedFriendsProvider provider) {
    return EmptyStateWidget(
      icon: Platform.isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
      title: 'Unable to Load Requests',
      message: provider.error ?? 'Something went wrong. Please try again.',
      actionText: 'Retry',
      onAction: () => provider.initialize(),
    );
  }

  /// Builds the friend requests list
  Widget _buildRequestsList(BuildContext context, SharedFriendsProvider provider) {
    final requests = provider.pendingRequests;

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _FriendRequestTile(
          request: requests[index],
          provider: provider,
        ),
      ),
    );
  }
}

/// Individual friend request tile with proper action filtering based on direction
class _FriendRequestTile extends StatelessWidget {
  final Map<String, dynamic> request;
  final SharedFriendsProvider provider;

  const _FriendRequestTile({
    required this.request,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final name = request['displayName'] ?? request['name'] ?? 'Unknown';
    final photoUrl = request['photoURL'];
    final relationshipId = request['relationshipId'] ?? request['id'];
    final isIncoming = request['isIncoming'] ?? false; // Get direction flag

    if (Platform.isIOS) {
      return _buildCupertinoTile(context, name, photoUrl, relationshipId, isIncoming);
    } else {
      return _buildMaterialTile(context, name, photoUrl, relationshipId, isIncoming);
    }
  }

  /// Builds iOS-style request tile
  Widget _buildCupertinoTile(BuildContext context, String name, String? photoUrl, String? relationshipId, bool isIncoming) {
    final isAccepting = relationshipId != null && provider.isProcessingAcceptRequest(relationshipId);
    final isRejecting = relationshipId != null && provider.isProcessingRejectRequest(relationshipId);
    final isCancelling = relationshipId != null && provider.isProcessingCancelRequest(relationshipId);
    final isProcessing = isAccepting || isRejecting || isCancelling;

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.separator.resolveFrom(context).withOpacity(0.3),
            offset: const Offset(0, 1),
            blurRadius: 3,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildAvatar(name, photoUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  isIncoming ? 'Wants to be your friend' : 'Request sent',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (isProcessing) ...[
            const CupertinoActivityIndicator(),
          ] else if (isIncoming) ...[
            // Show Accept/Decline for incoming requests
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: CupertinoColors.systemGreen,
                  child: const Text('Accept', style: TextStyle(fontSize: 14)),
                  onPressed: () => _acceptRequest(context, request),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: CupertinoColors.systemGrey,
                  child: const Text('Decline', style: TextStyle(fontSize: 14)),
                  onPressed: () => _rejectRequest(context, relationshipId),
                ),
              ],
            ),
          ] else ...[
            // Show Cancel for outgoing requests
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              color: CupertinoColors.systemRed,
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
              onPressed: () => _cancelRequest(context, relationshipId),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds Android-style request tile
  Widget _buildMaterialTile(BuildContext context, String name, String? photoUrl, String? relationshipId, bool isIncoming) {
    final theme = Theme.of(context);
    final isAccepting = relationshipId != null && provider.isProcessingAcceptRequest(relationshipId);
    final isRejecting = relationshipId != null && provider.isProcessingRejectRequest(relationshipId);
    final isCancelling = relationshipId != null && provider.isProcessingCancelRequest(relationshipId);
    final isProcessing = isAccepting || isRejecting || isCancelling;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _buildAvatar(name, photoUrl),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isIncoming ? 'Wants to be your friend' : 'Request sent',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (isProcessing) ...[
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (isIncoming) ...[
              // Show Accept/Decline for incoming requests
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _acceptRequest(context, request),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Accept', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _rejectRequest(context, relationshipId),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: const Text('Decline', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ] else ...[
              // Show Cancel for outgoing requests
              OutlinedButton(
                onPressed: () => _cancelRequest(context, relationshipId),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  minimumSize: Size.zero,
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds avatar with photo or initials fallback
  Widget _buildAvatar(String name, String? photoUrl) {
    // If photo URL is available, use network image
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(photoUrl),
        onBackgroundImageError: (exception, stackTrace) {
          // If image fails to load, fall back to initials
        },
        child: photoUrl.isEmpty ? _buildInitialsWidget(name) : null,
      );
    }

    // Fallback to initials avatar
    return _buildInitialsAvatar(name);
  }

  /// Builds avatar with user initials
  Widget _buildInitialsAvatar(String name) {
    final backgroundColor = _getAvatarColor(name);

    return CircleAvatar(
      radius: 24,
      backgroundColor: backgroundColor,
      child: _buildInitialsWidget(name),
    );
  }

  /// Builds the initials text widget
  Widget _buildInitialsWidget(String name) {
    final initials = _getInitials(name);
    
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  /// Extracts initials from full name
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Generates a consistent color for the avatar based on name hash
  Color _getAvatarColor(String name) {
    final colors = [
      Colors.blue.shade400,
      Colors.green.shade400,
      Colors.orange.shade400,
      Colors.purple.shade400,
      Colors.red.shade400,
      Colors.teal.shade400,
      Colors.indigo.shade400,
      Colors.pink.shade400,
    ];
    
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  /// Accepts a friend request
  Future<void> _acceptRequest(BuildContext context, Map<String, dynamic> request) async {
    final relationshipId = request['relationshipId'] ?? request['id'];
    if (relationshipId == null) return;

    // Determine the correct user ID to pass based on request direction
    final isIncoming = request['isIncoming'] ?? false;
    final fromUid = isIncoming 
        ? (request['initiatorId'] as String?) // For incoming requests, use initiatorId
        : (request['uid'] as String?);        // For outgoing requests, use uid
    
    if (fromUid == null) return;

    // Silent operation - no external error notifications
    await provider.acceptFriendRequest(fromUid);
  }

  /// Rejects a friend request
  Future<void> _rejectRequest(BuildContext context, String? relationshipId) async {
    if (relationshipId == null) return;

    // Silent operation - no external error notifications
    await provider.rejectFriendRequest(relationshipId);
  }

  /// Cancels a sent friend request
  Future<void> _cancelRequest(BuildContext context, String? relationshipId) async {
    if (relationshipId == null) return;

    // Silent operation - no external error notifications
    await provider.cancelFriendRequest(relationshipId);
  }
}
