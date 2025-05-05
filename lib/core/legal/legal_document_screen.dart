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

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  late Future<LegalDocument> _documentFuture;

  @override
  void initState() {
    super.initState();
    _documentFuture = widget.documentLoader();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.surfaceBlack,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
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
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _documentFuture = widget.documentLoader();
                        });
                      },
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
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),

                  // Document sections
                  ...document.sections.map(
                    (section) => _buildSection(section, context),
                  ),

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
    );
  }

  Widget _buildSection(LegalSection section, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
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
          const SizedBox(height: 8),
          Text(section.content, style: Theme.of(context).textTheme.bodyMedium),
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
