import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LegalSheet extends StatelessWidget {
  const LegalSheet({Key? key}) : super(key: key);

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    }
  }

  void _showTermsOrPrivacy(BuildContext context, bool isTerms) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Animate(
        effects: [
          SlideEffect(
            begin: const Offset(0, 1),
            end: const Offset(0, 0),
            duration: 600.ms,
            curve: Curves.easeOutExpo,
          ),
          FadeEffect(
            duration: 500.ms,
            curve: Curves.easeOut,
          ),
        ],
        child: Container(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height * 0.4,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: IntrinsicHeight(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 200.ms)
                      .scale(delay: 200.ms),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isTerms ? 'Terms of Service' : 'Privacy Policy',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _launchURL(
                            isTerms
                                ? 'https://duckbuck.in/terms'
                                : 'https://duckbuck.in/privacy',
                          ),
                          child: Text(
                            'Read Full',
                            style: TextStyle(
                              color: isTerms ? Colors.purple : Colors.teal,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms)
                      .slideY(begin: 0.2, end: 0),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        isTerms ? _termsText : _privacyText,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.6,
                        ),
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 400.ms)
                      .slideY(begin: 0.2, end: 0),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 1),
          end: const Offset(0, 0),
          duration: 600.ms,
          curve: Curves.easeOutExpo,
        ),
        FadeEffect(
          duration: 500.ms,
          curve: Curves.easeOut,
        ),
      ],
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.3,
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: IntrinsicHeight(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 200.ms)
                    .scale(delay: 200.ms),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Legal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 400.ms, delay: 300.ms)
                    .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      _buildLegalButton(
                        context: context,
                        title: 'Terms of Service',
                        subtitle: 'Read our terms of service',
                        icon: Icons.gavel,
                        color: Colors.purple,
                        onTap: () => _showTermsOrPrivacy(context, true),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 400.ms)
                          .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 400.ms,
                              curve: Curves.easeOutExpo),
                      const SizedBox(height: 16),
                      _buildLegalButton(
                        context: context,
                        title: 'Privacy Policy',
                        subtitle: 'Read our privacy policy',
                        icon: Icons.security,
                        color: Colors.teal,
                        onTap: () => _showTermsOrPrivacy(context, false),
                      )
                          .animate()
                          .fadeIn(delay: 500.ms, duration: 400.ms)
                          .slideY(
                              begin: 0.2,
                              end: 0,
                              delay: 500.ms,
                              curve: Curves.easeOutExpo),
                    ],
                  ),
                ),
                const Spacer(),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(
                    begin: 0.2,
                    end: 0,
                    delay: 600.ms,
                    curve: Curves.easeOutExpo),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegalButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color.withOpacity(0.7),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  static const String _termsText = '''
1. Acceptance of Terms

By accessing and using DuckBuck, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our service.

2. Use of Service

- You must be at least 13 years old to use DuckBuck
- You are responsible for maintaining the security of your account
- You agree not to use the service for any illegal purposes
- You will not attempt to breach or circumvent any security measures

3. User Content

- You retain rights to content you create and share
- You grant DuckBuck license to use, store, and display your content
- You agree not to share inappropriate or harmful content

4. Service Modifications

We reserve the right to modify or discontinue the service at any time.
''';

  static const String _privacyText = '''
1. Information Collection

We collect information that you provide directly to us, including:
- Account information
- Usage data
- Device information
- Communications

2. How We Use Information

- To provide and maintain our service
- To improve user experience
- To communicate with you
- To ensure security

3. Information Sharing

We do not sell your personal information. We share information only:
- With your consent
- For legal compliance
- To protect rights and safety

4. Data Security

We implement reasonable security measures to protect your information.
''';
}
