# Usage Examples

This document provides practical usage examples for the Relationship Service methods.

## Basic Usage Patterns

### Sending and Managing Friend Requests

```dart
class FriendRequestManager {
  final RelationshipService _relationshipService;
  
  FriendRequestManager(this._relationshipService);
  
  /// Send a friend request with proper error handling
  Future<bool> sendFriendRequest(String friendId) async {
    try {
      final relationship = await _relationshipService.sendFriendRequest(friendId);
      
      // Log successful request
      print('Friend request sent: ${relationship.id}');
      
      // Show success message to user
      _showSuccess('Friend request sent successfully!');
      
      return true;
      
    } on RelationshipException catch (e) {
      _handleFriendRequestError(e);
      return false;
    } catch (e) {
      _showError('An unexpected error occurred');
      return false;
    }
  }
  
  /// Handle friend request response
  Future<void> respondToFriendRequest(String requestId, bool accept) async {
    try {
      if (accept) {
        final relationship = await _relationshipService.acceptFriendRequest(requestId);
        _showSuccess('You are now friends!');
        
        // Update UI to reflect new friendship
        _updateFriendsList();
        
      } else {
        await _relationshipService.declineFriendRequest(requestId);
        _showInfo('Friend request declined');
      }
      
      // Refresh pending requests
      _refreshPendingRequests();
      
    } on RelationshipException catch (e) {
      _handleFriendRequestError(e);
    }
  }
  
  void _handleFriendRequestError(RelationshipException e) {
    switch (e.code) {
      case RelationshipErrorCode.userNotFound:
        _showError('User not found');
        break;
      case RelationshipErrorCode.alreadyFriends:
        _showInfo('You are already friends with this user');
        break;
      case RelationshipErrorCode.requestAlreadyExists:
        _showInfo('Friend request already sent');
        break;
      case RelationshipErrorCode.userBlocked:
        _showError('Unable to send friend request');
        break;
      default:
        _showError('Failed to process friend request');
    }
  }
}
```

### Building a Friends List UI

```dart
class FriendsListWidget extends StatefulWidget {
  @override
  _FriendsListWidgetState createState() => _FriendsListWidgetState();
}

class _FriendsListWidgetState extends State<FriendsListWidget> {
  final RelationshipService _relationshipService = GetIt.instance();
  
  List<RelationshipModel> _friends = [];
  Map<String, CachedProfile> _profiles = {};
  bool _loading = false;
  bool _hasMorePages = false;
  int _currentPage = 1;
  
  @override
  void initState() {
    super.initState();
    _loadFriends();
  }
  
  Future<void> _loadFriends({bool loadMore = false}) async {
    if (_loading) return;
    
    setState(() {
      _loading = true;
    });
    
    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final result = await _relationshipService.getFriends(
        page: page,
        pageSize: 20,
      );
      
      setState(() {
        if (loadMore) {
          _friends.addAll(result.relationships);
          _currentPage = page;
        } else {
          _friends = result.relationships;
          _currentPage = 1;
        }
        
        // Update profiles map
        for (final profile in result.profiles) {
          _profiles[profile.id] = profile;
        }
        
        _hasMorePages = result.hasNextPage;
        _loading = false;
      });
      
    } on RelationshipException catch (e) {
      setState(() {
        _loading = false;
      });
      
      _showError('Failed to load friends: ${e.message}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadFriends,
      child: ListView.builder(
        itemCount: _friends.length + (_hasMorePages ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _friends.length) {
            // Load more indicator
            return _buildLoadMoreButton();
          }
          
          final relationship = _friends[index];
          final profile = _profiles[relationship.friendId];
          
          return _buildFriendTile(relationship, profile);
        },
      ),
    );
  }
  
  Widget _buildFriendTile(RelationshipModel relationship, CachedProfile? profile) {
    if (profile == null) return SizedBox.shrink();
    
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile.photoURL != null
            ? NetworkImage(profile.photoURL!)
            : null,
        child: profile.photoURL == null
            ? Text(profile.displayName[0].toUpperCase())
            : null,
      ),
      title: Text(profile.displayName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Profile updated ${_formatTime(profile.lastUpdated)}',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'view_profile',
            child: Text('View Profile'),
          ),
          PopupMenuItem(
            value: 'remove_friend',
            child: Text('Remove Friend'),
          ),
          PopupMenuItem(
            value: 'block_user',
            child: Text('Block User'),
          ),
        ],
        onSelected: (value) => _handleFriendAction(value, relationship),
      ),
    );
  }
  
  Future<void> _handleFriendAction(String action, RelationshipModel relationship) async {
    switch (action) {
      case 'remove_friend':
        await _removeFriend(relationship.friendId);
        break;
      case 'block_user':
        await _blockUser(relationship.friendId);
        break;
      case 'view_profile':
        _navigateToProfile(relationship.friendId);
        break;
    }
  }
  
  Future<void> _removeFriend(String friendId) async {
    final confirmed = await _showConfirmDialog(
      'Remove Friend',
      'Are you sure you want to remove this friend?',
    );
    
    if (!confirmed) return;
    
    try {
      await _relationshipService.removeFriend(friendId);
      
      setState(() {
        _friends.removeWhere((r) => r.friendId == friendId);
      });
      
      _showSuccess('Friend removed');
      
    } on RelationshipException catch (e) {
      _showError('Failed to remove friend: ${e.message}');
    }
  }
}
```

### Implementing Friend Request Notifications

```dart
class FriendRequestNotificationService {
  final RelationshipService _relationshipService;
  final NotificationService _notificationService;
  
  FriendRequestNotificationService(
    this._relationshipService,
    this._notificationService,
  );
  
  /// Check for new friend requests and show notifications
  Future<void> checkForNewRequests() async {
    try {
      final result = await _relationshipService.getIncomingRequests(pageSize: 50);
      
      for (final relationship in result.relationships) {
        final profile = result.profiles.firstWhere(
          (p) => p.id == relationship.userId,
        );
        
        // Check if we've already notified about this request
        if (!_hasBeenNotified(relationship.id)) {
          await _showFriendRequestNotification(relationship, profile);
          _markAsNotified(relationship.id);
        }
      }
      
    } on RelationshipException catch (e) {
      print('Failed to check friend requests: ${e.message}');
    }
  }
  
  Future<void> _showFriendRequestNotification(
    RelationshipModel relationship,
    CachedProfile profile,
  ) async {
    await _notificationService.show(
      id: relationship.id.hashCode,
      title: 'New Friend Request',
      body: '${profile.displayName} wants to be your friend',
      payload: jsonEncode({
        'type': 'friend_request',
        'request_id': relationship.id,
      }),
      actions: [
        NotificationAction(
          id: 'accept',
          title: 'Accept',
        ),
        NotificationAction(
          id: 'decline',
          title: 'Decline',
        ),
      ],
    );
  }
  
  /// Handle notification action responses
  Future<void> handleNotificationAction(String action, String payload) async {
    final data = jsonDecode(payload) as Map<String, dynamic>;
    
    if (data['type'] != 'friend_request') return;
    
    final requestId = data['request_id'] as String;
    
    try {
      switch (action) {
        case 'accept':
          await _relationshipService.acceptFriendRequest(requestId);
          await _notificationService.show(
            title: 'Friend Request Accepted',
            body: 'You are now friends!',
          );
          break;
          
        case 'decline':
          await _relationshipService.declineFriendRequest(requestId);
          break;
      }
      
    } on RelationshipException catch (e) {
      await _notificationService.show(
        title: 'Error',
        body: 'Failed to process friend request',
      );
    }
  }
}
```

### User Profile Integration

```dart
class UserProfileScreen extends StatefulWidget {
  final String userId;
  
  const UserProfileScreen({required this.userId});
  
  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final RelationshipService _relationshipService = GetIt.instance();
  
  RelationshipModel? _relationship;
  List<CachedProfile> _mutualFriends = [];
  bool _loading = false;
  
  @override
  void initState() {
    super.initState();
    _loadRelationshipData();
  }
  
  Future<void> _loadRelationshipData() async {
    setState(() {
      _loading = true;
    });
    
    try {
      // Load relationship status
      _relationship = await _relationshipService.getRelationship(widget.userId);
      
      // Load mutual friends
      _mutualFriends = await _relationshipService.getMutualFriends(widget.userId);
      
      setState(() {
        _loading = false;
      });
      
    } on RelationshipException catch (e) {
      setState(() {
        _loading = false;
      });
      
      print('Failed to load relationship data: ${e.message}');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
        actions: [
          if (!_loading) _buildActionButton(),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : _buildProfileContent(),
    );
  }
  
  Widget _buildActionButton() {
    if (_relationship == null) {
      // No relationship - show send friend request button
      return IconButton(
        icon: Icon(Icons.person_add),
        onPressed: _sendFriendRequest,
      );
    }
    
    switch (_relationship!.status) {
      case RelationshipStatus.pending:
        if (_relationship!.userId == widget.userId) {
          // Incoming request - show accept/decline
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(Icons.check, color: Colors.green),
                onPressed: _acceptFriendRequest,
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.red),
                onPressed: _declineFriendRequest,
              ),
            ],
          );
        } else {
          // Outgoing request - show pending indicator
          return IconButton(
            icon: Icon(Icons.schedule),
            onPressed: null,
          );
        }
        
      case RelationshipStatus.accepted:
        // Friends - show options menu
        return PopupMenuButton(
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'remove_friend',
              child: Text('Remove Friend'),
            ),
            PopupMenuItem(
              value: 'block_user',
              child: Text('Block User'),
            ),
          ],
          onSelected: _handleFriendAction,
        );
        
      case RelationshipStatus.blocked:
        if (_relationship!.userId == getCurrentUserId()) {
          // Current user blocked this user - show unblock option
          return IconButton(
            icon: Icon(Icons.block),
            onPressed: _unblockUser,
          );
        } else {
          // This user blocked current user - no actions available
          return SizedBox.shrink();
        }
        
      default:
        return SizedBox.shrink();
    }
  }
  
  Widget _buildProfileContent() {
    return Column(
      children: [
        _buildRelationshipStatus(),
        if (_mutualFriends.isNotEmpty) _buildMutualFriends(),
        // ... other profile content
      ],
    );
  }
  
  Widget _buildRelationshipStatus() {
    if (_relationship == null) {
      return Card(
        child: ListTile(
          leading: Icon(Icons.person_outline),
          title: Text('No relationship'),
          subtitle: Text('Send a friend request to connect'),
        ),
      );
    }
    
    String statusText;
    IconData statusIcon;
    Color statusColor;
    
    switch (_relationship!.status) {
      case RelationshipStatus.pending:
        if (_relationship!.userId == widget.userId) {
          statusText = 'Sent you a friend request';
          statusIcon = Icons.person_add;
          statusColor = Colors.orange;
        } else {
          statusText = 'Friend request sent';
          statusIcon = Icons.schedule;
          statusColor = Colors.blue;
        }
        break;
        
      case RelationshipStatus.accepted:
        statusText = 'Friends since ${_formatDate(_relationship!.createdAt)}';
        statusIcon = Icons.people;
        statusColor = Colors.green;
        break;
        
      case RelationshipStatus.blocked:
        statusText = 'Blocked';
        statusIcon = Icons.block;
        statusColor = Colors.red;
        break;
        
      default:
        statusText = 'Unknown status';
        statusIcon = Icons.help;
        statusColor = Colors.grey;
    }
    
    return Card(
      child: ListTile(
        leading: Icon(statusIcon, color: statusColor),
        title: Text(statusText),
      ),
    );
  }
  
  Widget _buildMutualFriends() {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Mutual Friends (${_mutualFriends.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16),
              itemCount: _mutualFriends.length,
              itemBuilder: (context, index) {
                final friend = _mutualFriends[index];
                return _buildMutualFriendAvatar(friend);
              },
            ),
          ),
          SizedBox(height: 16),
        ],
      ),
    );
  }
  
  Future<void> _sendFriendRequest() async {
    try {
      await _relationshipService.sendFriendRequest(widget.userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent!')),
      );
      
      await _loadRelationshipData();
      
    } on RelationshipException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_getErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _acceptFriendRequest() async {
    try {
      await _relationshipService.acceptFriendRequest(_relationship!.id);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request accepted!')),
      );
      
      await _loadRelationshipData();
      
    } on RelationshipException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept friend request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

### Batch Operations

```dart
class RelationshipBatchOperations {
  final RelationshipService _relationshipService;
  
  RelationshipBatchOperations(this._relationshipService);
  
  /// Accept multiple friend requests at once
  Future<BatchOperationResult> acceptMultipleRequests(List<String> requestIds) async {
    final results = <String, bool>{};
    final errors = <String, String>{};
    
    for (final requestId in requestIds) {
      try {
        await _relationshipService.acceptFriendRequest(requestId);
        results[requestId] = true;
      } on RelationshipException catch (e) {
        results[requestId] = false;
        errors[requestId] = e.message;
      }
    }
    
    return BatchOperationResult(
      successCount: results.values.where((success) => success).length,
      totalCount: requestIds.length,
      errors: errors,
    );
  }
  
  /// Block multiple users at once
  Future<BatchOperationResult> blockMultipleUsers(List<String> userIds) async {
    final results = <String, bool>{};
    final errors = <String, String>{};
    
    for (final userId in userIds) {
      try {
        await _relationshipService.blockUser(userId);
        results[userId] = true;
      } on RelationshipException catch (e) {
        results[userId] = false;
        errors[userId] = e.message;
      }
    }
    
    return BatchOperationResult(
      successCount: results.values.where((success) => success).length,
      totalCount: userIds.length,
      errors: errors,
    );
  }
  
  /// Import friends from external source
  Future<ImportResult> importFriends(List<String> externalUserIds) async {
    final successful = <String>[];
    final failed = <String, String>{};
    final alreadyFriends = <String>[];
    
    for (final externalId in externalUserIds) {
      try {
        // Convert external ID to internal user ID
        final userId = await _resolveExternalId(externalId);
        
        // Check if already friends
        if (await _relationshipService.isFriend(userId)) {
          alreadyFriends.add(userId);
          continue;
        }
        
        // Send friend request
        await _relationshipService.sendFriendRequest(userId);
        successful.add(userId);
        
        // Add delay to avoid rate limiting
        await Future.delayed(Duration(milliseconds: 100));
        
      } on RelationshipException catch (e) {
        failed[externalId] = e.message;
      } catch (e) {
        failed[externalId] = 'Failed to resolve user';
      }
    }
    
    return ImportResult(
      successful: successful,
      failed: failed,
      alreadyFriends: alreadyFriends,
    );
  }
}

class BatchOperationResult {
  final int successCount;
  final int totalCount;
  final Map<String, String> errors;
  
  BatchOperationResult({
    required this.successCount,
    required this.totalCount,
    required this.errors,
  });
  
  bool get hasErrors => errors.isNotEmpty;
  int get failureCount => totalCount - successCount;
  double get successRate => successCount / totalCount;
}

class ImportResult {
  final List<String> successful;
  final Map<String, String> failed;
  final List<String> alreadyFriends;
  
  ImportResult({
    required this.successful,
    required this.failed,
    required this.alreadyFriends,
  });
}
```

### Real-time Updates with Streams

```dart
class RelationshipStreamService {
  final RelationshipService _relationshipService;
  final StreamController<RelationshipUpdate> _updateController;
  
  Stream<RelationshipUpdate> get updateStream => _updateController.stream;
  
  RelationshipStreamService(this._relationshipService)
      : _updateController = StreamController<RelationshipUpdate>.broadcast();
  
  /// Listen to relationship changes and emit updates
  void startListening() {
    // Set up periodic checks for relationship changes
    Timer.periodic(Duration(seconds: 30), _checkForUpdates);
    
    // Listen to real-time events if available
    _listenToRealTimeEvents();
  }
  
  Future<void> _checkForUpdates(Timer timer) async {
    try {
      // Check for new incoming requests
      final incomingResult = await _relationshipService.getIncomingRequests(pageSize: 50);
      
      for (final relationship in incomingResult.relationships) {
        if (_isNewRequest(relationship)) {
          final profile = incomingResult.profiles.firstWhere(
            (p) => p.id == relationship.userId,
          );
          
          _updateController.add(RelationshipUpdate(
            type: RelationshipUpdateType.newIncomingRequest,
            relationship: relationship,
            profile: profile,
          ));
        }
      }
      
      // Check for accepted/declined requests
      await _checkOutgoingRequestUpdates();
      
    } catch (e) {
      print('Error checking for relationship updates: $e');
    }
  }
  
  void dispose() {
    _updateController.close();
  }
}

enum RelationshipUpdateType {
  newIncomingRequest,
  requestAccepted,
  requestDeclined,
  friendRemoved,
  userBlocked,
  userUnblocked,
}

class RelationshipUpdate {
  final RelationshipUpdateType type;
  final RelationshipModel relationship;
  final CachedProfile? profile;
  
  RelationshipUpdate({
    required this.type,
    required this.relationship,
    this.profile,
  });
}
```
