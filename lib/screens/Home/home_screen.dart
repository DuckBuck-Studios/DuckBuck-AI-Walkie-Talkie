import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../widgets/animated_background.dart';
import '../../providers/user_provider.dart';
import '../../providers/friend_provider.dart';
import '../../providers/call_provider.dart';
import '../../services/agora_service.dart';
import '../../widgets/status_animation_popup.dart';
import 'profile_screen.dart';
import 'friend_screen.dart';
import 'widgets/friends_list.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final AgoraService _agoraService = AgoraService();
  bool _initializingAgora = false;

  @override
  void initState() {
    super.initState();
    // Register observer for app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize the user provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      print("HomeScreen: Starting initialization sequence");
      final userProvider = Provider.of<UserProvider>(context, listen: false);
      // Wait for user provider to initialize
      await userProvider.initialize();
      print("HomeScreen: UserProvider initialization completed");
      
      // Set user status as online automatically - without affecting animation status
      _setUserOnline();
      
      // Initialize friend provider
      final friendProvider = Provider.of<FriendProvider>(context, listen: false);
      print("HomeScreen: Initializing FriendProvider");
      await friendProvider.initialize();
      print("HomeScreen: FriendProvider initialization completed");
      
      // Start monitoring friend statuses
      _startFriendStatusMonitoring(friendProvider);

      // Initialize Agora engine and check permissions
      await _initializeAgoraAndPermissions();
    });
  }
  
  @override
  void dispose() {
    // Unregister observer
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Initialize Agora engine and check permissions
  Future<void> _initializeAgoraAndPermissions() async {
    // Avoid multiple initializations
    if (_initializingAgora) return;
    
    setState(() {
      _initializingAgora = true;
    });
    
    print("HomeScreen: Initializing Agora engine");
    
    // Initialize Agora engine
    final initialized = await _agoraService.initializeEngine();
    if (initialized) {
      print("HomeScreen: Agora engine initialized successfully");
      
      // Request permissions for future use (but don't block on them)
      _requestPermissions();
    } else {
      print("HomeScreen: Failed to initialize Agora engine");
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize video call service'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
    
    setState(() {
      _initializingAgora = false;
    });
  }
  
  // Request necessary permissions
  Future<void> _requestPermissions() async {
    print("HomeScreen: Checking call permissions");
    
    // Check microphone permission
    final micStatus = await Permission.microphone.status;
    if (micStatus != PermissionStatus.granted) {
      print("HomeScreen: Microphone permission not granted: $micStatus");
    }
    
    // Check camera permission
    final camStatus = await Permission.camera.status;
    if (camStatus != PermissionStatus.granted) {
      print("HomeScreen: Camera permission not granted: $camStatus");
    }
    
    // We don't automatically request permissions here, as it's better UX
    // to request them when actually needed (i.e., when user tries to unmute or enable video)
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("HomeScreen: App lifecycle state changed to $state");
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - set user as online
        print("HomeScreen: App resumed, setting user online");
        userProvider.setOnlineStatus(true);
        
        // Re-initialize Agora engine if needed
        _initializeAgoraAndPermissions();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        // App went to background - user will be set offline by Firebase onDisconnect
        print("HomeScreen: App went to background state: $state");
        break;
      case AppLifecycleState.hidden:
        // New state in Flutter 3.13+
        print("HomeScreen: App hidden");
        break;
    }
  }

  // Set user status as online
  void _setUserOnline() {
    print("HomeScreen: Setting user online status");
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    
    // Set user as online without changing animation status
    userProvider.setOnlineStatus(true);
    
    // Keep this for backward compatibility - it will only update animation if already set
    userProvider.setStatusAnimation(userProvider.statusAnimation, explicitChange: false);
  }

  // Show status animation popup
  void _showStatusAnimationPopup() {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (context) => StatusAnimationPopup(
        onAnimationSelected: (animation) {
          userProvider.setStatusAnimation(animation);
        },
      ),
    );
  }

  // Monitor friend statuses
  void _startFriendStatusMonitoring(FriendProvider friendProvider) {
    print("HomeScreen: Starting friend status monitoring");
    // This ensures the friend provider starts monitoring status updates
    friendProvider.startStatusMonitoring();
    
    // Add debugging for friend statuses
    final friends = friendProvider.friends;
    print("HomeScreen: Monitoring ${friends.length} friends for status updates");
    for (var friend in friends) {
      print("HomeScreen: Friend ${friend['displayName']} (${friend['id']}) status: ${friend['isOnline'] == true ? 'Online' : 'Offline'}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        body: DuckBuckAnimatedBackground(
          child: SafeArea(
            child: Column(
              children: [
                // Top Bar with Profile Icon and Friends Button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width * 0.04,
                    vertical: MediaQuery.of(context).size.height * 0.02,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculate appropriate sizes based on screen width
                      final double screenWidth = MediaQuery.of(context).size.width;
                      final bool isSmallScreen = screenWidth < 360;
                      final double buttonSize = isSmallScreen ? 45 : 50;
                      final double borderWidth = isSmallScreen ? 1.5 : 2;
                      final double iconSize = isSmallScreen ? 26 : 30;
                      final double titleFontSize = screenWidth * 0.06;
                      
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Profile Photo Button
                          Consumer<UserProvider>(
                            builder: (context, userProvider, child) {
                              final user = userProvider.currentUser;
                              return GestureDetector(
                                onTap: _navigateToProfile,
                                onLongPress: _showStatusAnimationPopup,
                                child: Hero(
                                  tag: 'profile-photo',
                                  child: Container(
                                    width: buttonSize,
                                    height: buttonSize,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFD4A76A), width: borderWidth),
                                      color: const Color(0xFFD4A76A).withOpacity(0.2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 4,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(buttonSize / 2),
                                      child: user?.photoURL != null && user!.photoURL!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: user.photoURL!,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.brown.shade100,
                                                child: Center(
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: isSmallScreen ? 2 : 3,
                                                    color: Colors.brown.shade800,
                                                  ),
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Icon(
                                                Icons.person, 
                                                size: iconSize, 
                                                color: const Color(0xFFD4A76A)
                                              ),
                                            )
                                          : Icon(
                                              Icons.person, 
                                              size: iconSize, 
                                              color: const Color(0xFFD4A76A)
                                            ),
                                    ),
                                  ),
                                ),
                              ).animate()
                                .fadeIn(duration: 400.ms)
                                .scale(
                                  begin: const Offset(0.5, 0.5),
                                  end: const Offset(1.0, 1.0),
                                  duration: 500.ms,
                                  curve: Curves.elasticOut,
                                );
                            }
                          ),
                          
                          // App Name or Title
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              "DuckBuck",
                              style: TextStyle(
                                fontSize: titleFontSize,
                                fontWeight: FontWeight.bold,
                                color: Colors.brown.shade800,
                              ),
                            ),
                          ).animate()
                            .fadeIn(duration: 600.ms)
                            .slideY(begin: -0.2, end: 0, duration: 600.ms, curve: Curves.easeOutCubic),
                          
                          // Friends Button with Lottie Animation
                          GestureDetector(
                            onTap: _navigateToFriendScreen,
                            child: Container(
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFD4A76A).withOpacity(0.2),
                                border: Border.all(color: const Color(0xFFD4A76A), width: borderWidth),
                              ),
                              child: Lottie.asset(
                                'assets/animations/friend.json',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ).animate()
                            .fadeIn(duration: 400.ms)
                            .scale(
                              begin: const Offset(0.5, 0.5),
                              end: const Offset(1.0, 1.0),
                              duration: 500.ms,
                              curve: Curves.elasticOut,
                            ),
                        ],
                      );
                    }
                  ),
                ),
                
                // Friends section with PageView
                Expanded(
                  child: Consumer<FriendProvider>(
                    builder: (context, friendProvider, child) {
                      final friends = friendProvider.friends;
                      return FriendsList(friends: friends);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const ProfileScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToFriendScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const FriendScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}