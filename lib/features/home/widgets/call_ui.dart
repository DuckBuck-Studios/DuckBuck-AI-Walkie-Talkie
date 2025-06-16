import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../call/models/call_state.dart';
import 'dart:io' show Platform;

/// Enhanced call UI with different loading states, shimmer animations, and funny messages
class CallUI {
  
  /// Builds the enhanced call loading UI with different states
  static Widget buildLoadingUI(
    BuildContext context, {
    required CallLoadingState state,
    VoidCallback? onRetry,
  }) {
    switch (state) {
      case CallLoadingState.connecting:
        return _buildConnectingState(context);
      case CallLoadingState.waitingLong:
        return _buildWaitingLongState(context);
      case CallLoadingState.failed:
        return _buildFailedState(context, onRetry);
    }
  }

  /// Builds the initial "connecting to your friend" state with shimmer
  static Widget _buildConnectingState(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    Widget container = Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth * 0.90, // Reduced from 0.92
        minHeight: screenHeight * 0.12,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04, // Reduced from 0.05
        vertical: screenHeight * 0.02,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Centered connecting text
          Center(
            child: _buildAnimatedText(
              context,
              text: "Connecting to your friend...", // Centered text
              fontSize: screenWidth * 0.04,
              color: Colors.white,
              delay: 200.ms,
            ),
          ),
          
          SizedBox(height: screenHeight * 0.015),
          
          // Enhanced animated dots with better spacing
          SizedBox(
            height: screenWidth * 0.04,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.01),
                  width: screenWidth * 0.025,
                  height: screenWidth * 0.025,
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.8),
                    shape: BoxShape.circle,
                  ),
                )
                .animate(onPlay: (controller) => controller.repeat())
                .scaleXY(
                  duration: 800.ms,
                  delay: (index * 250).ms,
                  begin: 0.6,
                  end: 1.3,
                  curve: Curves.easeInOut,
                )
                .then()
                .scaleXY(
                  duration: 800.ms,
                  begin: 1.3,
                  end: 0.6,
                  curve: Curves.easeInOut,
                );
              }),
            ),
          ),
        ],
      ),
    );
    
    Widget positioned = Positioned(
      bottom: screenHeight * 0.08, // Better spacing from bottom
      left: screenWidth * 0.05, // Increased for better margins
      right: screenWidth * 0.05, // Increased for better margins
      child: container,
    );
    
    return positioned.animate()
      .slideY(
        duration: 600.ms,
        curve: Curves.easeOutQuart,
        begin: 1.0,
        end: 0.0,
      )
      .fadeIn(duration: 500.ms, curve: Curves.easeOut);
  }

  /// Builds the "waiting long" state with a funny message about friend's internet
  static Widget _buildWaitingLongState(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    final funnyMessages = [
      "🐌 Your friend's internet is slower than a snail...",
      "📡 Waiting for your friend's dial-up connection...", 
      "🚀 Your friend's WiFi is stuck in the stone age...",
      "🔍 Your friend's router is taking a nap...",
      "⏰ Your friend's connection is buffering life...",
      "🦄 Searching for your friend's mythical signal...",
      "🛰️ Your friend's internet is powered by pigeons...",
      "🎭 Your friend's WiFi is having an existential crisis...",
    ];
    
    final randomMessage = funnyMessages[(DateTime.now().millisecondsSinceEpoch % funnyMessages.length)];
    
    return Positioned(
      bottom: screenHeight * 0.08,
      left: screenWidth * 0.05, // Increased for better margins
      right: screenWidth * 0.05, // Increased for better margins
      child: Container(
        constraints: BoxConstraints(
          maxWidth: screenWidth * 0.90, // Reduced from 0.92
          minHeight: screenHeight * 0.14,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04, // Reduced from 0.05
          vertical: screenHeight * 0.025,
        ),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.orange.withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Funny message with smooth text transition and reduced font size
            _buildAnimatedText(
              context,
              text: randomMessage,
              fontSize: screenWidth * 0.035, // Reduced from 0.038
              color: Colors.orange,
              delay: 300.ms,
            ),
            
            SizedBox(height: screenHeight * 0.02),
            
            // Enhanced waiting indicator with better spacing and overflow protection
            Container(
              height: screenHeight * 0.025,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: _buildAnimatedText(
                      context,
                      text: "Still trying to reach your friend",
                      fontSize: screenWidth * 0.03, // Reduced from 0.033
                      color: Colors.white,
                      delay: 600.ms,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.015), // Reduced from 0.02
                  ...List.generate(3, (index) {
                    return Text(
                      ".",
                      style: TextStyle(
                        color: Colors.orange.withValues(alpha: 0.9),
                        fontSize: screenWidth * 0.05, // Reduced from 0.055
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                        height: 1.0,
                      ),
                    )
                    .animate(onPlay: (controller) => controller.repeat())
                    .fadeIn(
                      duration: 900.ms,
                      delay: (index * 350).ms + 800.ms,
                      curve: Curves.easeInOut,
                    )
                    .then()
                    .fadeOut(
                      duration: 900.ms,
                      curve: Curves.easeInOut,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    )
    .animate()
    .slideX(
      duration: 700.ms,
      curve: Curves.easeOutQuart,
      begin: -1.0,
      end: 0.0,
    )
    .fadeIn(duration: 600.ms, curve: Curves.easeOut);
  }

  /// Builds the failed state with a funny error message
  static Widget _buildFailedState(BuildContext context, VoidCallback? onRetry) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    final errorMessages = [
      "💥 Oops! Your friend's phone went to Narnia...",
      "🤖 Connection failed - blame the robots!",
      "🌊 Your call got lost in the internet ocean...",
      "🎭 Your friend is in 'Do Not Disturb' mode IRL...",
      "🧙‍♂️ The WiFi wizard cast a disconnect spell...",
      "🎪 Connection error: friend's circus has no signal...",
      "👻 Your friend's phone is being haunted...",
      "🛸 Aliens abducted your friend's connection...",
    ];
    
    final randomError = errorMessages[(DateTime.now().millisecondsSinceEpoch % errorMessages.length)];
    
    return Positioned(
      bottom: screenHeight * 0.08,
      left: screenWidth * 0.05, // Increased for better margins
      right: screenWidth * 0.05, // Increased for better margins
      child: GestureDetector(
        onTap: onRetry, // Tap to retry
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenWidth * 0.90, // Reduced from 0.92
            minHeight: screenHeight * 0.12,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04, // Reduced from 0.05
            vertical: screenHeight * 0.025,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.red.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.red.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Error message with enhanced shake animation
              Text(
                randomError,
                style: TextStyle(
                  color: Colors.red.withValues(alpha: 0.95),
                  fontSize: screenWidth * 0.035, // Reduced from 0.038
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(
                duration: 600.ms,
                curve: Curves.easeOutQuart,
              )
              .slideY(
                duration: 500.ms,
                begin: 0.3,
                end: 0.0,
                curve: Curves.easeOutQuart,
              )
              .then(delay: 200.ms)
              .shake(
                duration: 600.ms, 
                hz: 2,
                curve: Curves.easeInOut,
              ),
              
              SizedBox(height: screenHeight * 0.02),
              
              // Instruction to try again with enhanced animation
              _buildAnimatedText(
                context,
                text: "✨ Tap to exit, hold to try again",
                fontSize: screenWidth * 0.035,
                color: Colors.blue,
                delay: 800.ms,
              ),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(
      duration: 600.ms,
      curve: Curves.easeOut,
    )
    .slideY(
      duration: 700.ms,
      curve: Curves.easeOutQuart,
      begin: 1.0,
      end: 0.0,
    )
    .then(delay: 300.ms)
    .shake(
      duration: 800.ms, 
      hz: 1.5,
      curve: Curves.easeInOut,
    );
  }

  /// Builds animated text with smooth transitions and premium effects
  static Widget _buildAnimatedText(
    BuildContext context, {
    required String text,
    required double fontSize,
    required Color color,
    Duration delay = Duration.zero,
  }) {
    return Text(
      text,
      style: TextStyle(
        color: color.withValues(alpha: 0.95),
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        decoration: TextDecoration.none,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    )
    .animate()
    .fadeIn(
      duration: 800.ms,
      delay: delay,
      curve: Curves.easeOutQuart,
    )
    .slideY(
      duration: 600.ms,
      delay: delay,
      begin: 0.3,
      end: 0.0,
      curve: Curves.easeOutQuart,
    )
    .shimmer(
      duration: 2500.ms,
      delay: delay + 400.ms,
      color: color.withValues(alpha: 0.3),
      angle: 45,
    );
  }
  
  /// Builds enhanced "tap to exit, hold to start" UI with clear instructions
  static Widget buildInstructionUI(
    BuildContext context, {
    required VoidCallback onExit,
    VoidCallback? onLongPress,
    // Walkie-talkie connection state
    bool isConnecting = false,
    String connectingMessage = '',
    int remainingSeconds = 0,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    Widget container = Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth * 0.90,
      ),
      height: screenHeight * 0.08, // Fixed height container
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isConnecting 
            ? Colors.orange.withValues(alpha: 0.6)
            : Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isConnecting 
              ? Colors.orange.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Use Align with simple Center widget for connecting state to prevent overflow
      child: isConnecting 
        ? _buildConnectingContent(context, connectingMessage, screenWidth)
        : Align(
            alignment: Alignment.center,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: screenHeight * 0.01),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildNormalInstructionContent(context, onLongPress, screenWidth, screenHeight),
              ),
            ),
          ),
    );
    
    Widget positioned = Positioned(
      bottom: screenHeight * 0.08,
      left: screenWidth * 0.05,
      right: screenWidth * 0.05,
      child: GestureDetector(
        onTap: isConnecting ? null : onExit, // No tap action when connecting
        onLongPress: isConnecting ? null : onLongPress, // No long press when already connecting
        child: container,
      ),
    );
    
    return positioned.animate()
      .slideY(
        duration: 600.ms,
        curve: Curves.easeOutQuart,
        begin: 1.0,
        end: 0.0,
      )
      .fadeIn(duration: 500.ms, curve: Curves.easeOut);
  }

  /// Build content when walkie-talkie is connecting
  static Widget _buildConnectingContent(
    BuildContext context,
    String connectingMessage,
    double screenWidth,
  ) {
    return Center(
      child: _buildAnimatedText(
        context,
        text: connectingMessage.isNotEmpty ? connectingMessage : 'Connecting...',
        fontSize: screenWidth * 0.035,
        color: Colors.orange,
        delay: 0.ms,
      ),
    );
  }

  /// Build normal instruction content (when not connecting)
  static List<Widget> _buildNormalInstructionContent(
    BuildContext context,
    VoidCallback? onLongPress,
    double screenWidth,
    double screenHeight,
  ) {
    return [
      // Main instruction with better spacing
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: screenWidth * 0.06,
            height: screenWidth * 0.06,
            child: Icon(
              Platform.isIOS ? CupertinoIcons.hand_point_left_fill : Icons.touch_app,
              color: Colors.blue.withValues(alpha: 0.8),
              size: screenWidth * 0.045,
            )
            .animate(onPlay: (controller) => controller.repeat())
            .scaleXY(
              duration: 1800.ms,
              begin: 1.0,
              end: 1.08,
              curve: Curves.easeInOut,
            )
            .then()
            .scaleXY(
              duration: 1800.ms,
              begin: 1.08,
              end: 1.0,
              curve: Curves.easeInOut,
            ),
          ),
          
          SizedBox(width: screenWidth * 0.025),
          
          _buildAnimatedText(
            context,
            text: 'Tap to exit',
            fontSize: screenWidth * 0.038,
            color: Colors.white,
            delay: 200.ms,
          ),
        ],
      ),
      
      // Better spacing between instructions
      if (onLongPress != null) ...[
        SizedBox(height: screenHeight * 0.008),
        
        // Hold instruction
        _buildAnimatedText(
          context,
          text: 'Hold to start walkie-talkie',
          fontSize: screenWidth * 0.032,
          color: Colors.green,
          delay: 400.ms,
        ),
      ],
    ];
  }
}
