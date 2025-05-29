# Relationship Service Documentation

This documentation provides comprehensive details about the Relationship Service methods, their return values, error handling, and usage examples.

## Overview

The Relationship Service manages user relationships including friend requests, blocking, and relationship status management. It provides methods for creating, accepting, declining, and managing relationships between users.

## Table of Contents

- [Data Models](./data-models.md) - Core data structures and models
- [Method Documentation](./methods.md) - Detailed method documentation
- [Error Handling](./error-handling.md) - Exception types and error codes
- [Usage Examples](./usage-examples.md) - Practical implementation examples
- [Pagination Guide](./pagination.md) - Working with paginated results

## Quick Reference

### Core Operations
- `sendFriendRequest()` - Send a friend request to another user
- `acceptFriendRequest()` - Accept an incoming friend request
- `declineFriendRequest()` - Decline an incoming friend request
- `blockUser()` - Block a user
- `unblockUser()` - Unblock a previously blocked user

### Query Operations
- `getFriends()` - Get paginated list of friends
- `getIncomingRequests()` - Get paginated list of incoming friend requests
- `getOutgoingRequests()` - Get paginated list of outgoing friend requests
- `getBlockedUsers()` - Get paginated list of blocked users
- `getRelationship()` - Get specific relationship details

### Utility Operations
- `removeFriend()` - Remove an existing friendship
- `isBlocked()` - Check if a user is blocked
- `isFriend()` - Check if users are friends
- `hasIncomingRequest()` - Check for incoming friend request
- `hasOutgoingRequest()` - Check for outgoing friend request

## Key Features

- **Pagination Support**: List methods support pagination for efficient data loading
- **Transaction Safety**: Critical operations use database transactions
- **Comprehensive Error Handling**: Specific exceptions for different error scenarios
- **Cached Profile Data**: Includes user profile information for performance
- **Flexible Querying**: Multiple methods for checking relationship status
