import 'dart:async';
import 'package:duckbuck/Home/providers/voice_note_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class RecordingScreen extends StatefulWidget {
  final String friendPhotoUrl;
  final String friendName;
  final String friendId;
  final String currentUserId;

  const RecordingScreen({
    Key? key,
    required this.friendPhotoUrl,
    required this.friendName,
    required this.friendId,
    required this.currentUserId,
  }) : super(key: key);

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isLocked = false;
  String? _recordingPath;
  late AnimationController _animationController;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  double _dragOffset = 0;
  bool _isDragging = false;
  late RecorderController recorderController;
  late PlayerController playerController;
  String? _currentPlayingPath;

  final Map<String, bool> _sendingStatus = {};
  final Map<String, bool> _sentStatus = {};

  // Add a map to store controllers for each message
  final Map<String, PlayerController> _playerControllers = {};

  @override
  void initState() {
    super.initState();
    _initControllers();
    _initAnimationController();
    _listenToVoiceMessages();
    _setupPlayerListener();
  }

  void _initControllers() {
    recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..iosEncoder = IosEncoder.kAudioFormatMPEG4AAC
      ..sampleRate = 44100;

    playerController = PlayerController();
  }

  void _initAnimationController() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  void _listenToVoiceMessages() {
    context.read<VoiceMessageProvider>().listenToVoiceMessages(
          widget.currentUserId,
          widget.friendId,
        );
  }

  void _setupPlayerListener() {
    playerController.onPlayerStateChanged.listen((state) {
      setState(() {
        if (state == PlayerState.stopped) {
          _currentPlayingPath = null;
        }
      });
    });
  }

  @override
  void dispose() {
    recorderController.dispose();
    // Dispose all player controllers
    for (var controller in _playerControllers.values) {
      controller.dispose();
    }
    _playerControllers.clear();
    _animationController.dispose();
    _recorder.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // Get or create controller for a message
  PlayerController _getPlayerController(String messageId) {
    if (!_playerControllers.containsKey(messageId)) {
      _playerControllers[messageId] = PlayerController();
    }
    return _playerControllers[messageId]!;
  }

  Future<void> _startRecording() async {
    try {
      if (await _recorder.hasPermission()) {
        HapticFeedback.mediumImpact();

        final directory = await getTemporaryDirectory();
        _recordingPath =
            '${directory.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';

        await recorderController.record(path: _recordingPath);

        setState(() {
          _isRecording = true;
          _isDragging = false;
          _dragOffset = 0;
          _isLocked = true;
        });

        _startTimer();
        _animationController.forward();
      }
    } catch (e) {
      _showErrorSnackBar('Failed to start recording');
    }
  }

  Future<void> _stopRecording({bool cancelled = false}) async {
    try {
      final path = await recorderController.stop();
      _stopTimer();

      setState(() {
        _isRecording = false;
        _isLocked = false;
      });

      if (!cancelled && path != null) {
        _recordingPath = path;
        await _uploadVoiceMessage();
      }

      _animationController.reverse();
    } catch (e) {
      _showErrorSnackBar('Failed to stop recording');
    }
  }

  Future<void> _uploadVoiceMessage() async {
    try {
      final file = File(_recordingPath!);
      final provider = context.read<VoiceMessageProvider>();

      // Create temporary message widget first
      final tempId = DateTime.now().millisecondsSinceEpoch.toString();
      setState(() => _sendingStatus[tempId] = true);

      // Add temporary message to UI
      final tempMessage = {
        'id': tempId,
        'senderUid': widget.currentUserId,
        'receiverUid': widget.friendId,
        'audioUrl': _recordingPath,
        'timestamp': DateTime.now(),
        'isOpened': false,
        'durationMs': _recordingDuration.inMilliseconds,
        'status': 'sending',
      };

      provider.addTemporaryMessage(tempMessage);

      // Upload the actual message
      final success = await provider.voiceMessageService.uploadVoiceMessage(
        file,
        widget.currentUserId,
        widget.friendId,
      );

      if (success != null) {
        setState(() {
          _sendingStatus[tempId] = false;
          _sentStatus[tempId] = true;
        });
      }
    } catch (e) {
      debugPrint('Error uploading voice message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Top Section - Profile (Fixed)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Profile Info
                  Container(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          backgroundImage: NetworkImage(widget.friendPhotoUrl),
                          radius: 30,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.friendName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Middle Section - Messages (Scrollable)
            Expanded(
              child: Container(
                color: const Color(0xFF1A1A1A),
                child: Stack(
                  children: [
                    // Messages List
                    Consumer<VoiceMessageProvider>(
                      builder: (context, provider, child) {
                        final messages = provider.messages;
                        return ListView.builder(
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          padding: EdgeInsets.only(
                            top: 16,
                            bottom:
                                100, // Add padding to prevent messages from going under mic button
                            left: 16,
                            right: 16,
                          ),
                          itemCount: messages.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                            final message = messages[index];
                            final isSender =
                                message['senderUid'] == widget.currentUserId;
                            return _buildVoiceMessageItem(message, isSender);
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Section - Recording Controls (Fixed)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_isLocked) ...[
                        _buildCancelButton(),
                        const SizedBox(width: 12),
                      ],
                      _buildRecordButton(),
                      if (_isLocked) ...[
                        const SizedBox(width: 12),
                        Expanded(child: _buildSendButton()),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessageItem(Map<String, dynamic> message, bool isSender) {
    final messageId = message['id'];
    final controller = _getPlayerController(messageId);

    return Animate(
      effects: [
        SlideEffect(
          curve: Curves.easeOutQuart,
          duration: 400.ms,
          begin: Offset(isSender ? 1 : -1, 0),
          end: Offset.zero,
        ),
        FadeEffect(
          curve: Curves.easeOut,
          duration: 300.ms,
        ),
      ],
      child: Slidable(
        key: ValueKey(messageId),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.4,
          dismissible: DismissiblePane(
            onDismissed: () async {
              // Stop playback before showing delete dialog
              if (controller.playerState == PlayerState.playing) {
                await controller.pausePlayer();
              }
              // Show delete confirmation dialog
              final shouldDelete = await _showDeleteOptions(message);
              if (!shouldDelete && mounted) {
                // If user cancels, reset the slidable
                Slidable.of(context)?.close();
              }
            },
            closeOnCancel: true,
            confirmDismiss: () async {
              return false; // Prevent automatic dismiss
            },
            motion: const InversedDrawerMotion(),
          ),
          children: [
            CustomSlidableAction(
              onPressed: (_) => _showDeleteOptions(message),
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              child: Animate(
                effects: const [
                  ScaleEffect(
                    begin: Offset(0.8, 0.8),
                    end: Offset(1, 1),
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                  ),
                  ShakeEffect(
                    duration: Duration(milliseconds: 600),
                    curve: Curves.easeInOut,
                  ),
                ],
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.delete_outline,
                        size: 32,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: isSender ? 64 : 16,
            right: isSender ? 16 : 64,
            top: 4,
            bottom: 4,
          ),
          child: Align(
            alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSender
                    ? const Color(0xFF8B5CF6)
                    : const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isSender ? 20 : 4),
                  bottomRight: Radius.circular(isSender ? 4 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: (isSender ? const Color(0xFF8B5CF6) : Colors.black)
                        .withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildPlayButton(controller, message),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AudioFileWaveforms(
                          size:
                              Size(MediaQuery.of(context).size.width * 0.4, 40),
                          playerController: controller,
                          enableSeekGesture: true,
                          waveformType: WaveformType.long,
                          playerWaveStyle: PlayerWaveStyle(
                            fixedWaveColor: Colors.white24,
                            liveWaveColor: Colors.white,
                            spacing: 4,
                            waveCap: StrokeCap.round,
                            waveThickness: 2,
                            showBottom: false,
                            showTop: true,
                            seekLineColor: Colors.white,
                            seekLineThickness: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatDuration(Duration(
                              milliseconds: message['durationMs'] ?? 0)),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTimestamp(message['timestamp']),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 11,
                          ),
                        ),
                        if (isSender) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message['isOpened'] ? Icons.done_all : Icons.done,
                            color: Colors.white.withOpacity(0.5),
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayButton(
      PlayerController controller, Map<String, dynamic> message) {
    return StreamBuilder<PlayerState>(
      stream: controller.onPlayerStateChanged,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data == PlayerState.playing;

        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(18),
          ),
          child: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                key: ValueKey(isPlaying),
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: () => _handlePlayback(message),
            padding: EdgeInsets.zero,
          ),
        );
      },
    );
  }

  Widget _buildCancelButton() {
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.mediumImpact();
          setState(() {
            _isLocked = false;
            _isRecording = false;
          });
          _stopTimer();
          _recordingPath = null;
          recorderController.stop();
          _animationController.reverse();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.withOpacity(0.1),
          foregroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Colors.red, width: 2),
          ),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.close, size: 20),
            SizedBox(width: 8),
            Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onLongPressStart: (_) => _startRecording(),
      onLongPressEnd: (_) {
        if (!_isLocked) _stopRecording();
      },
      onVerticalDragUpdate: (details) {
        if (_isRecording && !_isLocked) {
          setState(() {
            _dragOffset += details.delta.dy;
            _isDragging = _dragOffset < -50;
          });
        }
      },
      child: Container(
        height: 60,
        width: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _isRecording
                ? [const Color(0xFF8B5CF6), const Color(0xFF7C3AED)]
                : [const Color(0xFF2A2A2A), const Color(0xFF1E1E1E)],
          ),
          boxShadow: [
            BoxShadow(
              color: _isRecording
                  ? const Color(0xFF8B5CF6).withOpacity(0.3)
                  : Colors.black.withOpacity(0.2),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: _isRecording
              ? const Icon(
                  Icons.mic,
                  color: Colors.white,
                  size: 28,
                )
              : const Icon(
                  Icons.mic_none_rounded,
                  color: Colors.white,
                  size: 28,
                ),
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return ElevatedButton(
      onPressed: () => _stopRecording(),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B5CF6),
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.send, size: 20),
          SizedBox(width: 8),
          Text(
            'Send',
            style: TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _recordingDuration = Duration(seconds: timer.tick);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    setState(() {
      _recordingDuration = Duration.zero;
    });
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _showDeleteOptions(Map<String, dynamic> message) async {
    // First dispose the player controller for this message
    final messageId = message['id'];
    if (_playerControllers.containsKey(messageId)) {
      _playerControllers[messageId]!.dispose();
      _playerControllers.remove(messageId);
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutBack,
        tween: Tween(begin: 0.0, end: 1.0),
        builder: (context, value, child) => Transform.scale(
          scale: value,
          child: child,
        ),
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: const Color(0xFF1E1E1E),
          elevation: 20,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🗑️',
                  style: TextStyle(fontSize: 48),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Message',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'This message will be permanently deleted for everyone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDeleteDialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(context),
                      isOutlined: true,
                    ),
                    _buildDeleteDialogButton(
                      label: 'Delete',
                      onTap: () async {
                        HapticFeedback.heavyImpact();
                        Navigator.pop(context);
                        final provider = context.read<VoiceMessageProvider>();
                        await provider.voiceMessageService
                            .deleteMessageForEveryone(
                          _generateChatId(
                              widget.currentUserId, widget.friendId),
                          message['id'],
                          message['audioUrl'],
                        );
                      },
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (shouldDelete == true) {
      final provider = context.read<VoiceMessageProvider>();
      await provider.voiceMessageService.deleteMessageForEveryone(
        _generateChatId(widget.currentUserId, widget.friendId),
        message['id'],
        message['audioUrl'],
      );

      // Clean up after deletion
      setState(() {
        if (_playerControllers.containsKey(messageId)) {
          _playerControllers[messageId]!.dispose();
          _playerControllers.remove(messageId);
        }
      });

      return true;
    }
    return false;
  }

  Widget _buildDeleteDialogButton({
    required String label,
    required VoidCallback onTap,
    bool isOutlined = false,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isOutlined
                ? Colors.transparent
                : isDestructive
                    ? Colors.red.withOpacity(0.2)
                    : Colors.purple.withOpacity(0.2),
            border: Border.all(
              color: isDestructive ? Colors.red : Colors.purple,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.purple,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _generateChatId(String uid1, String uid2) {
    return uid1.hashCode <= uid2.hashCode ? "${uid1}_$uid2" : "${uid2}_$uid1";
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime dateTime;
    if (timestamp is DateTime) {
      dateTime = timestamp;
    } else if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      return '';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('h:mm a')
          .format(dateTime); // Changed to 12-hour format with AM/PM
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  Future<void> _handlePlayback(Map<String, dynamic> message) async {
    try {
      final controller = _getPlayerController(message['id']);
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/${message['id']}.aac';
      final file = File(filePath);

      if (controller.playerState == PlayerState.playing) {
        await controller.pausePlayer();
        setState(() {});
      } else {
        // Stop all other playing controllers
        for (var ctrl in _playerControllers.values) {
          if (ctrl != controller && ctrl.playerState == PlayerState.playing) {
            await ctrl.stopPlayer();
          }
        }

        if (!await file.exists()) {
          final response = await http.get(Uri.parse(message['audioUrl']));
          await file.writeAsBytes(response.bodyBytes);
        }

        await controller.preparePlayer(
          path: file.path,
          noOfSamples: 100,
        );
        await controller.startPlayer();
        setState(() {});

        // Mark message as opened if needed
        if (!message['isOpened'] &&
            message['senderUid'] != widget.currentUserId) {
          await Future.delayed(const Duration(milliseconds: 100));
          context.read<VoiceMessageProvider>().markMessageAsOpened(
                message['id'],
                widget.currentUserId,
                widget.friendId,
                message['senderUid'],
              );
        }
      }
    } catch (e) {
      debugPrint('Error playing voice message: $e');
      _showErrorSnackBar('Error playing voice message');
    }
  }
}
