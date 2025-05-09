import 'package:firebase_auth/firebase_auth.dart' as firebase;

/// Model class representing a user in the application
class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String? phoneNumber;
  final bool isEmailVerified;
  final Map<String, dynamic>? metadata;

  /// Creates a new UserModel instance
  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.phoneNumber,
    this.isEmailVerified = false,
    this.metadata,
  });

  /// Creates a UserModel from Firebase User
  factory UserModel.fromFirebaseUser(firebase.User user) {
    return UserModel(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoURL: user.photoURL,
      phoneNumber: user.phoneNumber,
      isEmailVerified: user.emailVerified,
      metadata: {
        'creationTime': user.metadata.creationTime?.millisecondsSinceEpoch,
        'lastSignInTime': user.metadata.lastSignInTime?.millisecondsSinceEpoch,
        'providerId': user.providerData.isNotEmpty ? user.providerData.first.providerId : null,
      },
    );
  }

  /// Convert user model to a map
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'phoneNumber': phoneNumber,
      'isEmailVerified': isEmailVerified,
      'metadata': metadata,
    };
  }

  /// Create a UserModel from a map
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid'],
      email: map['email'],
      displayName: map['displayName'],
      photoURL: map['photoURL'],
      phoneNumber: map['phoneNumber'],
      isEmailVerified: map['isEmailVerified'] ?? false,
      metadata: map['metadata'],
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
  }) {
    return UserModel(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      metadata: metadata ?? this.metadata,
    );
  }
}
