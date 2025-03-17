import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/friend_service.dart';

class FriendProvider with ChangeNotifier {
  final FriendService _friendService = FriendService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;

  // Getters
  List<Map<String, dynamic>> get friends => _friends;
  List<Map<String, dynamic>> get pendingRequests => _pendingRequests;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get currentUserId => _currentUserId;

  // Initialize streams for current user
  void initializeFriendStreams(String currentUserId) {
    _currentUserId = currentUserId;
    print('Initializing friend streams for user: $currentUserId');
    
    // Listen to the user document for any changes to the friends array
    _firestore.collection('users').doc(currentUserId).snapshots().listen((userDoc) {
      if (userDoc.exists) {
        final friendsData = userDoc.data()?['friends'] ?? [];
        print('Received friends data from Firestore: $friendsData');
        _processFriendsData(friendsData);
      } else {
        print('User document does not exist for ID: $currentUserId');
      }
    });
  }
  
  // Process friends data from Firestore
  void _processFriendsData(List<dynamic> friendsData) async {
    print('==================== PROCESSING FRIENDS DATA ====================');
    print('Raw friendsData: $friendsData');
    print('Processing ${friendsData.length} friend records');
    
    // Clear existing lists to prevent duplicates
    final List<Map<String, dynamic>> newFriends = [];
    final List<Map<String, dynamic>> newPendingRequests = [];
    
    // Stop here if the friends array is empty
    if (friendsData.isEmpty) {
      print('No friends data found - lists will be empty');
      _friends = [];
      _pendingRequests = [];
      notifyListeners();
      return;
    }
    
    // First scan through friend data without async operations to identify pending requests
    try {
      for (var friend in friendsData) {
        print('Checking friend entry: $friend');
        
        // Check if this is a valid friend entry with the required fields
        if (friend is! Map || !friend.containsKey('uid') || !friend.containsKey('status')) {
          print('Invalid friend entry: $friend - missing required fields');
          continue;
        }
        
        final String friendUid = friend['uid'] ?? '';
        final String status = friend['status'] ?? '';
        final String type = friend['type'] ?? '';
        
        print('Friend entry details: uid=$friendUid, status=$status, type=$type');
        
        if (friendUid.isEmpty) {
          print('Skipping friend with empty UID');
          continue;
        }
        
        // Add the request to correct list based on status
        if (status == 'pending') {
          print('Found pending request with ID: $friendUid, type: $type');
          
          // Create a basic entry without user details first (will fetch later)
          final Map<String, dynamic> basicRequest = {
            'uid': friendUid,
            'status': status,
            'type': type,
            'displayName': 'Loading...',
            'name': 'Loading...',
          };
          
          newPendingRequests.add(basicRequest);
        } else if (status == 'accepted') {
          print('Found accepted friend with ID: $friendUid');
          
          // Create a basic entry without user details first (will fetch later)
          final Map<String, dynamic> basicFriend = {
            'uid': friendUid,
            'status': status,
            'type': type,
            'displayName': 'Loading...',
            'name': 'Loading...',
          };
          
          newFriends.add(basicFriend);
        } else {
          print('Unknown friend status: $status');
        }
      }
      
      // Update the lists immediately with basic info
      _friends = newFriends;
      _pendingRequests = newPendingRequests;
      notifyListeners();
      
      print('Initial lists populated - Friends: ${_friends.length}, Pending: ${_pendingRequests.length}');
      
      // Now fetch user details for each friend and pending request in parallel
      await _fetchUserDetailsForFriends();
      
    } catch (e) {
      print('Error in initial processing of friends data: $e');
    }
    
    print('Final counts - Friends: ${_friends.length}, Pending Requests: ${_pendingRequests.length}');
    print('Pending Requests: $_pendingRequests');
    print('===============================================================');
  }
  
  // Fetch user details for all friends and pending requests
  Future<void> _fetchUserDetailsForFriends() async {
    try {
      print('Fetching user details for all friends and pending requests');
      
      // Create copies of the lists to work with
      final List<Map<String, dynamic>> updatedFriends = List.from(_friends);
      final List<Map<String, dynamic>> updatedPendingRequests = List.from(_pendingRequests);
      
      // Handle pending requests
      for (int i = 0; i < updatedPendingRequests.length; i++) {
        final request = updatedPendingRequests[i];
        final String friendId = request['uid'];
        
        try {
          final docSnapshot = await _firestore.collection('users').doc(friendId).get();
          
          if (docSnapshot.exists) {
            final userData = docSnapshot.data() ?? {};
            
            // Update the request with user details
            updatedPendingRequests[i] = {
              ...request,
              'displayName': userData['displayName'] ?? 'Unknown User',
              'name': userData['displayName'] ?? 'Unknown User',
              'photoURL': userData['photoURL'] ?? '',
              'isOnline': userData['isOnline'] ?? false,
            };
            
            print('Updated pending request with user details: ${updatedPendingRequests[i]}');
          } else {
            print('User document not found for pending request: $friendId');
          }
        } catch (e) {
          print('Error fetching user details for pending request $friendId: $e');
        }
      }
      
      // Handle accepted friends
      for (int i = 0; i < updatedFriends.length; i++) {
        final friend = updatedFriends[i];
        final String friendId = friend['uid'];
        
        try {
          final docSnapshot = await _firestore.collection('users').doc(friendId).get();
          
          if (docSnapshot.exists) {
            final userData = docSnapshot.data() ?? {};
            
            // Update the friend with user details
            updatedFriends[i] = {
              ...friend,
              'displayName': userData['displayName'] ?? 'Unknown User',
              'name': userData['displayName'] ?? 'Unknown User',
              'photoURL': userData['photoURL'] ?? '',
              'isOnline': userData['isOnline'] ?? false,
            };
            
            print('Updated friend with user details: ${updatedFriends[i]}');
          } else {
            print('User document not found for friend: $friendId');
          }
        } catch (e) {
          print('Error fetching user details for friend $friendId: $e');
        }
      }
      
      // Update the lists with user details
      _friends = updatedFriends;
      _pendingRequests = updatedPendingRequests;
      notifyListeners();
      
      print('Updated all friends and pending requests with user details');
      print('Final counts - Friends: ${_friends.length}, Pending Requests: ${_pendingRequests.length}');
    } catch (e) {
      print('Error fetching user details: $e');
    }
  }
  
  // Manually check for pending requests
  Future<void> checkForPendingRequests() async {
    if (_currentUserId == null) {
      print('Cannot check for pending requests - no current user ID');
      return;
    }
    
    try {
      print('Manually checking for pending requests for user: $_currentUserId');
      
      final docSnapshot = await _firestore.collection('users').doc(_currentUserId).get();
      
      if (!docSnapshot.exists) {
        print('User document does not exist');
        return;
      }
      
      final friendsData = docSnapshot.data()?['friends'] ?? [];
      print('Raw friends data from database: $friendsData');
      
      // Check specifically for pending requests
      final pendingRequests = (friendsData as List).where((friend) => 
        friend is Map && 
        friend['status'] == 'pending'
      ).toList();
      
      print('Found ${pendingRequests.length} pending requests in database');
      
      if (pendingRequests.isNotEmpty) {
        print('Pending requests detected: $pendingRequests');
        
        // Directly update pending requests list with basic info first
        final List<Map<String, dynamic>> tempPendingRequests = [];
        
        for (var request in pendingRequests) {
          final friendId = request['uid'];
          final requestType = request['type'] ?? '';
          
          tempPendingRequests.add({
            'uid': friendId,
            'status': 'pending',
            'type': requestType,
            'displayName': 'Loading...',
            'name': 'Loading...',
          });
        }
        
        _pendingRequests = tempPendingRequests;
        notifyListeners();
        
        // Then fetch full details
        await _fetchUserDetailsForFriends();
      }
    } catch (e) {
      print('Error checking for pending requests: $e');
    }
  }

  // Manually refresh lists - useful after operations
  Future<void> refreshLists() async {
    if (_currentUserId == null) {
      print('Cannot refresh lists - no current user ID');
      return;
    }
    
    try {
      print('Manually refreshing friend lists for user: $_currentUserId');
      final userDoc = await _firestore.collection('users').doc(_currentUserId).get();
      
      if (userDoc.exists) {
        final friendsData = userDoc.data()?['friends'] ?? [];
        print('Retrieved ${friendsData.length} friend entries from database');
        _processFriendsData(friendsData);
        
        // Also explicitly check for pending requests
        await checkForPendingRequests();
      } else {
        print('User document does not exist');
      }
    } catch (e) {
      print('Error refreshing friend lists: $e');
    }
  }

  // Send friend request
  Future<String> sendFriendRequest(String currentUserId, String friendId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Sending friend request from $currentUserId to $friendId');
      final result = await _friendService.sendFriendRequest(currentUserId, friendId);
      
      print('Friend request result: $result');
      
      // Force refresh the lists after sending a request
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure database updated
      await refreshLists();
      
      return result;
    } catch (e) {
      print('Error sending friend request: $e');
      _error = e.toString();
      return 'Failed to send friend request';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Accept friend request
  Future<void> acceptFriendRequest(String currentUserId, String friendId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Accepting friend request from $friendId for user $currentUserId');
      await _friendService.acceptFriendRequest(friendId, currentUserId);
      
      // Force refresh the lists after accepting a request
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure database updated
      await refreshLists();
    } catch (e) {
      print('Error accepting friend request: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove friend
  Future<void> removeFriend(String currentUserId, String friendId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      print('Removing friend $friendId for user $currentUserId');
      await _friendService.removeFriend(currentUserId, friendId);
      
      // Remove from local lists
      _friends.removeWhere((friend) => friend['uid'] == friendId);
      _pendingRequests.removeWhere((request) => request['uid'] == friendId);
      notifyListeners();
      
      // Force refresh the lists after removing a friend
      await Future.delayed(const Duration(milliseconds: 500)); // Small delay to ensure database updated
      await refreshLists();
    } catch (e) {
      print('Error removing friend: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Check friend status
  Future<String> checkFriendStatus(String currentUserId, String friendId) async {
    try {
      return await _friendService.checkFriendStatus(currentUserId, friendId);
    } catch (e) {
      _error = e.toString();
      return 'Error checking friend status';
    }
  }

  // Clear provider data (useful when logging out)
  void clear() {
    _friends = [];
    _pendingRequests = [];
    _isLoading = false;
    _error = null;
    _currentUserId = null;
    notifyListeners();
  }
}