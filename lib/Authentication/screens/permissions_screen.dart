import 'package:duckbuck/Home/home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:neopop/widgets/buttons/neopop_button/neopop_button.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

class PermissionsScreen extends StatefulWidget {
  @override
  _PermissionsScreenState createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with TickerProviderStateMixin {
  final List<PermissionItem> permissions = [
    PermissionItem(
      permission: Permission.camera,
      icon: Icons.camera_alt_rounded,
      title: 'Camera',
      description: 'Take photos and record videos for sharing with friends',
      color: Color(0xFF8D6E63),
    ),
    PermissionItem(
      permission: Permission.microphone,
      icon: Icons.mic_rounded,
      title: 'Microphone',
      description: 'Send voice messages and make voice calls',
      color: Color(0xFFD2B48C),
    ),
    PermissionItem(
      permission: Permission.mediaLibrary,
      icon: Icons.photo_library_rounded,
      title: 'Gallery',
      description: 'Share photos and videos from your gallery',
      color: Color(0xFFBCAAA4),
    ),
    PermissionItem(
      permission: Permission.notification,
      icon: Icons.notifications_rounded,
      title: 'Notifications',
      description: 'Stay updated with important messages and calls',
      color: Color(0xFFA1887F),
    ),
  ];

  late List<AnimationController> _controllers;
  late List<Animation<double>> _scaleAnimations;
  late List<Animation<double>> _slideAnimations;

  bool _allPermissionsGranted = false;

  @override
  void initState() {
    super.initState();

    _controllers = List.generate(
      permissions.length,
      (index) => AnimationController(
        duration: Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _scaleAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutBack,
        ),
      );
    }).toList();

    _slideAnimations = _controllers.map((controller) {
      return Tween<double>(begin: 100.0, end: 0.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeOutCubic,
        ),
      );
    }).toList();

    // Stagger the animations
    Future.forEach(
      List.generate(permissions.length, (index) => index),
      (int index) async {
        await Future.delayed(Duration(milliseconds: 200 * index));
        _controllers[index].forward();
      },
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _requestPermission(PermissionItem item, int index) async {
    final status = await item.permission.request();
    setState(() {
      permissions[index] = item..isGranted = status.isGranted;
      _checkAllPermissions();
    });
  }

  void _checkAllPermissions() {
    setState(() {
      _allPermissionsGranted = permissions.every((item) => item.isGranted);
    });
  }

  void _continueToSignup(BuildContext context) {
    if (_allPermissionsGranted) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => HomeScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            var begin = Offset(1.0, 0.0);
            var end = Offset.zero;
            var curve = Curves.easeInOutCubic;
            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEEDCB5),
              Color(0xFFD2B48C),
              Color(0xFFBCAAA4),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'One Last Step',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Enable these permissions to get the full DuckBuck experience',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 16,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(24),
                  itemCount: permissions.length,
                  itemBuilder: (context, index) {
                    final item = permissions[index];
                    return AnimatedBuilder(
                      animation: _controllers[index],
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _slideAnimations[index].value),
                          child: Transform.scale(
                            scale: _scaleAnimations[index].value,
                            child: _buildPermissionCard(item, index),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.all(24),
                child: AnimatedOpacity(
                  duration: Duration(milliseconds: 300),
                  opacity: _allPermissionsGranted ? 1.0 : 0.5,
                  child: NeoPopButton(
                    color: Color(0xFFD2B48C),
                    onTapUp: () => _continueToSignup(context),
                    enabled: _allPermissionsGranted,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: Color(0xFF8D6E63),
                        borderRadius: BorderRadius.zero,
                        boxShadow: _allPermissionsGranted
                            ? [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 15,
                                  offset: Offset(0, 8),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              color: Color(0xFF2A0845),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF2A0845),
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
    );
  }

  Widget _buildPermissionCard(PermissionItem item, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            item.color.withOpacity(0.15),
            item.color.withOpacity(0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: item.color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _requestPermission(item, index),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color.withOpacity(0.3),
                        item.color.withOpacity(0.4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    item.icon,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Shimmer.fromColors(
                    baseColor: Colors.white.withOpacity(0.9),
                    highlightColor: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 16),
                AnimatedContainer(
                  duration: Duration(milliseconds: 300),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: item.isGranted
                          ? [
                              item.color,
                              item.color.withOpacity(0.8),
                            ]
                          : [
                              Colors.white.withOpacity(0.2),
                              Colors.white.withOpacity(0.1),
                            ],
                    ),
                    border: Border.all(
                      color: item.isGranted
                          ? item.color
                          : Colors.white.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: item.isGranted
                      ? Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PermissionItem {
  final Permission permission;
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  bool isGranted;

  PermissionItem({
    required this.permission,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    this.isGranted = false,
  });
}
