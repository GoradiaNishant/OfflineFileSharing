import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'app_error.dart';
import '../app_state.dart';
import '../navigation_service.dart';

/// Centralized error handling service
class ErrorHandler {
  static final ErrorHandler _instance = ErrorHandler._internal();
  factory ErrorHandler() => _instance;
  ErrorHandler._internal();

  final StreamController<AppError> _errorController =
      StreamController<AppError>.broadcast();

  /// Stream of application errors
  Stream<AppError> get errorStream => _errorController.stream;

  /// Handles an error and determines appropriate user feedback
  void handleError(
    dynamic error, {
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final appError = _convertToAppError(error, context: context);

    // Log error for debugging
    _logError(appError, stackTrace);

    // Update app state
    AppState().setError(appError.displayMessage);

    // Emit error to stream for listeners
    _errorController.add(appError);

    // Show appropriate UI feedback
    _showErrorFeedback(appError);
  }

  /// Converts various error types to AppError
  AppError _convertToAppError(dynamic error, {Map<String, dynamic>? context}) {
    if (error is AppError) {
      return error;
    }

    // Network errors
    if (error is SocketException) {
      return _handleSocketException(error, context);
    }

    if (error is HttpException) {
      return _handleHttpException(error, context);
    }

    if (error is TimeoutException) {
      return NetworkError(
        message: 'Connection timeout: ${error.message}',
        userMessage:
            'Connection timed out. Please check your network and try again.',
        type: NetworkErrorType.connectionTimeout,
        context: context,
        originalException: error,
      );
    }

    // File system errors
    if (error is FileSystemException) {
      return _handleFileSystemException(error, context);
    }

    // Format errors (QR code parsing)
    if (error is FormatException) {
      return QRCodeError(
        message: 'Invalid QR code format: ${error.message}',
        userMessage:
            'The QR code format is invalid. Please scan a valid file sharing QR code.',
        type: QRCodeErrorType.invalidFormat,
        context: context,
        originalException: error,
      );
    }

    // State errors (server already running, etc.)
    if (error is StateError) {
      return _handleStateError(error, context);
    }

    // Argument errors
    if (error is ArgumentError) {
      return ServerError(
        message: 'Invalid argument: ${error.message}',
        userMessage:
            'Invalid session data. Please try scanning the QR code again.',
        type: ServerErrorType.authenticationFailed,
        context: context,
        originalException: Exception(error.toString()),
      );
    }

    // Generic error fallback
    return GenericAppError(
      message: error.toString(),
      userMessage: 'An unexpected error occurred. Please try again.',
      severity: ErrorSeverity.error,
      context: context,
      originalException: error is Exception
          ? error
          : Exception(error.toString()),
    );
  }

  /// Handles socket exceptions
  NetworkError _handleSocketException(
    SocketException error,
    Map<String, dynamic>? context,
  ) {
    if (error.message.contains('Connection refused')) {
      return NetworkError(
        message: 'Connection refused: ${error.message}',
        userMessage:
            'Cannot connect to the other device. Make sure both devices are on the same network.',
        type: NetworkErrorType.connectionRefused,
        context: context,
        originalException: error,
      );
    }

    if (error.message.contains('Network is unreachable')) {
      return NetworkError(
        message: 'Network unreachable: ${error.message}',
        userMessage:
            'No network connection. Please connect to Wi-Fi or enable hotspot.',
        type: NetworkErrorType.noNetwork,
        context: context,
        originalException: error,
      );
    }

    return NetworkError(
      message: 'Network error: ${error.message}',
      userMessage:
          'Network connection failed. Please check your connection and try again.',
      type: NetworkErrorType.connectionTimeout,
      context: context,
      originalException: error,
    );
  }

  /// Handles HTTP exceptions
  NetworkError _handleHttpException(
    HttpException error,
    Map<String, dynamic>? context,
  ) {
    if (error.message.contains('403')) {
      return NetworkError(
        message: 'Authentication failed: ${error.message}',
        userMessage: 'Access denied. Please scan the QR code again.',
        type: NetworkErrorType.serverUnavailable,
        context: context,
        originalException: error,
      );
    }

    if (error.message.contains('404')) {
      return NetworkError(
        message: 'File not found: ${error.message}',
        userMessage:
            'The file is no longer available. Please ask the sender to share it again.',
        type: NetworkErrorType.serverUnavailable,
        context: context,
        originalException: error,
      );
    }

    return NetworkError(
      message: 'HTTP error: ${error.message}',
      userMessage: 'Server communication failed. Please try again.',
      type: NetworkErrorType.serverUnavailable,
      context: context,
      originalException: error,
    );
  }

  /// Handles file system exceptions
  FileSystemError _handleFileSystemException(
    FileSystemException error,
    Map<String, dynamic>? context,
  ) {
    if (error.message.contains('Permission denied')) {
      return FileSystemError(
        message: 'Permission denied: ${error.message}',
        userMessage:
            'Storage permission required. Please grant storage access in settings.',
        type: FileSystemErrorType.permissionDenied,
        context: context,
        originalException: error,
      );
    }

    if (error.message.contains('No space left')) {
      return FileSystemError(
        message: 'Insufficient storage: ${error.message}',
        userMessage:
            'Not enough storage space. Please free up some space and try again.',
        type: FileSystemErrorType.insufficientStorage,
        context: context,
        originalException: error,
      );
    }

    if (error.message.contains('File does not exist')) {
      return FileSystemError(
        message: 'File not found: ${error.message}',
        userMessage:
            'The selected file could not be found. Please select the file again.',
        type: FileSystemErrorType.fileNotFound,
        context: context,
        originalException: error,
      );
    }

    return FileSystemError(
      message: 'File system error: ${error.message}',
      userMessage: 'File operation failed. Please try again.',
      type: FileSystemErrorType.corruptedFile,
      context: context,
      originalException: error,
    );
  }

  /// Handles state errors
  AppError _handleStateError(StateError error, Map<String, dynamic>? context) {
    final message = error.message;

    if (message.contains('Server is already running')) {
      return ServerError(
        message: message,
        userMessage:
            'File sharing is already active. Stop the current session first.',
        type: ServerErrorType.portUnavailable,
        context: context,
        originalException: Exception(error.toString()),
      );
    }

    if (message.contains('No available ports')) {
      return ServerError(
        message: message,
        userMessage: 'Cannot start file server. Please try again in a moment.',
        type: ServerErrorType.portUnavailable,
        context: context,
        originalException: Exception(error.toString()),
      );
    }

    if (message.contains('Could not determine local IP')) {
      return NetworkError(
        message: message,
        userMessage:
            'Cannot detect network connection. Please connect to Wi-Fi and try again.',
        type: NetworkErrorType.noNetwork,
        context: context,
        originalException: Exception(error.toString()),
      );
    }

    return GenericAppError(
      message: message,
      userMessage: 'An error occurred. Please try again.',
      severity: ErrorSeverity.error,
      context: context,
      originalException: Exception(error.toString()),
    );
  }

  /// Shows appropriate error feedback to the user
  void _showErrorFeedback(AppError error) {
    switch (error.severity) {
      case ErrorSeverity.info:
        NavigationService.showInfoSnackBar(error.displayMessage);
        break;
      case ErrorSeverity.warning:
        NavigationService.showWarningSnackBar(error.displayMessage);
        break;
      case ErrorSeverity.error:
      case ErrorSeverity.critical:
        NavigationService.showErrorSnackBar(error.displayMessage);
        break;
    }
  }

  /// Logs error for debugging purposes
  void _logError(AppError error, StackTrace? stackTrace) {
    if (kDebugMode) {
      print('=== ERROR LOGGED ===');
      print('Type: ${error.runtimeType}');
      print('Message: ${error.message}');
      print('User Message: ${error.displayMessage}');
      print('Severity: ${error.severity}');
      print('Context: ${error.context}');
      if (error.originalException != null) {
        print('Original Exception: ${error.originalException}');
      }
      if (stackTrace != null) {
        print('Stack Trace: $stackTrace');
      }
      print('==================');
    }
  }

  /// Handles errors with retry logic
  Future<T> handleWithRetry<T>(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 2),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempts = 0;
    dynamic lastError;

    while (attempts < maxRetries) {
      try {
        attempts++;
        return await operation();
      } catch (error, stackTrace) {
        lastError = error;

        final appError = _convertToAppError(error);

        // Check if we should retry
        final canRetry = shouldRetry?.call(error) ?? appError.isRetryable;

        if (!canRetry || attempts >= maxRetries) {
          handleError(error, stackTrace: stackTrace);
          rethrow;
        }

        // Log retry attempt
        if (kDebugMode) {
          print(
            'Retry attempt $attempts/$maxRetries for error: ${error.toString()}',
          );
        }

        // Wait before retry
        if (attempts < maxRetries) {
          await Future.delayed(delay * attempts); // Exponential backoff
        }
      }
    }

    // This should never be reached, but just in case
    handleError(lastError);
    throw lastError;
  }

  /// Clears all errors
  void clearErrors() {
    AppState().clearError();
  }

  /// Disposes of the error handler
  void dispose() {
    _errorController.close();
  }
}

/// Mixin for easy error handling in widgets and services
mixin ErrorHandlerMixin {
  ErrorHandler get errorHandler => ErrorHandler();

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
}
