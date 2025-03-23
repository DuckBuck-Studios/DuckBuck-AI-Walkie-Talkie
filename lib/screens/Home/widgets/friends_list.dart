import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'friend_card.dart';

class FriendsList extends StatefulWidget {
  final List<Map<String, dynamic>> friends;

  const FriendsList({
    Key? key,
    required this.friends,
  }) : super(key: key);

  @override
  State<FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<FriendsList> {
  final PageController _friendsPageController = PageController();

  @override
  void dispose() {
    _friendsPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Color(0xFF3C1F1F),
            ).animate()
              .fadeIn(duration: 800.ms)
              .scale(
                begin: const Offset(0.5, 0.5),
                duration: 800.ms,
                curve: Curves.elasticOut,
              ),
            const SizedBox(height: 16),
            Text(
              'No friends yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.brown.shade800,
              ),
            ).animate()
              .fadeIn(delay: 200.ms, duration: 600.ms),
            const SizedBox(height: 8),
            Text(
              'Add friends to see them here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.brown.shade600,
              ),
            ).animate()
              .fadeIn(delay: 400.ms, duration: 600.ms),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _friendsPageController,
            itemCount: widget.friends.length,
            itemBuilder: (context, index) {
              // Get screen dimensions for responsive padding
              final Size screenSize = MediaQuery.of(context).size;
              final bool isSmallScreen = screenSize.width < 360;
              final bool isLargeScreen = screenSize.width > 600;
              final bool isLandscape = screenSize.width > screenSize.height;
              
              // Calculate appropriate padding based on screen size
              final double horizontalPadding = isLargeScreen 
                  ? screenSize.width * 0.15 
                  : (isSmallScreen ? screenSize.width * 0.06 : screenSize.width * 0.08);
                  
              final double verticalPadding = isLandscape
                  ? screenSize.height * 0.05
                  : (isSmallScreen ? screenSize.height * 0.02 : screenSize.height * 0.03);
              
              // Staggered animation based on index
              return Padding(
                // Dynamic padding to adjust card size for different screens
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding, 
                  vertical: verticalPadding
                ),
                child: FriendCard(
                  friend: widget.friends[index],
                  showStatus: true, // Enable status display
                ).animate()
                  .fadeIn(
                    delay: Duration(milliseconds: 100 * index), 
                    duration: 800.ms
                  )
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    end: const Offset(1.0, 1.0),
                    delay: Duration(milliseconds: 100 * index),
                    duration: 800.ms,
                    curve: Curves.easeOutBack,
                  ),
              );
            },
          ),
        ),
        if (widget.friends.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.friends.length,
                (index) => AnimatedBuilder(
                  animation: _friendsPageController,
                  builder: (context, child) {
                    // Calculate current page for indicator
                    double page = _friendsPageController.hasClients
                        ? _friendsPageController.page ?? 0
                        : 0;
                    bool isActive = (index == page.round());
                    
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 12 : 8,
                      height: isActive ? 12 : 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? const Color(0xFF3C1F1F)
                            : const Color(0xFF3C1F1F).withOpacity(0.3),
                      ),
                    ).animate(
                      target: isActive ? 1.0 : 0.0,
                    ).scaleXY(
                      begin: 1.0,
                      end: 1.2,
                      duration: 300.ms,
                    );
                  },
                ),
              ),
            ),
          ).animate()
            .fadeIn(delay: 600.ms, duration: 400.ms),
      ],
    );
  }
} 