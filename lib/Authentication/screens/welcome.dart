import 'dart:math';
import 'dart:ui';
import 'package:duckbuck/Authentication/screens/auth_screen.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:neopop/utils/color_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:neopop/neopop.dart';
import 'package:shimmer/shimmer.dart';
import '../service/legal_service.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({Key? key}) : super(key: key);

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  bool _isLoading = false;
  bool _isButtonPressed = false;
  bool _hasAnimated = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeInController;
  late AnimationController _waveController;
  late AnimationController _shimmerController;
  late AnimationController _bubbleController;
  late List<Animation<double>> _circleAnimations;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  // Bubble animations
  final List<Bubble> _bubbles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    // Setup pulse animation for circles
    _pulseController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3),
    )..repeat(reverse: true);

    // Setup fade-in animation for initial load
    _fadeInController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );

    // Setup wave animation for sound icon
    _waveController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    )..repeat(reverse: true);

    // Setup shimmer controller for title
    _shimmerController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 2500),
    )..repeat();

    // Setup bubble animation controller
    _bubbleController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 15),
    )..repeat();

    // Initialize bubbles
    _initBubbles();

    // Create animations
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeInController,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fadeInController,
        curve: Curves.easeOutCubic,
      ),
    );

    // Create staggered animations for the circles
    _circleAnimations = List.generate(
      3,
      (index) => Tween<double>(
        begin: 1.0,
        end: 1.2 + (index * 0.1),
      ).animate(
        CurvedAnimation(
          parent: _pulseController,
          curve: Interval(
            index * 0.2,
            (0.8 + (index * 0.2)).clamp(0.0, 1.0),
            curve: Curves.easeInOut,
          ),
        ),
      ),
    );

    // Start initial animations after a short delay
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        _fadeInController.forward();
        setState(() {
          _hasAnimated = true;
        });
      }
    });
  }

  void _initBubbles() {
    // Create 15 random bubbles
    for (int i = 0; i < 15; i++) {
      _bubbles.add(
        Bubble(
          x: _random.nextDouble() * 400,
          y: _random.nextDouble() * 800 + 100,
          size: _random.nextDouble() * 30 + 10,
          speed: _random.nextDouble() * 0.5 + 0.2,
          opacity: _random.nextDouble() * 0.3 + 0.1,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeInController.dispose();
    _waveController.dispose();
    _shimmerController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  // Enhanced haptic feedback patterns
  Future<void> _performHapticFeedback({bool isLongPress = false}) async {
    if (isLongPress) {
      // Complex pattern for long press
      await HapticFeedback.lightImpact();
      await Future.delayed(Duration(milliseconds: 50));
      await HapticFeedback.mediumImpact();
      await Future.delayed(Duration(milliseconds: 50));
      await HapticFeedback.heavyImpact();
    } else {
      // Simple pattern for normal taps
      await HapticFeedback.mediumImpact();
    }
  }

  // Handle navigation to auth screen with slide transition
  Future<void> _handleLetsGoPress(BuildContext context) async {
    // Show loading state
    setState(() {
      _isLoading = true;
      _isButtonPressed = true;
    });

    // Trigger enhanced haptic feedback
    await _performHapticFeedback();

    // Simulate loading (you can remove this in production)
    await Future.delayed(Duration(seconds: 1));

    // Only navigate if the widget is still mounted
    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    // Navigate with slide right transition
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeInOutCubic;

          var tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(position: offsetAnimation, child: child);
        },
        transitionDuration: Duration(milliseconds: 500),
      ),
    );
  }

  Future<void> _handleClick() async {
    await _performHapticFeedback();
  }

  Future<void> _handleLongPress() async {
    await _performHapticFeedback(isLongPress: true);
  }

  void _showTermsSheet(BuildContext context, bool isTerms) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.withOpacity(0.08),
              Colors.purple.withOpacity(0.08),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: -5,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 12.0,
              sigmaY: 12.0,
            ),
            child: Container(
              color: Colors.transparent,
              child: Column(
                children: [
                  Container(
                    margin: EdgeInsets.symmetric(vertical: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      isTerms ? 'Terms of Service' : 'Privacy Policy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(20),
                      physics: BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String>(
                            future: LegalService.getLegalText(isTerms),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Text(
                                  snapshot.data!,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                );
                              }
                              return Center(
                                child: CircularProgressIndicator(
                                  color: Colors.amber.shade300,
                                  semanticsLabel:
                                      'Loading ${isTerms ? "Terms" : "Privacy Policy"}',
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 32),
                          Container(
                            width: double.infinity,
                            child: NeoPopButton(
                              color: Colors.black,
                              bottomShadowColor: ColorUtils.getVerticalShadow(
                                      Colors.amber.shade700)
                                  .toColor(),
                              rightShadowColor: ColorUtils.getHorizontalShadow(
                                      Colors.amber.shade700)
                                  .toColor(),
                              animationDuration: Duration(milliseconds: 200),
                              depth: 8,
                              onTapUp: () {
                                _handleClick();
                                launchUrl(
                                  Uri.parse(isTerms
                                      ? 'https://duckbuck.in/terms'
                                      : 'https://duckbuck.in/privacy'),
                                );
                              },
                              border: Border.all(
                                color: Colors.amber.shade300,
                                width: 1.5,
                              ),
                              child: Semantics(
                                button: true,
                                label:
                                    'Read Full ${isTerms ? "Terms" : "Policy"} on website',
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 15),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Read Full ${isTerms ? "Terms" : "Policy"}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      FaIcon(
                                        FontAwesomeIcons.externalLink,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ],
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
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.black87,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: Colors.amber.withOpacity(0.3),
                width: 1,
              ),
            ),
            title: const Text(
              'Exit App?',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to exit the app?',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No',
                  style: TextStyle(color: Colors.amber.shade300),
                ),
              ),
              TextButton(
                onPressed: () {
                  _performHapticFeedback();
                  SystemNavigator.pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text(
                  'Yes',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Warm ghee color palette
    final Color gheeColor = Color(0xFFF5E7C1);
    final Color gheeAccentDark = Color(0xFFDDAB52);
    final Color gheeAccentLight = Color(0xFFF7EFD5);
    final Color textColor = Color(0xFF5A3E2B);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        body: Semantics(
          label: 'DuckBuck Welcome Screen',
          child: AnimatedBuilder(
            animation: Listenable.merge([_fadeInController, _bubbleController]),
            builder: (context, child) {
              // Update bubble positions based on animation value
              for (var bubble in _bubbles) {
                bubble.y -= bubble.speed; // Move upward

                // Reset bubbles that have moved off screen
                if (bubble.y < -bubble.size) {
                  bubble.y = MediaQuery.of(context).size.height + bubble.size;
                  bubble.x =
                      _random.nextDouble() * MediaQuery.of(context).size.width;
                }
              }

              return Container(
                decoration: BoxDecoration(
                  // Warm ghee color gradient background
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      gheeAccentLight,
                      gheeColor,
                      Color(0xFFECD592),
                    ],
                  ),
                ),
                child: Stack(
                  children: [
                    // Glassmorphism bubbles in background
                    ...renderBubbles(gheeAccentDark),

                    // Warm overlay gradient
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        backgroundBlendMode: BlendMode.overlay,
                        gradient: RadialGradient(
                          colors: [
                            Colors.transparent,
                            gheeAccentDark.withOpacity(0.05),
                            gheeAccentDark.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.4, 0.7, 1.0],
                          radius: 1.2,
                        ),
                      ),
                    ),

                    // Initial fade-in animation wrapper
                    Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: SafeArea(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // App title and logo section
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // App name with shimmer animation
                                    Semantics(
                                      label: 'DuckBuck, the app name',
                                      child: Shimmer.fromColors(
                                        baseColor: textColor,
                                        highlightColor: gheeAccentDark,
                                        period: Duration(milliseconds: 2500),
                                        child: ShaderMask(
                                          blendMode: BlendMode.srcIn,
                                          shaderCallback: (bounds) =>
                                              LinearGradient(
                                            colors: [
                                              textColor,
                                              gheeAccentDark,
                                              Colors.amber.shade800,
                                              gheeAccentDark,
                                              textColor,
                                            ],
                                            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            tileMode: TileMode.mirror,
                                          ).createShader(bounds),
                                          child: Text(
                                            "DuckBuck",
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2.0,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16),
                                    // App tagline
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(30),
                                        color: gheeAccentDark.withOpacity(0.2),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                gheeAccentDark.withOpacity(0.3),
                                            blurRadius: 15,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                      child: Semantics(
                                        label:
                                            'App tagline: Talk Instantly Over the Internet',
                                        child: Text(
                                          "Talk Instantly Over the Internet",
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    // Subtitle
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 30, vertical: 10),
                                      child: Text(
                                        "Your Internet Walkie Talkie",
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.8),
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Animated graphic with ripple effect
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Semantics(
                                    label: 'Animated audio visualization',
                                    child: Container(
                                      width: 300,
                                      height: 300,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          // Animated circles with staggered animations
                                          ...List.generate(3, (index) {
                                            return AnimatedBuilder(
                                              animation:
                                                  _circleAnimations[index],
                                              builder: (context, child) {
                                                return Transform.scale(
                                                  scale:
                                                      _circleAnimations[index]
                                                          .value,
                                                  child: Container(
                                                    width: 150.0 + (index * 50),
                                                    height:
                                                        150.0 + (index * 50),
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: Colors.transparent,
                                                      border: Border.all(
                                                        color: gheeAccentDark
                                                            .withOpacity(0.3 -
                                                                (index * 0.08)),
                                                        width: 2,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: gheeAccentDark
                                                              .withOpacity(0.2 -
                                                                  (index *
                                                                      0.05)),
                                                          blurRadius: 15,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }),

                                          // Animated sound wave lines
                                          AnimatedBuilder(
                                            animation: _waveController,
                                            builder: (context, child) {
                                              return CustomPaint(
                                                size: Size(120, 80),
                                                painter:
                                                    GeometricSoundWavePainter(
                                                  animationValue:
                                                      _waveController.value,
                                                  primaryColor: textColor,
                                                  secondaryColor: textColor
                                                      .withOpacity(0.6),
                                                  useGradient: true,
                                                ),
                                              );
                                            },
                                          ),

                                          // NEW: 3D effect central sound wave component
                                          AnimatedBuilder(
                                            animation: _waveController,
                                            builder: (context, child) {
                                              return Center(
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // Glowing base
                                                    Container(
                                                      width: 110,
                                                      height: 110,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        gradient:
                                                            RadialGradient(
                                                          colors: [
                                                            gheeAccentDark
                                                                .withOpacity(
                                                                    0.8),
                                                            gheeAccentDark
                                                                .withOpacity(
                                                                    0.2),
                                                          ],
                                                          stops: [0.2, 1.0],
                                                        ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: gheeAccentDark
                                                                .withOpacity(
                                                                    0.5),
                                                            blurRadius: 20,
                                                            spreadRadius: 5,
                                                          )
                                                        ],
                                                      ),
                                                    ),

                                                    // Main circle with dynamic scaling
                                                    Transform.scale(
                                                      scale: 1.0 +
                                                          (_waveController
                                                                  .value *
                                                              0.1),
                                                      child: Container(
                                                        width: 90,
                                                        height: 90,
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          color: gheeColor,
                                                          gradient:
                                                              LinearGradient(
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                            colors: [
                                                              Colors.white
                                                                  .withOpacity(
                                                                      0.8),
                                                              gheeColor,
                                                              gheeAccentDark
                                                                  .withOpacity(
                                                                      0.8),
                                                            ],
                                                          ),
                                                          boxShadow: [
                                                            BoxShadow(
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                      0.2),
                                                              blurRadius: 10,
                                                              offset:
                                                                  Offset(5, 5),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),

                                                    // Microphone icon with animation
                                                    Transform.scale(
                                                      scale: 1.0 +
                                                          (_waveController
                                                                  .value *
                                                              0.05),
                                                      child: Icon(
                                                        FontAwesomeIcons
                                                            .microphone,
                                                        color: textColor
                                                            .withOpacity(0.7 +
                                                                _waveController
                                                                        .value *
                                                                    0.3),
                                                        size: 30,
                                                        key: const Key('microphone_icon'),
                                                      ),
                                                    ),

                                                    // Highlight overlay for 3D effect
                                                    Positioned(
                                                      top: 20,
                                                      left: 20,
                                                      child: Container(
                                                        width: 30,
                                                        height: 30,
                                                        decoration:
                                                            BoxDecoration(
                                                          shape:
                                                              BoxShape.circle,
                                                          gradient:
                                                              RadialGradient(
                                                            colors: [
                                                              Colors.white
                                                                  .withOpacity(
                                                                      0.9),
                                                              Colors.white
                                                                  .withOpacity(
                                                                      0.0),
                                                            ],
                                                            stops: [0.1, 1.0],
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),

                                          // Animated particles around the center (optional)
                                          ...List.generate(8, (index) {
                                            final angle = index * (pi / 4);
                                            final distance = 70.0 +
                                                (sin(_waveController.value *
                                                        pi *
                                                        2) *
                                                    10);

                                            return Positioned(
                                              left: 150 + cos(angle) * distance,
                                              top: 150 + sin(angle) * distance,
                                              child: Container(
                                                width: 8 +
                                                    (sin(_waveController.value *
                                                                pi *
                                                                2 +
                                                            index) *
                                                        3),
                                                height: 8 +
                                                    (sin(_waveController.value *
                                                                pi *
                                                                2 +
                                                            index) *
                                                        3),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: gheeAccentDark
                                                      .withOpacity(0.8),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: gheeAccentDark
                                                          .withOpacity(0.5),
                                                      blurRadius: 5,
                                                      spreadRadius: 1,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // Bottom section with button
                              Column(
                                children: [
                                  // Terms and Privacy text
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 32),
                                    child: Text.rich(
                                      TextSpan(
                                        text:
                                            'By continuing, you agree to our ',
                                        style: TextStyle(
                                          color: textColor.withOpacity(0.9),
                                          fontSize: 14,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: 'Terms of Service',
                                            style: TextStyle(
                                              color: Colors.amber.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () => _showTermsSheet(
                                                  context, true),
                                          ),
                                          TextSpan(text: ' and '),
                                          TextSpan(
                                            text: 'Privacy Policy',
                                            style: TextStyle(
                                              color: Colors.amber.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () => _showTermsSheet(
                                                  context, false),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  SizedBox(height: 20),

                                  // Enhanced NeoPop button
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 10),
                                    child: MergeSemantics(
                                      child: Semantics(
                                        button: true,
                                        enabled: !_isLoading,
                                        label: "Let's Go button, continues to authentication",
                                        child: GestureDetector(
                                          onLongPress: _isLoading ? null : _handleLongPress,
                                          child: EnhancedNeopopButton(
                                            isLoading: _isLoading,
                                            isPressed: _isButtonPressed,
                                            onTap: () => _handleLetsGoPress(context),
                                            buttonColor: gheeColor,
                                            textColor: textColor,
                                            accentColor: gheeAccentDark,
                                            borderColor: gheeAccentDark,
                                            buttonText: "Let's Go",
                                            suffixIcon: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: gheeAccentDark.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Icon(
                                                Icons.arrow_forward,
                                                color: textColor,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // Method to render the glassmorphism bubbles
  List<Widget> renderBubbles(Color accentColor) {
    return _bubbles.map((bubble) {
      return Positioned(
        left: bubble.x,
        top: bubble.y,
        child: Container(
          width: bubble.size,
          height: bubble.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(bubble.opacity),
                accentColor.withOpacity(bubble.opacity * 0.7),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.white.withOpacity(bubble.opacity * 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
            border: Border.all(
              color: Colors.white.withOpacity(bubble.opacity * 0.5),
              width: 1.5,
            ),
          ),
        ),
      );
    }).toList();
  }
}

// Bubble class for background animation
class Bubble {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Bubble({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Enhanced NeoPop button with clean animation and fixed arrow issue
class EnhancedNeopopButton extends StatelessWidget {
  final bool isLoading;
  final bool isPressed;
  final VoidCallback onTap;
  final Color buttonColor;
  final Color textColor;
  final Color accentColor;
  final Color borderColor;
  final String buttonText;
  final Widget? suffixIcon;

  const EnhancedNeopopButton({
    Key? key,
    required this.isLoading,
    required this.isPressed,
    required this.onTap,
    required this.buttonColor,
    required this.textColor,
    required this.accentColor,
    required this.borderColor,
    required this.buttonText,
    this.suffixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return NeoPopButton(
        color: buttonColor,
        bottomShadowColor: ColorUtils.getVerticalShadow(accentColor).toColor(),
        rightShadowColor: ColorUtils.getHorizontalShadow(accentColor).toColor(),
        animationDuration: Duration(milliseconds: 200),
        depth: isPressed ? 0 : 10,
        onTapUp: isLoading ? null : onTap,
        onTapDown: isLoading ? null : () {},
        border: Border.all(
          color: borderColor,
          width: 2,
        ),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              else
                Text(
                  buttonText,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              if (!isLoading)
                Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.arrow_forward,
                    color: textColor,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      );
    
  }
}

class GeometricSoundWavePainter extends CustomPainter {
  final double animationValue;
  final Color primaryColor;
  final Color secondaryColor;
  final bool useGradient;

  GeometricSoundWavePainter({
    required this.animationValue,
    required this.primaryColor,
    this.secondaryColor = Colors.white,
    this.useGradient = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerY = size.height / 2;
    final double width = size.width;

    // Create gradient for more aesthetic appeal
    final Paint gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Draw background glow effect
    if (useGradient) {
      final Paint glowPaint = Paint()
        ..color = primaryColor.withOpacity(0.15)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);

      final Path glowPath = Path();
      glowPath.addOval(Rect.fromCenter(
        center: Offset(width / 2, centerY),
        width: width * 0.8 * (0.7 + 0.3 * sin(animationValue * pi)),
        height: size.height * 0.7,
      ));
      canvas.drawPath(glowPath, glowPaint);
    }

    // Draw circular wave rings
    _drawCircularWaves(canvas, size, centerY, width);

    // Draw main frequency bars
    _drawFrequencyBars(canvas, size, centerY);

    // Draw particle effects
    _drawParticles(canvas, size, centerY, width);
  }

  void _drawCircularWaves(
      Canvas canvas, Size size, double centerY, double width) {
    final center = Offset(width / 2, centerY);
    final Paint circlePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw 3 expanding circles with decreasing opacity
    for (int i = 0; i < 3; i++) {
      double radius = (width / 3) *
          (0.2 + (i * 0.25)) *
          (1.0 + 0.3 * sin(animationValue * 2 * pi + i));
      double opacity = 0.7 - (i * 0.2) - (0.1 * sin(animationValue * 3 * pi));

      circlePaint.color = primaryColor.withOpacity(opacity);
      canvas.drawCircle(center, radius, circlePaint);
    }
  }

  void _drawFrequencyBars(Canvas canvas, Size size, double centerY) {
    final Paint barPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.0;

    final int barCount = 40;
    final double barWidth = size.width / barCount;
    final double maxBarHeight = size.height * 0.5;

    // Create shader gradient for the bars
    if (useGradient) {
      barPaint.shader = LinearGradient(
        colors: [primaryColor, secondaryColor, primaryColor],
        stops: [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    } else {
      barPaint.color = primaryColor;
    }

    for (int i = 0; i < barCount; i++) {
      final double x = i * barWidth + (barWidth / 2);
      final double normalizedX = i / barCount;

      // Create complex wave pattern using multiple sine waves
      double heightFactor = 0.1 +
          0.5 * sin(animationValue * 2 * pi + normalizedX * 6 * pi) +
          0.3 * sin(animationValue * 3 * pi + normalizedX * 8 * pi) +
          0.2 * sin(animationValue * 5 * pi + normalizedX * 4 * pi);

      // Apply a bell curve to make center bars taller
      double bellCurve = exp(-(pow(normalizedX - 0.5, 2) / 0.07));
      heightFactor *= bellCurve;

      final double barHeight = maxBarHeight * heightFactor;
      final double startY = centerY - barHeight / 2;
      final double endY = centerY + barHeight / 2;

      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        barPaint,
      );
    }
  }

  void _drawParticles(Canvas canvas, Size size, double centerY, double width) {
    final Paint particlePaint = Paint()..style = PaintingStyle.fill;

    final int particleCount = 20;
    final double baseSize = 3.0;

    for (int i = 0; i < particleCount; i++) {
      // Create pseudorandom but deterministic positions based on animation value
      final double angle = (i / particleCount) * 2 * pi + (animationValue * pi);
      final double distance =
          (width / 3) * (0.5 + 0.5 * sin(animationValue * 2 * pi + i * 0.7));

      final double x = width / 2 + cos(angle) * distance;
      final double y =
          centerY + sin(angle) * distance * 0.7; // Flatter elliptical path

      // Vary particle size and opacity
      final double sizeVariation =
          0.5 + 0.5 * sin(animationValue * 5 * pi + i * 0.5);
      final double size = baseSize * sizeVariation;
      final double opacity = 0.3 + 0.4 * sizeVariation;

      particlePaint.color = secondaryColor.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), size, particlePaint);
    }
  }

  @override
  bool shouldRepaint(GeometricSoundWavePainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}
