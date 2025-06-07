import 'package:get_it/get_it.dart';

import 'auth/auth_service_interface.dart';
import 'auth/auth_service.dart';
import 'auth/auth_security_manager.dart';
import 'firebase/firebase_database_service.dart';
import 'firebase/firebase_storage_service.dart';
import 'firebase/firebase_analytics_service.dart';
import 'firebase/firebase_crashlytics_service.dart';
import 'firebase/firebase_app_check_service.dart';
import 'crashlytics_consent_manager.dart';
import 'notifications/notifications_service.dart'; 
import 'notifications/email_notification_service.dart';  // Add import for the new service
import 'fcm/fcm_service.dart'; 
import 'api/api_service.dart';
import 'user/user_service_interface.dart';
import 'user/user_service.dart'; 
import '../repositories/user_repository.dart'; 
import '../repositories/relationship_repository.dart'; 
import 'logger/logger_service.dart';
import 'relationship/relationship_service_interface.dart';
import 'relationship/relationship_service.dart';
import 'call/agora_token_service.dart';
import 'cache/cache_sync_service.dart';
import 'lifecycle/app_lifecycle_manager.dart';


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
    () => AuthService(),
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
  
  // Register Crashlytics consent manager
  serviceLocator.registerLazySingleton<CrashlyticsConsentManager>(
    () => CrashlyticsConsentManager.create(),
  );

  // Register notifications service
  serviceLocator.registerLazySingleton<NotificationsService>(
    () => NotificationsService(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
      apiService: serviceLocator<ApiService>(),
    ),
  );

  // Register Email notification service
  serviceLocator.registerLazySingleton<EmailNotificationService>(
    () => EmailNotificationService(
      apiService: serviceLocator<ApiService>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );

  // Register repositories
  serviceLocator.registerLazySingleton<UserRepository>(
    () => UserRepository(
      authService: serviceLocator<AuthServiceInterface>(),
      userService: serviceLocator<UserServiceInterface>(),
      analytics: serviceLocator<FirebaseAnalyticsService>(),
      crashlytics: serviceLocator<FirebaseCrashlyticsService>(),
      emailService: serviceLocator<EmailNotificationService>(),
    ),
  );

  // Register relationship repository
  serviceLocator.registerLazySingleton<RelationshipRepository>(
    () => RelationshipRepository(
      relationshipService: serviceLocator<RelationshipServiceInterface>(),
      analytics: serviceLocator<FirebaseAnalyticsService>(),
      crashlytics: serviceLocator<FirebaseCrashlyticsService>(),
      logger: serviceLocator<LoggerService>(),
      authService: serviceLocator<AuthServiceInterface>(),
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
   
  
  // Register user service
  serviceLocator.registerLazySingleton<UserServiceInterface>(
    () => UserService(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
  
  // Register relationship service
  serviceLocator.registerLazySingleton<RelationshipServiceInterface>(
    () => RelationshipService(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
      userService: serviceLocator<UserServiceInterface>(),
      authService: serviceLocator<AuthServiceInterface>(),
      notificationsService: serviceLocator<NotificationsService>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
  
  // Register FCM service
  serviceLocator.registerLazySingleton<FCMService>(
    () => FCMService(),
  );
   
  // Register Agora token service
  serviceLocator.registerLazySingleton<AgoraTokenService>(
    () => AgoraTokenService(
      apiService: serviceLocator<ApiService>(),
      authService: serviceLocator<AuthServiceInterface>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
  
  // Register Cache Sync service
  serviceLocator.registerLazySingleton<CacheSyncService>(
    () => CacheSyncService(
      relationshipRepository: serviceLocator<RelationshipRepository>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
  
  // Register App Lifecycle manager
  serviceLocator.registerLazySingleton<AppLifecycleManager>(
    () => AppLifecycleManager(
      cacheSyncService: serviceLocator<CacheSyncService>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
}
