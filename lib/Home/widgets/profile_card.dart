import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/Home/providers/pfp_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/agora_service.dart';
import '../fcm_service/fcm_service.dart';

class ProfileCard extends StatefulWidget {
  final String profileUrl;
  final String name;
  final bool isLoading;
  final String friendId;
  final Function(double) onDragUpdate;
  final List<Map<String, dynamic>> friends;
  final int currentFriendIndex;
  final Function(int) onFriendSelected;
  final String channelName;

  const ProfileCard({
    Key? key,
    required this.profileUrl,
    required this.name,
    required this.friendId,
    required this.onDragUpdate,
    required this.friends,
    required this.currentFriendIndex,
    required this.onFriendSelected,
    required this.channelName,
    this.isLoading = false,
  }) : super(key: key);

  @override
  State<ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<ProfileCard> {
  late PageController _friendsPageController;
  double _dragStart = 0;
  final AgoraService _agoraService = AgoraService();
  bool _isJoining = false;
  bool _isInCall = false;
  bool _isMuted = false;
  bool _isSpeakerOn = true;

  @override
  void initState() {
    super.initState();
    _friendsPageController = PageController(
      viewportFraction: 0.3,
      initialPage: widget.currentFriendIndex,
    );
  }

  @override
  void dispose() {
    _friendsPageController.dispose();
    super.dispose();
  }

  void _handleVerticalDrag(DragUpdateDetails details) {
    if (_dragStart == 0) {
      _dragStart = details.globalPosition.dy;
    }
    widget.onDragUpdate(_dragStart - details.globalPosition.dy);
  }

  // Generate random 6-digit UID
  int _generateUID() {
    final random = Random();
    return 100000 + random.nextInt(900000);
  }

  Future<void> _joinChannel() async {
    if (_isJoining) return;

    setState(() => _isJoining = true);
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        debugPrint('No user logged in');
        return;
      }

      // Use existing channel name instead of creating new one
      final channelName = widget.channelName;
      final userUid = _generateUID();

      debugPrint('Joining channel: $channelName with UID: $userUid');

      // Initialize Agora if not already initialized
      await _agoraService.initializeAgora();

      // Join the channel
      await _agoraService.joinChannel(channelName, userUid);

      // Send FCM notification to friend
      await FCMService.sendCallNotificationToUser(
        receiverUid: widget.friendId,
        callerName: currentUser.displayName ?? 'Someone',
        callerId: currentUser.uid,
        channelName: channelName,
      );

      setState(() {
        _isInCall = true;
        _isJoining = false;
      });
      debugPrint('Successfully joined channel and sent notification');
    } catch (e) {
      debugPrint('Error joining channel: $e');
      setState(() => _isInCall = false);
    } finally {
      if (mounted) {
        setState(() => _isJoining = false);
      }
    }
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _agoraService.toggleMute();
    debugPrint('Mute toggled: $_isMuted');
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeakerOn = !_isSpeakerOn);
    await _agoraService.setSpeakerphoneOn(_isSpeakerOn);
    debugPrint('Speaker toggled: $_isSpeakerOn');
  }

  Future<void> _leaveChannel() async {
    try {
      await _agoraService.leaveChannel();
      setState(() => _isInCall = false);
      debugPrint('Left channel successfully');
    } catch (e) {
      debugPrint('Error leaving channel: $e');
    }
  }

  Widget _buildCallControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mute Button
          IconButton(
            onPressed: _toggleMute,
            icon: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Speaker Button
          IconButton(
            onPressed: _toggleSpeaker,
            icon: Icon(
              _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),

          // Leave Button
          IconButton(
            onPressed: _leaveChannel,
            icon: const Icon(
              Icons.call_end,
              color: Colors.red,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }

    final pfpProvider = Provider.of<PfpProvider>(context);
    final isMinimized = pfpProvider.isMinimized;
    final screenSize = MediaQuery.of(context).size;

    return GestureDetector(
      onVerticalDragUpdate: _handleVerticalDrag,
      onVerticalDragEnd: (_) => _dragStart = 0,
      child: Stack(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: isMinimized ? screenSize.width * 0.6 : screenSize.width,
            height: isMinimized ? screenSize.height * 0.6 : screenSize.height,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background Image
                Image(
                  image: widget.profileUrl.isNotEmpty
                      ? NetworkImage(widget.profileUrl)
                      : const AssetImage('assets/background.png')
                          as ImageProvider,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset('assets/background.png',
                        fit: BoxFit.cover);
                  },
                ),

                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),

                // Profile Name
                if (!isMinimized)
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Column(
                      children: [
                        Text(
                          widget.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            shadows: [
                              Shadow(
                                blurRadius: 3,
                                color: Colors.black.withOpacity(0.5),
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        if (widget.channelName.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              widget.channelName,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                shadows: [
                                  Shadow(
                                    blurRadius: 2,
                                    color: Colors.black.withOpacity(0.5),
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Add Join Channel Button
                if (!isMinimized)
                  Positioned(
                    bottom: 200,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _isInCall
                          ? _buildCallControls()
                          : ElevatedButton(
                              onPressed: _isJoining ? null : _joinChannel,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: _isJoining
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.black),
                                      ),
                                    )
                                  : const Text(
                                      'Join Call',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                    ),
                  ),
              ],
            ),
          ),

          // Friend Carousel
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
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
        ],
      ),
    );
  }
}
