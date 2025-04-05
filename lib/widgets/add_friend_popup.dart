import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart'; 
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../providers/friend_provider.dart';
import '../services/friend_service.dart';
import 'cool_button.dart';

class AddFriendPopup extends StatefulWidget {
  const AddFriendPopup({super.key});

  @override
  State<AddFriendPopup> createState() => _AddFriendPopupState();
}

class _AddFriendPopupState extends State<AddFriendPopup> with SingleTickerProviderStateMixin {
  bool _showScanner = false;
  
  // Update colors to better match the animated background
  final Color _backgroundColor = const Color(0xFFE3B77D); // Lighter warm tone
  final Color _accentColor = const Color(0xFFB8782E);   // Golden amber accent
  final Color _textColor = const Color(0xFF4A3520);     // Warm brown text 
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.6,
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
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _showScanner ? 'Scan QR Code' : 'Add Friend',
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
                      child: Icon(_showScanner ? Icons.arrow_back : Icons.close, color: _accentColor),
                    ),
                    onPressed: () {
                      if (_showScanner) {
                        setState(() => _showScanner = false);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Main content - Show either QR scanner or Add Friend content
            Expanded(
              child: _showScanner
                  ? _buildScannerContent()
                  : _buildScanQRContent(),
            ),
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

  Widget _buildScannerContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                children: [
                  // QR Scanner
                  MobileScanner(
                    controller: MobileScannerController(),
                    onDetect: (capture) {
                      final List<Barcode> barcodes = capture.barcodes;
                      if (barcodes.isNotEmpty) {
                        final String? code = barcodes.first.rawValue;
                        if (code != null) {
                          setState(() => _showScanner = false);
                          _processScannedCode(code);
                        }
                      }
                    },
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
                  
                  // Instructions text
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Scan your friend\'s QR code',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Method to show the QR scanner
  void _showQRScanner() {
    setState(() => _showScanner = true);
  }

  Widget _buildScanQRContent() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // QR Code Illustration
          Container(
            height: 180,
            width: 180,
            margin: const EdgeInsets.only(bottom: 20),
            child: Lottie.asset(
              'assets/animations/qr-code-scan.json',
              fit: BoxFit.contain,
              repeat: true,
              animate: true,
            ),
          ),
          
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
            'Open the scanner to scan your friend\'s QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: _textColor.withOpacity(0.7),
            ),
          ),
          
          const SizedBox(height: 30),
          
          // Open Scanner Button
          DuckBuckButton(
            text: 'Open Scanner',
            onTap: _showQRScanner,
            color: const Color(0xFF2C1810),
            borderColor: const Color(0xFFD4A76A),
            height: 65,
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            depth: 10,
            borderWidth: 1.5,
          ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

  void _processScannedCode(String encryptedCode) {
    try {
      // Try to decrypt the QR code
      final String? userId = _decryptQrData(encryptedCode);
      
      if (userId == null) {
        _showErrorMessage("Invalid QR code. Please try again.");
        return;
      }
      
      // Get current user ID to prevent self-scanning
      final friendService = FriendService();
      final currentUserId = friendService.currentUserId;
      
      // Don't allow scanning yourself
      if (userId == currentUserId) {
        _showErrorMessage("You cannot add yourself as a friend");
        return;
      }
      
      // Show the search user popup with the scanned code
      showDialog(
        context: context,
        builder: (context) => SearchUserPopup(initialSearchId: userId),
      ).then((result) {
        // Pass the result back to the original caller
        if (result != null) {
          Navigator.pop(context, result);
        }
      });
    } catch (e) {
      _showErrorMessage("Error processing QR code: ${e.toString()}");
    }
  }
  
  // Decrypt the QR code data
  String? _decryptQrData(String encryptedData) {
    try {
      // Decode base64
      final bytes = base64Decode(encryptedData);
      final decodedString = utf8.decode(bytes);
      
      // Check for our app prefix
      if (!decodedString.startsWith("DBK:")) {
        return null; // Not our QR code
      }
      
      // Remove prefix
      final dataWithoutPrefix = decodedString.substring(4);
      
      // Split into parts
      final parts = dataWithoutPrefix.split(":");
      if (parts.length != 3) {
        return null; // Invalid format
      }
      
      final userId = parts[0];
      final timestamp = parts[1];
      final providedSignature = parts[2];
      
      // Verify signature
      final dataToVerify = "$userId:$timestamp";
      final key = 'DuckBuckSecretKey';
      final hmacSha256 = Hmac(sha256, utf8.encode(key));
      final digest = hmacSha256.convert(utf8.encode(dataToVerify));
      final computedSignature = digest.toString().substring(0, 8);
      
      // Check if signatures match
      if (providedSignature != computedSignature) {
        return null; // Invalid signature
      }
      
      return userId;
    } catch (e) {
      print("Error decrypting QR data: $e");
      return null;
    }
  }
  
  void _showErrorMessage(String message) {
    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }
}

// Search User Popup for displaying results
class SearchUserPopup extends StatefulWidget {
  final String? initialSearchId;
  
  const SearchUserPopup({
    Key? key,
    this.initialSearchId,
  }) : super(key: key);

  @override
  State<SearchUserPopup> createState() => _SearchUserPopupState();
}

class _SearchUserPopupState extends State<SearchUserPopup> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _foundUser;
  bool _isLoading = true;
  bool _isSendingRequest = false;
  FriendRequestStatus? _requestStatus;
  
  // Update colors to better match the animated background
  final Color _backgroundColor = const Color(0xFFE3B77D); // Lighter warm tone
  final Color _accentColor = const Color(0xFFB8782E);   // Golden amber accent
  final Color _textColor = const Color(0xFF4A3520);     // Warm brown text
  final Color _secondaryBgColor = const Color(0xFFF0DDB3); // Light cream secondary

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchUser(widget.initialSearchId ?? '');
    });
  }

  Future<void> _searchUser(String uid) async {
    if (uid.isEmpty) {
      setState(() => _isLoading = false);
      _showErrorMessage('Invalid QR code');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Get current user ID to prevent self-search
      final friendService = FriendService();
      final currentUserId = friendService.currentUserId;
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      
      // Don't allow searching for yourself
      if (uid == currentUserId) {
        HapticFeedback.vibrate();
        setState(() => _isLoading = false);
        _showErrorMessage('You cannot add yourself as a friend');
        return;
      }
      
      // Check blocking status - do this before fetching user data
      final isUserBlocked = await friendProvider.isUserBlocked(uid);
      final isBlockedByUser = await friendService.isBlockedBy(uid);
      
      // Get the user document regardless of block status
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
          
      if (!userDoc.exists) {
        setState(() => _isLoading = false);
        _showErrorMessage('User not found');
        return;
      }
      
      // Set user data and block status if applicable
      final userData = userDoc.data()!;
      userData['id'] = userDoc.id;
      
      if (isUserBlocked || isBlockedByUser) {
        setState(() {
          _foundUser = userData;
          _isLoading = false;
          _requestStatus = FriendRequestStatus.blocked;
          _foundUser!['blockedBy'] = isUserBlocked ? 'me' : 'them';
        });
        
        _showErrorMessage(isUserBlocked 
          ? 'You have blocked this user' 
          : 'You are blocked by this user');
        return;
      }

      // If not blocked, check other relationship statuses
      final requestStatus = await friendProvider.getFriendRequestStatus(uid);
      final isFriend = await friendProvider.isFriend(uid);
      final hasPendingOutgoing = friendProvider.outgoingRequests.any((req) => req['id'] == uid);

      setState(() {
        _foundUser = userData;
        _isLoading = false;
        
        if (isFriend) {
          _requestStatus = FriendRequestStatus.accepted;
        } else if (hasPendingOutgoing) {
          _requestStatus = FriendRequestStatus.pending;
        } else if (requestStatus != null) {
          _requestStatus = requestStatus;
        }
      });
      
      // Give haptic feedback on successful user find
      HapticFeedback.mediumImpact();
      
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage('Error finding user: ${e.toString()}');
    }
  }
  
  void _showErrorMessage(String message) {
    if (!mounted) return;
    
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
    
    // Auto-dismiss the dialog after error
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _sendFriendRequest() async {
    if (_foundUser == null) return;

    HapticFeedback.selectionClick();
    setState(() => _isSendingRequest = true);

    try {
      // Check if there's a blocking relationship before sending the request
      final friendService = FriendService();
      final isUserBlocked = await friendService.isUserBlocked(_foundUser!['id']);
      final isBlockedByUser = await friendService.isBlockedBy(_foundUser!['id']);
      
      if (isUserBlocked || isBlockedByUser) {
        // Update UI to reflect block status
        setState(() {
          _isSendingRequest = false;
          _requestStatus = FriendRequestStatus.blocked;
          _foundUser!['blockedBy'] = isUserBlocked ? 'me' : 'them';
        });
        
        // Show appropriate message
        _showErrorMessage(isUserBlocked 
          ? 'You cannot send a request to a blocked user' 
          : 'You cannot send a request to this user');
        return;
      }
      
      // If no blocking relationship, proceed with sending the friend request
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      final result = await friendProvider.sendFriendRequestWithValidation(_foundUser!['id']);

      if (mounted) {
        if (result['success'] == true) {
          HapticFeedback.mediumImpact();
          
          // Show a success animation
          setState(() => _requestStatus = FriendRequestStatus.pending);
          
          // Show success snackbar
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
          
          // Auto-dismiss the popup after a short delay
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) {
            // Return success result to the original caller and close dialog
            Navigator.pop(context, result);
          }
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
          setState(() => _isSendingRequest = false);
        }
      }
    } catch (e) {
      HapticFeedback.vibrate();
      _showErrorMessage('Error: ${e.toString()}');
      setState(() => _isSendingRequest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: MediaQuery.of(context).size.width,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isLoading ? 'Finding User' : (_foundUser != null ? 'User Found' : 'No User Found'),
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
                      child: Icon(Icons.close, color: _accentColor),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Loading Indicator or User Card
            if (_isLoading)
              _buildLoadingIndicator()
            else if (_foundUser != null)
              _buildUserCard()
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: 0.2, end: 0, duration: 600.ms)
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1), duration: 600.ms),
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
  
  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/loading1.json',
            width: 120,
            height: 120,
            repeat: true,
            animate: true,
          ),
          const SizedBox(height: 16),
          Text(
            'Finding user...',
            style: TextStyle(
              color: _textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait while we process the QR code',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildUserCard() {
    // Determine blocked status
    final bool isBlocked = _requestStatus == FriendRequestStatus.blocked;
    // Check who blocked whom
    final String blockType = isBlocked && _foundUser!.containsKey('blockedBy') 
        ? _foundUser!['blockedBy'] 
        : '';
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        children: [
          // User profile with animated background
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _secondaryBgColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              children: [
                // Profile image with status indicator
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated glow effect
                      Container(
                        width: 130,
                        height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              _accentColor.withOpacity(0.7),
                              _accentColor.withOpacity(0.0),
                            ],
                            stops: const [0.5, 1.0],
                          ),
                        ),
                      ).animate(
                        onPlay: (controller) => controller.repeat(reverse: true),
                      ).scale(
                        begin: const Offset(0.95, 0.95),
                        end: const Offset(1.05, 1.05),
                        duration: 2000.ms,
                      ),
                      
                      // Profile photo
                      Hero(
                        tag: 'user-photo-${_foundUser!['id']}',
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
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
                          ),
                          child: _foundUser!['photoURL'] == null
                              ? Icon(Icons.person, size: 50, color: _accentColor)
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // User name and info
                Text(
                  _foundUser!['displayName'] ?? 'Unknown User',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                if (_foundUser!['username'] != null || _foundUser!['email'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _foundUser!['username'] ?? _foundUser!['email'] ?? 'User',
                      style: TextStyle(
                        fontSize: 16,
                        color: _textColor.withOpacity(0.7),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                const SizedBox(height: 16),
                
                // Status indicator
                if (_requestStatus != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(_requestStatus!).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(_requestStatus!).withOpacity(0.5),
                        width: 1.5,
                      ),
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
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Action section
          if (_isSendingRequest)
            Lottie.asset(
              'assets/animations/loading1.json',
              width: 80,
              height: 80,
              repeat: true,
              animate: true,
            )
          else if (!isBlocked && _requestStatus == null)
            // Send Friend Request button
            DuckBuckButton(
              text: 'Send Friend Request',
              onTap: _sendFriendRequest,
              color: const Color(0xFF2C1810),
              borderColor: const Color(0xFFD4A76A),
              height: 65,
              textStyle: const TextStyle(
                fontSize: 16, 
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              depth: 10,
              borderWidth: 1.5,
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0)
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: _getStatusColor(_requestStatus!).withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _getStatusColor(_requestStatus!).withOpacity(0.3),
                  width: 1.5,
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
            ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        ],
      ),
    );
  }

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

  String _getStatusText(FriendRequestStatus status, [String blockType = '']) {
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
  
  String _getActionText(FriendRequestStatus status, [String blockType = '']) {
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