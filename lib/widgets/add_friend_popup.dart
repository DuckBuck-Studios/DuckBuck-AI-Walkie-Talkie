import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart'; 
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart'; 
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../providers/friend_provider.dart';
import '../services/friend_service.dart';
import '../config/app_config.dart';
import 'cool_button.dart';

class AddFriendPopup extends StatefulWidget {
  const AddFriendPopup({super.key});

  @override
  State<AddFriendPopup> createState() => _AddFriendPopupState();
}

class _AddFriendPopupState extends State<AddFriendPopup> with SingleTickerProviderStateMixin {
  final AppConfig _appConfig = AppConfig();
  
  // State variables
  bool _isScanning = false;
  bool _isSearching = false;
  bool _isSendingRequest = false;
  Map<String, dynamic>? _foundUser;
  FriendRequestStatus? _requestStatus;
  
  // Scanner controller
  MobileScannerController? _scannerController;
  
  // Colors
  final Color _backgroundColor = const Color(0xFFE3B77D);
  final Color _accentColor = const Color(0xFFB8782E);
  final Color _textColor = const Color(0xFF4A3520);
  final Color _secondaryBgColor = const Color(0xFFF0DDB3);
  
  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutQuart,
        width: MediaQuery.of(context).size.width,
        height: _foundUser != null 
            ? MediaQuery.of(context).size.height * 0.5  // Shorter when user found
            : MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
          border: Border.all(
            color: _accentColor.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Header with title and close/back button
            _buildHeader(),
            
            // Main content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms)
      .scale(
        begin: const Offset(0.9, 0.9),
        end: const Offset(1.0, 1.0),
        duration: 400.ms,
        curve: Curves.easeOutBack,
      );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getHeaderText(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ).animate()
            .fadeIn(duration: 300.ms)
            .slideX(begin: -0.1, end: 0, duration: 300.ms),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _accentColor.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(_isScanning || _isSearching || _foundUser != null ? 
                Icons.arrow_back : Icons.close, color: _accentColor),
            ),
            onPressed: _handleBackOrClose,
          ),
        ],
      ),
    );
  }
  
  String _getHeaderText() {
    if (_isScanning) {
      return 'Scan QR Code';
    } else if (_isSearching) {
      return 'Finding User';
    } else if (_foundUser != null) {
      return 'User Found';
    } else {
      return 'Add Friend';
    }
  }
  
  void _handleBackOrClose() {
    if (_isScanning) {
      // Close scanner and return to initial screen
      _scannerController?.stop();
      setState(() {
        _isScanning = false;
        _scannerController = null;
      });
    } else if (_isSearching || _foundUser != null) {
      // Go back to initial screen
      setState(() {
        _isSearching = false;
        _foundUser = null;
        _requestStatus = null;
      });
    } else {
      // Close popup
      Navigator.pop(context);
    }
  }
  
  Widget _buildContent() {
    if (_isScanning) {
      return _buildScanner();
    } else if (_isSearching) {
      return _buildSearching();
    } else if (_foundUser != null) {
      return _buildUserProfile();
    } else {
      return _buildInitialScreen();
    }
  }
  
  // Initial screen with QR code scan option
  Widget _buildInitialScreen() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // QR Code animation
          Lottie.asset(
            'assets/animations/qr-code-scan.json',
            height: 160,
            repeat: true,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Scan your friend\'s QR code to add them',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 32),
          
          DuckBuckButton(
            text: 'Open Scanner',
            onTap: _openScanner,
            color: const Color(0xFF2C1810),
            borderColor: const Color(0xFFD4A76A),
            height: 60,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            depth: 10,
            borderWidth: 1.5,
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }
  
  void _openScanner() {
    HapticFeedback.selectionClick();
    _scannerController = MobileScannerController();
    setState(() => _isScanning = true);
  }
  
  // QR code scanner
  Widget _buildScanner() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Scanner
            MobileScanner(
              controller: _scannerController!,
              onDetect: _onQRCodeDetected,
            ),
            
            // Scanner overlay
            Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _accentColor,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
              ).animate(
                onPlay: (controller) => controller.repeat(),
              ).shimmer(
                duration: 1500.ms,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
            
            // Instructions
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Point camera at your friend\'s QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    final String? code = barcodes.first.rawValue;
    if (code == null) return;
    
    // Stop scanning
    _scannerController?.stop();
    
    // Process the scanned code directly
    _processScannedCode(code);
  }
  
  void _processScannedCode(String encodedData) {
    try {
      // Extract user ID from QR code
      final String? userId = _decryptQrData(encodedData);
      
      if (userId == null) {
        _showErrorMessage("Invalid or expired QR code");
        setState(() => _isScanning = false);
        return;
      }
      
      // Start searching for user
      _searchUser(userId);
      
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: "Error processing QR code");
      _showErrorMessage("Error processing QR code");
      setState(() => _isScanning = false);
    }
  }
  
  String? _decryptQrData(String encodedData) {
    try {
      // Decode base64
      final bytes = base64Decode(encodedData);
      final decodedString = utf8.decode(bytes);
      
      // Check for app prefix
      if (!decodedString.startsWith("DBK:")) {
        return null; // Not our QR code
      }
      
      // Remove prefix
      final dataWithoutPrefix = decodedString.substring(4);
      
      // Split parts
      final parts = dataWithoutPrefix.split(":");
      if (parts.length != 3) {
        return null; // Invalid format
      }
      
      final userId = parts[0];
      final timestamp = parts[1];
      final providedSignature = parts[2];
      
      // Verify signature
      final dataToVerify = "$userId:$timestamp";
      final key = 'DuckBuckSecretKey'; // In production, use a secure key
      final hmacSha256 = Hmac(sha256, utf8.encode(key));
      final digest = hmacSha256.convert(utf8.encode(dataToVerify));
      final computedSignature = digest.toString().substring(0, 8);
      
      if (providedSignature != computedSignature) {
        return null; // Invalid signature
      }
      
      return userId;
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: "Error decrypting QR data");
      return null;
    }
  }
  
  // Searching state with animation
  Widget _buildSearching() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading1.json',
            height: 120,
            repeat: true,
          ),
          
          const SizedBox(height: 24),
          
          Text(
            'Finding user...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'Please wait while we process the QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _textColor.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _searchUser(String userId) {
    // Transition to searching state
    setState(() {
      _isScanning = false;
      _isSearching = true;
    });
    
    return _lookupUser(userId);
  }
  
  Future<void> _lookupUser(String userId) async {
    try {
      _appConfig.trackEvent('search_user_start', parameters: {'source': 'qr_code'});
      
      // Get friend services
      final friendService = FriendService();
      final currentUserId = friendService.currentUserId;
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      
      // Validate not adding self
      if (userId == currentUserId) {
        if (!mounted) return;
        HapticFeedback.vibrate();
        _showErrorMessage('You cannot add yourself as a friend');
        setState(() => _isSearching = false);
        return;
      }
      
      // Check for blocking relationships
      final isUserBlocked = await friendProvider.isUserBlocked(userId);
      final isBlockedByUser = await friendService.isBlockedBy(userId);
      
      // Get user document using provider instead of direct Firestore access
      final userResult = await friendProvider.getUserById(userId);
          
      if (!mounted) return;
          
      if (!userResult['success']) {
        _showErrorMessage(userResult['error'] ?? 'User not found');
        setState(() => _isSearching = false);
        return;
      }
      
      // Prepare user data from the service response
      final userData = userResult['user'];
      
      if (isUserBlocked || isBlockedByUser) {
        setState(() {
          _isSearching = false;
          _foundUser = userData;
          _requestStatus = FriendRequestStatus.blocked;
          _foundUser!['blockedBy'] = isUserBlocked ? 'me' : 'them';
        });
        
        _showErrorMessage(isUserBlocked 
          ? 'You have blocked this user' 
          : 'You are blocked by this user');
        return;
      }

      // Check relationship status
      final requestStatus = await friendProvider.getFriendRequestStatus(userId);
      final isFriend = await friendProvider.isFriend(userId);
      final hasPendingOutgoing = friendProvider.outgoingRequests.any((req) => req['id'] == userId);

      if (!mounted) return;

      // Update UI with found user
      setState(() {
        _isSearching = false;
        _foundUser = userData;
        
        if (isFriend) {
          _requestStatus = FriendRequestStatus.accepted;
        } else if (hasPendingOutgoing) {
          _requestStatus = FriendRequestStatus.pending;
        } else if (requestStatus != null) {
          _requestStatus = requestStatus;
        }
      });
      
      // Success feedback
      HapticFeedback.mediumImpact();
      _appConfig.trackEvent('search_user_success', parameters: {'found_user_id': userId});
      
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: "Error searching for user");
      
      if (!mounted) return;
      
      setState(() => _isSearching = false);
      _showErrorMessage('Error finding user');
    }
  }
  
  void _showErrorMessage(String message) {
    _appConfig.log('Error in AddFriendPopup: $message');
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  // User profile with action buttons
  Widget _buildUserProfile() {
    if (_foundUser == null) return const SizedBox.shrink();
    
    // Determine blocked status
    final bool isBlocked = _requestStatus == FriendRequestStatus.blocked;
    final String blockType = isBlocked && _foundUser!.containsKey('blockedBy') 
        ? _foundUser!['blockedBy'] : '';
    
    // Create a gradient based on the accent color
    final LinearGradient cardGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _secondaryBgColor,
        Color.lerp(_secondaryBgColor, _accentColor.withOpacity(0.3), 0.15)!,
      ],
    );
    
    return Column(
      children: [
        // User profile card - full width design
        Expanded(
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            decoration: BoxDecoration(
              gradient: cardGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Profile photo - slightly larger rectangular with rounded corners
                Container(
                  width: 160,
                  height: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _accentColor,
                      width: 3,
                    ),
                    image: _foundUser!['photoURL'] != null
                        ? DecorationImage(
                            image: NetworkImage(_foundUser!['photoURL']),
                            fit: BoxFit.cover,
                          )
                        : null,
                    color: _foundUser!['photoURL'] == null
                        ? _accentColor.withOpacity(0.2)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: _foundUser!['photoURL'] == null
                      ? Center(
                          child: Icon(
                            Icons.person,
                            size: 80, 
                            color: _accentColor,
                          ),
                        )
                      : null,
                ).animate()
                  .fadeIn(duration: 400.ms)
                  .slide(begin: const Offset(0, -0.1), end: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutQuart)
                  .scaleXY(begin: 0.9, end: 1.0, duration: 500.ms, curve: Curves.easeOutBack),
                
                const SizedBox(height: 24),
                
                // Username - larger, more prominent with shadow
                Text(
                  _foundUser!['displayName'] ?? 'Unknown User',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                    shadows: [
                      Shadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ).animate()
                  .fadeIn(duration: 400.ms, delay: 150.ms)
                  .slide(begin: const Offset(0, 0.2), end: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutQuart),
                
                // Username/email in smaller text
                if (_foundUser!['username'] != null || _foundUser!['email'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 40, right: 40),
                    child: Text(
                      _foundUser!['username'] ?? _foundUser!['email'] ?? '',
                      style: TextStyle(
                        fontSize: 18,
                        color: _textColor.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ).animate()
                    .fadeIn(duration: 400.ms, delay: 250.ms)
                    .slide(begin: const Offset(0, 0.2), end: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutQuart),
                  
                // Status indicator pill - only if there's a status
                if (_requestStatus != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getStatusColor(_requestStatus!).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _getStatusColor(_requestStatus!).withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getStatusIcon(_requestStatus!),
                            color: _getStatusColor(_requestStatus!),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getStatusText(_requestStatus!, blockType),
                            style: TextStyle(
                              color: _getStatusColor(_requestStatus!),
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate()
                    .fadeIn(duration: 400.ms, delay: 350.ms)
                    .slide(begin: const Offset(0, 0.2), end: const Offset(0, 0), duration: 500.ms, curve: Curves.easeOutQuart),
              ],
            ),
          ),
        ),
        
        // Action button at the bottom
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: _isSendingRequest
              ? SizedBox(
                  height: 60,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _accentColor,
                      strokeWidth: 3,
                    ),
                  ),
                )
              : (!isBlocked && _requestStatus == null
                  ? _buildSendRequestButton()
                  : _buildStatusMessage(blockType)),
        ),
      ],
    );
  }
  
  // Send friend request button
  Widget _buildSendRequestButton() {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xFF2C1810),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: _sendFriendRequest,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Send Friend Request',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.person_add,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
      .fadeIn(duration: 400.ms, delay: 450.ms)
      .slideY(begin: 0.4, end: 0, curve: Curves.easeOutQuart);
  }
  
  // Status message container
  Widget _buildStatusMessage(String blockType) {
    if (_requestStatus == null) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: _getStatusColor(_requestStatus!).withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(_requestStatus!).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        _getActionText(_requestStatus!, blockType),
        style: TextStyle(
          color: _textColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 250.ms);
  }
  
  Future<void> _sendFriendRequest() async {
    if (_foundUser == null) return;

    HapticFeedback.selectionClick();
    setState(() => _isSendingRequest = true);

    try {
      // Verify no blocking relationship
      final friendService = FriendService();
      final isUserBlocked = await friendService.isUserBlocked(_foundUser!['id']);
      final isBlockedByUser = await friendService.isBlockedBy(_foundUser!['id']);
      
      if (!mounted) return;
      
      if (isUserBlocked || isBlockedByUser) {
        setState(() {
          _isSendingRequest = false;
          _requestStatus = FriendRequestStatus.blocked;
          _foundUser!['blockedBy'] = isUserBlocked ? 'me' : 'them';
        });
        
        _showErrorMessage(isUserBlocked 
          ? 'You cannot send a request to a blocked user' 
          : 'You cannot send a request to this user');
        return;
      }
      
      _appConfig.trackEvent('send_friend_request_start', 
          parameters: {'target_user_id': _foundUser!['id']});
      
      // Send the request
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      final result = await friendProvider.sendFriendRequestWithValidation(_foundUser!['id']);

      if (!mounted) return;

      if (result['success'] == true) {
        HapticFeedback.mediumImpact();
        
        setState(() => _requestStatus = FriendRequestStatus.pending);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Friend request sent successfully'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        
        _appConfig.trackEvent('send_friend_request_success', 
            parameters: {'target_user_id': _foundUser!['id']});
        
        // Auto-dismiss after short delay
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (!mounted) return;
        Navigator.pop(context, result);
      } else {
        HapticFeedback.vibrate();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to send friend request'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
        
        _appConfig.trackEvent('send_friend_request_failure', 
          parameters: {
            'target_user_id': _foundUser!['id'],
            'error': result['error'] ?? 'Unknown error',
            'error_code': result['errorCode'] ?? 'unknown'
          }
        );
        
        setState(() => _isSendingRequest = false);
      }
    } catch (e, stackTrace) {
      _appConfig.reportError(e, stackTrace, reason: "Error sending friend request");
      
      if (!mounted) return;
      
      HapticFeedback.vibrate();
      _showErrorMessage('Error sending friend request');
      setState(() => _isSendingRequest = false);
    }
  }
  
  // Helper methods for status representation
  Color _getStatusColor(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return Colors.orange;
      case FriendRequestStatus.accepted:
        return Colors.green;
      case FriendRequestStatus.declined:
        return Colors.red;
      case FriendRequestStatus.blocked:
        return Colors.grey;
    }
  }
  
  IconData _getStatusIcon(FriendRequestStatus status) {
    switch (status) {
      case FriendRequestStatus.pending:
        return Icons.hourglass_bottom;
      case FriendRequestStatus.accepted:
        return Icons.check_circle;
      case FriendRequestStatus.declined:
        return Icons.cancel;
      case FriendRequestStatus.blocked:
        return Icons.block;
    }
  }

  String _getStatusText(FriendRequestStatus status, String blockType) {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'Request Pending';
      case FriendRequestStatus.accepted:
        return 'Already Friends';
      case FriendRequestStatus.declined:
        return 'Request Declined';
      case FriendRequestStatus.blocked:
        return blockType == 'me' ? 'Blocked by You' : 'You Are Blocked';
    }
  }
  
  String _getActionText(FriendRequestStatus status, String blockType) {
    switch (status) {
      case FriendRequestStatus.pending:
        return 'You already sent a friend request to this user. They need to accept it.';
      case FriendRequestStatus.accepted:
        return 'You are already friends with this user.';
      case FriendRequestStatus.declined:
        return 'Your friend request was declined by this user.';
      case FriendRequestStatus.blocked:
        return blockType == 'me' 
            ? 'You have blocked this user. Unblock them from your settings to add them as a friend.' 
            : 'You cannot interact with this user because they have blocked you.';
    }
  }
} 