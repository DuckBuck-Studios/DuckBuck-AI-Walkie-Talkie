import 'package:flutter/material.dart';
import '../widgets/error_boundary.dart';
import '../utils/crash_reporter.dart';

/// This file demonstrates how to use the error boundary widget and crash reporter utility
/// 
/// EXAMPLE CODE - For demonstration purposes only

/// Example screen showing how to use ErrorBoundary
class ExampleScreen extends StatelessWidget {
  const ExampleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Error Handling Example'),
      ),
      body: Column(
        children: [
          // Regular feature that will crash the entire screen if it fails
          const _RegularFeature(),
          
          // Protected feature that will gracefully handle errors
          ErrorBoundary(
            featureName: 'protected_feature',
            child: const _CrashableFeature(),
          ),
          
          // Example of a button that uses the CrashReporter utility
          ElevatedButton(
            onPressed: () => _handleRiskyOperation(),
            child: const Text('Perform Risky Operation'),
          ),
        ],
      ),
    );
  }

  /// Example of using CrashReporter to wrap risky code
  Future<void> _handleRiskyOperation() async {
    await CrashReporter.wrap(
      () async {
        // This is the code that might throw an exception
        await Future.delayed(const Duration(seconds: 1));
        throw Exception('This is a test exception');
      },
      feature: 'example_feature',
      operation: 'risky_operation',
      additionalInfo: {
        'attempt_count': 1,
        'user_triggered': true,
      },
      onError: (error, stack) {
        debugPrint('Handled error in risky operation: $error');
        // Show user-friendly message
      },
    );
  }
}

/// Example widget that doesn't have error protection
class _RegularFeature extends StatelessWidget {
  const _RegularFeature();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('This feature works fine'),
      ),
    );
  }
}

/// Example widget that might crash but is protected by ErrorBoundary
class _CrashableFeature extends StatelessWidget {
  const _CrashableFeature();

  @override
  Widget build(BuildContext context) {
    // Uncomment this to test error boundary
    // if (DateTime.now().millisecond % 2 == 0) {
    //   throw Exception('Random crash in protected feature!');
    // }

    return const Card(
      margin: EdgeInsets.all(16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('This feature is protected by ErrorBoundary'),
      ),
    );
  }
}

/// Example of synchronous error handling
void exampleSyncErrorHandling() {
  final result = CrashReporter.wrapSync(
    () {
      // Code that might throw
      if (DateTime.now().second % 2 == 0) {
        throw Exception('Example sync error');
      }
      return 'Success result';
    },
    feature: 'example_feature',
    operation: 'sync_operation',
    fallbackValue: 'Fallback result',
  );
  
  debugPrint('Result: $result');
}
