import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart'; 
import 'package:url_launcher/url_launcher.dart';

class TermsAgreementWidget extends StatelessWidget {
  const TermsAgreementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Get screen size for responsive text sizing
    final screenWidth = MediaQuery.of(context).size.width;
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    final fontSize = (screenWidth < 360 ? 12.0 : 14.0) * (textScaleFactor > 1.3 ? 1.3 : textScaleFactor);
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
        ),
        children: [
          const TextSpan(
            text: 'By continuing, you agree to our ',
          ),
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: const Color(0xFFB38B4D),
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showTermsBottomSheet(context, 'terms_of_service');
              },
          ),
          const TextSpan(
            text: ' and ',
          ),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: const Color(0xFFB38B4D),
              fontWeight: FontWeight.bold,
              fontSize: fontSize,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                _showTermsBottomSheet(context, 'privacy_policy');
              },
          ),
        ],
      ),
    );
  }

  void _showTermsBottomSheet(BuildContext context, String type) async {
    try {
      // Load legal content
      final String jsonPath = 'assets/legal/$type.json';
      String jsonString = await DefaultAssetBundle.of(context).loadString(jsonPath);
      final Map<String, dynamic> data = json.decode(jsonString);
      
      final String url = type == 'terms_of_service' 
          ? 'https://duckbuck.in/terms' 
          : 'https://duckbuck.in/privacy';
      
      // Get screen metrics for responsive sizing
      final screenSize = MediaQuery.of(context).size; 
      final isSmallScreen = screenSize.width < 360;
      
      // Check if context is still valid
      if (!context.mounted) return;
      
      // Create a GlobalKey for the action button to ensure we have a valid context
      final GlobalKey buttonKey = GlobalKey();
      
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext modalContext) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (sheetContext, scrollController) {
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.brown.shade50.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    border: Border.all(
                      color: Colors.brown.shade200.withOpacity(0.3),
                      width: 0.5,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenSize.width * 0.04,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with title and close button
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              data['title'],
                              style: TextStyle(
                                fontSize: isSmallScreen ? 18 : 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.brown.shade800),
                            onPressed: () => Navigator.pop(modalContext),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 40,
                              minHeight: 40,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Last Updated: ${data['lastUpdated']}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          color: Colors.brown.shade600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: data['sections'].length,
                          itemBuilder: (context, index) {
                            final section = data['sections'][index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section['title'],
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.brown.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    section['content'],
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 12 : 14,
                                      color: Colors.brown.shade900,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      
                      // Read Full Button
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          key: buttonKey,
                          height: 56,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE5BA74),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                // Close the modal first
                                Navigator.pop(modalContext);
                                
                                // Then attempt to launch URL
                                _launchBrowserUrl(url);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Read Full ${type == 'terms_of_service' ? 'Terms' : 'Privacy Policy'}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(
                                      Icons.open_in_new,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
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
    } catch (e) {
      debugPrint("Error showing terms bottom sheet: $e");
    }
  }

  Future<void> _launchBrowserUrl(String url) async {
    // Add a small delay to avoid animation controller errors
    await Future.delayed(const Duration(milliseconds: 300));
    
    try {
      // Convert URL to URI
      final Uri uri = Uri.parse(url);
      
      // Use inAppWebView to open inside the app
      await launchUrl(
        uri,
        mode: LaunchMode.inAppWebView,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
    } catch (e) {
      debugPrint("Error launching URL: $e");
      
      // Fallback to external browser if in-app view fails
      try {
        final Uri uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        // Silently fail if even the fallback doesn't work
      }
    }
  }
}
