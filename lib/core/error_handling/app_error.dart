/// Comprehensive error handling system for the offline file sharing app
library;

/// Base class for all application errors
abstract class AppError implements Exception {
  final String message;
  final String? userMessage;
  final ErrorSeverity severity;
  final Map<String, dynamic>? context;
  final Exception? originalException;

  const AppError({
    required this.message,
    this.userMessage,
    this.severity = ErrorSeverity.error,
    this.context,
    this.originalException,
  });

  /// User-friendly message to display in the UI
  String get displayMessage => userMessage ?? message;

  /// Whether this error can be retried
  bool get isRetryable => false;

  /// Suggested actions for the user
  List<ErrorAction> get suggestedActions => [];

  @override
  String toString() => 'AppError: $message';
}

/// Error severity levels
enum ErrorSeverity { info, warning, error, critical }

/// Suggested actions for error recovery
class ErrorAction {
  final String label;
  final String description;
  final VoidCallback? action;

  const ErrorAction({
    required this.label,
    required this.description,
    this.action,
  });
}

/// Network-related errors
class NetworkError extends AppError {
  final NetworkErrorType type;

  const NetworkError({
    required super.message,
    super.userMessage,
    required this.type,
    super.context,
    super.originalException,
  }) : super(severity: ErrorSeverity.error);

  @override
  bool get isRetryable => type.isRetryable;

  @override
  List<ErrorAction> get suggestedActions {
    switch (type) {
      case NetworkErrorType.connectionTimeout:
        return [
          const ErrorAction(
            label: 'Retry',
            description: 'Try connecting again',
          ),
          const ErrorAction(
            label: 'Check Network',
            description: 'Ensure both devices are on the same Wi-Fi network',
          ),
        ];
      case NetworkErrorType.connectionRefused:
        return [
          const ErrorAction(
            label: 'Retry',
            description: 'Try connecting again',
          ),
          const ErrorAction(
            label: 'Rescan QR',
            description: 'Scan the QR code again',
          ),
        ];
      case NetworkErrorType.noNetwork:
        return [
          const ErrorAction(
            label: 'Check Wi-Fi',
            description: 'Connect to a Wi-Fi network or enable hotspot',
          ),
        ];
      case NetworkErrorType.serverUnavailable:
        return [
          const ErrorAction(
            label: 'Retry',
            description: 'Try again in a moment',
          ),
          const ErrorAction(
            label: 'Ask Sender',
            description: 'Ask the sender to restart file sharing',
          ),
        ];
    }
  }
}

enum NetworkErrorType {
  connectionTimeout(true),
  connectionRefused(true),
  noNetwork(false),
  serverUnavailable(true);

  const NetworkErrorType(this.isRetryable);
  final bool isRetryable;
}

/// File system related errors
class FileSystemError extends AppError {
  final FileSystemErrorType type;

  const FileSystemError({
    required super.message,
    super.userMessage,
    required this.type,
    super.context,
    super.originalException,
  }) : super(severity: ErrorSeverity.error);

  @override
  bool get isRetryable => type.isRetryable;

  @override
  List<ErrorAction> get suggestedActions {
    switch (type) {
      case FileSystemErrorType.insufficientStorage:
        return [
          const ErrorAction(
            label: 'Free Space',
            description: 'Delete some files to make space',
          ),
        ];
      case FileSystemErrorType.permissionDenied:
        return [
          const ErrorAction(
            label: 'Grant Permission',
            description: 'Allow storage access in app settings',
          ),
        ];
      case FileSystemErrorType.fileNotFound:
        return [
          const ErrorAction(
            label: 'Try Again',
            description: 'Select the file again',
          ),
        ];
      case FileSystemErrorType.corruptedFile:
        return [
          const ErrorAction(
            label: 'Retry Download',
            description: 'Download the file again',
          ),
        ];
    }
  }
}

enum FileSystemErrorType {
  insufficientStorage(false),
  permissionDenied(false),
  fileNotFound(true),
  corruptedFile(true);

  const FileSystemErrorType(this.isRetryable);
  final bool isRetryable;
}

/// QR code related errors
class QRCodeError extends AppError {
  final QRCodeErrorType type;

  const QRCodeError({
    required super.message,
    super.userMessage,
    required this.type,
    super.context,
    super.originalException,
  }) : super(severity: ErrorSeverity.error);

  @override
  bool get isRetryable => type.isRetryable;

  @override
  List<ErrorAction> get suggestedActions {
    switch (type) {
      case QRCodeErrorType.invalidFormat:
        return [
          const ErrorAction(
            label: 'Scan Again',
            description: 'Try scanning the QR code again',
          ),
          const ErrorAction(
            label: 'Check QR Code',
            description: 'Make sure you\'re scanning the correct QR code',
          ),
        ];
      case QRCodeErrorType.cameraPermissionDenied:
        return [
          const ErrorAction(
            label: 'Grant Permission',
            description: 'Allow camera access in app settings',
          ),
        ];
      case QRCodeErrorType.cameraUnavailable:
        return [
          const ErrorAction(
            label: 'Restart App',
            description: 'Close and reopen the app',
          ),
        ];
    }
  }
}

enum QRCodeErrorType {
  invalidFormat(true),
  cameraPermissionDenied(false),
  cameraUnavailable(true);

  const QRCodeErrorType(this.isRetryable);
  final bool isRetryable;
}

/// Server related errors
class ServerError extends AppError {
  final ServerErrorType type;

  const ServerError({
    required super.message,
    super.userMessage,
    required this.type,
    super.context,
    super.originalException,
  }) : super(severity: ErrorSeverity.error);

  @override
  bool get isRetryable => type.isRetryable;

  @override
  List<ErrorAction> get suggestedActions {
    switch (type) {
      case ServerErrorType.portUnavailable:
        return [
          const ErrorAction(
            label: 'Try Again',
            description: 'The app will try a different port',
          ),
        ];
      case ServerErrorType.authenticationFailed:
        return [
          const ErrorAction(
            label: 'Rescan QR',
            description: 'Scan the QR code again',
          ),
          const ErrorAction(
            label: 'Ask for New QR',
            description: 'Ask the sender to generate a new QR code',
          ),
        ];
      case ServerErrorType.sessionExpired:
        return [
          const ErrorAction(
            label: 'Get New QR',
            description: 'Ask the sender to share the file again',
          ),
        ];
    }
  }
}

enum ServerErrorType {
  portUnavailable(true),
  authenticationFailed(true),
  sessionExpired(false);

  const ServerErrorType(this.isRetryable);
  final bool isRetryable;
}

/// Permission related errors
class PermissionError extends AppError {
  final PermissionErrorType type;

  const PermissionError({
    required super.message,
    super.userMessage,
    required this.type,
    super.context,
    super.originalException,
  }) : super(severity: ErrorSeverity.warning);

  @override
  bool get isRetryable => false;

  @override
  List<ErrorAction> get suggestedActions {
    switch (type) {
      case PermissionErrorType.camera:
        return [
          const ErrorAction(
            label: 'Open Settings',
            description: 'Grant camera permission in app settings',
          ),
        ];
      case PermissionErrorType.storage:
        return [
          const ErrorAction(
            label: 'Open Settings',
            description: 'Grant storage permission in app settings',
          ),
        ];
      case PermissionErrorType.network:
        return [
          const ErrorAction(
            label: 'Open Settings',
            description: 'Grant network permission in app settings',
          ),
        ];
    }
  }
}

enum PermissionErrorType { camera, storage, network }

/// Generic callback type for error actions
typedef VoidCallback = void Function();

/// Concrete implementation of AppError for generic errors
class GenericAppError extends AppError {
  const GenericAppError({
    required super.message,
    super.userMessage,
    super.severity = ErrorSeverity.error,
    super.context,
    super.originalException,
  });

  @override
  bool get isRetryable => true;

  @override
  List<ErrorAction> get suggestedActions => [
    const ErrorAction(label: 'Try Again', description: 'Retry the operation'),
  ];
}
