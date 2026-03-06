import 'dart:async';
import 'package:flutter/material.dart';
import 'package:splitease_test/core/services/notification_service.dart';
import 'package:splitease_test/core/services/auth_service.dart';

class NotificationProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  Timer? _pollingTimer;
  bool _isLoading = false;
  Set<String> _seenIds = {};
  bool _isFirstFetch = true;

  // Callback for when new notifications arrive
  void Function(NotificationModel)? onNewNotification;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  NotificationProvider() {
    _startPolling();
  }

  void _startPolling() {
    _fetch(); // Initial fetch
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      final isLoggedIn = await AuthService.isLoggedIn();
      if (isLoggedIn) {
        _fetch();
      }
    });
  }

  Future<void> _fetch() async {
    final results = await NotificationService.fetchNotifications();

    if (_isFirstFetch) {
      _notifications = results;
      _seenIds = results.map((n) => n.id).toSet();
      _isFirstFetch = false;
      notifyListeners();
      return;
    }

    // Detect new UNREAD notifications (not seen in this session)
    for (var n in results) {
      if (!n.isRead && !_seenIds.contains(n.id)) {
        if (onNewNotification != null) {
          onNewNotification!(n);
        }
      }
    }

    _notifications = results;
    _seenIds.addAll(results.map((n) => n.id));
    notifyListeners();
  }

  Future<void> markAsRead(String id) async {
    final success = await NotificationService.markAsRead(id);
    if (success) {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        final old = _notifications[index];
        _notifications[index] = NotificationModel(
          id: old.id,
          userId: old.userId,
          userName: old.userName,
          title: old.title,
          message: old.message,
          isRead: true,
          status: old.status,
          scheduledAt: old.scheduledAt,
          createdAt: old.createdAt,
        );
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }
}
