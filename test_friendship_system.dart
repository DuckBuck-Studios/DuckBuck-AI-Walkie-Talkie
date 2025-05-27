import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'lib/core/services/service_locator.dart';
import 'lib/core/services/relationship/relationship_service_interface.dart';
import 'lib/core/models/relationship_model.dart';
import 'lib/firebase_options.dart';

/// Interactive CLI test script for the friendship system
/// 
/// This script allows you to test all friendship operations:
/// 1. Send friend requests
/// 2. Accept/decline requests
/// 3. Cancel requests
/// 4. Remove friends
/// 5. Block/unblock users
/// 6. View relationship lists
/// 
/// Usage: dart run test_friendship_system.dart
void main() async {
  print('🚀 DuckBuck Friendship System Test Tool');
  print('=====================================');

  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize services
    await setupServiceLocator();
    
    print('✅ Firebase and services initialized successfully!');
    print('');
    
    // Start interactive session
    await runInteractiveSession();
    
  } catch (e) {
    print('❌ Error initializing: $e');
    exit(1);
  }
}

Future<void> runInteractiveSession() async {
  final relationshipService = serviceLocator<RelationshipServiceInterface>();
  
  while (true) {
    print('\n📋 Available Commands:');
    print('1.  Send Friend Request');
    print('2.  Accept Friend Request');
    print('3.  Decline Friend Request');
    print('4.  Cancel Friend Request');
    print('5.  Remove Friend');
    print('6.  Block User');
    print('7.  Unblock User');
    print('8.  Get Friends List');
    print('9.  Get Pending Requests');
    print('10. Get Sent Requests');
    print('11. Get Blocked Users');
    print('12. Check Friendship Status');
    print('13. Get Relationship Summary');
    print('14. Search Friends');
    print('15. Get Mutual Friends');
    print('16. Exit');
    print('');
    
    stdout.write('Enter command number: ');
    final input = stdin.readLineSync()?.trim();
    
    try {
      switch (input) {
        case '1':
          await handleSendFriendRequest(relationshipService);
          break;
        case '2':
          await handleAcceptFriendRequest(relationshipService);
          break;
        case '3':
          await handleDeclineFriendRequest(relationshipService);
          break;
        case '4':
          await handleCancelFriendRequest(relationshipService);
          break;
        case '5':
          await handleRemoveFriend(relationshipService);
          break;
        case '6':
          await handleBlockUser(relationshipService);
          break;
        case '7':
          await handleUnblockUser(relationshipService);
          break;
        case '8':
          await handleGetFriends(relationshipService);
          break;
        case '9':
          await handleGetPendingRequests(relationshipService);
          break;
        case '10':
          await handleGetSentRequests(relationshipService);
          break;
        case '11':
          await handleGetBlockedUsers(relationshipService);
          break;
        case '12':
          await handleCheckFriendshipStatus(relationshipService);
          break;
        case '13':
          await handleGetRelationshipSummary(relationshipService);
          break;
        case '14':
          await handleSearchFriends(relationshipService);
          break;
        case '15':
          await handleGetMutualFriends(relationshipService);
          break;
        case '16':
          print('👋 Goodbye!');
          exit(0);
        default:
          print('❌ Invalid command. Please enter a number between 1-16.');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }
}

Future<void> handleSendFriendRequest(RelationshipServiceInterface service) async {
  stdout.write('Enter target user ID: ');
  final targetUserId = stdin.readLineSync()?.trim();
  
  if (targetUserId == null || targetUserId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Sending friend request...');
  final relationshipId = await service.sendFriendRequest(targetUserId);
  print('✅ Friend request sent! Relationship ID: $relationshipId');
}

Future<void> handleAcceptFriendRequest(RelationshipServiceInterface service) async {
  stdout.write('Enter relationship ID: ');
  final relationshipId = stdin.readLineSync()?.trim();
  
  if (relationshipId == null || relationshipId.isEmpty) {
    print('❌ Invalid relationship ID');
    return;
  }
  
  print('⏳ Accepting friend request...');
  await service.acceptFriendRequest(relationshipId);
  print('✅ Friend request accepted!');
}

Future<void> handleDeclineFriendRequest(RelationshipServiceInterface service) async {
  stdout.write('Enter relationship ID: ');
  final relationshipId = stdin.readLineSync()?.trim();
  
  if (relationshipId == null || relationshipId.isEmpty) {
    print('❌ Invalid relationship ID');
    return;
  }
  
  print('⏳ Declining friend request...');
  await service.declineFriendRequest(relationshipId);
  print('✅ Friend request declined!');
}

Future<void> handleCancelFriendRequest(RelationshipServiceInterface service) async {
  stdout.write('Enter relationship ID: ');
  final relationshipId = stdin.readLineSync()?.trim();
  
  if (relationshipId == null || relationshipId.isEmpty) {
    print('❌ Invalid relationship ID');
    return;
  }
  
  print('⏳ Cancelling friend request...');
  await service.cancelFriendRequest(relationshipId);
  print('✅ Friend request cancelled!');
}

Future<void> handleRemoveFriend(RelationshipServiceInterface service) async {
  stdout.write('Enter relationship ID: ');
  final relationshipId = stdin.readLineSync()?.trim();
  
  if (relationshipId == null || relationshipId.isEmpty) {
    print('❌ Invalid relationship ID');
    return;
  }
  
  print('⏳ Removing friend...');
  await service.removeFriend(relationshipId);
  print('✅ Friend removed!');
}

Future<void> handleBlockUser(RelationshipServiceInterface service) async {
  stdout.write('Enter relationship ID: ');
  final relationshipId = stdin.readLineSync()?.trim();
  
  if (relationshipId == null || relationshipId.isEmpty) {
    print('❌ Invalid relationship ID');
    return;
  }
  
  print('⏳ Blocking user...');
  await service.blockUser(relationshipId);
  print('✅ User blocked!');
}

Future<void> handleUnblockUser(RelationshipServiceInterface service) async {
  stdout.write('Enter relationship ID: ');
  final relationshipId = stdin.readLineSync()?.trim();
  
  if (relationshipId == null || relationshipId.isEmpty) {
    print('❌ Invalid relationship ID');
    return;
  }
  
  print('⏳ Unblocking user...');
  await service.unblockUser(relationshipId);
  print('✅ User unblocked!');
}

Future<void> handleGetFriends(RelationshipServiceInterface service) async {
  stdout.write('Enter user ID: ');
  final userId = stdin.readLineSync()?.trim();
  
  if (userId == null || userId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Getting friends list...');
  final friends = await service.getFriends(userId);
  
  if (friends.isEmpty) {
    print('📝 No friends found');
  } else {
    print('👥 Friends (${friends.length}):');
    for (final friendship in friends) {
      final friendId = friendship.getFriendId(userId);
      final cachedProfile = friendship.getCachedProfile(friendId);
      print('  • ID: ${friendship.id}');
      print('    Friend: $friendId (${cachedProfile?.displayName ?? 'Unknown'})');
      print('    Accepted: ${friendship.acceptedAt?.toIso8601String()}');
      print('');
    }
  }
}

Future<void> handleGetPendingRequests(RelationshipServiceInterface service) async {
  stdout.write('Enter user ID: ');
  final userId = stdin.readLineSync()?.trim();
  
  if (userId == null || userId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Getting pending requests...');
  final requests = await service.getPendingRequests(userId);
  
  if (requests.isEmpty) {
    print('📝 No pending requests found');
  } else {
    print('📨 Pending Requests (${requests.length}):');
    for (final request in requests) {
      final fromUserId = request.initiatorId!;
      final cachedProfile = request.getCachedProfile(fromUserId);
      print('  • ID: ${request.id}');
      print('    From: $fromUserId (${cachedProfile?.displayName ?? 'Unknown'})');
      print('    Created: ${request.createdAt.toIso8601String()}');
      print('');
    }
  }
}

Future<void> handleGetSentRequests(RelationshipServiceInterface service) async {
  stdout.write('Enter user ID: ');
  final userId = stdin.readLineSync()?.trim();
  
  if (userId == null || userId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Getting sent requests...');
  final requests = await service.getSentRequests(userId);
  
  if (requests.isEmpty) {
    print('📝 No sent requests found');
  } else {
    print('📤 Sent Requests (${requests.length}):');
    for (final request in requests) {
      final toUserId = request.getFriendId(userId);
      final cachedProfile = request.getCachedProfile(toUserId);
      print('  • ID: ${request.id}');
      print('    To: $toUserId (${cachedProfile?.displayName ?? 'Unknown'})');
      print('    Created: ${request.createdAt.toIso8601String()}');
      print('');
    }
  }
}

Future<void> handleGetBlockedUsers(RelationshipServiceInterface service) async {
  stdout.write('Enter user ID: ');
  final userId = stdin.readLineSync()?.trim();
  
  if (userId == null || userId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Getting blocked users...');
  final blocked = await service.getBlockedUsers(userId);
  
  if (blocked.isEmpty) {
    print('📝 No blocked users found');
  } else {
    print('🚫 Blocked Users (${blocked.length}):');
    for (final relationship in blocked) {
      final blockedUserId = relationship.getFriendId(userId);
      final cachedProfile = relationship.getCachedProfile(blockedUserId);
      print('  • ID: ${relationship.id}');
      print('    Blocked User: $blockedUserId (${cachedProfile?.displayName ?? 'Unknown'})');
      print('    Updated: ${relationship.updatedAt.toIso8601String()}');
      print('');
    }
  }
}

Future<void> handleCheckFriendshipStatus(RelationshipServiceInterface service) async {
  stdout.write('Enter first user ID: ');
  final userId1 = stdin.readLineSync()?.trim();
  
  stdout.write('Enter second user ID: ');
  final userId2 = stdin.readLineSync()?.trim();
  
  if (userId1 == null || userId1.isEmpty || userId2 == null || userId2.isEmpty) {
    print('❌ Invalid user IDs');
    return;
  }
  
  print('⏳ Checking friendship status...');
  final relationship = await service.getFriendshipStatus(userId1, userId2);
  
  if (relationship == null) {
    print('📝 No relationship exists between these users');
  } else {
    print('🔍 Relationship Status:');
    print('  • ID: ${relationship.id}');
    print('  • Status: ${relationship.status.name}');
    print('  • Type: ${relationship.type.name}');
    print('  • Initiator: ${relationship.initiatorId}');
    print('  • Created: ${relationship.createdAt.toIso8601String()}');
    print('  • Updated: ${relationship.updatedAt.toIso8601String()}');
    if (relationship.acceptedAt != null) {
      print('  • Accepted: ${relationship.acceptedAt!.toIso8601String()}');
    }
  }
}

Future<void> handleGetRelationshipSummary(RelationshipServiceInterface service) async {
  stdout.write('Enter user ID: ');
  final userId = stdin.readLineSync()?.trim();
  
  if (userId == null || userId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Getting relationship summary...');
  final summary = await service.getUserRelationshipsSummary(userId);
  
  print('📊 Relationship Summary:');
  print('  • Friends: ${summary['friends']}');
  print('  • Pending Received: ${summary['pending_received']}');
  print('  • Pending Sent: ${summary['pending_sent']}');
  print('  • Blocked: ${summary['blocked']}');
}

Future<void> handleSearchFriends(RelationshipServiceInterface service) async {
  stdout.write('Enter user ID: ');
  final userId = stdin.readLineSync()?.trim();
  
  stdout.write('Enter search query: ');
  final query = stdin.readLineSync()?.trim() ?? '';
  
  if (userId == null || userId.isEmpty) {
    print('❌ Invalid user ID');
    return;
  }
  
  print('⏳ Searching friends...');
  final friends = await service.searchFriends(userId, query);
  
  if (friends.isEmpty) {
    print('📝 No friends found matching "$query"');
  } else {
    print('🔍 Search Results (${friends.length}):');
    for (final friendship in friends) {
      final friendId = friendship.getFriendId(userId);
      final cachedProfile = friendship.getCachedProfile(friendId);
      print('  • ${cachedProfile?.displayName ?? 'Unknown'} ($friendId)');
    }
  }
}

Future<void> handleGetMutualFriends(RelationshipServiceInterface service) async {
  stdout.write('Enter first user ID: ');
  final userId1 = stdin.readLineSync()?.trim();
  
  stdout.write('Enter second user ID: ');
  final userId2 = stdin.readLineSync()?.trim();
  
  if (userId1 == null || userId1.isEmpty || userId2 == null || userId2.isEmpty) {
    print('❌ Invalid user IDs');
    return;
  }
  
  print('⏳ Getting mutual friends...');
  final mutualFriends = await service.getMutualFriends(userId1, userId2);
  
  if (mutualFriends.isEmpty) {
    print('📝 No mutual friends found');
  } else {
    print('🤝 Mutual Friends (${mutualFriends.length}):');
    for (final friendship in mutualFriends) {
      final friendId = friendship.getFriendId(userId1);
      final cachedProfile = friendship.getCachedProfile(friendId);
      print('  • ${cachedProfile?.displayName ?? 'Unknown'} ($friendId)');
    }
  }
}

/// Helper function to display relationship information
void displayRelationship(RelationshipModel relationship) {
  print('📋 Relationship Details:');
  print('  • ID: ${relationship.id}');
  print('  • Participants: ${relationship.participants.join(', ')}');
  print('  • Type: ${relationship.type.name}');
  print('  • Status: ${relationship.status.name}');
  print('  • Initiator: ${relationship.initiatorId}');
  print('  • Created: ${relationship.createdAt.toIso8601String()}');
  print('  • Updated: ${relationship.updatedAt.toIso8601String()}');
  
  if (relationship.acceptedAt != null) {
    print('  • Accepted: ${relationship.acceptedAt!.toIso8601String()}');
  }
  
  if (relationship.cachedProfiles.isNotEmpty) {
    print('  • Cached Profiles:');
    relationship.cachedProfiles.forEach((userId, profile) {
      print('    - $userId: ${profile.displayName}');
    });
  }
}
