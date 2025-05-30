import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import '../../providers/friends_provider.dart';
import '../request_tile.dart';
import '../request_tile_skeleton.dart';

class OutgoingRequestsSection extends StatelessWidget {
  final FriendsProvider provider;
  final bool showSectionTitle; // Added

  const OutgoingRequestsSection({
    super.key,
    required this.provider,
    required this.showSectionTitle, // Added
  });

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoSection(context);
    } else {
      return _buildMaterialSection(context);
    }
  }

  Widget _buildMaterialSection(BuildContext context) {
    // final bool showTitle = provider.incomingCount > 0 || provider.outgoingCount > 0; // Use passed parameter
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSectionTitle)
          Padding(
            padding: const EdgeInsets.only(left: 4.0, bottom: 8.0), // Minor padding for alignment
            child: Text(
              'Outgoing Friend Requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
        if (showSectionTitle) const SizedBox(height: 8), // Adjusted spacing
        _buildMaterialContent(context),
      ],
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    if (provider.isLoadingOutgoing && provider.outgoingRequests.isEmpty) {
      return Column(
        children: List.generate(
          3, // Show 3 skeleton tiles
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RequestTileSkeleton(isIOS: false),
          ),
        ),
      );
    }

    if (provider.outgoingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16), // Adjusted padding
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.hourglass_empty,
              size: 56, // Slightly smaller icon
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No Outgoing Requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you send friend requests,\nthey will appear here',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      child: Column(
        children: provider.outgoingRequests.map((relationship) {
          final String id = relationship.id; // Assuming RelationshipModel has an 'id' field
          return RequestTile(
            key: ValueKey(id), // Add key for better list performance
            relationship: relationship,
            isIncoming: false,
            provider: provider,
            // Outgoing requests don't have accept/decline actions or individual loading states here
            isLoadingAccept: false, 
            isLoadingDecline: false,
            isLoadingCancel: provider.isCancellingRequest(id), // Use new getter
            onAccept: () {},
            onDecline: () {},
            onCancel: () => provider.cancelFriendRequest(id), // Call cancel method
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCupertinoSection(BuildContext context) {
    // final bool showTitle = provider.incomingCount > 0 || provider.outgoingCount > 0; // Use passed parameter
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSectionTitle)
            Padding(
              padding: const EdgeInsets.only(left: 0.0, bottom: 8.0, top: 8.0),
              child: Text(
                'Outgoing Friend Requests',
                style: CupertinoTheme.of(context).textTheme.navLargeTitleTextStyle.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 20, // Explicitly set if navLargeTitleTextStyle is too big
                    ),
              ),
            ),
          if (showSectionTitle) const SizedBox(height: 8),
          _buildCupertinoContent(context),
        ],
      ),
    );
  }

  Widget _buildCupertinoContent(BuildContext context) {
    if (provider.isLoadingOutgoing && provider.outgoingRequests.isEmpty) {
      return Column(
        children: List.generate(
          3, // Show 3 skeleton tiles
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RequestTileSkeleton(isIOS: true),
          ),
        ),
      );
    }

    if (provider.outgoingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.hourglass,
              size: 56,
              color: CupertinoColors.secondaryLabel,
            ),
            const SizedBox(height: 16),
            Text(
              'No Outgoing Requests',
              style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you send friend requests,\nthey will appear here',
              style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                    color: CupertinoColors.secondaryLabel,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).barBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: provider.outgoingRequests.map((relationship) {
          final String id = relationship.id;
          return RequestTile(
            key: ValueKey(id),
            relationship: relationship,
            isIncoming: false,
            provider: provider,
            isLoadingAccept: false,
            isLoadingDecline: false,
            isLoadingCancel: provider.isCancellingRequest(id), // Use new getter
            onAccept: () {},
            onDecline: () {},
            onCancel: () => provider.cancelFriendRequest(id), // Call cancel method
          );
        }).toList(),
      ),
    );
  }
}
