import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
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
          
          // Logo moved to top
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
                  blurRadius: 30,
                  spreadRadius: 8,
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
          ),
          
          const SizedBox(height: 48),
          
          // Time display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isIOS 
                  ? CupertinoColors.secondarySystemGroupedBackground.resolveFrom(context)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Time: ${provider.formattedRemainingTime}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: provider.remainingTimeSeconds > 0
                    ? (isIOS ? CupertinoColors.systemGreen : theme.colorScheme.primary)
                    : (isIOS ? CupertinoColors.systemRed : theme.colorScheme.error),
              ),
            ),
          ),
          
          const Spacer(),
          
          // Bottom Button
          _buildActionButton(context, provider, isIOS),
        ],
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
