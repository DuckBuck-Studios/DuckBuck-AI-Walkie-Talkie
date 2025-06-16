import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;

/// UI components for walkie-talkie connection with funny messages
class WalkieTalkieUI {
  
  /// Build the walkie-talkie connection UI with timer and funny messages
  static Widget buildConnectionUI(
    BuildContext context, {
    required String message,
    required int remainingSeconds,
  }) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    
    Widget container = Container(
      constraints: BoxConstraints(
        maxWidth: screenWidth * 0.90,
        minHeight: screenHeight * 0.14,
        maxHeight: screenHeight * 0.15, // Added max height to prevent overflow
      ),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.02,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.6),
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
        mainAxisAlignment: MainAxisAlignment.center, // Center alignment
        mainAxisSize: MainAxisSize.min,
        children: [            
          // Funny message text (centered)
          _buildMessageText(context, message, screenWidth),
          
          SizedBox(height: screenHeight * 0.015),
          
          // Timer countdown
          _buildTimerDisplay(context, remainingSeconds, screenWidth),
        ],
      ),
    );
    
    Widget positioned = Positioned(
      bottom: screenHeight * 0.08,
      left: screenWidth * 0.05,
      right: screenWidth * 0.05,
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
  
  /// Build the funny message text with shimmer effect
  static Widget _buildMessageText(BuildContext context, String message, double screenWidth) {
    return Text(
      message,
      style: TextStyle(
        color: Colors.white,
        fontSize: screenWidth * 0.04,
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.none,
      ),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    )
    .animate()
    .shimmer(
      duration: 2000.ms,
      color: Colors.orange.withValues(alpha: 0.3),
      angle: 45,
    );
  }
  
  /// Build the countdown timer display
  static Widget _buildTimerDisplay(BuildContext context, int remainingSeconds, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenWidth * 0.015,
      ),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Platform.isIOS ? CupertinoIcons.timer : Icons.timer,
            color: Colors.orange,
            size: screenWidth * 0.04,
          ),
          SizedBox(width: screenWidth * 0.02),
          Text(
            '${remainingSeconds}s',
            style: TextStyle(
              color: Colors.orange,
              fontSize: screenWidth * 0.035,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    )
    .animate()
    .scaleXY(
      duration: 1000.ms,
      begin: 1.0,
      end: 1.05,
      curve: Curves.easeInOut,
    )
    .then()
    .scaleXY(
      duration: 1000.ms,
      begin: 1.05,
      end: 1.0,
      curve: Curves.easeInOut,
    );
  }
}
