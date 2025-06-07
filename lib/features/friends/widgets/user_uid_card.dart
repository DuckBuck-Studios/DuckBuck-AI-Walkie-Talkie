import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

/// A beautiful card widget that displays the current user's UID with copy functionality
/// 
/// Features:
/// - Platform-specific design (iOS/Android)
/// - Copy to clipboard functionality with haptic feedback
/// - Success animation and feedback
/// - Modern card design with shadows and proper spacing
class UserUidCard extends StatefulWidget {
  final String? uid;
  final VoidCallback? onCopy;

  const UserUidCard({
    super.key,
    required this.uid,
    this.onCopy,
  });

  @override
  State<UserUidCard> createState() => _UserUidCardState();
}

class _UserUidCardState extends State<UserUidCard>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  bool _showCopiedFeedback = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _copyToClipboard() async {
    if (widget.uid == null) return;

    // Animate button press
    await _animationController.forward();
    await _animationController.reverse();

    // Copy to clipboard
    await Clipboard.setData(ClipboardData(text: widget.uid!));
    
    // Haptic feedback
    if (Platform.isIOS) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.vibrate();
    }

    // Show copied feedback
    setState(() {
      _showCopiedFeedback = true;
    });

    // Hide feedback after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _showCopiedFeedback = false;
        });
      }
    });

    // Call optional callback
    widget.onCopy?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid == null) {
      return const SizedBox.shrink();
    }

    return Platform.isIOS ? _buildCupertinoCard() : _buildMaterialCard();
  }

  Widget _buildCupertinoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.resolveFrom(context).withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _copyToClipboard,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue.resolveFrom(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        CupertinoIcons.person_badge_plus,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                        size: 20,
                      ),
                    ),
                    
                    const SizedBox(width: 16),
                    
                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your User ID',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.secondaryLabel.resolveFrom(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.uid!,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.label.resolveFrom(context),
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Copy action
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _showCopiedFeedback
                          ? Icon(
                              CupertinoIcons.checkmark_circle_fill,
                              color: CupertinoColors.systemGreen,
                              size: 24,
                              key: const ValueKey('success'),
                            )
                          : Icon(
                              CupertinoIcons.doc_on_doc,
                              color: CupertinoColors.activeBlue.resolveFrom(context),
                              size: 20,
                              key: const ValueKey('copy'),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterialCard() {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: theme.colorScheme.surface,
              child: InkWell(
                onTap: _copyToClipboard,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withAlpha(26), // 0.1 * 255 = ~26
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.badge,
                          color: theme.colorScheme.primary,
                          size: 20,
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Your User ID',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.uid!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurface,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Copy action
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _showCopiedFeedback
                            ? Icon(
                                Icons.check_circle,
                                color: theme.colorScheme.primary,
                                size: 24,
                                key: const ValueKey('success'),
                              )
                            : Icon(
                                Icons.copy,
                                color: theme.colorScheme.primary,
                                size: 20,
                                key: const ValueKey('copy'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
