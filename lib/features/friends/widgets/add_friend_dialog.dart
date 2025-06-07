import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../providers/relationship_provider.dart';
import 'profile_avatar.dart';

class AddFriendDialog extends StatefulWidget {
  final RelationshipProvider provider;

  const AddFriendDialog({
    super.key,
    required this.provider,
  });

  static Future<void> show(BuildContext context, RelationshipProvider provider) {
    if (Platform.isIOS) {
      return showCupertinoModalBottomSheet(context, provider);
    } else {
      return showMaterialModalBottomSheet(context, provider);
    }
  }
  
  // iOS-specific bottom sheet
  static Future<void> showCupertinoModalBottomSheet(BuildContext context, RelationshipProvider provider) {
    // Adjust height based on device size (smaller on smaller devices, larger on tablets)
    final mediaQuery = MediaQuery.of(context);
    final isSmallDevice = mediaQuery.size.height < 700;
    final height = mediaQuery.size.height * (isSmallDevice ? 0.80 : 0.85);
    
    return showCupertinoModalPopup(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      filter: ImageFilter.blur(sigmaX: 0.5, sigmaY: 0.5),
      useRootNavigator: true,
      semanticsDismissible: true,
      builder: (BuildContext dialogContext) {
        return SafeArea(
          child: AnimatedPadding(
            padding: MediaQuery.of(dialogContext).viewInsets,
            duration: const Duration(milliseconds: 275),
            curve: Curves.easeOutQuad,
            child: SizedBox(
              height: height,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(12),
                ),
                child: AddFriendDialog(provider: provider),
              ),
            ),
          ),
        );
      },
    );
  }
  
  // Android/Material-specific bottom sheet
  static Future<void> showMaterialModalBottomSheet(BuildContext context, RelationshipProvider provider) {
    // Adjust height based on device size (smaller on smaller devices, larger on tablets)
    final mediaQuery = MediaQuery.of(context);
    final isSmallDevice = mediaQuery.size.height < 700;
    final heightFactor = isSmallDevice ? 0.80 : 0.85;
    
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      useRootNavigator: true,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (BuildContext dialogContext) {
        return FractionallySizedBox(
          heightFactor: heightFactor,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.2),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: ModalRoute.of(dialogContext)!.animation!,
              curve: Curves.easeOutCubic,
            )),
            child: AddFriendDialog(provider: provider),
          ),
        );
      },
    );
  }

  @override
  State<AddFriendDialog> createState() => _AddFriendDialogState();
}

class _AddFriendDialogState extends State<AddFriendDialog> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _foundUserData;
  bool _isSearching = false;
  bool _hasSearched = false;
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Show platform-specific notification
  void _showNotification(String message, {bool isError = false}) {
    if (Platform.isIOS) {
      _showCupertinoNotification(message, isError: isError);
    } else {
      _showMaterialNotification(message, isError: isError);
    }
  }
  
  // iOS-specific notification
  void _showCupertinoNotification(String message, {bool isError = false}) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: true,
      useRootNavigator: true,
      builder: (context) => CupertinoAlertDialog(
        title: Text(isError ? 'Error' : 'Success'),
        content: Text(
          message,
          style: const TextStyle(
            fontSize: 15,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
  
  // Android-specific notification
  void _showMaterialNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _searchUser() async {
    final uid = _controller.text.trim();
    if (uid.isEmpty) return;
    
    // Clear previous search results
    if (_foundUserData != null) {
      setState(() {
        _foundUserData = null;
      });
    }
    
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });
    
    try {
      final result = await widget.provider.searchUserByUid(uid);
      
      if (mounted) {
        setState(() {
          _foundUserData = result;
          _isSearching = false;
        });
        
        if (result == null) {
          _showNotification('User not found', isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showNotification('Error: ${e.toString()}', isError: true);
        setState(() {
          _isSearching = false;
        });
      }
    }
  }
  
  Future<void> _sendFriendRequest() async {
    if (_foundUserData == null) return;
    
    setState(() {
      _isSearching = true;
    });
    
    try {
      final userName = _foundUserData!['displayName'] ?? 'Unknown User';
      final uid = _foundUserData!['uid'];
      final success = await widget.provider.sendFriendRequest(uid);
      
      if (mounted) {
        // Clear the search field and properly reset all state
        _controller.clear();
        setState(() {
          _foundUserData = null;
          _hasSearched = false;
          _isSearching = false;
        });
        
        // Show success message and close the dialog
        Navigator.of(context).pop();
        
        _showNotification(
          success 
            ? 'Friend request sent to $userName!' 
            : 'Failed to send friend request',
          isError: !success
        );
      }
    } catch (e) {
      if (mounted) {
        // Show error message
        _showNotification('Error: ${e.toString()}', isError: true);
        
        // Reset loading state but keep other state intact
        setState(() {
          _isSearching = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // Use platform-specific container
    final container = Platform.isIOS ? _buildCupertinoContainer(context) : _buildMaterialContainer(context);
    
    // Wrap with Material or CupertinoApp if theming issues persist at the root of the dialog
    // For now, assuming the context provides the necessary theme.
    return SafeArea(child: container);
  }
  
  // iOS-specific UI container
  Widget _buildCupertinoContainer(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    return CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        // Ensuring the dialog uses the app's dark theme context if applicable
        // or override specific parts like primaryColor if needed.
        // primaryColor: AppColors.accentBlue, // Example, prefer inherited theme
        textTheme: CupertinoTheme.of(context).textTheme.copyWith(
          // textStyle: TextStyle(color: AppColors.textPrimary), // Prefer inherited theme
        )
      ),
      child: Container(
        decoration: BoxDecoration(
          color: CupertinoColors.systemGroupedBackground.resolveFrom(context), // Changed from darkBackgroundGray
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle indicator
            Center(
              child: Container(
                height: 5,
                width: 40,
                margin: const EdgeInsets.only(top: 8, bottom: 16),
                decoration: BoxDecoration(
                  color: CupertinoColors.inactiveGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Add New Friend',
                    style: cupertinoTheme.textTheme.navTitleTextStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      color: cupertinoTheme.textTheme.textStyle.color
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Icon(CupertinoIcons.xmark_circle_fill, size: 24),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Search description
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                'Enter the DuckBuck ID of the user you want to add.',
                style: cupertinoTheme.textTheme.tabLabelTextStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context)
                ),
              ),
            ),
            
            // Search input - iOS style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: CupertinoTextField(
                controller: _controller,
                placeholder: 'Enter User ID',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 12.0),
                  child: Icon(CupertinoIcons.search, color: CupertinoColors.placeholderText),
                ),
                clearButtonMode: OverlayVisibilityMode.editing,
                keyboardType: TextInputType.text,
                autocorrect: false,
                onSubmitted: (_) => _searchUser(),
                style: TextStyle(color: cupertinoTheme.textTheme.textStyle.color),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            
            // Result section
            Expanded(
              child: _isSearching
                ? const Center(child: CupertinoActivityIndicator())
                : _buildResultSection(),
            ),
            
            // Search button (moved to bottom)
            if (!_hasSearched || (_hasSearched && _foundUserData == null)) 
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _searchUser,
                    child: const Text('Search User'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Material-specific UI container
  Widget _buildMaterialContainer(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface, // Changed from AppColors.surfaceBlack
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle indicator
          Center(
            child: Container(
              height: 5,
              width: 40,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2.5),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add New Friend',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: theme.colorScheme.onSurface),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          
          // Search description
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Text(
              'Enter the DuckBuck ID of the user you want to add.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          
          // Search input - Material style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter User ID',
                prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest, // Or surfaceVariant
              ),
              onSubmitted: (_) => _searchUser(),
              style: TextStyle(color: theme.colorScheme.onSurface),
            ),
          ),
          
          // Result section
          Expanded(
            child: _isSearching
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : _buildResultSection(),
          ),
          
          // Search button (moved to bottom)
          if (!_hasSearched || (_hasSearched && _foundUserData == null)) 
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search User'),
                  onPressed: _searchUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildResultSection() {
    // Show platform-specific result section
    return Platform.isIOS 
      ? _buildCupertinoResultSection() 
      : _buildMaterialResultSection();
  }
  
  // iOS-specific result section
  Widget _buildCupertinoResultSection() {
    final cupertinoTheme = CupertinoTheme.of(context);
    // Show nothing if we haven't searched yet
    if (!_hasSearched) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.search_circle, size: 80, color: CupertinoColors.systemGrey2.resolveFrom(context)),
              const SizedBox(height: 16),
              Text(
                'Find your friends by their ID',
                style: cupertinoTheme.textTheme.tabLabelTextStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context)
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Show user not found
    if (_foundUserData == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(CupertinoIcons.person_crop_circle_badge_xmark, size: 80, color: CupertinoColors.systemRed.resolveFrom(context)),
              const SizedBox(height: 16),
              Text(
                'User Not Found',
                style: cupertinoTheme.textTheme.navTitleTextStyle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cupertinoTheme.textTheme.textStyle.color
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Double-check the ID and try again.',
                style: cupertinoTheme.textTheme.tabLabelTextStyle.copyWith(
                  color: CupertinoColors.secondaryLabel.resolveFrom(context)
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Show found user
    final userName = _foundUserData!['displayName'] ?? 'Unknown User';
    final photoURL = _foundUserData!['photoURL'];
    
    // Calculate optimal avatar size based on device size
    final deviceWidth = MediaQuery.of(context).size.width;
    final avatarRadius = deviceWidth * 0.18; // 36% of screen width for diameter
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User profile card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                ProfileAvatar(
                  radius: avatarRadius, 
                  photoURL: photoURL, 
                  displayName: userName,
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: cupertinoTheme.textTheme.navTitleTextStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: deviceWidth * 0.05, // Responsive font size
                    color: cupertinoTheme.textTheme.textStyle.color
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Send request button - iOS style
          SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled( // Changed to filled
              onPressed: _sendFriendRequest,
              child: const Text('Send Friend Request'),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Cancel button - iOS style
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: cupertinoTheme.primaryColor)),
            ),
          ),
        ],
      ),
    );
  }
  
  // Android-specific result section
  Widget _buildMaterialResultSection() {
    final theme = Theme.of(context);
    // Show nothing if we haven't searched yet
    if (!_hasSearched) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, size: 80, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              Text(
                'Find your friends by their ID',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Show user not found
    if (_foundUserData == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 80, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(
                'User Not Found',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onErrorContainer, // Or onSurface
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Double-check the ID and try again.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    // Show found user
    final userName = _foundUserData!['displayName'] ?? 'Unknown User';
    final photoURL = _foundUserData!['photoURL'];
    
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // User profile card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest, // Or surfaceVariant
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                // Calculate optimal avatar size based on device width
                ProfileAvatar(
                  radius: MediaQuery.of(context).size.width * 0.18, 
                  photoURL: photoURL, 
                  displayName: userName
                ),
                const SizedBox(height: 16),
                Text(
                  userName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: MediaQuery.of(context).size.width * 0.05, // Responsive font size
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const Spacer(),
          
          // Send request button - Material style
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Send Friend Request'),
              onPressed: _sendFriendRequest,
              style: ElevatedButton.styleFrom( // Ensured proper styling
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Cancel button - Material style
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
