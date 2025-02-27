import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:duckbuck/Authentication/screens/profile_screen.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';
import 'package:neopop/utils/color_utils.dart';
import 'package:shimmer/shimmer.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({Key? key}) : super(key: key);

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();
  bool _isButtonEnabled = false;
  late AnimationController _buttonController;
  late Animation<double> _buttonAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    _nameController.addListener(_validateInput);

    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _buttonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _buttonController,
      curve: Curves.easeInOut,
    ));
  }

  void _validateInput() {
    setState(() {
      _isButtonEnabled = _nameController.text.trim().length >= 3;
    });
  }

  Future<void> _validateAndProceed() async {
    await HapticFeedback.mediumImpact();
    
    if (_formKey.currentState!.validate()) {
      await _authService.updateName(_nameController.text);
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOut,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    }
  }

  @override
  void dispose() {
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: Color(0xFFFFE0B2), // Warm ghee color
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Shimmer.fromColors(
                        baseColor: Color(0xFF4A4A4A),
                        highlightColor: Color(0xFF8B8B8B),
                        child: Text(
                          "whats your name?",
                          style: TextStyle(
                            color: Color(0xFF4A4A4A),
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        "this is how your friends will see you",
                        style: TextStyle(
                          color: Color(0xFF6B6B6B),
                          fontSize: 18,
                          letterSpacing: 0.3,
                        ),
                      ),
                      SizedBox(height: 40),
                      Padding(
  padding: const EdgeInsets.symmetric(horizontal: 24),
  child: Center(  // Center widget to align the TextFormField
    child: Form(
      key: _formKey,
      child: TextFormField(
        controller: _nameController,
        style: TextStyle(
          color: Color(0xFF4A4A4A),
          fontSize: 26,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        decoration: InputDecoration(
          hintText: "your name",
          hintStyle: TextStyle(
            color: Color(0xFF8B8B8B),
            fontSize: 26,
            letterSpacing: 0.3,
          ),
          border: InputBorder.none,
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Color(0xFF8B8B8B).withOpacity(0.3), width: 2),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Name cannot be empty';
          } else if (value.trim().length < 3) {
            return 'Name is too short';
          }
          return null;
        },
      ),
    ),
  ),
)
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedBuilder(
                  animation: _buttonAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _scaleAnimation.value,
                      child: NeoPopButton(
                        color: Color(0xFFFF9800),
                        bottomShadowColor: ColorUtils.getVerticalShadow(Color(0xFFFF9800)).toColor(),
                        rightShadowColor: ColorUtils.getHorizontalShadow(Color(0xFFFF9800)).toColor(),
                        animationDuration: Duration(milliseconds: 200),
                        depth: 8,
                        onTapUp: _isButtonEnabled ? () {
                          _buttonController.forward().then((_) {
                            _buttonController.reverse();
                            _validateAndProceed();
                          });
                        } : null,
                        onTapDown: () => _buttonController.forward(),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}