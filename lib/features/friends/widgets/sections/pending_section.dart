import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import '../../providers/relationship_provider.dart';
import '../sections/incoming_requests_section.dart';
import '../sections/outgoing_requests_section.dart';

/// A combined section that contains both incoming and outgoing friend requests
class PendingSection extends StatefulWidget {
  final RelationshipProvider provider;

  const PendingSection({
    super.key,
    required this.provider,
  });

  @override
  State<PendingSection> createState() => _PendingSectionState();
}

class _PendingSectionState extends State<PendingSection> {
  @override
  Widget build(BuildContext context) {
    final hasIncoming = widget.provider.incomingCount > 0;
    final hasOutgoing = widget.provider.outgoingCount > 0;
    final hasPending = hasIncoming || hasOutgoing;
    final bool showMainPendingTitle = hasPending; // Determine if the main 'Pending Requests' title should be shown

    // Show empty state only if there are no pending requests AND not currently loading either list.
    if (!hasPending && !widget.provider.isLoadingIncoming && !widget.provider.isLoadingOutgoing) {
      return Platform.isIOS ? _buildCupertinoEmptyState(context) : _buildMaterialEmptyState(context);
    }
    // If loading and lists are empty, show a loading indicator at the PendingSection level.
    // The individual sections will also show their own loading indicators if they are loading data for the first time.
    if ((widget.provider.isLoadingIncoming && widget.provider.incomingRequests.isEmpty) || 
        (widget.provider.isLoadingOutgoing && widget.provider.outgoingRequests.isEmpty)) {
      // You might want a more prominent loading indicator here if both are loading and empty.
      // For now, relying on individual section loaders or a subtle one here.
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pending Requests Title
        if (showMainPendingTitle)
          Padding(
            padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0), // Match typical section header padding
            child: Text(
              'Pending Requests',
              style: Platform.isIOS
                  ? CupertinoTheme.of(context).textTheme.navTitleTextStyle.copyWith(
                      color: CupertinoTheme.of(context).textTheme.textStyle.color, 
                      fontWeight: FontWeight.bold
                    )
                  : Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
            ),
          ),
        // const SizedBox(height: 16), // Adjusted spacing, sections handle their own top padding
        
        // Incoming Requests
        IncomingRequestsSection(provider: widget.provider, showSectionTitle: !showMainPendingTitle && hasIncoming),
          
        if (hasIncoming && hasOutgoing) 
          const SizedBox(height: 24), // Spacing between sections
          
        // Outgoing Requests
        OutgoingRequestsSection(provider: widget.provider, showSectionTitle: !showMainPendingTitle && hasOutgoing),
      ],
    );
  }

  Widget _buildCupertinoEmptyState(BuildContext context) {
    final cupertinoTheme = CupertinoTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.hourglass,
            size: 64,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: cupertinoTheme.textTheme.navTitleTextStyle.copyWith(
              color: cupertinoTheme.textTheme.textStyle.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any outgoing or incoming friend requests',
            style: cupertinoTheme.textTheme.tabLabelTextStyle.copyWith(
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20), // Added horizontal padding
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any outgoing or incoming friend requests',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
