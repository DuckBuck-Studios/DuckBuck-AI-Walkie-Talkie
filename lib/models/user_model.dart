import 'package:cloud_firestore/cloud_firestore.dart';

/// Authentication providers supported by the app
enum AuthProvider {
  email,
  google,
  apple,
  phone
}

/// User gender options
enum Gender {
  male,
  female,
  other,
  preferNotToSay
}

/// Represents a user in the application
/// 
/// Contains all user data including authentication details,
/// profile information, and subscription status
class UserModel {
  final String uid;
  final String displayName;
  final String? photoURL;
  final List<AuthProvider> providers;
  final String? fcmToken;
  final Timestamp createdAt;
  final Timestamp lastLoginAt;
  final Map<String, dynamic>? subscriptions;
  final Map<String, dynamic>? metadata;
  final String? roomId;

  /// Creates a new user model with the required fields
  UserModel({
    required this.uid,
    required this.displayName,
    this.photoURL,
    required this.providers,
    this.fcmToken,
    required this.createdAt,
    required this.lastLoginAt,
    this.subscriptions,
    this.metadata,
    this.roomId,
  });

  /// Create a user model from a Firestore document
  factory UserModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? subscriptionsMap;
    if (json['subscriptions'] != null) {
      subscriptionsMap = Map<String, dynamic>.from(
        (json['subscriptions'] as Map).map(
          (key, value) => MapEntry(
            key,
            value as Map<String, dynamic>,
          ),
        ),
      );
    }

    List<AuthProvider> providersList = [];
    if (json['providers'] != null) {
      providersList = (json['providers'] as List)
          .map((p) => _parseAuthProvider(p))
          .toList();
    } else if (json['provider'] != null) {
      // For backward compatibility
      providersList = [_parseAuthProvider(json['provider'])];
    }

    // Create or update metadata
    Map<String, dynamic> metadataMap = Map<String, dynamic>.from(json['metadata'] ?? {});
    
    // Move email and phoneNumber to metadata if they exist at top level
    if (json['email'] != null) {
      metadataMap['email'] = json['email'];
    }
    
    if (json['phoneNumber'] != null) {
      metadataMap['phoneNumber'] = json['phoneNumber'];
    }

    // Get roomId from either top level or metadata
    String? roomId = json['roomId'] as String?;
    if (roomId == null && metadataMap.containsKey('roomId')) {
      // If roomId exists in metadata but not at top level, use from metadata
      roomId = metadataMap['roomId'] as String?;
      // And remove it from metadata
      metadataMap.remove('roomId');
    }

    return UserModel(
      uid: json['uid'] ?? '',
      displayName: json['displayName'] ?? '',
      photoURL: json['photoURL'],
      providers: providersList.isEmpty ? [AuthProvider.email] : providersList,
      fcmToken: json['fcmToken'],
      createdAt: json['createdAt'] ?? Timestamp.now(),
      lastLoginAt: json['lastLoginAt'] ?? Timestamp.now(),
      subscriptions: subscriptionsMap,
      metadata: metadataMap,
      roomId: roomId,
    );
  }

  /// Convert user model to a Firestore document
  Map<String, dynamic> toJson() {
    Map<String, dynamic>? subscriptionsJson;
    if (subscriptions != null) {
      subscriptionsJson = Map<String, dynamic>.from(
        subscriptions!.map(
          (key, value) => MapEntry(key, value is Map ? value : {'data': value}),
        ),
      );
    }

    return {
      'uid': uid,
      'displayName': displayName,
      'photoURL': photoURL,
      'providers': providers.map((p) => p.toString().split('.').last).toList(),
      'fcmToken': fcmToken,
      'createdAt': createdAt,
      'lastLoginAt': lastLoginAt,
      'subscriptions': subscriptionsJson,
      'metadata': metadata,
      'roomId': roomId,
    };
  }

  /// Create a copy of the user model with updated fields
  UserModel copyWith({
    String? uid,
    String? displayName,
    String? photoURL,
    List<AuthProvider>? providers,
    String? fcmToken,
    Timestamp? createdAt,
    Timestamp? lastLoginAt,
    Map<String, dynamic>? subscriptions,
    Map<String, dynamic>? metadata,
    String? roomId,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      providers: providers ?? this.providers,
      fcmToken: fcmToken ?? this.fcmToken,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      subscriptions: subscriptions ?? this.subscriptions,
      metadata: metadata ?? this.metadata,
      roomId: roomId ?? this.roomId,
    );
  }

  /// Update the FCM token for push notifications
  UserModel updateFcmToken(String token) {
    return copyWith(fcmToken: token);
  }

  /// Add a new authentication provider to the user's account
  UserModel addProvider(AuthProvider provider) {
    if (providers.contains(provider)) return this;
    
    final updatedProviders = List<AuthProvider>.from(providers);
    updatedProviders.add(provider);
    return copyWith(providers: updatedProviders);
  }

  /// Remove an authentication provider from the user's account
  UserModel removeProvider(AuthProvider provider) {
    if (!providers.contains(provider) || providers.length <= 1) return this;
    
    final updatedProviders = List<AuthProvider>.from(providers);
    updatedProviders.remove(provider);
    return copyWith(providers: updatedProviders);
  }

  /// Check if user's account is connected to a specific provider
  bool hasProvider(AuthProvider provider) {
    return providers.contains(provider);
  }

  /// Add or update a subscription for a topic
  UserModel updateSubscription(String topic, Map<String, dynamic> status) {
    final updatedSubscriptions = Map<String, dynamic>.from(
      subscriptions ?? {},
    );
    updatedSubscriptions[topic] = status;
    return copyWith(subscriptions: updatedSubscriptions);
  }

  /// Remove a subscription for a topic
  UserModel removeSubscription(String topic) {
    if (subscriptions == null) return this;
    final updatedSubscriptions = Map<String, dynamic>.from(subscriptions!);
    updatedSubscriptions.remove(topic);
    return copyWith(subscriptions: updatedSubscriptions);
  }

  /// Check if user is subscribed to a specific topic
  bool isSubscribedTo(String topic) {
    if (subscriptions == null) return false;
    return subscriptions!.containsKey(topic) && 
           subscriptions![topic]!['isActive'] == true;
  }

  /// Get a specific metadata value by key
  dynamic getMetadata(String key) {
    if (metadata == null) return null;
    return metadata![key];
  }

  /// Update or add a metadata field
  UserModel updateMetadata(String key, dynamic value) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata[key] = value;
    return copyWith(metadata: updatedMetadata);
  }

  /// Get the date of birth from metadata
  DateTime? get dateOfBirth {
    if (metadata == null || !metadata!.containsKey('dateOfBirth')) return null;
    
    final dob = metadata!['dateOfBirth'];
    if (dob is Timestamp) {
      return dob.toDate();
    } else if (dob is String) {
      return DateTime.tryParse(dob);
    }
    return null;
  }
  
  /// Get the gender from metadata
  Gender? get gender {
    if (metadata == null || !metadata!.containsKey('gender')) return null;
    return _parseGender(metadata!['gender']);
  }

  /// Set or update the date of birth
  UserModel updateDateOfBirth(DateTime dob) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata['dateOfBirth'] = Timestamp.fromDate(dob);
    return copyWith(metadata: updatedMetadata);
  }
  
  /// Set or update the gender
  UserModel updateGender(Gender newGender) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata['gender'] = newGender.toString().split('.').last;
    return copyWith(metadata: updatedMetadata);
  }

  /// Calculate the user's age based on date of birth
  int? get age {
    if (dateOfBirth == null) return null;
    
    final today = DateTime.now();
    final birthDate = dateOfBirth!;
    int age = today.year - birthDate.year;
    
    // Adjust age if birthday hasn't occurred yet this year
    if (today.month < birthDate.month || 
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    
    return age;
  }

  /// Check if this user account has completed the onboarding process
  bool get hasCompletedOnboarding {
    return metadata != null && 
           metadata!.containsKey('onboardingCompleted') && 
           metadata!['onboardingCompleted'] == true;
  }

  /// Check if the user has a profile picture
  bool get hasProfilePicture => photoURL != null && photoURL!.isNotEmpty;

  /// Update the room ID for this user
  UserModel updateRoomId(String newRoomId) {
    return copyWith(roomId: newRoomId);
  }

  /// Get email from metadata
  String get email => metadata?['email'] as String? ?? '';

  /// Get phone number from metadata
  String? get phoneNumber => metadata?['phoneNumber'] as String?;

  /// Set or update email
  UserModel updateEmail(String newEmail) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata['email'] = newEmail;
    return copyWith(metadata: updatedMetadata);
  }
  
  /// Set or update phone number
  UserModel updatePhoneNumber(String? newPhoneNumber) {
    final updatedMetadata = Map<String, dynamic>.from(metadata ?? {});
    updatedMetadata['phoneNumber'] = newPhoneNumber;
    return copyWith(metadata: updatedMetadata);
  }
}

/// Helper method to parse auth provider from string
AuthProvider _parseAuthProvider(String? providerString) {
  if (providerString == null) return AuthProvider.email;
  
  try {
    final cleanString = providerString.contains('.') 
        ? providerString.split('.').last 
        : providerString;
        
    return AuthProvider.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == cleanString.toLowerCase(),
      orElse: () => AuthProvider.email,
    );
  } catch (_) {
    return AuthProvider.email;
  }
}

/// Helper method to parse gender from string
Gender? _parseGender(String? genderString) {
  if (genderString == null) return null;
  
  try {
    final cleanString = genderString.contains('.') 
        ? genderString.split('.').last 
        : genderString;
        
    return Gender.values.firstWhere(
      (e) => e.toString().split('.').last.toLowerCase() == cleanString.toLowerCase(),
      orElse: () => Gender.other,
    );
  } catch (_) {
    return null;
  }
}
