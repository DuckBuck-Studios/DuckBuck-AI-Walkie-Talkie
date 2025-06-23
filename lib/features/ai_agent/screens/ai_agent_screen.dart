import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:io' show Platform;
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../../../core/theme/app_colors.dart';
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
      navigationBar: CupertinoNavigationBar(
        backgroundColor: AppColors.backgroundBlack,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: AppColors.backgroundBlack,
      child: SafeArea(
        child: _buildContent(context, provider, true),
      ),
    );
  }

  Widget _buildMaterialScreen(BuildContext context, AiAgentProvider provider) {
    return Scaffold(
      backgroundColor: AppColors.backgroundBlack,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundBlack,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _buildContent(context, provider, false),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AiAgentProvider provider, bool isIOS) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          
          // Logo with clean visual indicators for AI agent state
          Stack(
            alignment: Alignment.center,
            children: [
              // Static wave rings when AI agent is running
              if (provider.isAgentRunning || provider.state == AiAgentState.starting || (provider.state == AiAgentState.error && provider.currentSession != null)) ...[
                // Outer ring
                Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentBlue,
                      width: 1,
                    ),
                  ),
                ),
                
                // Middle ring
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentBlue,
                      width: 1,
                    ),
                  ),
                ),
                
                // Inner ring
                Container(
                  width: 230,
                  height: 230,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.accentBlue,
                      width: 1,
                    ),
                  ),
                ),
                
                // Speaking indicator ring when AI is speaking
                if (provider.isAiSpeaking) 
                  Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.successGreen,
                        width: 2,
                      ),
                    ),
                  ),
              ],
              
              // Main logo container with clean design
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error) 
                      ? AppColors.accentBlue 
                      : AppColors.backgroundBlack,
                  border: Border.all(
                    color: AppColors.borderColor,
                    width: 2,
                  ),
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
                        color: AppColors.textPrimary,
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
              color: AppColors.backgroundBlack,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.borderColor,
                width: 1,
              ),
            ),
            child: Text(
              provider.isAgentRunning 
                  ? 'Elapsed: ${provider.formattedElapsedTime}'
                  : 'Time: ${provider.formattedRemainingTime}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: provider.isAgentRunning
                    ? AppColors.accentBlue
                    : provider.remainingTimeSeconds > 0
                        ? AppColors.successGreen
                        : AppColors.errorRed,
              ),
            ),
          ),
          
          const Spacer(),
          
          // Call Controls when there's an active session (starting, running, or error), Join button when idle
          (provider.isAgentRunning || provider.state == AiAgentState.starting || provider.state == AiAgentState.error)
              ? _buildCallControls(context, provider)
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
        color: AppColors.backgroundBlack,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.borderColor,
          width: 1,
        ),
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
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Connecting...',
                  style: TextStyle(
                    color: AppColors.accentBlue,
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
                  backgroundColor: provider.isMicrophoneMuted ? AppColors.errorRed : AppColors.backgroundBlack,
                  borderColor: provider.isMicrophoneMuted ? AppColors.errorRed : AppColors.borderColor,
                  iconColor: provider.isMicrophoneMuted ? AppColors.textPrimary : AppColors.accentBlue,
                ),
                
                // End Call Button
                _buildCallControlButton(
                  context,
                  icon: Platform.isIOS ? CupertinoIcons.phone_down_fill : Icons.call_end,
                  onPressed: () async {
                    await provider.stopAgent();
                  },
                  backgroundColor: AppColors.errorRed,
                  borderColor: AppColors.errorRed,
                  iconColor: AppColors.textPrimary,
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
                  backgroundColor: provider.isSpeakerEnabled ? AppColors.successGreen : AppColors.backgroundBlack,
                  borderColor: provider.isSpeakerEnabled ? AppColors.successGreen : AppColors.borderColor,
                  iconColor: provider.isSpeakerEnabled ? AppColors.backgroundBlack : AppColors.accentBlue,
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
    required Color borderColor,
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
          border: Border.all(
            color: borderColor,
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: 28,
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, AiAgentProvider provider, bool isIOS) {
    final isLoading = provider.state == AiAgentState.starting || provider.state == AiAgentState.stopping;
    final canJoin = provider.canStartAgent && !isLoading;
    final isRunning = provider.isAgentRunning;
    
    Color backgroundColor;
    Color borderColor;
    Color textColor;
    
    if (isRunning) {
      backgroundColor = AppColors.errorRed;
      borderColor = AppColors.errorRed;
      textColor = AppColors.textPrimary;
    } else if (canJoin) {
      backgroundColor = AppColors.accentBlue;
      borderColor = AppColors.accentBlue;
      textColor = AppColors.backgroundBlack;
    } else {
      backgroundColor = AppColors.backgroundBlack;
      borderColor = AppColors.borderColor;
      textColor = AppColors.textSecondary;
    }
    
    if (isIOS) {
      return SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: CupertinoButton(
            onPressed: isLoading ? null : (isRunning ? _handleStopAgent : (canJoin ? _handleJoinAgent : null)),
            borderRadius: BorderRadius.circular(16),
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoActivityIndicator(color: textColor),
                      const SizedBox(width: 12),
                      Text(
                        isRunning ? 'Stopping...' : 'Starting...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
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
                        color: textColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRunning ? 'Stop AI Agent' : 'Join AI Agent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: 2,
            ),
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : (isRunning ? _handleStopAgent : (canJoin ? _handleJoinAgent : null)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: textColor,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
            ),
            child: isLoading
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(textColor),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        isRunning ? 'Stopping...' : 'Starting...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textColor,
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
                        color: textColor,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isRunning ? 'Stop AI Agent' : 'Join AI Agent',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      );
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
          content: Text(
            message,
            style: TextStyle(color: AppColors.textPrimary),
          ),
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
