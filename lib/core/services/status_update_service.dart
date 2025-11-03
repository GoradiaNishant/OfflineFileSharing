import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/transfer_progress.dart';
import '../models/file_transfer_session.dart';
import 'notification_service.dart';

/// Service for managing real-time status updates and notifications
class StatusUpdateService {
  static final StatusUpdateService _instance = StatusUpdateService._internal();
  factory StatusUpdateService() => _instance;
  StatusUpdateService._internal();

  final StreamController<TransferStatusUpdate> _statusController =
      StreamController<TransferStatusUpdate>.broadcast();

  final StreamController<TransferProgress> _progressController =
      StreamController<TransferProgress>.broadcast();

  final NotificationService _notificationService = NotificationService();

  Timer? _progressUpdateTimer;
  TransferProgress? _lastProgress;
  TransferState _currentState = TransferState.idle;
  String? _currentFileName;

  /// Stream of status updates
  Stream<TransferStatusUpdate> get statusStream => _statusController.stream;

  /// Stream of progress updates
  Stream<TransferProgress> get progressStream => _progressController.stream;

  /// Current transfer state
  TransferState get currentState => _currentState;

  /// Updates the transfer status
  void updateStatus({
    required TransferState state,
    String? message,
    String? fileName,
    Map<String, dynamic>? metadata,
  }) {
    _currentState = state;
    _currentFileName = fileName ?? _currentFileName;

    final update = TransferStatusUpdate(
      state: state,
      message: message,
      fileName: _currentFileName,
      timestamp: DateTime.now(),
      metadata: metadata,
    );

    _statusController.add(update);

    // Handle status-specific notifications
    _handleStatusNotification(update);

    if (kDebugMode) {
      print('Status Update: ${state.name} - $message');
    }
  }

  /// Updates transfer progress
  void updateProgress(TransferProgress progress) {
    _lastProgress = progress;
    _progressController.add(progress);

    // Update status if transferring
    if (_currentState == TransferState.transferring) {
      updateStatus(
        state: TransferState.transferring,
        message: 'Transferring... ${progress.formattedProgress}',
      );
    }

    // Show periodic progress notifications for long transfers
    _showProgressNotificationIfNeeded(progress);
  }

  /// Starts a file server session
  void startServerSession(FileTransferSession session) {
    updateStatus(
      state: TransferState.serverStarted,
      message: 'Server started for "${session.fileName}"',
      fileName: session.fileName,
      metadata: {
        'sessionId': session.sessionId,
        'ipAddress': session.ipAddress,
        'port': session.port,
        'fileSize': session.fileSize,
      },
    );

    _notificationService.showServerStarted(
      fileName: session.fileName,
      onStop: () => stopServerSession(),
    );
  }

  /// Stops the server session
  void stopServerSession() {
    updateStatus(
      state: TransferState.serverStopped,
      message: 'File sharing stopped',
    );

    _stopProgressUpdates();
  }

  /// Starts a download session
  void startDownloadSession(FileTransferSession session) {
    updateStatus(
      state: TransferState.connecting,
      message: 'Connecting to ${session.ipAddress}...',
      fileName: session.fileName,
      metadata: {
        'sessionId': session.sessionId,
        'ipAddress': session.ipAddress,
        'port': session.port,
        'fileSize': session.fileSize,
      },
    );
  }

  /// Connection established
  void connectionEstablished(String deviceInfo) {
    updateStatus(
      state: TransferState.connected,
      message: 'Connected to $deviceInfo',
    );

    _notificationService.showConnectionEstablished(deviceInfo: deviceInfo);
  }

  /// Transfer started
  void transferStarted() {
    updateStatus(
      state: TransferState.transferring,
      message: 'Transfer started...',
    );

    _startProgressUpdates();
  }

  /// Transfer completed successfully
  void transferCompleted({
    required String fileName,
    required String filePath,
    VoidCallback? onOpenFile,
    VoidCallback? onOpenFolder,
  }) {
    updateStatus(
      state: TransferState.completed,
      message: 'Transfer completed successfully',
      metadata: {'filePath': filePath},
    );

    _notificationService.showTransferComplete(
      fileName: fileName,
      filePath: filePath,
      onOpenFile: onOpenFile,
      onOpenFolder: onOpenFolder,
    );

    _stopProgressUpdates();
  }

  /// Transfer failed
  void transferFailed({required String error, VoidCallback? onRetry}) {
    updateStatus(
      state: TransferState.error,
      message: 'Transfer failed: $error',
      metadata: {'error': error},
    );

    if (_currentFileName != null) {
      _notificationService.showTransferFailed(
        fileName: _currentFileName!,
        error: error,
        onRetry: onRetry,
      );
    }

    _stopProgressUpdates();
  }

  /// Transfer cancelled
  void transferCancelled() {
    updateStatus(state: TransferState.cancelled, message: 'Transfer cancelled');

    _stopProgressUpdates();
  }

  /// QR code scanned successfully
  void qrCodeScanned(FileTransferSession session) {
    updateStatus(
      state: TransferState.qrScanned,
      message: 'QR code scanned for "${session.fileName}"',
      fileName: session.fileName,
      metadata: {'sessionId': session.sessionId, 'fileSize': session.fileSize},
    );
  }

  /// Network error occurred
  void networkError(String error) {
    updateStatus(
      state: TransferState.error,
      message: 'Network error: $error',
      metadata: {'errorType': 'network', 'error': error},
    );
  }

  /// Permission error occurred
  void permissionError(String permission, String error) {
    updateStatus(
      state: TransferState.error,
      message: 'Permission error: $error',
      metadata: {
        'errorType': 'permission',
        'permission': permission,
        'error': error,
      },
    );
  }

  /// Resets the service to idle state
  void reset() {
    updateStatus(state: TransferState.idle, message: 'Ready');

    _stopProgressUpdates();
    _currentFileName = null;
    _lastProgress = null;
  }

  /// Handles status-specific notifications
  void _handleStatusNotification(TransferStatusUpdate update) {
    switch (update.state) {
      case TransferState.error:
        // Error notifications are handled by specific error methods
        break;
      case TransferState.completed:
        // Completion notifications are handled by transferCompleted method
        break;
      case TransferState.connected:
        // Connection notifications are handled by connectionEstablished method
        break;
      default:
        // Other states don't need automatic notifications
        break;
    }
  }

  /// Shows progress notifications for long transfers
  void _showProgressNotificationIfNeeded(TransferProgress progress) {
    // Show progress notification every 25% for transfers > 10MB
    if (_currentFileName != null && progress.totalBytes > 10 * 1024 * 1024) {
      final percentage = progress.percentage;
      final milestones = [25.0, 50.0, 75.0];

      for (final milestone in milestones) {
        if (percentage >= milestone &&
            (_lastProgress?.percentage ?? 0) < milestone) {
          _notificationService.showInfo(
            title: 'Transfer Progress',
            message: '${milestone.toInt()}% of "$_currentFileName" transferred',
            duration: const Duration(seconds: 2),
          );
          break;
        }
      }
    }
  }

  /// Starts periodic progress updates
  void _startProgressUpdates() {
    _stopProgressUpdates();

    _progressUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_lastProgress != null && !_lastProgress!.isComplete) {
        // Update progress with current time for accurate speed calculation
        final updatedProgress = _lastProgress!.copyWith(
          lastUpdateTime: DateTime.now(),
        );
        _progressController.add(updatedProgress);
      }
    });
  }

  /// Stops periodic progress updates
  void _stopProgressUpdates() {
    _progressUpdateTimer?.cancel();
    _progressUpdateTimer = null;
  }

  /// Disposes of the service
  void dispose() {
    _stopProgressUpdates();
    _statusController.close();
    _progressController.close();
  }
}

/// Transfer state enumeration
enum TransferState {
  idle,
  serverStarted,
  serverStopped,
  qrScanned,
  connecting,
  connected,
  transferring,
  completed,
  error,
  cancelled,
}

/// Transfer status update data class
class TransferStatusUpdate {
  final TransferState state;
  final String? message;
  final String? fileName;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  const TransferStatusUpdate({
    required this.state,
    this.message,
    this.fileName,
    required this.timestamp,
    this.metadata,
  });

  @override
  String toString() {
    return 'TransferStatusUpdate(state: $state, message: $message, fileName: $fileName)';
  }
}

/// Extension for transfer state display
extension TransferStateExtension on TransferState {
  String get displayName {
    switch (this) {
      case TransferState.idle:
        return 'Ready';
      case TransferState.serverStarted:
        return 'Sharing File';
      case TransferState.serverStopped:
        return 'Sharing Stopped';
      case TransferState.qrScanned:
        return 'QR Code Scanned';
      case TransferState.connecting:
        return 'Connecting';
      case TransferState.connected:
        return 'Connected';
      case TransferState.transferring:
        return 'Transferring';
      case TransferState.completed:
        return 'Completed';
      case TransferState.error:
        return 'Error';
      case TransferState.cancelled:
        return 'Cancelled';
    }
  }

  bool get isActive {
    switch (this) {
      case TransferState.serverStarted:
      case TransferState.connecting:
      case TransferState.connected:
      case TransferState.transferring:
        return true;
      default:
        return false;
    }
  }

  bool get isError {
    return this == TransferState.error;
  }

  bool get isComplete {
    return this == TransferState.completed;
  }
}
