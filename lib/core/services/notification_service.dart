import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../navigation_service.dart';
import '../models/transfer_progress.dart';

/// Service for handling user notifications and feedback
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Shows a success notification with optional actions
  void showSuccess({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
    List<NotificationAction>? actions,
    VoidCallback? onTap,
  }) {
    _showNotification(
      type: NotificationType.success,
      title: title,
      message: message,
      duration: duration,
      actions: actions,
      onTap: onTap,
    );
  }

  /// Shows an error notification with optional retry action
  void showError({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 6),
    List<NotificationAction>? actions,
    VoidCallback? onRetry,
    VoidCallback? onTap,
  }) {
    final errorActions = <NotificationAction>[
      if (onRetry != null)
        NotificationAction(label: 'Retry', onPressed: onRetry),
      ...?actions,
    ];

    _showNotification(
      type: NotificationType.error,
      title: title,
      message: message,
      duration: duration,
      actions: errorActions.isNotEmpty ? errorActions : null,
      onTap: onTap,
    );
  }

  /// Shows a warning notification
  void showWarning({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 5),
    List<NotificationAction>? actions,
    VoidCallback? onTap,
  }) {
    _showNotification(
      type: NotificationType.warning,
      title: title,
      message: message,
      duration: duration,
      actions: actions,
      onTap: onTap,
    );
  }

  /// Shows an info notification
  void showInfo({
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    List<NotificationAction>? actions,
    VoidCallback? onTap,
  }) {
    _showNotification(
      type: NotificationType.info,
      title: title,
      message: message,
      duration: duration,
      actions: actions,
      onTap: onTap,
    );
  }

  /// Shows a transfer completion notification
  void showTransferComplete({
    required String fileName,
    required String filePath,
    VoidCallback? onOpenFile,
    VoidCallback? onOpenFolder,
  }) {
    showSuccess(
      title: 'Transfer Complete',
      message: 'Successfully received "$fileName"',
      duration: const Duration(seconds: 6),
      actions: [
        if (onOpenFile != null)
          NotificationAction(label: 'Open File', onPressed: onOpenFile),
        if (onOpenFolder != null)
          NotificationAction(label: 'Show in Folder', onPressed: onOpenFolder),
      ],
    );
  }

  /// Shows a transfer failed notification
  void showTransferFailed({
    required String fileName,
    required String error,
    VoidCallback? onRetry,
  }) {
    showError(
      title: 'Transfer Failed',
      message: 'Failed to receive "$fileName": $error',
      onRetry: onRetry,
    );
  }

  /// Shows a server started notification
  void showServerStarted({required String fileName, VoidCallback? onStop}) {
    showInfo(
      title: 'Sharing File',
      message: 'Ready to share "$fileName". Show QR code to receiver.',
      duration: const Duration(seconds: 5),
      actions: onStop != null
          ? [NotificationAction(label: 'Stop Sharing', onPressed: onStop)]
          : null,
    );
  }

  /// Shows a connection established notification
  void showConnectionEstablished({required String deviceInfo}) {
    showInfo(
      title: 'Connected',
      message: 'Connected to $deviceInfo',
      duration: const Duration(seconds: 2),
    );
  }

  /// Shows a progress notification (for long operations)
  void showProgressNotification({
    required String title,
    required TransferProgress progress,
    VoidCallback? onCancel,
  }) {
    final context = NavigationService.context;
    if (context == null) return;

    // For now, show as a snackbar. In a full implementation,
    // this could be a persistent notification
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: progress.percentage / 100.0,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 4),
            Text(
              '${progress.percentage.toStringAsFixed(1)}% • ${progress.formattedSpeed}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        action: onCancel != null
            ? SnackBarAction(
                label: 'Cancel',
                textColor: Colors.white,
                onPressed: onCancel,
              )
            : null,
      ),
    );
  }

  /// Shows a custom notification
  void _showNotification({
    required NotificationType type,
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
    List<NotificationAction>? actions,
    VoidCallback? onTap,
  }) {
    final context = NavigationService.context;
    if (context == null) return;

    // Provide haptic feedback
    _provideHapticFeedback(type);

    // Show as a custom snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: _buildNotificationContent(
          context,
          type,
          title,
          message,
          actions,
          onTap,
        ),
        backgroundColor: _getNotificationColor(context, type),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        action: actions?.isNotEmpty == true
            ? null // Actions are handled in content
            : SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white.withOpacity(0.8),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
      ),
    );
  }

  /// Builds the notification content widget
  Widget _buildNotificationContent(
    BuildContext context,
    NotificationType type,
    String title,
    String? message,
    List<NotificationAction>? actions,
    VoidCallback? onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            // Icon
            Icon(_getNotificationIcon(type), color: Colors.white, size: 24),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],

                  // Actions
                  if (actions?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: actions!.map((action) {
                        return TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            action.onPressed();
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            action.label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Gets the appropriate icon for notification type
  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.error:
        return Icons.error;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.info:
        return Icons.info;
    }
  }

  /// Gets the appropriate color for notification type
  Color _getNotificationColor(BuildContext context, NotificationType type) {
    final colorScheme = Theme.of(context).colorScheme;

    switch (type) {
      case NotificationType.success:
        return Colors.green.shade600;
      case NotificationType.error:
        return colorScheme.error;
      case NotificationType.warning:
        return Colors.orange.shade600;
      case NotificationType.info:
        return colorScheme.primary;
    }
  }

  /// Provides haptic feedback based on notification type
  void _provideHapticFeedback(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        HapticFeedback.lightImpact();
        break;
      case NotificationType.error:
        HapticFeedback.heavyImpact();
        break;
      case NotificationType.warning:
        HapticFeedback.mediumImpact();
        break;
      case NotificationType.info:
        HapticFeedback.selectionClick();
        break;
    }
  }

  /// Clears all notifications
  void clearAll() {
    final context = NavigationService.context;
    if (context != null) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }
}

/// Notification types
enum NotificationType { success, error, warning, info }

/// Notification action
class NotificationAction {
  final String label;
  final VoidCallback onPressed;

  const NotificationAction({required this.label, required this.onPressed});
}
