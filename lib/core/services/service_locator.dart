import 'package:get_it/get_it.dart';

import 'auth/auth_service_interface.dart';
import 'auth/firebase_auth_service.dart';
import 'firebase/firebase_database_service.dart';
import 'firebase/firebase_storage_service.dart';
import 'firebase/firebase_analytics_service.dart';
import 'notifications/notifications_service.dart';
import 'friend/friend_service.dart';
import '../repositories/user_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/message_repository.dart';
import 'message/message_cache_service.dart';
import '../../features/messages/controllers/message_feature_controller.dart';

/// Global service locator instance
final GetIt serviceLocator = GetIt.instance;

/// Initialize all services and repositories
Future<void> setupServiceLocator() async {
  // Register Firebase services
  serviceLocator.registerLazySingleton<AuthServiceInterface>(
    () => FirebaseAuthService(),
  );

  serviceLocator.registerLazySingleton<FirebaseDatabaseService>(
    () => FirebaseDatabaseService(),
  );

  serviceLocator.registerLazySingleton<FirebaseStorageService>(
    () => FirebaseStorageService(),
  );

  serviceLocator.registerLazySingleton<FirebaseAnalyticsService>(
    () => FirebaseAnalyticsService(),
  );

  // Register notifications service
  serviceLocator.registerLazySingleton<NotificationsService>(
    () => NotificationsService(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
    ),
  );

  // Register repositories
  serviceLocator.registerLazySingleton<UserRepository>(
    () => UserRepository(authService: serviceLocator<AuthServiceInterface>()),
  );
  
  // Register friend service
  serviceLocator.registerLazySingleton<FriendService>(
    () => FriendService(databaseService: serviceLocator<FirebaseDatabaseService>()),
  );
  
  // Register friend repository
  serviceLocator.registerLazySingleton<FriendRepository>(
    () => FriendRepository(
      friendService: serviceLocator<FriendService>(),
      userRepository: serviceLocator<UserRepository>(),
    ),
  );
  
  // Register message cache service
  serviceLocator.registerLazySingleton<MessageCacheService>(
    () => MessageCacheService(),
  );
  
  // Register message repository
  serviceLocator.registerLazySingleton<MessageRepository>(
    () => MessageRepository(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
      storageService: serviceLocator<FirebaseStorageService>(),
      friendService: serviceLocator<FriendService>(),
      cacheService: serviceLocator<MessageCacheService>(),
    ),
  );
  
  // Register MessageFeatureController
  serviceLocator.registerFactory<MessageFeatureController>(
    () => MessageFeatureController(
      messageRepository: serviceLocator<MessageRepository>(),
      friendRepository: serviceLocator<FriendRepository>(),
    ),
  );

  // Add more service registrations here as needed
}
