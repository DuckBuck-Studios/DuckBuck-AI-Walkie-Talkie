import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
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
        return Platform.isIOS 
            ? _buildCupertinoScreen(context, provider)
            : _buildMaterialScreen(context, provider);
      },
    );
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
          
          // Logo with wave animations when AI speaks
          Stack(
            alignment: Alignment.center,
            children: [
              // Wave rings when AI is speaking
              if (provider.isAiSpeaking) ...[
                // Outer wave
                Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isIOS ? CupertinoColors.systemBlue : theme.colorScheme.primary).withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(begin: 0.8, end: 1.2, duration: 1500.ms)
                  .fadeOut(duration: 1500.ms),
                
                // Middle wave
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isIOS ? CupertinoColors.systemBlue : theme.colorScheme.primary).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(begin: 0.9, end: 1.1, duration: 1200.ms)
                  .fadeOut(duration: 1200.ms),
                
                // Inner wave
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isIOS ? CupertinoColors.systemBlue : theme.colorScheme.primary).withValues(alpha: 0.7),
                      width: 2,
                    ),
                  ),
                ).animate(onPlay: (controller) => controller.repeat())
                  .scaleXY(begin: 0.95, end: 1.05, duration: 1000.ms)
                  .fadeOut(duration: 1000.ms),
              ],
              
              // Main logo container with subtle pulse when speaking
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isIOS ? [
                      CupertinoColors.systemBlue,
                      CupertinoColors.systemPurple,
                      CupertinoColors.systemIndigo,
                    ] : [
                      theme.colorScheme.primary,
                      theme.colorScheme.secondary,
                      theme.colorScheme.tertiary,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isIOS 
                          ? CupertinoColors.systemBlue.withAlpha(102)
                          : theme.colorScheme.primary.withAlpha(102),
                      blurRadius: provider.isAiSpeaking ? 35 : 30,
                      spreadRadius: provider.isAiSpeaking ? 12 : 8,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
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
              ).animate(target: provider.isAiSpeaking ? 1 : 0)
                .scaleXY(begin: 1.0, end: 1.02, duration: 600.ms)
                .then()
                .scaleXY(begin: 1.02, end: 1.0, duration: 600.ms),
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
          
          // Call Controls when running, Join button when idle
          provider.isAgentRunning 
              ? _buildCallControls(context, provider)
              : _buildActionButton(context, provider, isIOS),
        ],
      ),
    );
  }

  Widget _buildCallControls(BuildContext context, AiAgentProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Button
          _buildCallControlButton(
            context,
            icon: provider.isMicrophoneMuted 
                ? (Platform.isIOS ? CupertinoIcons.mic_slash_fill : Icons.mic_off)
                : (Platform.isIOS ? CupertinoIcons.mic_fill : Icons.mic),
            onPressed: () async {
              await provider.toggleMicrophone();
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
              await provider.toggleSpeaker();
            },
            backgroundColor: provider.isSpeakerEnabled ? Colors.blue : Colors.white.withValues(alpha: 0.2),
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
      onTap: onPressed,
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
          child: isLoading
              ? const CupertinoActivityIndicator(color: CupertinoColors.white)
              : Text(
                  isRunning ? 'Stop' : 'Join',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
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
            elevation: 4,
          ),
          child: isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  isRunning ? 'Stop' : 'Join',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }
  }
}
