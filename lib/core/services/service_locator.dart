import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/auth_service_interface.dart';
import 'auth/firebase_auth_service.dart';
import 'auth/auth_security_manager.dart';
import 'firebase/firebase_database_service.dart';
import 'firebase/firebase_storage_service.dart';
import 'firebase/firebase_analytics_service.dart';
import 'firebase/firebase_crashlytics_service.dart';
import 'firebase/firebase_app_check_service.dart';
import 'crashlytics_consent_manager.dart';
import 'notifications/notifications_service.dart';
import 'friend/friend_service.dart';
import 'security/app_security_service.dart';
import 'api/api_service.dart';
import '../repositories/user_repository.dart';
import '../repositories/friend_repository.dart';
import '../repositories/message_repository.dart';
import 'message/message_cache_service.dart';
import 'logger/logger_service.dart';


/// Global service locator instance
final GetIt serviceLocator = GetIt.instance;

/// Initialize all services and repositories
Future<void> setupServiceLocator() async {
  // Register logger service (singleton)
  serviceLocator.registerLazySingleton<LoggerService>(
    () => LoggerService(),
  );

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

  // Register Firebase Crashlytics service
  serviceLocator.registerLazySingleton<FirebaseCrashlyticsService>(
    () => FirebaseCrashlyticsService(),
  );
  
  // Register Firebase App Check service
  serviceLocator.registerLazySingleton<FirebaseAppCheckService>(
    () => FirebaseAppCheckService(),
  );
  
  // Register Crashlytics consent manager as async factory
  serviceLocator.registerSingletonAsync<CrashlyticsConsentManager>(
    () async {
      final prefs = await SharedPreferences.getInstance();
      return CrashlyticsConsentManager(
        prefs: prefs,
        crashlytics: serviceLocator<FirebaseCrashlyticsService>(),
      );
    },
  );

  // Register notifications service
  serviceLocator.registerLazySingleton<NotificationsService>(
    () => NotificationsService(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
    ),
  );

  // Register repositories
  serviceLocator.registerLazySingleton<UserRepository>(
    () => UserRepository(
      authService: serviceLocator<AuthServiceInterface>(),
      analytics: serviceLocator<FirebaseAnalyticsService>(),
    ),
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
   
  // Register authentication security manager
  serviceLocator.registerLazySingleton<AuthSecurityManager>(
    () => AuthSecurityManager(
      authService: serviceLocator<AuthServiceInterface>(),
      userRepository: serviceLocator<UserRepository>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
  
  // Register API service
  serviceLocator.registerLazySingleton<ApiService>(
    () => ApiService(
      authService: serviceLocator<AuthServiceInterface>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
  
  // Register application security service
  serviceLocator.registerLazySingleton<AppSecurityService>(
    () => AppSecurityService(),
  );

  // Add more service registrations here as needed
}
