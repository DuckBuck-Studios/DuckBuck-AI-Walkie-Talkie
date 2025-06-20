import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:io' show Platform;
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/ai_agent_provider.dart';
import '../models/ai_agent_models.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> {
  final AuthServiceInterface _authService = serviceLocator<AuthServiceInterface>();
  
  @override
  void initState() {
    super.initState();
    _initializeProvider();
  }

  void _initializeProvider() {
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AiAgentProvider>().initialize(currentUser.uid);
      });
    }
  }

  Future<void> _handleJoinAgent() async {
    final provider = context.read<AiAgentProvider>();
    await provider.startAgent();
  }

  Future<void> _handleStopAgent() async {
    final provider = context.read<AiAgentProvider>();
    await provider.stopAgent();
  }



  @override
  Widget build(BuildContext context) {
    return Consumer<AiAgentProvider>(
      builder: (context, provider, child) {
        // Block navigation when AI agent is active
        return PopScope(
          canPop: !provider.isAgentRunning,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && provider.isAgentRunning) {
              // Show dialog when user tries to go back during active call
              _showCallActiveDialog(context);
            }
          },
          child: Platform.isIOS 
              ? _buildCupertinoScreen(context, provider)
              : _buildMaterialScreen(context, provider),
        );
      },
    );
  }

  /// Show dialog when user tries to navigate back during active call
  void _showCallActiveDialog(BuildContext context) {
    if (Platform.isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('AI Call Active'),
          content: const Text('Please end the AI call before going back.'),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('End Call'),
              onPressed: () {
                Navigator.of(context).pop();
                _handleStopAgent();
              },
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('AI Call Active'),
          content: const Text('Please end the AI call before going back.'),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('End Call'),
              onPressed: () {
                Navigator.of(context).pop();
                _handleStopAgent();
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildCupertinoScreen(BuildContext context, AiAgentProvider provider) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.systemGroupedBackground,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: _buildContent(context, provider, true),
      ),
    );
  }

  Widget _buildMaterialScreen(BuildContext context, AiAgentProvider provider) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _buildContent(context, provider, false),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AiAgentProvider provider, bool isIOS) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Logo with wave animations when AI agent is running
          Stack(
            alignment: Alignment.center,
            children: [
              // Wave rings when AI agent is running, starting, or has an active session
              if (provider.isAgentRunning || provider.state == AiAgentState.starting || (provider.state == AiAgentState.error && provider.currentSession != null)) ...[
                // Outer wave - slower and larger
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isIOS ? CupertinoColors.systemGreen : Colors.green).withValues(alpha: 0.2),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(begin: 0.7, end: 1.3, duration: 2000.ms)
                  .fadeOut(duration: 2000.ms)
                  .animate() // Initial entrance animation
                  .scaleXY(begin: 0.0, end: 0.7, duration: 800.ms, curve: Curves.elasticOut),
                
                // Middle wave - medium speed
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isIOS ? CupertinoColors.systemGreen : Colors.green).withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(begin: 0.8, end: 1.2, duration: 1600.ms)
                  .fadeOut(duration: 1600.ms)
                  .animate(delay: 200.ms) // Staggered entrance
                  .scaleXY(begin: 0.0, end: 0.8, duration: 700.ms, curve: Curves.elasticOut),
                
                // Inner wave - faster
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isIOS ? CupertinoColors.systemGreen : Colors.green).withValues(alpha: 0.6),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(begin: 0.85, end: 1.15, duration: 1200.ms)
                  .fadeOut(duration: 1200.ms)
                  .animate(delay: 400.ms) // More staggered entrance
                  .scaleXY(begin: 0.0, end: 0.85, duration: 600.ms, curve: Curves.elasticOut),
                
                // Additional inner pulse when AI is speaking
                if (provider.isAiSpeaking) 
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: (isIOS ? CupertinoColors.systemOrange : Colors.orange).withValues(alpha: 0.8),
                        width: 3,
                      ),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                    .scaleXY(begin: 0.9, end: 1.1, duration: 800.ms)
                    .fadeOut(duration: 800.ms),
              ],
              
              // Main logo container with simple, clean animations
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error) ? (isIOS ? [
                      CupertinoColors.systemGreen,
                      CupertinoColors.systemBlue,
                      CupertinoColors.systemTeal,
                    ] : [
                      Colors.green,
                      Colors.blue,
                      Colors.teal,
                    ]) : (isIOS ? [
                      CupertinoColors.systemGrey,
                      CupertinoColors.systemGrey2,
                    ] : [
                      theme.colorScheme.outline,
                      theme.colorScheme.outlineVariant,
                    ]),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error)
                          ? (isIOS 
                              ? CupertinoColors.systemGreen.withAlpha(provider.isAiSpeaking ? 153 : 102)
                              : Colors.green.withAlpha(provider.isAiSpeaking ? 153 : 102))
                          : Colors.grey.withAlpha(51),
                      blurRadius: (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error)
                          ? (provider.isAiSpeaking ? 40 : 30) 
                          : 15,
                      spreadRadius: (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error)
                          ? (provider.isAiSpeaking ? 15 : 10) 
                          : 5,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icon-ico.png',
                    width: 200,
                    height: 200,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        isIOS ? CupertinoIcons.sparkles : Icons.auto_awesome,
                        size: 100,
                        color: Colors.white,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          
          // Time display - shows elapsed time when running, remaining time when idle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isIOS 
                  ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              provider.isAgentRunning 
                  ? 'Elapsed: ${provider.formattedElapsedTime}'
                  : 'Time: ${provider.formattedRemainingTime}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: provider.isAgentRunning
                    ? (isIOS ? CupertinoColors.systemBlue : theme.colorScheme.primary)
                    : provider.remainingTimeSeconds > 0
                        ? (isIOS ? CupertinoColors.systemGreen : theme.colorScheme.primary)
                        : (isIOS ? CupertinoColors.systemRed : theme.colorScheme.error),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Call Controls when there's an active session (starting, running, or error), Join button when idle
          (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error)
              ? _buildCallControls(context, provider)
                  .animate()
                  .slideY(begin: 1.0, end: 0.0, duration: 800.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 600.ms)
              : _buildActionButton(context, provider, isIOS),
        ],
      ),
    );
  }

  Widget _buildCallControls(BuildContext context, AiAgentProvider provider) {
    final isStarting = provider.state == AiAgentState.starting;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: isStarting
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Connecting...',
                  style: TextStyle(
                    color: Colors.green,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Mute Button
                _buildCallControlButton(
                  context,
                  icon: provider.isMicrophoneMuted 
                      ? (Platform.isIOS ? CupertinoIcons.mic_slash_fill : Icons.mic_off)
                      : (Platform.isIOS ? CupertinoIcons.mic_fill : Icons.mic),
                  onPressed: () async {
                    final success = await provider.toggleMicrophone();
                    if (!success && context.mounted) {
                      _showErrorSnackBar(context, 'Failed to toggle microphone');
                    }
                  },
                  backgroundColor: provider.isMicrophoneMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
                  iconColor: Colors.white,
                ),
                
                // End Call Button
                _buildCallControlButton(
                  context,
                  icon: Platform.isIOS ? CupertinoIcons.phone_down_fill : Icons.call_end,
                  onPressed: () async {
                    await provider.stopAgent();
                  },
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                ),
                
                // Speaker Button
                _buildCallControlButton(
                  context,
                  icon: provider.isSpeakerEnabled
                      ? (Platform.isIOS ? CupertinoIcons.speaker_3_fill : Icons.volume_up)
                      : (Platform.isIOS ? CupertinoIcons.speaker_1_fill : Icons.volume_down),
                  onPressed: () async {
                    final success = await provider.toggleSpeaker();
                    if (!success && context.mounted) {
                      _showErrorSnackBar(context, 'Failed to toggle speaker');
                    }
                  },
                  backgroundColor: provider.isSpeakerEnabled ? Colors.green : Colors.white.withValues(alpha: 0.2),
                  iconColor: Colors.white,
                ),
              ],
            ),
    );
  }

  Widget _buildCallControlButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AiAgentProvider provider, bool isIOS) {
    final theme = Theme.of(context);
    final isLoading = provider.state == AiAgentState.starting || provider.state == AiAgentState.stopping;
    final canJoin = provider.canStartAgent && !isLoading;
    final isRunning = provider.isAgentRunning;
    
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        child: CupertinoButton.filled(
          onPressed: isLoading ? null : (isRunning ? _handleStopAgent : (canJoin ? _handleJoinAgent : null)),
          borderRadius: BorderRadius.circular(16),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CupertinoActivityIndicator(color: CupertinoColors.white),
                    const SizedBox(width: 12),
                    Text(
                      isRunning ? 'Stopping...' : 'Starting...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isRunning 
                          ? CupertinoIcons.stop_fill 
                          : CupertinoIcons.play_fill,
                      color: CupertinoColors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning ? 'Stop AI Agent' : 'Join AI Agent',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ).animate(target: canJoin || isRunning ? 1 : 0)
        .fadeIn(duration: 300.ms)
        .scaleXY(begin: 0.95, end: 1.0, duration: 300.ms);
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isLoading ? null : (isRunning ? _handleStopAgent : (canJoin ? _handleJoinAgent : null)),
          style: ElevatedButton.styleFrom(
            backgroundColor: isRunning 
                ? theme.colorScheme.error 
                : theme.colorScheme.primary,
            foregroundColor: isRunning 
                ? theme.colorScheme.onError 
                : theme.colorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: canJoin || isRunning ? 6 : 2,
          ),
          child: isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isRunning ? 'Stopping...' : 'Starting...',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isRunning 
                          ? Icons.stop 
                          : Icons.play_arrow,
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isRunning ? 'Stop AI Agent' : 'Join AI Agent',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
        ),
      ).animate(target: canJoin || isRunning ? 1 : 0)
        .fadeIn(duration: 300.ms)
        .scaleXY(begin: 0.95, end: 1.0, duration: 300.ms);
    }
  }

  /// Show error snack bar
  void _showErrorSnackBar(BuildContext context, String message) {
    if (Platform.isIOS) {
      // For iOS, show a simple dialog
      showCupertinoDialog(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('Error'),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
    } else {
      // For Android, show snack bar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
