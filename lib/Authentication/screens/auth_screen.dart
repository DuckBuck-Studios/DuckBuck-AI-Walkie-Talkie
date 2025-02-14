import 'package:duckbuck/Authentication/screens/name_screen.dart';
import 'package:duckbuck/home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:duckbuck/Authentication/service/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _buttonScaleAnimation;
  bool _isLoading = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _initializeUI();
    _initializeAnimations();
  }

  void _initializeUI() {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _initializeAnimations() {
    _controller = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _buttonScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.95), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    super.dispose();
  }

  void _buttonPressHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  void _successHaptic() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.mediumImpact();
  }

  void _failureHaptic() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    try {
      _buttonPressHaptic();
      setState(() => _isLoading = true);

      final result = await _authService.signInWithGoogle();
      final user = result['user'];
      final isNewUser = result['isNewUser'];

      if (!mounted) return;

      if (user != null) {
        _successHaptic();
        if (isNewUser) {
          // New user, go to NameScreen for profile setup
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NameScreen()),
          );
        } else {
          // Existing user, go directly to HomeScreen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      } else {
        _failureHaptic();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sign-in failed: Unable to authenticate'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _failureHaptic();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleAppleSignIn() async {
    if (_isLoading) return;

    try {
      _buttonPressHaptic(); // Haptic feedback on button press
      setState(() => _isLoading = true);

      final result = await _authService.signInWithApple();

      if (!mounted) return;

      if (result != null) {
        _successHaptic(); // Success haptic feedback
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => NameScreen()),
        );
      } else {
        _failureHaptic(); // Failure haptic feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Sign-in failed: Unable to authenticate'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _failureHaptic(); // Failure haptic feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Colors.red.shade900,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildSocialButton({
    required String text,
    required String svgPath,
    required VoidCallback onPressed,
    required List<Color> gradientColors,
  }) {
    return AnimatedBuilder(
      animation: _buttonScaleAnimation,
      builder: (context, child) => Transform.scale(
        scale: _buttonScaleAnimation.value,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            boxShadow: [
              BoxShadow(
                color: gradientColors.last.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _isLoading ? null : onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      svgPath,
                      height: 24,
                      width: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      text,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Stack(
      alignment: Alignment.center,
      children: [
        AnimatedBuilder(
          animation: _rotationAnimation,
          builder: (context, child) => Transform.rotate(
            angle: _rotationAnimation.value,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Colors.purple.withOpacity(0.1),
                    Colors.purple.withOpacity(0.4),
                    Colors.purple.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [Colors.white, Colors.purple.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Text(
                'DuckBuck',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black,
                Colors.black,
                Colors.purple.shade900,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(child: _buildLogo()),
                    ),
                    Column(
                      children: [
                        _buildSocialButton(
                          text: 'Continue with Google',
                          svgPath: 'assets/google.svg',
                          onPressed: _handleGoogleSignIn,
                          gradientColors: [
                            Colors.purple.shade800,
                            Colors.purple.shade900,
                          ],
                        ),
                        _buildSocialButton(
                          text: 'Continue with Apple',
                          svgPath: 'assets/apple.svg',
                          onPressed: _handleAppleSignIn,
                          gradientColors: [
                            Colors.grey.shade800,
                            Colors.black87,
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ],
                ),
                if (_isLoading)
                  Container(
                    color: Colors.black54,
                    child: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.purple.shade300,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
