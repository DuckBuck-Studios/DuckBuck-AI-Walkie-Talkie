import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/app/app_bootstrapper.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/services/logger/logger_service.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/repositories/user_repository.dart';
import '../../../core/repositories/relationship_repository.dart';
import '../../../core/theme/app_colors.dart';

/// Premium $10,000 Application Splash Screen
/// 
/// Features:
/// - Luxury black aesthetic with golden accents
/// - Smooth 60fps animations optimized for performance
/// - Premium visual effects and micro-interactions
/// - Sophisticated loading experience
/// - High-end brand presentation
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreen();
}

class _SplashScreen extends State<SplashScreen>
    with TickerProviderStateMixin {
  
  // Premium animation controllers
  late AnimationController _primaryController;
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late AnimationController _loadingController;
  late AnimationController _fadeOutController;
  
  // Sophisticated animations
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _textFadeAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<Offset> _logoSlideAnimation;
  late Animation<double> _loadingProgressAnimation;
  late Animation<double> _fadeOutAnimation;
  
  bool _isAppReady = false;
  
  @override
  void initState() {
    super.initState();
    _setupPremiumAnimations();
    _startLuxurySequence();
  }
  
  void _setupPremiumAnimations() {
    // Primary animation controller (2 seconds for premium feel)
    _primaryController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Glow effect controller
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    
    // Shimmer effect controller
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    
    // Loading progress controller
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1800), // 1.8 second loading animation
      vsync: this,
    );
    
    // Fade out controller
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 800), // Faster, responsive fade
      vsync: this,
    );
    
    // Logo slide from top with elegant curve
    _logoSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
    ));
    
    // Logo scale with premium bounce
    _logoScaleAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
    ));
    
    // Logo fade with precision timing
    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: const Interval(0.2, 0.9, curve: Curves.easeOut),
    ));
    
    // Text fade with delay for sophistication
    _textFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _primaryController,
      curve: const Interval(0.6, 1.0, curve: Curves.easeInOut),
    ));
    
    // Golden glow effect
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // Premium shimmer effect
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));
    
    // Loading progress animation
    _loadingProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingController,
      curve: Curves.easeInOut,
    ));
    
    // Fade out animation with smooth curve
    _fadeOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _fadeOutController,
      curve: Curves.easeInCubic, // Smooth fade out curve
    ));
  }
  
  Future<void> _startLuxurySequence() async {
    try {
      // Premium haptic feedback
      HapticFeedback.lightImpact();
      
      // Start primary entrance animation
      _primaryController.forward();
      
      // Start glow effect after logo appears
      await Future.delayed(const Duration(milliseconds: 800));
      _glowController.repeat(reverse: true);
      
      // Start shimmer effect
      await Future.delayed(const Duration(milliseconds: 400));
      _shimmerController.repeat(reverse: true);
      
      // Start loading progress after animations settle
      await Future.delayed(const Duration(milliseconds: 800));
      _loadingController.forward();
      
      // Initialize app during loading animation
      await Future.wait([
        _initializeApp(),
        Future.delayed(const Duration(milliseconds: 3000)), // Wait for loading animation duration
      ]);
      
      // Mark app as ready
      setState(() {
        _isAppReady = true;
      });
      
      // Hold the complete state briefly
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Start fade out transition
      await _fadeOutController.forward();
      
      // Navigate to next screen
      if (mounted) {
        _navigateToNextScreen();
      }
      
    } catch (e) {
      // Graceful premium error handling
      if (mounted) {
        // Complete loading even on error
        if (!_loadingController.isCompleted) {
          await _loadingController.forward();
        }
        await Future.delayed(const Duration(milliseconds: 1000));
        await _fadeOutController.forward();
        if (mounted) {
          _navigateToNextScreen();
        }
      }
    }
  }
  
  Future<void> _initializeApp() async {
    try {
      // Initialize core app services and pre-load critical data in parallel
      final logger = serviceLocator<LoggerService>();
      logger.i('SPLASH', 'Starting parallel app initialization and data pre-loading');
      
      await Future.wait([
        _initializeCoreServices(),
        _preloadCriticalData(),
      ]);
      
      logger.i('SPLASH', 'App initialization and data pre-loading completed');
      
    } catch (e) {
      final logger = serviceLocator<LoggerService>();
      logger.e('SPLASH', 'App initialization failed: $e');
      rethrow;
    }
  }
  
  /// Initialize core app services
  Future<void> _initializeCoreServices() async {
    final bootstrapper = AppBootstrapper();
    await bootstrapper.initialize();
  }
  
  /// Pre-load critical data while splash is showing
  Future<void> _preloadCriticalData() async {
    try {
      final logger = serviceLocator<LoggerService>();
      logger.i('SPLASH', 'Starting critical data pre-loading');
      
      // Wait a bit for core services to be ready
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Pre-load user data and relationship data if user is authenticated
      await _preloadUserAndRelationshipData();
      
      logger.i('SPLASH', 'Critical data pre-loading completed');
      
    } catch (e) {
      // Don't fail the entire splash if data pre-loading fails
      // The home screen can still load the data when it appears
      final logger = serviceLocator<LoggerService>();
      logger.w('SPLASH', 'Data pre-loading failed (non-critical): $e');
    }
  }
  
  /// Pre-load user and relationship data to speed up home screen
  Future<void> _preloadUserAndRelationshipData() async {
    try {
      final authService = serviceLocator<AuthServiceInterface>();
      final userRepository = serviceLocator<UserRepository>();
      final logger = serviceLocator<LoggerService>();
      
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        logger.d('SPLASH', 'User authenticated, pre-loading profile and relationship data');
        
        // Pre-load current user's profile to cache it
        await userRepository.getUserData(currentUser.uid);
        
        // Pre-load relationship data by creating and initializing providers
        await _preloadRelationshipData();
        
        logger.d('SPLASH', 'User and relationship data pre-loaded');
      } else {
        logger.d('SPLASH', 'User not authenticated, skipping data pre-loading');
      }
      
    } catch (e) {
      final logger = serviceLocator<LoggerService>();
      logger.w('SPLASH', 'User/relationship data pre-loading failed: $e');
    }
  }
  
  /// Pre-load relationship data (friends, etc.)
  Future<void> _preloadRelationshipData() async {
    try {
      final logger = serviceLocator<LoggerService>();
      logger.d('SPLASH', 'Pre-loading relationship data');
      
      // Import relationship repository to pre-load data
      final relationshipRepository = serviceLocator<RelationshipRepository>();
      
      // Pre-load friends data (this will cache it)
      final friendsStream = relationshipRepository.getFriendsStream();
      await friendsStream.first.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          logger.w('SPLASH', 'Friends data pre-loading timed out');
          return <Map<String, dynamic>>[];
        },
      );
      
      logger.d('SPLASH', 'Relationship data pre-loaded successfully');
      
    } catch (e) {
      final logger = serviceLocator<LoggerService>();
      logger.w('SPLASH', 'Relationship data pre-loading failed: $e');
    }
  }
  
  void _navigateToNextScreen() {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    
    if (firebaseUser != null) {
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } else {
      Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
    }
  }
  
  @override
  void dispose() {
    _primaryController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _loadingController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _primaryController,
          _glowController,
          _shimmerController,
          _loadingController,
          _fadeOutController,
        ]),
        builder: (context, _) {
          return Opacity(
            opacity: _fadeOutAnimation.value,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                // Subtle premium gradient overlay
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    Colors.black,
                    Colors.black.withOpacity(0.95),
                    Colors.black,
                  ],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Premium Logo with sophisticated animations and loading ring
                    SlideTransition(
                      position: _logoSlideAnimation,
                      child: Transform.scale(
                        scale: _logoScaleAnimation.value,
                        child: Opacity(
                          opacity: _logoFadeAnimation.value,
                          child: _buildPremiumLogoWithLoading(size),
                        ),
                      ),
                    ),
                    
                    SizedBox(height: size.height * 0.08),
                    
                    // Premium Brand Text with shimmer effect
                    Opacity(
                      opacity: _textFadeAnimation.value,
                      child: _buildPremiumBrandText(size),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildPremiumLogoWithLoading(Size size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Circular loading progress bar
        SizedBox(
          width: size.width * 0.42,
          height: size.width * 0.42,
          child: CircularProgressIndicator(
            value: _loadingProgressAnimation.value,
            strokeWidth: 4,
            backgroundColor: AppColors.accentBlue.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(
              _isAppReady 
                ? AppColors.accentBlue 
                : AppColors.accentBlue.withOpacity(0.8),
            ),
          ),
        ),
        
        // Logo with glow effect
        Container(
          width: size.width * 0.35,
          height: size.width * 0.35,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Premium green glow effect
            boxShadow: [
              BoxShadow(
                color: AppColors.accentBlue.withOpacity(_glowAnimation.value * 0.6),
                blurRadius: 40 * _glowAnimation.value,
                spreadRadius: 10 * _glowAnimation.value,
              ),
              BoxShadow(
                color: AppColors.accentTeal.withOpacity(_glowAnimation.value * 0.4),
                blurRadius: 80 * _glowAnimation.value,
                spreadRadius: 20 * _glowAnimation.value,
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              // Subtle inner shadow for depth
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/logo.png',
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildPremiumBrandText(Size size) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.accentBlue, // Emerald green
            AppColors.accentTeal, // Light green
            AppColors.accentBlue, // Emerald green
          ],
          stops: [
            (_shimmerAnimation.value - 1.0).clamp(0.0, 1.0),
            _shimmerAnimation.value.clamp(0.0, 1.0),
            (_shimmerAnimation.value + 1.0).clamp(0.0, 1.0),
          ],
        ).createShader(bounds);
      },
      child: Text(
        'DuckBuck',
        style: TextStyle(
          fontSize: size.width * 0.1,
          fontWeight: FontWeight.w300,
          color: Colors.white,
          letterSpacing: 4.0,
          shadows: [
            Shadow(
              color: AppColors.accentBlue.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}
