import 'dart:ui';
import 'package:flutter/material.dart';

class NotificationHelper {
  static void showInfo(BuildContext context, String message) {
    _show(context, message, Colors.white.withValues(alpha: 0.1));
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Colors.red.withValues(alpha: 0.2));
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green.withValues(alpha: 0.2));
  }

  static void _show(BuildContext context, String message, Color tint) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _TopNotification(
          message: message,
          tint: tint,
          onDismiss: () {
            entry.remove();
          },
        );
      },
    );

    overlay.insert(entry);
  }
}

class _TopNotification extends StatefulWidget {
  final String message;
  final Color tint;
  final VoidCallback onDismiss;

  const _TopNotification({
    required this.message,
    required this.tint,
    required this.onDismiss,
  });

  @override
  State<_TopNotification> createState() => _TopNotificationState();
}

class _TopNotificationState extends State<_TopNotification>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _controller.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -20 * (1 - _animation.value)),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
