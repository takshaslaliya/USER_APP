import 'package:flutter/material.dart';

/// A simple provider to signal that something changed and data needs to be re-fetched.
class DataRefreshProvider extends ChangeNotifier {
  /// Signal a global refresh of data
  void signalRefresh() {
    notifyListeners();
  }
}
