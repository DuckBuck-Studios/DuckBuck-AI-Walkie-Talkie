import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../../../core/models/relationship_model.dart';
import '../../../core/services/auth/auth_service_interface.dart';
import '../../../core/services/service_locator.dart';
import '../providers/home_provider.dart';
import '../../friends/widgets/profile_avatar.dart';

class UserProfileScreen extends StatelessWidget {
  final RelationshipModel relationship;
  final HomeProvider provider;

  const UserProfileScreen({
    super.key,
    required this.relationship,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final authService = serviceLocator<AuthServiceInterface>();
    final currentUserId = authService.currentUser?.uid ?? '';
    final profile = provider.getCachedProfile(relationship, currentUserId);

    return Platform.isIOS ? _buildCupertinoPage(context, profile) : _buildMaterialPage(context, profile);
  }

  Widget _buildCupertinoPage(BuildContext context, CachedProfile? profile) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(profile?.displayName ?? 'User Profile'),
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildProfileHeader(context, profile, true),
              const SizedBox(height: 32),
              _buildProfileDetails(context, profile, true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaterialPage(BuildContext context, CachedProfile? profile) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(profile?.displayName ?? 'User Profile'),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 32),
              _buildProfileHeader(context, profile, false),
              const SizedBox(height: 32),
              _buildProfileDetails(context, profile, false),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, CachedProfile? profile, bool isIOS) {
    return Column(
      children: [
        // Profile Avatar
        ProfileAvatar(
          photoURL: profile?.photoURL,
          displayName: profile?.displayName ?? 'Unknown User',
          radius: 60,
        ),
        const SizedBox(height: 16),
        
        // User Name
        Text(
          profile?.displayName ?? 'Unknown User',
          style: isIOS 
            ? CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                fontWeight: FontWeight.bold,
              )
            : Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 8),
        
        // Friend Status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isIOS 
              ? CupertinoColors.systemGreen.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isIOS 
                ? CupertinoColors.systemGreen
                : Colors.green,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isIOS ? CupertinoIcons.checkmark_circle_fill : Icons.check_circle,
                color: isIOS ? CupertinoColors.systemGreen : Colors.green,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                'Friends',
                style: isIOS
                  ? CupertinoTheme.of(context).textTheme.textStyle.copyWith(
                      color: CupertinoColors.systemGreen,
                      fontWeight: FontWeight.w600,
                    )
                  : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetails(BuildContext context, CachedProfile? profile, bool isIOS) {
    if (isIOS) {
      return CupertinoListSection.insetGrouped(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(context),
        children: [
          CupertinoListTile(
            leading: const Icon(CupertinoIcons.person),
            title: const Text('Display Name'),
            additionalInfo: Text(profile?.displayName ?? 'Unknown User'),
          ),
          CupertinoListTile(
            leading: const Icon(CupertinoIcons.calendar),
            title: const Text('Friends Since'),
            additionalInfo: Text(
              relationship.acceptedAt != null 
                ? _formatDate(relationship.acceptedAt!)
                : 'Unknown',
            ),
          ),
        ],
      );
    } else {
      final theme = Theme.of(context);
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: theme.colorScheme.surfaceContainerHighest,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Display Name'),
              subtitle: Text(profile?.displayName ?? 'Unknown User'),
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Friends Since'),
              subtitle: Text(
                relationship.acceptedAt != null 
                  ? _formatDate(relationship.acceptedAt!)
                  : 'Unknown',
              ),
            ),
          ],
        ),
      );
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays < 1) {
      return 'Today';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years year${years == 1 ? '' : 's'} ago';
    }
  }
}
