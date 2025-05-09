import 'package:flutter/material.dart';
import 'package:duckbuck/core/legal/legal_service.dart';
import 'package:duckbuck/core/theme/app_colors.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalDocumentScreen extends StatefulWidget {
  final String title;
  final Future<LegalDocument> Function() documentLoader;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.documentLoader,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> with SingleTickerProviderStateMixin {
  late Future<LegalDocument> _documentFuture;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _documentFuture = widget.documentLoader();
    
    // Setup animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    // Create slide animation from right to left (for opening)
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // Start the animation
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Get the web URL for the current document
  String get _getWebUrl {
    if (widget.title.toLowerCase().contains('privacy')) {
      return 'https://duckbuck.in/privacy';
    } else if (widget.title.toLowerCase().contains('terms')) {
      return 'https://duckbuck.in/terms';
    }
    return 'https://duckbuck.in';
  }

  /// Launch URL in browser
  Future<void> _launchUrl() async {
    final Uri url = Uri.parse(_getWebUrl);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $_getWebUrl')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
  
  /// Handle back button and animate out
  Future<bool> _handleBackPress() async {
    // Reverse the animation
    await _animationController.reverse();
    // Now actually pop
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBackPress,
      child: SlideTransition(
        position: _slideAnimation,
        child: Scaffold(
          backgroundColor: AppColors.backgroundBlack,
          appBar: AppBar(
            title: Text(widget.title),
            backgroundColor: AppColors.surfaceBlack,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            // Override the back button to trigger our custom animation
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                await _handleBackPress();
                if (mounted) Navigator.of(context).pop();
              },
            ),
          ),
          body: FutureBuilder<LegalDocument>(
            future: _documentFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.accentBlue),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: AppColors.errorRed,
                          size: 48,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading document',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _documentFuture = widget.documentLoader();
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentBlue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasData) {
                final document = snapshot.data!;
                return Scrollbar(
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Document header
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        'Version ${document.version} | Last Updated: ${document.lastUpdated}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Document sections with no animation
                      ...List.generate(document.sections.length, (index) {
                        final section = document.sections[index];
                        return _buildSection(section, context);
                      }),

                      // Read more section with link to website
                      _buildReadMoreSection(context),

                      // Bottom padding
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              }

              return const Center(child: Text('No document found'));
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSection(LegalSection section, BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.accentBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            section.content, 
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadMoreSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: ElevatedButton(
          onPressed: _launchUrl,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Read More',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
