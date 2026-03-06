import 'dart:ui';
import 'package:flutter/material.dart';

class NotificationHelper {
  static void showInfo(BuildContext context, String message, {String? title}) {
    _show(context, message, Colors.white.withValues(alpha: 0.1), title: title);
  }

  static void showError(BuildContext context, String message, {String? title}) {
    _show(context, message, Colors.red.withValues(alpha: 0.2), title: title);
  }

  static void showSuccess(
    BuildContext context,
    String message, {
    String? title,
  }) {
    _show(context, message, Colors.green.withValues(alpha: 0.2), title: title);
  }

  static void _show(
    BuildContext context,
    String message,
    Color tint, {
    String? title,
  }) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return _TopNotification(
          message: message,
          title: title,
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
  final String? title;
  final Color tint;
  final VoidCallback onDismiss;

  const _TopNotification({
    required this.message,
    this.title,
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
      duration: const Duration(milliseconds: 600),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );

    _controller.forward();

    // Auto dismiss after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
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
      left: 15,
      right: 15,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return Opacity(
            opacity: _animation.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, -30 * (1 - _animation.value)),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.black : Colors.white).withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title != null && widget.title!.isNotEmpty) ...[
                      Text(
                        widget.title!.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                        height: 1.3,
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
