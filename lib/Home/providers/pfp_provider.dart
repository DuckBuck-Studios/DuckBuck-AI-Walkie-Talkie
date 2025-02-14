import 'package:flutter/foundation.dart';

class PfpProvider with ChangeNotifier {
  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;

  void setMinimized(bool value) {
    _isMinimized = value;
    notifyListeners();
  }
}
