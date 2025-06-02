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

  // Define the screens for the GNav
  static const List<Widget> _widgetOptions = <Widget>[
    HomeScreen(),     // Home tab
    FriendsScreen(),  // Friends tab
    SettingsScreen(), // Settings tab
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
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.grey[900], // Dark color for the Nav Bar background
            boxShadow: [
              BoxShadow(
                blurRadius: 20,
                color: Colors.black.withOpacity(0.25), // Darker shadow
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 8),
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
      ),
    );
  }
}
