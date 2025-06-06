
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

/// Platform-specific icons for call controls
/// Provides consistent iconography that matches each platform's design language
class PlatformIcons {
  // Microphone icons
  static IconData getMicIcon(bool isIOS) {
    return isIOS ? CupertinoIcons.mic : Icons.mic;
  }

  static IconData getMicOffIcon(bool isIOS) {
    return isIOS ? CupertinoIcons.mic_slash : Icons.mic_off;
  }

  // Speaker icons
  static IconData getSpeakerOnIcon(bool isIOS) {
    return isIOS ? CupertinoIcons.speaker_3 : Icons.volume_up;
  }

  static IconData getSpeakerOffIcon(bool isIOS) {
    return isIOS ? CupertinoIcons.speaker_1 : Icons.volume_down;
  }

  // Call end icon
  static IconData getCallEndIcon(bool isIOS) {
    return isIOS ? CupertinoIcons.phone_down : Icons.call_end;
  }

  // Phone call icon
  static IconData getCallIcon(bool isIOS) {
    return isIOS ? CupertinoIcons.phone : Icons.call;
  }
}
