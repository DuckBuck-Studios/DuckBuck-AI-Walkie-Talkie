import 'dart:convert';
import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:duckbuck/widgets/cool_button.dart';
import 'package:url_launcher/url_launcher.dart';

class TermsAgreementWidget extends StatelessWidget {
  const TermsAgreementWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.black87,
          fontSize: 14,
        ),
        children: [
          const TextSpan(
            text: 'By continuing, you agree to our ',
          ),
          TextSpan(
            text: 'Terms of Service',
            style: const TextStyle(
              color: Color(0xFFB38B4D),
              fontWeight: FontWeight.bold,
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
            style: const TextStyle(
              color: Color(0xFFB38B4D),
              fontWeight: FontWeight.bold,
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
    final String jsonPath = 'assets/legal/${type}.json';
    String jsonString = await DefaultAssetBundle.of(context).loadString(jsonPath);
    final Map<String, dynamic> data = json.decode(jsonString);
    
    final String url = type == 'terms_of_service' 
        ? 'https://duckbuck.in/terms' 
        : 'https://duckbuck.in/privacy';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) {
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['title'],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.brown.shade800,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.brown.shade800),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Last Updated: ${data['lastUpdated']}',
                      style: TextStyle(
                        fontSize: 12,
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.brown.shade700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  section['content'],
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.brown.shade900,
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
                      child: DuckBuckButton(
                        text: "Read Full ${type == 'terms_of_service' ? 'Terms' : 'Privacy Policy'}",
                        onTap: () async {
                          final Uri uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        color: const Color(0xFFD4A76A),
                        borderColor: const Color(0xFFB38B4D),
                        textColor: Colors.white,
                        alignment: MainAxisAlignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        icon: const Icon(Icons.open_in_new, color: Colors.white),
                        textStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                        height: 48,
                        width: double.infinity,
                      ),
                    ),
                  ],
                ),
              )
            ),
          );
        },
      ),
    );
  }
}
