import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'security/app_security_service.dart';
import 'api/api_service.dart';
import 'user/user_service_interface.dart';
import 'user/user_service.dart'; 
import '../repositories/user_repository.dart'; 
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
      userService: serviceLocator<UserServiceInterface>(),
      analytics: serviceLocator<FirebaseAnalyticsService>(),
      crashlytics: serviceLocator<FirebaseCrashlyticsService>(),
      apiService: serviceLocator<ApiService>(),
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
  
  // Register user service
  serviceLocator.registerLazySingleton<UserServiceInterface>(
    () => UserService(
      databaseService: serviceLocator<FirebaseDatabaseService>(),
      logger: serviceLocator<LoggerService>(),
    ),
  );
   
}
