import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../providers/relationship_provider.dart';
import '../request_tile.dart';
import '../request_tile_skeleton.dart';

class IncomingRequestsSection extends StatelessWidget {
  final RelationshipProvider provider;
  final bool showSectionTitle; // Added

  const IncomingRequestsSection({
    super.key,
    required this.provider,
    required this.showSectionTitle, // Added
  });

  @override
  Widget build(BuildContext context) {
    // if (provider.incomingCount == 0 && !provider.isLoadingIncoming) { // Keep section for empty/loading states
    //   return const SizedBox.shrink();
    // }

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
        if (showSectionTitle) _buildMaterialHeader(context),
        if (showSectionTitle) const SizedBox(height: 12),
        _buildMaterialContent(context),
      ],
    );
  }

  Widget _buildMaterialHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (Theme.of(context).colorScheme.primary).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.person_add,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Incoming Requests',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const Spacer(),
        if (provider.incomingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              provider.incomingCount.toString(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMaterialContent(BuildContext context) {
    if (provider.isLoadingIncoming && provider.incomingRequests.isEmpty) {
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

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      child: Column(
        children: provider.incomingRequests.map((relationship) {
          final String id = relationship.id;
          return RequestTile(
            key: ValueKey(id),
            relationship: relationship,
            isIncoming: true,
            provider: provider,
            isLoadingAccept: provider.isAcceptingRequest(id), // Use new getter
            isLoadingDecline: provider.isDecliningRequest(id), // Use new getter
            isLoadingCancel: false, // Not used for incoming requests
            onAccept: () => provider.acceptFriendRequest(id),
            onDecline: () => provider.declineFriendRequest(id),
            onCancel: () {}, // Not used for incoming requests
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
          if (showSectionTitle) _buildCupertinoHeader(context),
          if (showSectionTitle) const SizedBox(height: 12),
          _buildCupertinoContent(context),
        ],
      ),
    );
  }

  Widget _buildCupertinoHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: CupertinoColors.activeBlue.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            CupertinoIcons.person_add,
            color: CupertinoColors.activeBlue,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Incoming Requests',
          style: CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        const Spacer(),
        if (provider.incomingCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.activeBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              provider.incomingCount.toString(),
              style: CupertinoTheme.of(context).textTheme.tabLabelTextStyle.copyWith(
                color: CupertinoColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCupertinoContent(BuildContext context) {
    if (provider.isLoadingIncoming && provider.incomingRequests.isEmpty) {
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

    return Container(
      decoration: BoxDecoration(
        color: CupertinoTheme.of(context).barBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: provider.incomingRequests.map((relationship) {
          final String id = relationship.id;
          return RequestTile(
            key: ValueKey(id),
            relationship: relationship,
            isIncoming: true,
            provider: provider,
            isLoadingAccept: provider.isAcceptingRequest(id), // Use new getter
            isLoadingDecline: provider.isDecliningRequest(id), // Use new getter
            isLoadingCancel: false, // Not used for incoming requests
            onAccept: () => provider.acceptFriendRequest(id),
            onDecline: () => provider.declineFriendRequest(id),
            onCancel: () {}, // Not used for incoming requests
          );
        }).toList(),
      ),
    );
  }
}
