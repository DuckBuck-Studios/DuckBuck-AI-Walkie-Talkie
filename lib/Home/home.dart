import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:duckbuck/Home/providers/UserProvider.dart';
import 'package:duckbuck/Home/providers/friend_provider.dart';
import 'package:duckbuck/Home/providers/pfp_provider.dart';
import 'package:duckbuck/Home/buttom_sheets/friends_bottom_sheet.dart';
import 'package:duckbuck/Home/widgets/profile_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late PageController _friendsPageController;
  int _currentFriendIndex = 0;
  late AnimationController _swipeHintController;
  bool _hasShownSwipeHint = false;
  bool _isLoading = true;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _friendsPageController = PageController(viewportFraction: 0.3);
    _setupSwipeHintAnimation();
  }

  void _setupSwipeHintAnimation() {
    _swipeHintController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Repeat the animation with a pause
    _swipeHintController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(seconds: 1), () {
          if (_swipeHintController.isCompleted) {
            _swipeHintController.reverse();
          }
        });
      } else if (status == AnimationStatus.dismissed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!_swipeHintController.isAnimating) {
            _swipeHintController.forward();
          }
        });
      }
    });
  }

  void _showSwipeHint() {
    if (!_hasShownSwipeHint) {
      _swipeHintController.forward();
      _hasShownSwipeHint = true;
    }
  }

  @override
  void dispose() {
    _friendsPageController.dispose();
    _swipeHintController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    try {
      await _initializeUser();
      await Provider.of<FriendsProvider>(context, listen: false)
          .initFriendsListener();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeUser() async {
    try {
      final user = await _authService.getCurrentUserData();
      if (user != null) {
        Provider.of<UserProvider>(context, listen: false).initializeUser();
      }
    } catch (e) {
      debugPrint('Error fetching user details: $e');
    }
  }

  void _showFriendsBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FriendsBottomSheet(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'connect with your tribe',
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 24,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          Text(
            'add your daily chat buddies',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 40),
          GestureDetector(
            onTap: _showFriendsBottomSheet,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    final friendsProvider = Provider.of<FriendsProvider>(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PfpProvider()),
        ],
        child: Scaffold(
          backgroundColor: Colors.black,
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: _isLoading
                ? _buildShimmerEffect()
                : Consumer<FriendsProvider>(
                    builder: (context, friendsProvider, _) {
                      final friends = friendsProvider.friends;

                      // Show empty state if there are no friends
                      if (friends.isEmpty) {
                        return _buildEmptyState();
                      }

                      return Stack(
                        children: [
                          // Profile background with shimmer while loading
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            child: ProfileCard(
                              key:
                                  ValueKey(friends[_currentFriendIndex]['uid']),
                              profileUrl: friends[_currentFriendIndex]
                                      ['photoURL'] ??
                                  '',
                              name: friends[_currentFriendIndex]['name'] ??
                                  'Friend',
                              friendId:
                                  friends[_currentFriendIndex]['uid'] ?? '',
                              channelName: friends[_currentFriendIndex]
                                      ['channelName'] ??
                                  '',
                              isLoading: userProvider.isLoading,
                              friends: friends,
                              currentFriendIndex: _currentFriendIndex,
                              onFriendSelected: (index) {
                                debugPrint(
                                    'Selected friend channel: ${friends[index]['channelName']}');
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _currentFriendIndex = index;
                                });
                                _showSwipeHint();
                              },
                              onDragUpdate: (dragDistance) {
                                // Handle drag updates if needed
                              },
                            ),
                          ),

                          // User profile button with shimmer while loading
                          Positioned(
                            top: 50,
                            right: 16,
                            child: _buildProfileButton(userProvider),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileButton(UserProvider userProvider) {
    if (userProvider.isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showFriendsBottomSheet();
        },
        child: Hero(
          tag: 'profile_avatar',
          child: CircleAvatar(
            radius: 25,
            backgroundImage: userProvider.photoURL.isNotEmpty
                ? NetworkImage(userProvider.photoURL)
                : null,
            backgroundColor: userProvider.photoURL.isEmpty
                ? Colors.white.withOpacity(0.2)
                : Colors.transparent,
            child: userProvider.photoURL.isEmpty
                ? Text(
                    userProvider.name.isNotEmpty
                        ? userProvider.name[0].toUpperCase()
                        : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  )
                : null,
          ),
        ),
      ),
    );
  }

  Future<bool> _onWillPop() async {
    if (_lastBackPressTime == null ||
        DateTime.now().difference(_lastBackPressTime!) >
            const Duration(seconds: 2)) {
      _lastBackPressTime = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black87,
        ),
      );
      return false;
    }
    return true;
  }

  Widget _buildShimmerEffect() {
    return Stack(
      children: [
        // Shimmer for profile card
        Shimmer.fromColors(
          baseColor: Colors.grey[900]!,
          highlightColor: Colors.grey[800]!,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
          ),
        ),

        // Shimmer for profile button
        Positioned(
          top: 50,
          right: 16,
          child: Shimmer.fromColors(
            baseColor: Colors.grey[900]!,
            highlightColor: Colors.grey[800]!,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),

        // Shimmer for friend carousel
        Positioned(
          bottom: 100,
          left: 0,
          right: 0,
          child: Shimmer.fromColors(
            baseColor: Colors.grey[900]!,
            highlightColor: Colors.grey[800]!,
            child: Container(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
