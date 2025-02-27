import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';
import '../providers/call_provider.dart';
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

class _ProfileCardState extends State<ProfileCard>
    with SingleTickerProviderStateMixin {
  final AgoraService _agoraService = AgoraService();
  double _dragDistance = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _radiusAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.85,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _radiusAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Generate random 6-digit UID
  int _generateUID() {
    final random = Random();
    return 100000 + random.nextInt(900000);
  }

  Future<void> _initiateCall(BuildContext context) async {
    HapticFeedback.heavyImpact();
    final callProvider = context.read<CallProvider>();

    // Start the animation to full screen
    _animationController.forward();

    await callProvider.initiateCall(
      receiverId: widget.friendId,
      receiverName: widget.name,
      channelName: widget.channelName,
    );
  }

  void _handleHorizontalDrag(DragUpdateDetails details, bool isInCall) {
    if (!isInCall) {
      setState(() {
        _dragDistance += details.primaryDelta ?? 0;
      });
    }
  }

  void _handleHorizontalDragEnd(DragEndDetails details, bool isInCall) {
    if (isInCall) return;

    final velocity = details.primaryVelocity ?? 0;
    if (velocity > 1000 && widget.currentFriendIndex > 0) {
      widget.onFriendSelected(widget.currentFriendIndex - 1);
      HapticFeedback.mediumImpact();
    } else if (velocity < -1000 &&
        widget.currentFriendIndex < widget.friends.length - 1) {
      widget.onFriendSelected(widget.currentFriendIndex + 1);
      HapticFeedback.mediumImpact();
    }
    setState(() => _dragDistance = 0);
  }

  Widget _buildCallControls(CallProvider callProvider) {
    // For receiver, show different UI based on whether they've started speaking
    if (!callProvider.isInitiator) {
      if (!callProvider.hasStartedSpeaking) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Text(
            'Tap and hold to start speaking',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      }

      // After starting to speak, show same controls as caller
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: callProvider.toggleMute,
              icon: Icon(
                callProvider.isMuted ? Icons.mic_off : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: callProvider.toggleSpeaker,
              icon: Icon(
                callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            IconButton(
              onPressed: callProvider.endCall,
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

    // For initiator, show all controls
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: callProvider.toggleMute,
            icon: Icon(
              callProvider.isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: callProvider.toggleSpeaker,
            icon: Icon(
              callProvider.isSpeakerOn ? Icons.volume_up : Icons.volume_off,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: callProvider.endCall,
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

  Widget _buildCallStatus(CallProvider callProvider) {
    String statusText = '';
    switch (callProvider.callState) {
      case CallState.calling:
        statusText = 'Calling...';
        break;
      case CallState.connected:
        statusText = callProvider.callDuration;
        break;
      case CallState.error:
        statusText = callProvider.errorMessage ?? 'Error';
        break;
      default:
        statusText = 'Long press to join call';
    }

    return Text(
      statusText,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
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

    return Consumer<CallProvider>(
      builder: (context, callProvider, child) {
        final screenSize = MediaQuery.of(context).size;
        final isInCall = callProvider.isInCall || callProvider.isCalling;

        // If in a call, keep the animation at the end state
        if (isInCall && !_animationController.isCompleted) {
          _animationController.forward();
        } else if (!isInCall && _animationController.isCompleted) {
          _animationController.reverse();
        }

        return Center(
          child: GestureDetector(
            onLongPress: isInCall ? null : () => _initiateCall(context),
            onLongPressStart: !callProvider.isInitiator &&
                    isInCall &&
                    !callProvider.hasStartedSpeaking
                ? (_) => callProvider.startSpeaking()
                : null,
            onLongPressEnd: null,
            onHorizontalDragUpdate: (details) =>
                _handleHorizontalDrag(details, isInCall),
            onHorizontalDragEnd: (details) =>
                _handleHorizontalDragEnd(details, isInCall),
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.translate(
                  offset:
                      Offset(_dragDistance * (1 - _scaleAnimation.value), 0),
                  child: Container(
                    width: screenSize.width * _scaleAnimation.value,
                    height: screenSize.height * _scaleAnimation.value,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius:
                          BorderRadius.circular(_radiusAnimation.value),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(_radiusAnimation.value),
                          child: Image(
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
                        ),
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
                        if (callProvider.isSpeaking)
                          Container(
                            color: Colors.green.withOpacity(0.3),
                            child: const Center(
                              child: Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: 48,
                              ),
                            ),
                          ),
                        Positioned(
                          bottom: 40,
                          left: 0,
                          right: 0,
                          child: Column(
                            children: [
                              Text(
                                isInCall
                                    ? (callProvider.receiverName ??
                                        callProvider.callerName ??
                                        widget.name)
                                    : widget.name,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              _buildCallStatus(callProvider),
                              if (isInCall)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: _buildCallControls(callProvider),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
