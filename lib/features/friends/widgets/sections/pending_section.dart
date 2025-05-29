import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/friends_provider.dart';
import '../sections/incoming_requests_section.dart';
import '../sections/outgoing_requests_section.dart';

/// A combined section that contains both incoming and outgoing friend requests
class PendingSection extends StatefulWidget {
  final FriendsProvider provider;

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

    if (!hasPending) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pending Requests Title
        Text(
          'Pending Requests',
          style: TextStyle(
            fontSize: 22, 
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 24),
        
        // Incoming Requests
        if (hasIncoming)
          IncomingRequestsSection(provider: widget.provider),
          
        if (hasIncoming && hasOutgoing) 
          const SizedBox(height: 24),
          
        // Outgoing Requests
        if (hasOutgoing)
          OutgoingRequestsSection(provider: widget.provider),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60),
      width: double.infinity,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.hourglass_empty,
            size: 64,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Requests',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don\'t have any outgoing or incoming friend requests',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
