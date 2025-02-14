import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_animate/flutter_animate.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({Key? key}) : super(key: key);

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                HapticFeedback.mediumImpact();
                Navigator.pop(context, barcode.rawValue);
              }
            },
          ).animate().fadeIn(duration: 400.ms),

          // Overlay
          SafeArea(
            child: Stack(
              children: [
                // Scanner Overlay
                Center(
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.black.withOpacity(0.3),
                    ),
                    child: Stack(
                      children: [
                        // Corner decorations
                        ...List.generate(4, (index) {
                          final isTop = index < 2;
                          final isLeft = index.isEven;
                          return Positioned(
                            top: isTop ? -2 : null,
                            bottom: !isTop ? -2 : null,
                            left: isLeft ? -2 : null,
                            right: !isLeft ? -2 : null,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: isTop
                                      ? BorderSide(
                                          color: Colors.purple, width: 4)
                                      : BorderSide.none,
                                  bottom: !isTop
                                      ? BorderSide(
                                          color: Colors.purple, width: 4)
                                      : BorderSide.none,
                                  left: isLeft
                                      ? BorderSide(
                                          color: Colors.purple, width: 4)
                                      : BorderSide.none,
                                  right: !isLeft
                                      ? BorderSide(
                                          color: Colors.purple, width: 4)
                                      : BorderSide.none,
                                ),
                              ),
                            ),
                          )
                              .animate(delay: (200 + (index * 100)).ms)
                              .fadeIn()
                              .scale(
                                begin: const Offset(0.5, 0.5),
                                end: const Offset(1, 1),
                              );
                        }),
                      ],
                    ),
                  ),
                ),

                // Header
                Positioned(
                  top: 20,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      Text(
                        'Scan QR Code',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Align the QR code within the frame',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: -0.2),
                ),

                // Close Button
                Positioned(
                  top: 20,
                  right: 20,
                  child: IconButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black38,
                      padding: const EdgeInsets.all(12),
                    ),
                  ).animate().fadeIn(delay: 400.ms).scale(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
