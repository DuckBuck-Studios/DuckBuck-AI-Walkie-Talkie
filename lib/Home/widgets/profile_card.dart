import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:duckbuck/Home/providers/pfp_provider.dart';
import 'package:shimmer/shimmer.dart';

class ProfileCard extends StatelessWidget {
  final String profileUrl;
  final String name;
  final bool isLoading;

  const ProfileCard({
    Key? key,
    required this.profileUrl,
    required this.name,
    this.isLoading = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[900]!,
        highlightColor: Colors.grey[800]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }

    final pfpProvider = Provider.of<PfpProvider>(context);
    final isMinimized = pfpProvider.isMinimized;
    final screenSize = MediaQuery.of(context).size;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isMinimized ? screenSize.width * 0.6 : screenSize.width,
      height: isMinimized ? screenSize.height * 0.6 : screenSize.height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image(
            image: profileUrl.isNotEmpty
                ? NetworkImage(profileUrl)
                : const AssetImage('assets/background.png') as ImageProvider,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset('assets/background.png', fit: BoxFit.cover);
            },
          ),

          // Gradient Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.1),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),

          // Profile Name
          if (!isMinimized)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(
                      blurRadius: 3,
                      color: Colors.black.withOpacity(0.5),
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
