import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/user_service.dart';

class QRCodeScreen {
  final GlobalKey qrKey = GlobalKey();

  // Show QR code dialog
  void showQRCode(BuildContext context) {
    // Use UserService to get current user ID
    final userService = UserService();
    final userId = userService.currentUserId ?? '';
    
    // Make sure we have a valid Firebase Auth UID 
    if (userId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not generate QR code. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Encrypt user ID for QR code
    final qrData = _encryptUserId(userId);
    
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final screenWidth = MediaQuery.of(context).size.width;
    
    showGeneralDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      barrierDismissible: true,
      barrierLabel: "QR Code",
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, animation, secondaryAnimation) => const SizedBox.shrink(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutQuint,
        );
        
        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: Dialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              insetPadding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: 24,
              ),
              child: SingleChildScrollView(
                child: Container(
                  width: screenWidth * 0.9,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5E8C7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B4513).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.qr_code,
                              color: Color(0xFF8B4513),
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Your DuckBuck QR Code',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B4513),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Share this code with friends to connect',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF8B4513).withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // QR code
                      RepaintBoundary(
                        key: qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF9F0),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD4A76A).withOpacity(0.15),
                                blurRadius: 8,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          // Adjust QR size based on screen width and text scale factor
                          child: QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: textScaleFactor > 1.3 ? 
                              180 / (textScaleFactor > 1.5 ? 1.5 : textScaleFactor) : 
                              200,
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF8B4513),
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFFD4A76A),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF8B4513),
                            ),
                            embeddedImage: const AssetImage('assets/app_logo.png'),
                            embeddedImageStyle: QrEmbeddedImageStyle(
                              size: Size(textScaleFactor > 1.3 ? 30 : 40, textScaleFactor > 1.3 ? 30 : 40),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Buttons
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Share button on top
                          SizedBox(
                            width: double.infinity, // Make button full width
                            child: ElevatedButton.icon(
                              onPressed: () => _captureAndShareQR(context),
                              icon: const Icon(Icons.share, size: 18),
                              label: const Text('Share'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD4A76A),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Close button at the bottom
                          SizedBox(
                            width: double.infinity, // Make button full width
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF8B4513),
                                side: const BorderSide(color: Color(0xFFE6C38D), width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Capture and share QR code
  Future<void> _captureAndShareQR(BuildContext context) async {
    try {
      // Capture QR code image
      final RenderRepaintBoundary boundary = qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        
        // Save to temporary file
        final tempDir = await getTemporaryDirectory();
        final file = await File('${tempDir.path}/duckbuck_qr_code.png').create();
        await file.writeAsBytes(pngBytes);
        
        // Share the file
        await Share.shareXFiles(
          [XFile(file.path)],
          text: 'Add me on DuckBuck!',
          subject: 'DuckBuck Profile QR Code'
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sharing QR code: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Encrypt the user ID for QR code
  String _encryptUserId(String userId) {
    // Create a prefix to identify our app's QR codes
    const prefix = "DBK:";
    
    // Add a simple timestamp to make each QR code unique
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Combine data
    final dataToEncrypt = "$userId:$timestamp";
    
    // Create a SHA-256 hash as a signature
    final key = 'DuckBuckSecretKey';
    final hmacSha256 = Hmac(sha256, utf8.encode(key));
    final digest = hmacSha256.convert(utf8.encode(dataToEncrypt));
    final signature = digest.toString().substring(0, 8); // Use first 8 chars of hash
    
    // Combine all parts with the signature
    final combinedData = "$prefix$dataToEncrypt:$signature";
    
    // Encode in base64 for compactness
    return base64Encode(utf8.encode(combinedData));
  }
} 