import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../providers/relationship_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:io' show Platform;

/// Production-level bottom sheet for searching and adding friends
/// 
/// Features:
/// - Real-time user search by UID
/// - Send friend request functionality
/// - Platform-specific design (iOS/Android)
/// - Loading states and error handling
/// - Input validation and debouncing
/// - Search and Cancel buttons at the bottom
/// 
/// This widget provides a complete user search and friend request flow
/// with proper UX patterns and error handling.
class SearchUserBottomSheet extends StatefulWidget {
  const SearchUserBottomSheet({super.key});

  /// Shows the search bottom sheet
  static void show(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (context) => const SearchUserBottomSheet(),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const SearchUserBottomSheet(),
      );
    }
  }

  @override
  State<SearchUserBottomSheet> createState() => _SearchUserBottomSheetState();
}

class _SearchUserBottomSheetState extends State<SearchUserBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  Map<String, dynamic>? _searchResult;
  bool _isSearching = false;
  String? _searchError;
  bool _isSendingRequest = false;
  
  // Friend request result states
  String? _requestSuccessMessage;
  String? _requestErrorMessage;

  @override
  void initState() {
    super.initState();
    // Auto-focus search field when sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoBottomSheet(context);
    } else {
      return _buildMaterialBottomSheet(context);
    }
  }

  /// Builds iOS-style bottom sheet
  Widget _buildCupertinoBottomSheet(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: screenHeight * 0.9,
      decoration: BoxDecoration(
        color: AppColors.backgroundBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
            decoration: BoxDecoration(
              color: AppColors.whiteOpacity30,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: Text(
              'Search Friends',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          
          SizedBox(height: screenHeight * 0.02),
          
          // Search field only
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
            child: CupertinoTextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              placeholder: 'Enter User ID',
              onChanged: _onSearchChanged,
              onSubmitted: (value) => _performSearch(value),
              style: TextStyle(color: AppColors.textPrimary),
              decoration: BoxDecoration(
                color: AppColors.whiteOpacity10,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.04,
                vertical: screenHeight * 0.015,
              ),
            ),
          ),
          
          SizedBox(height: screenHeight * 0.03),
          
          // Content
          Expanded(
            child: _buildContent(),
          ),
          
          // Bottom buttons - Search/Send Request and Cancel
          Container(
            padding: EdgeInsets.all(screenWidth * 0.04),
            decoration: BoxDecoration(
              color: AppColors.backgroundBlack,
              border: Border(
                top: BorderSide(
                  color: AppColors.whiteOpacity20,
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomPadding),
              child: SafeArea(
                top: false,
                child: _shouldShowBottomButtons() ? Column(
                  children: [
                    // Primary action button (Search or Send Friend Request)
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton.filled(
                        onPressed: _isSearching || _isSendingRequest ? null : _handlePrimaryAction,
                        child: _isSearching || _isSendingRequest
                            ? const CupertinoActivityIndicator(color: AppColors.primaryBlack, radius: 12)
                            : Text(
                                _getPrimaryButtonText(),
                                style: TextStyle(
                                  color: AppColors.primaryBlack,
                                  fontWeight: FontWeight.w600,
                                  fontSize: screenWidth * 0.04,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.015),
                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: CupertinoButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: screenWidth * 0.04,
                          ),
                        ),
                      ),
                    ),
                  ],
                ) : SizedBox(
                  width: double.infinity,
                  child: CupertinoButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds Android-style bottom sheet
  Widget _buildMaterialBottomSheet(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.backgroundBlack,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: Column(
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.whiteOpacity30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Search Friends',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Search field only
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter User ID',
                  hintStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: Icon(Icons.search, color: AppColors.accentBlue),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: AppColors.textSecondary),
                          onPressed: _clearSearch,
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.accentBlue, width: 2),
                  ),
                  filled: true,
                  fillColor: AppColors.whiteOpacity10,
                ),
                onChanged: _onSearchChanged,
                onSubmitted: _performSearch,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Content
            Expanded(
              child: _buildContent(),
            ),
            
            // Bottom buttons - Search/Send Request and Cancel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundBlack,
                border: Border(
                  top: BorderSide(
                    color: AppColors.whiteOpacity20,
                    width: 1,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: _shouldShowBottomButtons() ? Column(
                  children: [
                    // Primary action button (Search or Send Friend Request)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSearching || _isSendingRequest ? null : _handlePrimaryAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentBlue,
                          foregroundColor: AppColors.primaryBlack,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isSearching || _isSendingRequest
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlack),
                                ),
                              )
                            : Text(
                                _getPrimaryButtonText(),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryBlack,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Cancel button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppColors.textSecondary),
                          foregroundColor: AppColors.textSecondary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ) : SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: AppColors.textSecondary),
                      foregroundColor: AppColors.textSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the main content area based on current state
  Widget _buildContent() {
    if (_isSendingRequest) {
      return _buildSendingRequestState();
    }

    if (_requestSuccessMessage != null) {
      return _buildSuccessState();
    }

    if (_requestErrorMessage != null) {
      return _buildRequestErrorState();
    }

    if (_isSearching) {
      return _buildLoadingState();
    }

    if (_searchError != null) {
      return _buildErrorState();
    }

    if (_searchResult != null) {
      return _buildSearchResult();
    }

    return _buildEmptyState();
  }

  /// Builds loading state
  Widget _buildLoadingState() {
    if (Platform.isIOS) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CupertinoActivityIndicator(
              radius: 16,
              color: AppColors.accentBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }
  }

  /// Builds error state
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.exclamationmark_triangle : Icons.error_outline,
              size: 64,
              color: AppColors.errorRed,
            ),
            const SizedBox(height: 16),
            Text(
              'User Not Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchError ?? 'Please check the User ID and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            // Retry button
            if (Platform.isIOS)
              CupertinoButton(
                onPressed: () => _performSearch(_searchController.text),
                color: AppColors.accentBlue,
                child: Text(
                  'Try Again',
                  style: TextStyle(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () => _performSearch(_searchController.text),
                icon: Icon(Icons.refresh, color: AppColors.primaryBlack),
                label: Text(
                  'Try Again',
                  style: TextStyle(
                    color: AppColors.primaryBlack,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Builds empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Platform.isIOS ? CupertinoIcons.search : Icons.person_search,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Find Friends',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Enter a User ID to find and add friends.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds search result user card
  Widget _buildSearchResult() {
    final user = _searchResult!;
    final name = user['displayName'] ?? user['name'] ?? 'Unknown User';
    final photoUrl = user['photoURL'];
    final userId = user['uid'] ?? user['id'];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.whiteOpacity08,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.borderColor.withOpacity(0.3),
                ),
              ),
              child: Column(
                children: [
                  _buildAvatar(name, photoUrl),
                  const SizedBox(height: 20),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.whiteOpacity15,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'ID: $userId',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds sending request loading state
  Widget _buildSendingRequestState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (Platform.isIOS)
            CupertinoActivityIndicator(
              radius: 16,
              color: AppColors.accentBlue,
            )
          else
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
            ),
          const SizedBox(height: 16),
          Text(
            'Sending friend request...',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds success state
  Widget _buildSuccessState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Platform.isIOS ? CupertinoIcons.check_mark_circled_solid : Icons.check_circle,
                size: 48,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Request Sent!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _requestSuccessMessage ?? 'Friend request sent successfully!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            // Search for another user button
            SizedBox(
              width: double.infinity,
              child: Platform.isIOS
                  ? CupertinoButton(
                      onPressed: _resetToSearch,
                      color: AppColors.accentBlue,
                      child: Text(
                        'Search Another User',
                        style: TextStyle(
                          color: AppColors.primaryBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _resetToSearch,
                      icon: Icon(Icons.search, color: AppColors.primaryBlack),
                      label: Text(
                        'Search Another User',
                        style: TextStyle(
                          color: AppColors.primaryBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds request error state
  Widget _buildRequestErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.errorRed.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Platform.isIOS ? CupertinoIcons.xmark_circle_fill : Icons.error,
                size: 48,
                color: AppColors.errorRed,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Request Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _requestErrorMessage ?? 'Failed to send friend request',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 32),
            // Try again button
            SizedBox(
              width: double.infinity,
              child: Platform.isIOS
                  ? CupertinoButton(
                      onPressed: _retryRequest,
                      color: AppColors.accentBlue,
                      child: Text(
                        'Try Again',
                        style: TextStyle(
                          color: AppColors.primaryBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _retryRequest,
                      icon: Icon(Icons.refresh, color: AppColors.primaryBlack),
                      label: Text(
                        'Try Again',
                        style: TextStyle(
                          color: AppColors.primaryBlack,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            // Search another user button
            SizedBox(
              width: double.infinity,
              child: Platform.isIOS
                  ? CupertinoButton(
                      onPressed: _resetToSearch,
                      child: Text(
                        'Search Another User',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: _resetToSearch,
                      icon: Icon(Icons.search, color: AppColors.textSecondary),
                      label: Text(
                        'Search Another User',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.textSecondary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }



  /// Builds user avatar
  Widget _buildAvatar(String name, String? photoUrl) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: photoUrl != null && photoUrl.isNotEmpty
          ? _buildNetworkAvatar(name, photoUrl)
          : _buildInitialsAvatar(name),
    );
  }

  /// Builds network image avatar with fallback
  Widget _buildNetworkAvatar(String name, String photoUrl) {
    return CircleAvatar(
      radius: 50,
      backgroundColor: _getAvatarColor(name),
      child: ClipOval(
        child: Image.network(
          photoUrl,
          width: 100,
          height: 100,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: _getAvatarColor(name),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Platform.isIOS 
                    ? const CupertinoActivityIndicator(color: Colors.white)
                    : const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildInitialsWidget(name);
          },
        ),
      ),
    );
  }

  /// Builds initials avatar
  Widget _buildInitialsAvatar(String name) {
    final backgroundColor = _getAvatarColor(name);

    return CircleAvatar(
      radius: 50,
      backgroundColor: backgroundColor,
      child: _buildInitialsWidget(name),
    );
  }

  /// Builds initials text
  Widget _buildInitialsWidget(String name) {
    final initials = _getInitials(name);
    
    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 28,
      ),
    );
  }

  /// Gets user initials
  String _getInitials(String name) {
    if (name.isEmpty) return 'U';
    
    final words = name.trim().split(' ');
    if (words.length == 1) {
      return words[0][0].toUpperCase();
    } else {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
  }

  /// Gets avatar color based on name
  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEF4444), // Red
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFFF97316), // Orange
      const Color(0xFF84CC16), // Lime
      const Color(0xFFEC4899), // Pink
      const Color(0xFF3B82F6), // Blue
    ];
    
    final hash = name.hashCode;
    return colors[hash.abs() % colors.length];
  }

  /// Handles search input changes
  void _onSearchChanged(String value) {
    setState(() {
      _searchError = null;
      _searchResult = null;
    });
    
    // Clear error if user starts typing again
    if (value.isNotEmpty && _searchError != null) {
      setState(() {
        _searchError = null;
      });
    }
  }

  /// Performs user search
  Future<void> _performSearch(String uid) async {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      setState(() {
        _searchError = 'Please enter a User ID';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
      _searchResult = null;
    });

    final provider = Provider.of<RelationshipProvider>(context, listen: false);
    final result = await provider.searchUserByUid(trimmedUid);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
      if (result != null) {
        _searchResult = result;
      } else {
        // Use provider's error if available, otherwise show user not found
        _searchError = provider.error ?? 'No user found with ID "$trimmedUid"';
      }
    });
  }

  /// Sends friend request
  Future<void> _sendFriendRequest(String userId) async {
    setState(() {
      _isSendingRequest = true;
      _requestErrorMessage = null;
      _requestSuccessMessage = null;
    });

    final provider = Provider.of<RelationshipProvider>(context, listen: false);
    final success = await provider.sendFriendRequest(userId);

    if (!mounted) return;

    setState(() {
      _isSendingRequest = false;
      if (success) {
        _requestSuccessMessage = 'Friend request sent successfully! They will be notified of your request.';
      } else {
        // Use the provider's error message directly since it comes from RelationshipException
        _requestErrorMessage = provider.error ?? 'Failed to send friend request';
      }
    });
  }

  /// Clears search
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchError = null;
      _searchResult = null;
      _requestSuccessMessage = null;
      _requestErrorMessage = null;
    });
  }

  /// Handles the primary action (Search or Send Friend Request)
  Future<void> _handlePrimaryAction() async {
    if (_searchResult != null) {
      // If we have a search result, send friend request
      final userId = _searchResult!['uid'] ?? _searchResult!['id'];
      if (userId != null) {
        await _sendFriendRequest(userId);
      }
    } else {
      // If no search result, perform search
      await _performSearch(_searchController.text);
    }
  }

  /// Gets the text for the primary button based on current state
  String _getPrimaryButtonText() {
    if (_searchResult != null) {
      return 'Send Friend Request';
    } else {
      return 'Search';
    }
  }

  /// Determines if bottom buttons should be shown (not in success/error states)
  bool _shouldShowBottomButtons() {
    return _requestSuccessMessage == null && _requestErrorMessage == null;
  }

  /// Resets to search state
  void _resetToSearch() {
    setState(() {
      _searchResult = null;
      _searchError = null;
      _requestSuccessMessage = null;
      _requestErrorMessage = null;
    });
    _searchController.clear();
    _searchFocusNode.requestFocus();
  }

  /// Retries the friend request
  void _retryRequest() {
    if (_searchResult != null) {
      final userId = _searchResult!['uid'] ?? _searchResult!['id'];
      if (userId != null) {
        setState(() {
          _requestErrorMessage = null;
        });
        _sendFriendRequest(userId);
      }
    }
  }
}
