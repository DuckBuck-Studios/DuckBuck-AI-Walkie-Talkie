import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:duckbuck/features/home/screens/home_screen.dart'; 
import 'package:duckbuck/features/friends/screens/friends_screen.dart';
import 'package:duckbuck/features/settings/screens/settings_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  late PageController _pageController;
  Widget? _fullscreenOverlay;

  // Define the screens for the GNav
  List<Widget> get _widgetOptions => <Widget>[
    HomeScreen(onShowFullscreenOverlay: _showFullscreenOverlay, onHideFullscreenOverlay: _hideFullscreenOverlay),     // Home tab
    const FriendsScreen(),  
    const SettingsScreen(), 
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    // Check if the PageController is attached to a PageView
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300), // Consistent animation duration
        curve: Curves.easeInOut, // Smoother curve
      );
    } else {
      // If not attached yet (e.g. during initial build), just set the index
      // The PageView will pick this up when it builds
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _showFullscreenOverlay(Widget overlay) {
    setState(() {
      _fullscreenOverlay = overlay;
    });
  }

  void _hideFullscreenOverlay() {
    setState(() {
      _fullscreenOverlay = null;
    });
  }

  /// Handle back button press - prevent navigation back to login/onboarding
  Future<bool> _onWillPop() async {
    // Show a brief haptic feedback to indicate the action was blocked
    HapticFeedback.lightImpact();
    
    // Always return false to prevent back navigation
    // Users must use the logout functionality in settings to sign out
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.black, // Set Scaffold background to black
            body: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              children: _widgetOptions,
            ),
          ),
          // Floating navigation bar overlay
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(30), // Rounded corners
                boxShadow: [
                  BoxShadow(
                    blurRadius: 30,
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: GNav(
                  rippleColor: Colors.grey[800]!,
                  hoverColor: Colors.grey[700]!,
                  gap: 8,
                  activeColor: Colors.white, // Active icon/text color
                  iconSize: 24,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  duration: const Duration(milliseconds: 400),
                  tabBackgroundColor: Colors.grey[800]!, // Background color for active tab
                  color: Colors.grey[400]!, // Inactive icon/text color
                  tabs: const [
                    GButton(
                      icon: Icons.home_outlined,
                      text: 'Home',
                    ),
                    GButton(
                      icon: Icons.people_outline,
                      text: 'Friends',
                    ),
                    GButton(
                      icon: Icons.settings_outlined,
                      text: 'Settings',
                    ),
                  ],
                  selectedIndex: _selectedIndex,
                  onTabChange: _onItemTapped, // Use the consolidated tap handler
                ),
              ),
            ),
          ),
          // Fullscreen overlay - truly fullscreen without any constraints
          if (_fullscreenOverlay != null)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: 0,
              child: Material(
                type: MaterialType.transparency,
                child: _fullscreenOverlay!,
              ),
            ),
        ],
      ),
    );
  }
}
