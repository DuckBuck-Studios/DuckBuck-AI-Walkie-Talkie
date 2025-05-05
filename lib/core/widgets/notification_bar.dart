import 'package:flutter/material.dart';

/// A reusable notification bar widget that appears at the bottom.
class NotificationBar extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const NotificationBar({
    super.key,
    required this.message,
    required this.onDismiss,
    this.backgroundColor = Colors.redAccent, // Default to error color
    this.textColor = Colors.white,
    this.icon = Icons.error_outline, // Default error icon
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SafeArea(
        top: false, // Only handle bottom safe area
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: textColor, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: textColor, size: 20),
                onPressed: onDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
