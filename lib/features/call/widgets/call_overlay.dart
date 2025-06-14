import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/call_provider.dart';
import '../models/call_state.dart';
import '../screens/call_screen.dart';

/// A global overlay widget that shows the call screen when a call is active
/// This should be placed at the root of the app to overlay all other screens
class CallOverlay extends StatelessWidget {
  final Widget child;

  const CallOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main app content
        child,
        
        // Call overlay - only visible when there's an active call from receiver side
        Consumer<CallProvider>(
          builder: (context, callProvider, _) {
            // Only show overlay for receiver calls, not initiator calls
            // Initiator calls should stay in the fullscreen photo viewer
            if (!callProvider.isInCall || 
                callProvider.currentCall == null ||
                callProvider.currentRole == CallRole.INITIATOR) {
              return const SizedBox.shrink();
            }
            
            return Material(
              type: MaterialType.transparency,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.black,
                child: const CallScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}
