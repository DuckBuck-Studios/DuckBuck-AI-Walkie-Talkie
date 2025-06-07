import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// A reusable notification bar widget that appears at the top.
/// Now with platform-specific implementation, auto-dismiss, and optimized rendering.
class NotificationBar extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  final Color backgroundColor;
  final Color textColor;
  final IconData? icon;
  final bool autoDismiss;
  final Duration autoDismissDuration;

  const NotificationBar({
    super.key,
    required this.message,
    required this.onDismiss,
    this.backgroundColor = Colors.redAccent, // Default to error color
    this.textColor = Colors.white,
    this.icon = Icons.error_outline, // Default error icon
    this.autoDismiss = true, // Auto-dismiss by default
    this.autoDismissDuration = const Duration(milliseconds: 1500), // 1.5 seconds
  });

  @override
  State<NotificationBar> createState() => _NotificationBarState();
}

class _NotificationBarState extends State<NotificationBar> {
  @override
  void initState() {
    super.initState();
    
    // Set up auto-dismiss timer if enabled
    if (widget.autoDismiss) {
      Future.delayed(widget.autoDismissDuration, () {
        if (mounted) {
          widget.onDismiss();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    // Platform specific icon
    final displayIcon = widget.icon ?? (isIOS 
      ? CupertinoIcons.exclamationmark_triangle 
      : Icons.error_outline);
    
    // Use RepaintBoundary for better rendering performance
    return RepaintBoundary(
      child: Material(
        color: widget.backgroundColor,
        elevation: 2,
        child: SafeArea(
          bottom: false, // Only handle top safe area
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isIOS ? 18.0 : 16.0, 
              vertical: isIOS ? 12.0 : 10.0
            ),
            child: Row(
              children: [
                Icon(displayIcon, color: widget.textColor, size: isIOS ? 18 : 20),
                SizedBox(width: isIOS ? 10 : 12),
                Expanded(
                  child: Text(
                    widget.message,
                    style: TextStyle(
                      color: widget.textColor, 
                      fontSize: isIOS ? 13 : 14,
                      fontWeight: isIOS ? FontWeight.w500 : FontWeight.normal
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Platform-specific close button
                if (!widget.autoDismiss) // Only show close button if not auto-dismissing
                  isIOS                        ? CupertinoButton(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(20, 20),
                          onPressed: widget.onDismiss,
                          child: Icon(
                            CupertinoIcons.clear, 
                            color: widget.textColor, 
                            size: 18
                          ),
                        )
                      : IconButton(
                          icon: Icon(Icons.close, color: widget.textColor, size: 20),
                          onPressed: widget.onDismiss,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Dismiss',
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
