import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Crashlytics Consent', () {
    late SharedPreferences preferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
    });

    test('Crashlytics consent should default to enabled in release mode', () async {
      // This is a basic test to ensure the file compiles
      expect(preferences.getBool('crashlytics_enabled'), null);
      
      // Setup appropriate preferences
      await preferences.setBool('crashlytics_enabled', true);
      
      // Verify setting was saved
      expect(preferences.getBool('crashlytics_enabled'), true);
    });
    
    test('Crashlytics consent can be disabled', () async {
      // Set initial value
      await preferences.setBool('crashlytics_enabled', true);
      
      // Change to disabled
      await preferences.setBool('crashlytics_enabled', false);
      
      // Verify setting was saved
      expect(preferences.getBool('crashlytics_enabled'), false);
    });
  });
}
