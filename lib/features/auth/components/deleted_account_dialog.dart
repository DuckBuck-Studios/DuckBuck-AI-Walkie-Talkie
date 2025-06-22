import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import '../../../core/theme/app_colors.dart';
import '../../../core/exceptions/auth_exceptions.dart';
import '../../../core/repositories/auth_repository.dart';
import '../../../core/services/service_locator.dart';

/// Result of the deleted account dialog interaction
enum DeletedAccountAction {
  restore,
  keepDeleted,
  cancel,
}

/// A beautiful, enhanced dialog for handling deleted account scenarios
class DeletedAccountDialog extends StatefulWidget {
  final AuthException error;
  final VoidCallback? onRestoreSuccess;
  final VoidCallback? onKeepDeleted;

  const DeletedAccountDialog({
    super.key,
    required this.error,
    this.onRestoreSuccess,
    this.onKeepDeleted,
  });

  /// Show the deleted account dialog
  static Future<DeletedAccountAction?> show({
    required BuildContext context,
    required AuthException error,
    VoidCallback? onRestoreSuccess,
    VoidCallback? onKeepDeleted,
  }) async {
    final bool isIOS = Platform.isIOS;
    
    if (isIOS) {
      return await showCupertinoDialog<DeletedAccountAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DeletedAccountDialog(
          error: error,
          onRestoreSuccess: onRestoreSuccess,
          onKeepDeleted: onKeepDeleted,
        ),
      );
    } else {
      return await showDialog<DeletedAccountAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) => DeletedAccountDialog(
          error: error,
          onRestoreSuccess: onRestoreSuccess,
          onKeepDeleted: onKeepDeleted,
        ),
      );
    }
  }

  @override
  State<DeletedAccountDialog> createState() => _DeletedAccountDialogState();
}

class _DeletedAccountDialogState extends State<DeletedAccountDialog>
    with TickerProviderStateMixin {
  bool _isRestoring = false;
  String? _uid;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _extractUidFromError();
    _setupAnimations();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _extractUidFromError() {
    try {
      // Get UID from Firebase Auth user since they're still temporarily signed in
      // Using AuthRepository for clean architecture
      final authRepository = serviceLocator<AuthRepository>();
      _uid = authRepository.currentUser?.uid;

      // Fallback: try to extract from error message if auth provider doesn't have it
      if (_uid == null) {
        final errorMessage = widget.error.message;
        if (errorMessage.contains('uid:')) {
          final uidMatch = RegExp(r'uid:\s*([^,}]+)').firstMatch(errorMessage);
          if (uidMatch != null) {
            _uid = uidMatch.group(1)?.trim();
          }
        }
      }
      
      // Debug logging to understand what's happening
      print('DEBUG: Extracted UID for account restoration: $_uid');
      print('DEBUG: Firebase Auth user exists: ${authRepository.currentUser != null}');
      print('DEBUG: Error code: ${widget.error.code}');
      print('DEBUG: Error message: ${widget.error.message}');
    } catch (e) {
      print('Failed to get UID for account restoration: ${e.toString()}');
    }
  }

  Future<void> _handleRestore() async {
    if (_uid == null || _isRestoring) return;

    setState(() => _isRestoring = true);
    HapticFeedback.mediumImpact();

    try {
      // Use AuthRepository for clean architecture
      final authRepository = serviceLocator<AuthRepository>();
      await authRepository.restoreCurrentUserAccount();

      if (mounted) {
        // Close dialog with restore result
        Navigator.of(context).pop(DeletedAccountAction.restore);
        
        // Call success callback
        widget.onRestoreSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isRestoring = false);
        
        // Show error with enhanced feedback
        HapticFeedback.heavyImpact();
        _showErrorSnackBar('Failed to restore account: ${e.toString()}');
      }
    }
  }

  void _handleKeepDeleted() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop(DeletedAccountAction.keepDeleted);
    widget.onKeepDeleted?.call();
  }

  void _showErrorSnackBar(String message) {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      print('Failed to show error message: $message');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isIOS = Platform.isIOS;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: isIOS ? _buildCupertinoDialog() : _buildMaterialDialog(),
          ),
        );
      },
    );
  }

  Widget _buildCupertinoDialog() {
    return CupertinoAlertDialog(
      title: Column(
        children: [
          Icon(
            CupertinoIcons.exclamationmark_triangle_fill,
            color: Colors.orange,
            size: 28,
          ),
          const SizedBox(height: 8),
          Text(
            'Account Deleted',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      content: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          _uid != null 
            ? 'Your account is marked as deleted. You can restore it or keep it deleted permanently.'
            : 'This account has been deleted. Restoration is not available.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
      actions: _buildCupertinoActions(),
    );
  }

  Widget _buildMaterialDialog() {
    final screenSize = MediaQuery.of(context).size;
    final maxWidth = screenSize.width > 400 ? 350.0 : screenSize.width * 0.85;
    final maxHeight = screenSize.height * 0.8; // Prevent dialog from being too tall
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: maxHeight,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.pureBlack,
              AppColors.pureBlack.withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.whiteOpacity20,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTitle(),
                const SizedBox(height: 16),
                _buildContent(),
                const SizedBox(height: 24),
                _buildMaterialActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.orange.withValues(alpha: 0.3),
                Colors.orange.withValues(alpha: 0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Icon(
            Platform.isIOS ? CupertinoIcons.exclamationmark_triangle_fill : Icons.warning_rounded,
            color: Colors.orange,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Account Deleted',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return Text(
      _uid != null 
        ? 'Your account is marked as deleted. You can restore it or keep it deleted permanently.'
        : 'This account has been deleted. Restoration is not available.',
      style: TextStyle(
        fontSize: 16,
        color: AppColors.whiteOpacity80,
        height: 1.5,
        letterSpacing: 0.1,
      ),
      textAlign: TextAlign.center,
    );
  }

  List<Widget> _buildCupertinoActions() {
    return [
      CupertinoDialogAction(
        onPressed: _isRestoring ? null : _handleKeepDeleted,
        isDestructiveAction: true,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.trash,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text('Keep Deleted'),
          ],
        ),
      ),
      if (_uid != null)
        CupertinoDialogAction(
          onPressed: _isRestoring ? null : _handleRestore,
          child: _isRestoring
            ? const CupertinoActivityIndicator()
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    CupertinoIcons.refresh_circled,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text('Restore Account'),
                ],
              ),
        ),
    ];
  }

  Widget _buildMaterialActions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Use vertical layout for smaller screens or when dialog would be cramped
    final isSmallScreen = screenWidth < 500 || screenHeight < 600;
    final useVerticalLayout = isSmallScreen && _uid != null;
    
    if (useVerticalLayout) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              onPressed: _isRestoring ? null : _handleRestore,
              label: 'Restore Account',
              isDestructive: false,
              isLoading: _isRestoring,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: _buildActionButton(
              onPressed: _isRestoring ? null : _handleKeepDeleted,
              label: 'Keep Deleted',
              isDestructive: true,
              isLoading: false,
            ),
          ),
        ],
      );
    }
    
    // Use horizontal layout for larger screens
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            onPressed: _isRestoring ? null : _handleKeepDeleted,
            label: 'Keep Deleted',
            isDestructive: true,
            isLoading: false,
          ),
        ),
        if (_uid != null) ...[
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionButton(
              onPressed: _isRestoring ? null : _handleRestore,
              label: 'Restore Account',
              isDestructive: false,
              isLoading: _isRestoring,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback? onPressed,
    required String label,
    required bool isDestructive,
    required bool isLoading,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        gradient: isDestructive
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.shade600,
                Colors.red.shade800,
              ],
            )
          : LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accentBlue,
                AppColors.accentBlue.withValues(alpha: 0.8),
              ],
            ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDestructive 
            ? Colors.red.shade500.withValues(alpha: 0.6)
            : AppColors.accentBlue.withValues(alpha: 0.6),
          width: 1,
        ),
        boxShadow: onPressed != null ? [
          BoxShadow(
            color: isDestructive 
              ? Colors.red.withValues(alpha: 0.3)
              : AppColors.accentBlue.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ] : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            alignment: Alignment.center,
            child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isDestructive) ...[
                      Icon(
                        Platform.isIOS ? CupertinoIcons.trash : Icons.delete_outline,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                    ] else ...[
                      Icon(
                        Platform.isIOS ? CupertinoIcons.refresh_circled : Icons.restore_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
          ),
        ),
      ),
    );
  }
}
