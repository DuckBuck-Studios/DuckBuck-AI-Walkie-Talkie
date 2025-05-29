import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../providers/friends_provider.dart';
import '../request_tile.dart';

class IncomingRequestsSection extends StatelessWidget {
  final FriendsProvider provider;

  const IncomingRequestsSection({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    if (provider.incomingCount == 0) {
      return const SizedBox.shrink();
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Subsection heading
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_add,
                color: AppColors.accentBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Incoming Requests',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            if (provider.incomingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentBlue,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  provider.incomingCount.toString(),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildContent(),
      ],
    );
  }

  Widget _buildContent() {
    if (provider.isLoadingIncoming) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentBlue),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: AppColors.surfaceBlack,
      child: Column(
        children: provider.incomingRequests.map((relationship) =>
          RequestTile(
            relationship: relationship,
            isIncoming: true,
            provider: provider,
          ),
        ).toList(),
      ),
    );
  }
}
