import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/models/file_transfer_session.dart';
import '../core/models/transfer_progress.dart';
import 'services/status_update_service.dart';

/// Global application state management
class AppState extends ChangeNotifier {
  static final AppState _instance = AppState._internal();
  factory AppState() => _instance;
  AppState._internal() {
    // Listen to status updates
    _statusUpdateService.statusStream.listen((update) {
      _currentStatus = update;
      notifyListeners();
    });

    // Listen to progress updates
    _statusUpdateService.progressStream.listen((progress) {
      _transferProgress = progress;
      notifyListeners();
    });
  }

  final StatusUpdateService _statusUpdateService = StatusUpdateService();

  // Transfer session state
  FileTransferSession? _currentSession;
  TransferProgress? _transferProgress;
  String? _errorMessage;
  bool _isTransferActive = false;
  TransferStatusUpdate? _currentStatus;

  // Getters
  FileTransferSession? get currentSession => _currentSession;
  TransferProgress? get transferProgress => _transferProgress;
  String? get errorMessage => _errorMessage;
  bool get isTransferActive => _isTransferActive;
  TransferStatusUpdate? get currentStatus => _currentStatus;
  TransferState get transferState => _statusUpdateService.currentState;

  // Status service getter
  StatusUpdateService get statusService => _statusUpdateService;

  // Session management
  void setCurrentSession(FileTransferSession? session) {
    _currentSession = session;
    _isTransferActive = session != null;
    notifyListeners();
  }

  void updateTransferProgress(TransferProgress progress) {
    _transferProgress = progress;
    _statusUpdateService.updateProgress(progress);
    notifyListeners();
  }

  void setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSession() {
    _currentSession = null;
    _transferProgress = null;
    _isTransferActive = false;
    _statusUpdateService.reset();
    notifyListeners();
  }

  void reset() {
    _currentSession = null;
    _transferProgress = null;
    _errorMessage = null;
    _isTransferActive = false;
    _statusUpdateService.reset();
    notifyListeners();
  }

  // Status update methods
  void updateStatus({
    required TransferState state,
    String? message,
    String? fileName,
    Map<String, dynamic>? metadata,
  }) {
    _statusUpdateService.updateStatus(
      state: state,
      message: message,
      fileName: fileName,
      metadata: metadata,
    );
  }

  // Convenience methods for common status updates
  void startServerSession(FileTransferSession session) {
    setCurrentSession(session);
    _statusUpdateService.startServerSession(session);
  }

  void stopServerSession() {
    _statusUpdateService.stopServerSession();
    clearSession();
  }

  void startDownloadSession(FileTransferSession session) {
    setCurrentSession(session);
    _statusUpdateService.startDownloadSession(session);
  }

  void connectionEstablished(String deviceInfo) {
    _statusUpdateService.connectionEstablished(deviceInfo);
  }

  void transferStarted() {
    _statusUpdateService.transferStarted();
  }

  void transferCompleted({
    required String fileName,
    required String filePath,
    VoidCallback? onOpenFile,
    VoidCallback? onOpenFolder,
  }) {
    _statusUpdateService.transferCompleted(
      fileName: fileName,
      filePath: filePath,
      onOpenFile: onOpenFile,
      onOpenFolder: onOpenFolder,
    );
  }

  void transferFailed({required String error, VoidCallback? onRetry}) {
    _statusUpdateService.transferFailed(error: error, onRetry: onRetry);
  }

  void transferCancelled() {
    _statusUpdateService.transferCancelled();
    clearSession();
  }

  void qrCodeScanned(FileTransferSession session) {
    _statusUpdateService.qrCodeScanned(session);
  }

  void networkError(String error) {
    _statusUpdateService.networkError(error);
  }

  void permissionError(String permission, String error) {
    _statusUpdateService.permissionError(permission, error);
  }
}
