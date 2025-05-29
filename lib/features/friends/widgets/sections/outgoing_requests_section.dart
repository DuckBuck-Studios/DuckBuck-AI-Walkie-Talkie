import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/friends_provider.dart';
import '../request_tile.dart';

class OutgoingRequestsSection extends StatelessWidget {
  final FriendsProvider provider;

  const OutgoingRequestsSection({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Outgoing Friend Requests',
          style: TextStyle(
            fontSize: 20, 
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (provider.isLoadingOutgoing) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentPurple),
          ),
        ),
      );
    }

    if (provider.outgoingRequests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 60),
        width: double.infinity,
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
              'No outgoing requests',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you send friend requests,\nthey will appear here',
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

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surfaceBlack,
      child: Column(
        children: provider.outgoingRequests.map((relationship) =>
          RequestTile(
            relationship: relationship,
            isIncoming: false,
            provider: provider,
          ),
        ).toList(),
      ),
    );
  }
}
