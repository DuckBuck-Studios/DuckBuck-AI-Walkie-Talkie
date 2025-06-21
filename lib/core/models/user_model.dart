import 'package:firebase_auth/firebase_auth.dart' as firebase;

/// Model class representing a user in the application
/// Stores only relevant authentication fields based on auth method (phone or email)
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final bool isEmailVerified;
  final Map<String, dynamic>? metadata;
  final Map<String, dynamic>? fcmTokenData;
  final bool isNewUser;
  final int agentRemainingTime; // Time in seconds, default 1 hour (3600 seconds)
  final bool deleted; // Indicates if the user account has been marked as deleted  

  /// Creates a new UserModel instance
  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.metadata,
    this.fcmTokenData,
    this.isNewUser = false,  
    this.agentRemainingTime = 3600,      
    this.deleted = false, // Default to false
  });

  /// Creates a UserModel from Firebase User
  /// Note: This factory only creates a basic model from Firebase auth data.
  /// For existing users, the actual agentRemainingTime should be loaded from Firestore
  /// and updated using copyWith() method to preserve premium features.
  factory UserModel.fromFirebaseUser(firebase.User user) {
    // Get provider ID for metadata
    String? providerId = user.providerData.isNotEmpty ? user.providerData.first.providerId : null;
    String? authMethod;
    
    if (providerId == 'phone') {
      authMethod = 'phone';
    } else if (providerId == 'google.com') {
      authMethod = 'google';
    } else if (providerId == 'apple.com') {
      authMethod = 'apple';
    }

    return UserModel(
      uid: user.uid,
      // Only include email-related fields if not phone auth
      email: authMethod != 'phone' ? user.email : null,
      displayName: user.displayName,
      photoURL: user.photoURL,
      // Only include phone number if it's phone auth
      phoneNumber: user.phoneNumber,
      // No more specific email verification since we don't have email/password auth
      isEmailVerified: false,
      // DO NOT set default time here - this will be loaded from Firestore for existing users
      // Only new users should get the default time, which is handled by the service layer
      agentRemainingTime: 0, // Temporary value - will be updated from Firestore
      deleted: false, // Default to false for new users
      metadata: {
        'creationTime': user.metadata.creationTime?.millisecondsSinceEpoch,
        'lastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
        'providerId': providerId,
        'authMethod': authMethod,
      },
    );
  }

  /// Convert user model to a map
  /// Only includes relevant fields based on auth method
  Map<String, dynamic> toMap() {
    final Map<String, dynamic> data = {
      'uid': uid,
      'displayName': displayName,
      'photoURL': photoURL,
      'metadata': metadata,
      'fcmTokenData': fcmTokenData,
      'isNewUser': isNewUser, // Include isNewUser field
      'agentRemainingTime': agentRemainingTime, // Include agent remaining time
      'deleted': deleted, // Include deleted field
    };
    
    // Get auth method from metadata if available
    String? authMethod;
    if (metadata != null && metadata!.containsKey('authMethod')) {
      authMethod = metadata!['authMethod'] as String?;
    }
    
    // For Google and Apple auth, include email
    if (authMethod == 'google' || authMethod == 'apple') {
      data['email'] = email;
    }
    
    // For phone auth, include phone number
    if (authMethod == 'phone') {
      data['phoneNumber'] = phoneNumber;
    }
    // If phone number exists but auth method isn't set
    else if (phoneNumber != null) {
      data['phoneNumber'] = phoneNumber;
    }
    
    return data;
  }

  /// Create a UserModel from a map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'],
      isNewUser: map['isNewUser'] ?? false,
      isEmailVerified: map['isEmailVerified'] ?? false,
      agentRemainingTime: map['agentRemainingTime'] ?? 3600, // Default to 1 hour if not present
      deleted: map['deleted'] ?? false, // Default to false if not present
      metadata: map['metadata'],
      fcmTokenData: map['fcmTokenData'],
    );
  }

  /// Create a copy of this user model with updated fields
  UserModel copyWith({
    String? displayName,
    String? photoURL,
    String? email,
    String? phoneNumber,
    bool? isEmailVerified,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? fcmTokenData,
    int? agentRemainingTime,
    bool? deleted,
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      metadata: metadata ?? this.metadata,
      fcmTokenData: fcmTokenData ?? this.fcmTokenData,
      agentRemainingTime: agentRemainingTime ?? this.agentRemainingTime,
      deleted: deleted ?? this.deleted,
    );
  }
}
