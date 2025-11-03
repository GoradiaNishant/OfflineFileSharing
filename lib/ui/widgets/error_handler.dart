import 'package:flutter/material.dart';
import '../../core/app_state.dart';
import '../../core/navigation_service.dart';
import '../../core/error_handling/error_handler.dart' as eh;
import '../../core/error_handling/app_error.dart';

/// Widget that listens to global app state and displays error messages
class ErrorHandler extends StatefulWidget {
  final Widget child;

  const ErrorHandler({super.key, required this.child});

  @override
  State<ErrorHandler> createState() => _ErrorHandlerState();
}

class _ErrorHandlerState extends State<ErrorHandler> {
  late final eh.ErrorHandler _errorHandler;

  @override
  void initState() {
    super.initState();
    _errorHandler = eh.ErrorHandler();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppError>(
      stream: _errorHandler.errorStream,
      builder: (context, errorSnapshot) {
        return ListenableBuilder(
          listenable: AppState(),
          builder: (context, _) {
            final appState = AppState();

            // Show error message if present in app state
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (appState.errorMessage != null) {
                NavigationService.showErrorSnackBar(appState.errorMessage!);
                appState.clearError();
              }
            });

            // Handle structured errors from error stream
            if (errorSnapshot.hasData) {
              final error = errorSnapshot.data!;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showErrorDialog(context, error);
              });
            }

            return widget.child;
          },
        );
      },
    );
  }

  /// Shows a detailed error dialog with suggested actions
  void _showErrorDialog(BuildContext context, AppError error) {
    if (error.suggestedActions.isEmpty) {
      return; // Let the snackbar handle simple errors
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          _getErrorIcon(error.severity),
          color: _getErrorColor(error.severity),
          size: 32,
        ),
        title: Text(_getErrorTitle(error.severity)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error.displayMessage),
            if (error.suggestedActions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Suggested actions:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...error.suggestedActions.map(
                (action) => ListTile(
                  dense: true,
                  leading: const Icon(Icons.lightbulb_outline, size: 20),
                  title: Text(action.label),
                  subtitle: Text(action.description),
                  onTap: () {
                    Navigator.of(context).pop();
                    action.action?.call();
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Dismiss'),
          ),
          if (error.isRetryable)
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Retry logic would be handled by the calling code
              },
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  IconData _getErrorIcon(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Icons.info_outline;
      case ErrorSeverity.warning:
        return Icons.warning_amber_outlined;
      case ErrorSeverity.error:
        return Icons.error_outline;
      case ErrorSeverity.critical:
        return Icons.dangerous_outlined;
    }
  }

  Color _getErrorColor(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return Colors.blue;
      case ErrorSeverity.warning:
        return Colors.orange;
      case ErrorSeverity.error:
        return Colors.red;
      case ErrorSeverity.critical:
        return Colors.red.shade800;
    }
  }

  String _getErrorTitle(ErrorSeverity severity) {
    switch (severity) {
      case ErrorSeverity.info:
        return 'Information';
      case ErrorSeverity.warning:
        return 'Warning';
      case ErrorSeverity.error:
        return 'Error';
      case ErrorSeverity.critical:
        return 'Critical Error';
    }
  }
}

/// Mixin for handling common error scenarios
mixin ErrorHandlerMixin {
  eh.ErrorHandler get errorHandler => eh.ErrorHandler();

  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    errorHandler.handleError(error, stackTrace: stackTrace, context: context);
  }

  Future<T> handleWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    bool Function(dynamic error)? shouldRetry,
  }) {
    return errorHandler.handleWithRetry(
      operation,
      maxRetries: maxRetries,
      delay: delay,
      shouldRetry: shouldRetry,
    );
  }

  void showSuccess(String message) {
    NavigationService.showSuccessSnackBar(message);
  }

  void showInfo(String message) {
    NavigationService.showInfoSnackBar(message);
  }

  void showWarning(String message) {
    NavigationService.showWarningSnackBar(message);
  }

  void clearError() {
    AppState().clearError();
  }
}
