import 'package:get_it/get_it.dart';

import 'auth/auth_service_interface.dart';
import 'auth/firebase_auth_service.dart';
import 'firebase/firebase_database_service.dart';
import 'firebase/firebase_storage_service.dart';
import 'firebase/firebase_analytics_service.dart';
import 'notifications/notifications_service.dart';
import '../repositories/user_repository.dart';

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

  // Add more service registrations here as needed
}
