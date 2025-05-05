import 'package:flutter/material.dart';
import 'package:slide_to_act/slide_to_act.dart';

/// A wrapper around the SlideAction widget that safely handles layout timing issues
/// to prevent "RenderBox was not laid out" errors, especially during hot reload/restart
class SafeSlideAction extends StatefulWidget {
  /// Text to display in the slider
  final String text;

  /// Height of the slider
  final double height;

  /// Size of the slider button icon
  final double sliderButtonIconSize;

  /// Whether to rotate the slider button icon
  final bool sliderRotate;

  /// Border radius of the slider
  final double borderRadius;

  /// Elevation shadow of the slider
  final double elevation;

  /// Color of the slider button
  final Color innerColor;

  /// Background color of the slider
  final Color outerColor;

  /// Icon to display in the slider button
  final Widget sliderButtonIcon;

  /// Text style for the slider text
  final TextStyle textStyle;

  /// Callback when the slide action is submitted
  final Function()? onSubmit;

  const SafeSlideAction({
    super.key,
    required this.text,
    this.height = 60,
    this.sliderButtonIconSize = 24,
    this.sliderRotate = false,
    this.borderRadius = 16,
    this.elevation = 0,
    required this.innerColor,
    required this.outerColor,
    required this.sliderButtonIcon,
    required this.textStyle,
    this.onSubmit,
  });

  @override
  State<SafeSlideAction> createState() => _SafeSlideActionState();
}

class _SafeSlideActionState extends State<SafeSlideAction> {
  final GlobalKey<SlideActionState> _slideActionKey = GlobalKey();
  bool _isLayoutReady = false;

  @override
  void initState() {
    super.initState();
    // Delay creating the SlideAction until the layout phase is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLayoutReady = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Don't render the SlideAction until after the first frame
    if (!_isLayoutReady) {
      return SizedBox(
        width: double.infinity,
        height: widget.height,
        child: Container(
          decoration: BoxDecoration(
            color: widget.outerColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth,
          height: widget.height,
          child: SlideAction(
            key: _slideActionKey,
            height: widget.height,
            sliderButtonIconSize: widget.sliderButtonIconSize,
            sliderRotate: widget.sliderRotate,
            borderRadius: widget.borderRadius,
            elevation: widget.elevation,
            innerColor: widget.innerColor,
            outerColor: widget.outerColor,
            sliderButtonIcon: widget.sliderButtonIcon,
            text: widget.text,
            textStyle: widget.textStyle,
            onSubmit: () {
              if (widget.onSubmit != null) {
                widget.onSubmit!();
              }
              return null;
            },
          ),
        );
      },
    );
  }

  /// Reset the slider to its initial position
  void reset() {
    if (_isLayoutReady && _slideActionKey.currentState != null) {
      _slideActionKey.currentState?.reset();
    }
  }
}
