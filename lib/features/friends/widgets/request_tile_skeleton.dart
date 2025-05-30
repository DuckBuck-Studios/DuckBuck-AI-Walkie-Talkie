import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A skeleton version of the request tile for loading states
class RequestTileSkeleton extends StatelessWidget {
  final bool isIOS;
  
  const RequestTileSkeleton({
    super.key, 
    this.isIOS = false,
  });

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: true,
      child: isIOS ? _buildCupertinoSkeleton(context) : _buildMaterialSkeleton(context),
    );
  }
  
  Widget _buildMaterialSkeleton(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const CircleAvatar(radius: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('User Name'),
                  const SizedBox(height: 4),
                  Text(
                    'Sent you a friend request',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Action buttons placeholder
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 20),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCupertinoSkeleton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: CupertinoColors.systemBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: CupertinoColors.systemGrey5,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(radius: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('User Name'),
                const SizedBox(height: 4),
                Text(
                  'Sent you a friend request',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.systemGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons placeholder
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: CupertinoColors.activeGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.check_mark, size: 20, color: CupertinoColors.white),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: CupertinoColors.destructiveRed,
                  shape: BoxShape.circle,
                ),
                child: const Icon(CupertinoIcons.clear, size: 20, color: CupertinoColors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
