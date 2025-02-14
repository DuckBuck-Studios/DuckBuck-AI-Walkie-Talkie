import 'package:duckbuck/Authentication/screens/welcome.dart';
import 'package:duckbuck/Authentication/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'bug_report_page.dart';

class ErrorSheet extends StatelessWidget {
  const ErrorSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Animate(
      effects: [
        SlideEffect(
          begin: const Offset(0, 1),
          end: const Offset(0, 0),
          duration: 600.ms,
          curve: Curves.easeOutExpo,
        ),
        FadeEffect(
          duration: 500.ms,
          curve: Curves.easeOut,
        ),
      ],
      child: Container(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height * 0.4,
          maxHeight: MediaQuery.of(context).size.height * 0.80,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 200.ms)
                .scale(delay: 200.ms),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Something Went Wrong',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms, delay: 300.ms)
                .slideY(begin: 0.2, end: 0),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _buildOption(
                    context: context,
                    icon: Icons.bug_report_outlined,
                    title: 'Found a Bug',
                    subtitle: 'Report an issue to help us improve',
                    color: Colors.orange,
                    emoji: '🐛',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const BugReportPage()),
                      );
                    },
                  ).animate().fadeIn(delay: 400.ms, duration: 400.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 400.ms,
                      curve: Curves.easeOutExpo),
                  const SizedBox(height: 16),
                  _buildOption(
                    context: context,
                    icon: Icons.logout_rounded,
                    title: 'Logout',
                    subtitle: 'Sign out from your account securely',
                    color: Colors.red,
                    emoji: '👋',
                    onTap: () {},
                  ).animate().fadeIn(delay: 500.ms, duration: 400.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 500.ms,
                      curve: Curves.easeOutExpo),
                  const SizedBox(height: 16),
                  _buildOption(
                    context: context,
                    icon: Icons.delete_outline_rounded,
                    title: 'Delete Account',
                    subtitle: 'Permanently remove your account and data',
                    color: Colors.purple,
                    emoji: '🗑️',
                    onTap: () {},
                  ).animate().fadeIn(delay: 600.ms, duration: 400.ms).slideY(
                      begin: 0.2,
                      end: 0,
                      delay: 600.ms,
                      curve: Curves.easeOutExpo),
                ],
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 25),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.white.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ).animate().fadeIn(delay: 700.ms, duration: 400.ms).slideY(
                begin: 0.2, end: 0, delay: 700.ms, curve: Curves.easeOutExpo),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(BuildContext context, String title, String content,
      String emoji, VoidCallback onConfirm) {
    HapticFeedback.lightImpact();

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.8),
      builder: (context) => Animate(
        effects: [
          ScaleEffect(
            begin: const Offset(0.8, 0.8),
            end: const Offset(1, 1),
            duration: 400.ms,
            curve: Curves.easeOutExpo,
          ),
          FadeEffect(
            duration: 300.ms,
            curve: Curves.easeOut,
          ),
        ],
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          backgroundColor: const Color(0xFF1E1E1E),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 48),
                )
                    .animate(
                      onPlay: (controller) => controller.repeat(reverse: true),
                    )
                    .scale(
                      duration: 1500.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                    ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildDialogButton(
                      'Cancel',
                      () => Navigator.pop(context),
                      isOutlined: true,
                    ),
                    _buildDialogButton(
                      'Confirm',
                      () {
                        Navigator.pop(context);
                        onConfirm();
                      },
                      isDestructive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required String emoji,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          if (title == "Delete Account") {
            _showConfirmDialog(
              context,
              "Delete Account",
              "This action cannot be undone. All your data will be permanently deleted.",
              "🗑️",
              () async {
                try {
                  await AuthService().deleteAccount();
                  if (context.mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const WelcomeScreen(),
                      ),
                      (route) => false,
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting account: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          } else if (title == "Logout") {
            _showConfirmDialog(
              context,
              "Logout",
              "Are you sure you want to sign out from your account?",
              "👋",
              () async {
                await AuthService().signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                    ),
                    (route) => false,
                  );
                }
              },
            );
          } else {
            onTap();
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withOpacity(0.5), width: 2),
                ),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Icon(icon, color: color, size: 22),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: color.withOpacity(0.7),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogButton(
    String label,
    VoidCallback onTap, {
    bool isOutlined = false,
    bool isDestructive = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isOutlined
                ? Colors.transparent
                : isDestructive
                    ? Colors.red.withOpacity(0.2)
                    : Colors.purple.withOpacity(0.2),
            border: Border.all(
              color: isDestructive ? Colors.red : Colors.purple,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isDestructive ? Colors.red : Colors.purple,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
