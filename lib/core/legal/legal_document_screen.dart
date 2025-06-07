import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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

class _LegalDocumentScreenState extends State<LegalDocumentScreen> 
    with SingleTickerProviderStateMixin {
  LegalDocument? _document;
  bool _isLoading = true;
  String? _errorMessage;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    
    // Use shorter animation duration for better performance
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    
    // Start the animation
    _animationController.forward();
    
    // Pre-fetch document data to eliminate visible loading state
    _preloadDocument();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  /// Preload document data with optimized loading strategy
  Future<void> _preloadDocument() async {
    // Add a microtask to allow UI to render first before loading data
    Future.microtask(() async {
      try {
        // Preload document with compute to avoid UI jank
        final document = await widget.documentLoader();
        
        // Only update state if the widget is still mounted
        if (!mounted) return;
        
        setState(() {
          _document = document;
          _isLoading = false;
        });
      } catch (e) {
        if (!mounted) return;
        
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    });
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
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      // Silent error handling with debugPrint
      debugPrint('Error launching URL $_getWebUrl: $e');
    }
  }
  
  /// Handle back button and animate out
  Future<void> _handleBackPress() async {
    // Reverse the animation
    await _animationController.reverse();
    // Now actually pop if context is mounted
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleBackPress();
        }
      },
      child: Platform.isIOS 
        ? _buildCupertinoUI()
        : _buildMaterialUI(),
    );
  }

  /// Build iOS-specific UI
  Widget _buildCupertinoUI() {
    return FadeTransition(
      opacity: _animationController.drive(CurveTween(curve: Curves.easeOut)),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoTheme.of(context).scaffoldBackgroundColor,
        navigationBar: CupertinoNavigationBar(
          backgroundColor: CupertinoTheme.of(context).barBackgroundColor,
          middle: Text(
            widget.title,
            style: const TextStyle(color: AppColors.textPrimary),
          ),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.back, color: AppColors.textPrimary),
            onPressed: () async {
              await _handleBackPress();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
        child: _buildBody(context, useCupertinoStyle: true),
      ),
    );
  }

  /// Build Android-specific UI
  Widget _buildMaterialUI() {
    final theme = Theme.of(context);
    return FadeTransition(
      opacity: _animationController.drive(CurveTween(curve: Curves.easeOut)),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text(widget.title),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await _handleBackPress();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: _buildBody(context, useCupertinoStyle: false),
      ),
    );
  }

  /// Builds the body content with conditional styling based on platform
  Widget _buildBody(BuildContext context, {required bool useCupertinoStyle}) {
    // Show blank space instead of loading indicator to improve perceived performance
    if (_isLoading) {
      return const SizedBox.shrink();
    }
    
    // Show error view if document loading failed
    if (_errorMessage != null) {
      return _buildErrorView(context, useCupertinoStyle);
    }

    // Document is loaded
    if (_document != null) {
      return _buildDocumentView(context, useCupertinoStyle);
    }

    return const SizedBox.shrink();
  }

  /// Creates the error view with platform-specific styling
  Widget _buildErrorView(BuildContext context, bool useCupertinoStyle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              useCupertinoStyle ? CupertinoIcons.exclamationmark_circle : Icons.error_outline,
              color: AppColors.errorRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading document',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            useCupertinoStyle
                ? CupertinoButton(
                    color: AppColors.accentBlue,
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _preloadDocument();
                    },
                    child: const Text('Retry'),
                  )
                : ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _errorMessage = null;
                      });
                      _preloadDocument();
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

  /// Creates the document view with a memory-efficient approach 
  Widget _buildDocumentView(BuildContext context, bool useCupertinoStyle) {
    // Use platform-specific scrolling with optimized builders for better performance
    final scrollView = ListView.builder(
      // Use builder pattern with caching for better memory management
      padding: const EdgeInsets.all(16.0),
      // Adding physics for smoother scrolling based on platform
      physics: useCupertinoStyle 
        ? const AlwaysScrollableScrollPhysics() 
        : const ClampingScrollPhysics(),
      // Efficient item count calculation
      itemCount: _document!.sections.length + 3, // header, info line, read more button, sections
      // Add cacheExtent for smoother scrolling
      cacheExtent: 500,
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header - use RepaintBoundary for performance
          return RepaintBoundary(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _document!.title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          );
        } else if (index == 1) {
          // Version info
          return Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: Text(
              'Version ${_document!.version} | Last Updated: ${_document!.lastUpdated}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          );
        } else if (index == _document!.sections.length + 2) {
          // Read more button
          return _buildReadMoreButton(context, useCupertinoStyle);
        } else {
          // Section with memory optimizations
          final sectionIndex = index - 2;
          final section = _document!.sections[sectionIndex];
          // Using RepaintBoundary to prevent unnecessary repaints
          return RepaintBoundary(
            child: _buildSection(section, context, useCupertinoStyle),
          );
        }
      },
    );
    
    return useCupertinoStyle
        ? CupertinoScrollbar(child: scrollView)
        : Scrollbar(child: scrollView);
  }

  /// Creates an optimized section card with platform-specific styling
  /// Uses memory optimization techniques to prevent lag
  Widget _buildSection(LegalSection section, BuildContext context, bool useCupertinoStyle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceBlack,
        borderRadius: BorderRadius.circular(12),
        // Optimize border with only top and bottom for better performance
        border: Border.all(color: AppColors.borderColor, width: 1),
      ),
      // Use more efficient ConstrainedBox for better layout performance
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title with optimized text rendering
            Text(
              section.title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.accentBlue,
              ),
              // Optimize text rendering
              textAlign: TextAlign.left,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Content with optimized text
            Text(
              section.content,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
                // Use height for better readability and performance
                height: 1.4,
              ),
              // Don't use rich text features for better performance
              textAlign: TextAlign.left,
            ),
          ],
        ),
      ),
    );
  }

  /// Creates a platform-specific read more button
  Widget _buildReadMoreButton(BuildContext context, bool useCupertinoStyle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: useCupertinoStyle
            ? CupertinoButton(
                color: AppColors.accentBlue,
                onPressed: _launchUrl,
                child: const Text(
                  'Read More',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              )
            : ElevatedButton(
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
