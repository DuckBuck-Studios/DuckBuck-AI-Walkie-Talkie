import 'package:flutter/material.dart';
import '../services/service_locator.dart';
import '../services/firebase/firebase_crashlytics_service.dart';

/// A widget that catches errors in its child widget tree and displays a fallback UI.
///
/// This widget uses the Firebase Crashlytics service to report any errors that occur
/// in its child widget tree. It also provides context about which feature was using
/// when the error occurred.
class ErrorBoundary extends StatefulWidget {
  /// The child widget that this boundary will catch errors for
  final Widget child;
  
  /// The name of the feature that this boundary is protecting.
  /// This helps with tracking which part of the app is experiencing errors.
  final String featureName;
  
  /// Optional custom error widget to display when an error occurs
  final Widget? errorWidget;

  const ErrorBoundary({
    super.key,
    required this.child,
    required this.featureName,
    this.errorWidget,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  bool _hasError = false;
  late FirebaseCrashlyticsService _crashlytics;

  @override
  void initState() {
    super.initState();
    _crashlytics = serviceLocator<FirebaseCrashlyticsService>();
    
    // Set the current feature for better error tracking
    _crashlytics.setCurrentFeature(widget.featureName);
  }

  @override
  void dispose() {
    // Clear feature tracking on dispose
    _crashlytics.setCurrentFeature('none');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      // Return custom error widget or default error widget
      return widget.errorWidget ?? _buildDefaultErrorWidget(context);
    }

    // Use ErrorWidget.builder to catch errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      _recordError(details.exception, details.stack, reason: details.summary.toString());
      setState(() {
        _hasError = true;
      });
      return _buildDefaultErrorWidget(context);
    };
    
    // Return the child widget
    return widget.child;
  }

  Widget _buildDefaultErrorWidget(BuildContext context) {
    return Material(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There was a problem in the ${widget.featureName} feature.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                setState(() {
                  _hasError = false;
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  void _recordError(dynamic exception, StackTrace? stack, {String? reason}) {
    // Only record if Crashlytics is available
    try {
      _crashlytics.recordError(
        exception,
        stack,
        reason: reason ?? 'Error in ${widget.featureName}',
        fatal: false,
        information: {
          'feature': widget.featureName,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } catch (e) {
      debugPrint('Failed to record error to Crashlytics: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update the current screen name for better error tracking
    _crashlytics.setCurrentScreen(
      '${widget.featureName}_screen',
    );
  }
}