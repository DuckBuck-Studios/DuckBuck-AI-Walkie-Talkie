import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:duckbuck/Home/service/bugService.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class BugReportPage extends StatefulWidget {
  const BugReportPage({Key? key}) : super(key: key);

  @override
  _BugReportPageState createState() => _BugReportPageState();
}

class _BugReportPageState extends State<BugReportPage>
    with TickerProviderStateMixin {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<File> _selectedVideos = [];
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  late AnimationController _loadingController;
  late AnimationController _successController;
  late AnimationController _bugLogoController;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _bugLogoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _loadingController.dispose();
    _successController.dispose();
    _bugLogoController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(bool isImage) async {
    final maxFileSize = 10 * 1024 * 1024;
    final picker = ImagePicker();

    if (isImage && _selectedImages.length >= 5) {
      _showAnimatedError('Maximum 5 images allowed');
      return;
    }

    if (!isImage && _selectedVideos.length >= 2) {
      _showAnimatedError('Maximum 2 videos allowed');
      return;
    }

    try {
      final XFile? pickedFile = isImage
          ? await picker.pickImage(source: ImageSource.gallery)
          : await picker.pickVideo(source: ImageSource.gallery);

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSize = await file.length();

        if (fileSize > maxFileSize) {
          _showAnimatedError('File size must be less than 10MB');
          return;
        }

        setState(() {
          if (isImage) {
            _selectedImages.add(file);
          } else {
            _selectedVideos.add(file);
          }
        });
      }
    } catch (e) {
      _showAnimatedError('Error picking media: $e');
    }
  }

  void _showAnimatedError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white)
                .animate(onPlay: (controller) => controller.repeat())
                .shake(duration: 400.ms),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message)
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideX(begin: 0.2, end: 0),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red.shade400,
        duration: const Duration(seconds: 3),
        dismissDirection: DismissDirection.horizontal,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.0;
    });

    try {
      final bugReportService = BugReportService(
        auth: FirebaseAuth.instance,
        firestore: FirebaseFirestore.instance,
        storage: FirebaseStorage.instance,
      );

      void onProgress(double progress) {
        setState(() {
          _uploadProgress = progress;
        });
      }

      final reportId = await bugReportService.submitReport(
        title: _titleController.text,
        description: _descriptionController.text,
        images: _selectedImages,
        videos: _selectedVideos,
        onProgress: onProgress,
      );

      _loadingController.stop();
      _successController.forward();

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog();
      }
    } catch (e) {
      _loadingController.stop();
      _showAnimatedError('Error submitting report: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 150,
              height: 150,
              child: Lottie.asset(
                'assets/success.json',
                fit: BoxFit.contain,
                animate: true,
                repeat: false,
                onLoaded: (composition) {
                  Future.delayed(composition.duration, () {
                    Navigator.of(dialogContext).pop();
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      child: Material(
        color: Colors.transparent,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: const BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              children: [
                // Drag Handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white30,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

                const SizedBox(height: 20),

                // Title Section with modern design
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.withOpacity(0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.purple.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.bug_report_outlined,
                          color: Colors.purple,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Report Bug',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

                // Form Content
                Expanded(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAnimatedTextField(
                              "Bug Title",
                              _titleController,
                              maxLines: 1,
                              hint: "Enter a short title",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a title';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildAnimatedTextField(
                              "Bug Description",
                              _descriptionController,
                              maxLines: 5,
                              hint: "Describe the issue in detail...",
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter a description';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),
                            _buildMediaSection(),
                            if (_isSubmitting) ...[
                              const SizedBox(height: 20),
                              _buildProgressIndicator(),
                            ],
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Submit Button - Fixed at bottom
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: _buildSubmitButton(),
                ),

                // Safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    String? hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.purple.shade200,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            contentPadding: const EdgeInsets.all(20),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.purple.withOpacity(0.5),
                width: 2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Colors.purple.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildMediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Attachments",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.2, end: 0),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildMediaButton(
              "Add Images (${_selectedImages.length}/5)",
              Icons.image,
              () => _pickMedia(true),
            ),
            const SizedBox(width: 10),
            _buildMediaButton(
              "Add Videos (${_selectedVideos.length}/2)",
              Icons.videocam,
              () => _pickMedia(false),
            ),
          ],
        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),
        if (_selectedImages.isNotEmpty) ...[
          const SizedBox(height: 15),
          _buildMediaPreviewList(_selectedImages, true),
        ],
        if (_selectedVideos.isNotEmpty) ...[
          const SizedBox(height: 15),
          _buildMediaPreviewList(_selectedVideos, false),
        ],
      ],
    );
  }

  Widget _buildMediaButton(String label, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Colors.purple.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: Colors.purple,
                size: 28,
              )
                  .animate(onPlay: (controller) => controller.repeat())
                  .shimmer(duration: 2000.ms),
              const SizedBox(height: 5),
              Text(
                label,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreviewList(List<File> mediaFiles, bool isImage) {
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: mediaFiles.length,
        itemBuilder: (context, index) {
          return Stack(
            children: [
              Container(
                width: 100,
                margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: isImage
                      ? Image.file(mediaFiles[index], fit: BoxFit.cover)
                      : Container(
                          color: Colors.black,
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: Colors.white,
                            size: 40,
                          ),
                        ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .scale(delay: Duration(milliseconds: index * 100)),
              Positioned(
                top: 5,
                right: 15,
                child: GestureDetector(
                  onTap: () => _removeMedia(isImage, index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 200 + index * 100)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submitReport,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple.withOpacity(0.8),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
          side: BorderSide(
            color: Colors.purple.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: _isSubmitting
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white.withOpacity(0.8),
                  ),
                ),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    "Submit Report",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildProgressIndicator() {
    return Column(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
          ),
          child: LinearProgressIndicator(
            value: _uploadProgress.isFinite ? _uploadProgress : 0.0,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.purple.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Uploading... ${(_uploadProgress.isFinite ? _uploadProgress * 100 : 0).toInt()}%',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms);
  }

  void _removeMedia(bool isImage, int index) {
    setState(() {
      if (isImage) {
        _selectedImages.removeAt(index);
      } else {
        _selectedVideos.removeAt(index);
      }
    });
  }
}
