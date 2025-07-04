import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
import '../screens/call_screen.dart';

/// CallOverlay - Manages showing/hiding the call screen as an overlay
class CallOverlay extends StatelessWidget {
  final Widget child;

  const CallOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CallProvider>(
      builder: (context, callProvider, _) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Stack(
            children: [
              // Main app content
              child,
              
              // Call screen overlay (only shown when call is active)
              if (callProvider.isCallActive)
                const Positioned.fill(
                  child: CallScreen(),
                ),
            ],
          ),
        );
      },
    );
  }
}
