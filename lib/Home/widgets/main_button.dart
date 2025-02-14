import 'package:duckbuck/Home/widgets/profile_popup_voice_note.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import 'package:flutter_animate/flutter_animate.dart';

class FriendCarousel extends StatefulWidget {
  final Function(int) onFriendSelected;
  final int currentFriendIndex;
  final List<Map<String, dynamic>> friends;

  const FriendCarousel({
    Key? key,
    required this.onFriendSelected,
    required this.currentFriendIndex,
    required this.friends,
  }) : super(key: key);

  @override
  _FriendCarouselState createState() => _FriendCarouselState();
}

class _FriendCarouselState extends State<FriendCarousel> {
  late PageController _friendsPageController;
  double _dragStart = 0;

  @override
  void initState() {
    super.initState();
    _friendsPageController = PageController(
      viewportFraction: 0.3,
      initialPage: widget.currentFriendIndex,
    );
  }

  Future<void> _handleVerticalDrag(DragUpdateDetails details) async {
    if (_dragStart == 0) {
      _dragStart = details.globalPosition.dy;
    }

    if (_dragStart - details.globalPosition.dy > 100) {
      _dragStart = 0;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to continue')),
        );
        return;
      }

      final currentUserId = currentUser.uid;
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        isDismissible: true,
        enableDrag: true,
        transitionAnimationController: AnimationController(
          vsync: Navigator.of(context),
          duration: const Duration(milliseconds: 400),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Animate(
            effects: [
              SlideEffect(
                begin: const Offset(0, 1),
                end: const Offset(0, 0),
                duration: 400.ms,
                curve: Curves.easeOutExpo,
              ),
              FadeEffect(
                begin: 0.0,
                end: 1.0,
                duration: 300.ms,
                curve: Curves.easeOut,
              ),
              ScaleEffect(
                begin: const Offset(0.95, 0.95),
                end: const Offset(1, 1),
                duration: 400.ms,
                curve: Curves.easeOutExpo,
              ),
            ],
            child: RecordingScreen(
              friendPhotoUrl:
                  widget.friends[widget.currentFriendIndex]['photoURL'] ?? '',
              friendName:
                  widget.friends[widget.currentFriendIndex]['name'] ?? '',
              friendId: widget.friends[widget.currentFriendIndex]['uid'] ?? '',
              currentUserId: currentUserId,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 100,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDrag,
        onVerticalDragEnd: (_) => _dragStart = 0,
        child: SizedBox(
          height: 100,
          child: PageView.builder(
            controller: _friendsPageController,
            onPageChanged: widget.onFriendSelected,
            itemCount: widget.friends.length,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _friendsPageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_friendsPageController.position.haveDimensions) {
                    value = _friendsPageController.page! - index;
                    value = (1 - (value.abs() * 0.3)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: Curves.easeOut.transform(value) * 100,
                      width: Curves.easeOut.transform(value) * 100,
                      child: child,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index == widget.currentFriendIndex
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: Image.network(
                      widget.friends[index]['photoURL'] ?? '',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Image.asset(
                          'assets/background.png',
                          fit: BoxFit.cover,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
