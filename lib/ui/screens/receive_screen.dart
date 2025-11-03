import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/permission_service.dart';
import '../../services/qr_code_service.dart';
import '../../services/file_download_service.dart';
import '../../services/file_operations_service.dart';
import '../../core/models/file_transfer_session.dart';
import '../../core/models/transfer_progress.dart';

enum ReceiveScreenState {
  requestingPermissions,
  scanning,
  connecting,
  downloading,
  completed,
  error,
}

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  final PermissionService _permissionService = PermissionService();
  final QRCodeService _qrCodeService = QRCodeService();
  final FileDownloadService _downloadService = FileDownloadService();

  MobileScannerController? _scannerController;
  ReceiveScreenState _currentState = ReceiveScreenState.requestingPermissions;

  String? _errorMessage;
  FileTransferSession? _session;
  TransferProgress? _progress;
  String? _downloadedFilePath;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _currentState = ReceiveScreenState.requestingPermissions;
      _errorMessage = null;
    });

    final hasCamera = await _permissionService.requestCameraPermissions();
    final hasStorage = await _permissionService.requestStoragePermissions();

    if (!hasCamera) {
      setState(() {
        _currentState = ReceiveScreenState.error;
        _errorMessage = _permissionService.getPermissionDenialMessage('camera');
      });
      return;
    }

    if (!hasStorage) {
      setState(() {
        _currentState = ReceiveScreenState.error;
        _errorMessage = _permissionService.getPermissionDenialMessage(
          'storage',
        );
      });
      return;
    }

    _startScanning();
  }

  void _startScanning() {
    setState(() {
      _currentState = ReceiveScreenState.scanning;
      _errorMessage = null;
    });

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) return;

    // Stop scanning immediately
    await _scannerController?.stop();

    setState(() {
      _currentState = ReceiveScreenState.connecting;
    });

    try {
      // Parse QR code data
      final session = _qrCodeService.parseQRData(qrData);

      // Validate connection
      final isConnected = await _downloadService.validateConnection(
        session.ipAddress,
        session.port,
        session.securityToken,
      );

      if (!isConnected) {
        throw Exception(
          'Cannot connect to sender device at ${session.ipAddress}:${session.port}',
        );
      }

      setState(() {
        _session = session;
      });

      // Show confirmation dialog before starting download
      final shouldDownload = await _showDownloadConfirmationDialog(session);
      if (shouldDownload) {
        await _startDownload(session);
      } else {
        _restartScanning();
      }
    } catch (e) {
      setState(() {
        _currentState = ReceiveScreenState.error;
        _errorMessage = _getErrorMessage(e);
      });
    }
  }

  String _getErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('FormatException')) {
      return 'Invalid QR code format. Please scan a valid file sharing QR code.';
    } else if (errorString.contains('Cannot connect')) {
      return 'Cannot connect to sender device. Make sure both devices are on the same network.';
    } else if (errorString.contains('timeout') ||
        errorString.contains('Timeout')) {
      return 'Connection timeout. Please check your network connection and try again.';
    } else if (errorString.contains('version')) {
      return 'Incompatible QR code version. Please update the app on both devices.';
    } else {
      return 'Failed to process QR code: $errorString';
    }
  }

  Future<bool> _showDownloadConfirmationDialog(
    FileTransferSession session,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: const Text('Download File?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to download this file?',
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.insert_drive_file,
                          size: 20,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            session.fileName,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.data_usage,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatFileSize(session.fileSize),
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.devices,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'From: ${session.ipAddress}',
                          style: TextStyle(
                            fontSize: 14,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The file will be saved to your Downloads folder.',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Download'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '$bytes B';
    }
  }

  Future<void> _startDownload(FileTransferSession session) async {
    try {
      // Check storage space before starting download
      final hasEnoughStorage = await _downloadService.hasEnoughStorage(
        session.fileSize,
      );
      if (!hasEnoughStorage) {
        setState(() {
          _currentState = ReceiveScreenState.error;
          _errorMessage =
              'Insufficient storage space. Need ${_formatFileSize(session.fileSize)} free space.';
        });
        return;
      }

      setState(() {
        _currentState = ReceiveScreenState.downloading;
        _progress = TransferProgress.start(session.fileSize);
      });

      // Listen to download progress
      _downloadService.progressStream.listen(
        (progress) {
          if (mounted) {
            setState(() {
              _progress = progress;
            });
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _currentState = ReceiveScreenState.error;
              _errorMessage = _getDownloadErrorMessage(error);
            });
          }
        },
      );

      // Start download with retry logic
      final downloadedPath = await _downloadService.downloadFileWithRetry(
        session,
        maxRetries: 3,
        retryDelay: const Duration(seconds: 2),
      );

      // Validate downloaded file
      final isValid = await _downloadService.validateDownloadedFile(
        downloadedPath,
        session.fileSize,
      );

      if (!isValid) {
        setState(() {
          _currentState = ReceiveScreenState.error;
          _errorMessage =
              'Downloaded file is corrupted or incomplete. Please try again.';
        });
        return;
      }

      setState(() {
        _currentState = ReceiveScreenState.completed;
        _downloadedFilePath = downloadedPath;
      });

      // Show completion notification
      _showDownloadCompletionNotification();
    } catch (e) {
      setState(() {
        _currentState = ReceiveScreenState.error;
        _errorMessage = _getDownloadErrorMessage(e);
      });
    }
  }

  String _getDownloadErrorMessage(dynamic error) {
    final errorString = error.toString();

    if (errorString.contains('NetworkException')) {
      return 'Network error occurred. Please check your connection and try again.';
    } else if (errorString.contains('StorageException')) {
      return errorString.replaceAll('StorageException: ', '');
    } else if (errorString.contains('timeout') ||
        errorString.contains('Timeout')) {
      return 'Download timeout. Please check your network connection and try again.';
    } else if (errorString.contains('Connection refused')) {
      return 'Cannot connect to sender device. Make sure the sender is still sharing the file.';
    } else if (errorString.contains('HTTP 403') ||
        errorString.contains('Forbidden')) {
      return 'Access denied. The security token may have expired.';
    } else if (errorString.contains('HTTP 404') ||
        errorString.contains('Not Found')) {
      return 'File not found on sender device. The transfer may have been cancelled.';
    } else {
      return 'Download failed: $errorString';
    }
  }

  void _cancelDownload() async {
    await _downloadService.cancelDownload();
    _restartScanning();
  }

  void _restartScanning() {
    setState(() {
      _currentState = ReceiveScreenState.scanning;
      _errorMessage = null;
      _session = null;
      _progress = null;
      _downloadedFilePath = null;
    });

    _scannerController?.start();
  }

  void _retryOperation() {
    switch (_currentState) {
      case ReceiveScreenState.error:
        if (_errorMessage?.contains('permission') == true) {
          _requestPermissions();
        } else if (_errorMessage?.contains('storage') == true ||
            _errorMessage?.contains('Storage') == true) {
          _showStorageErrorDialog();
        } else if (_session != null &&
            (_errorMessage?.contains('Download failed') == true ||
                _errorMessage?.contains('Network error') == true ||
                _errorMessage?.contains('timeout') == true)) {
          // Retry download for the same session
          _startDownload(_session!);
        } else {
          _restartScanning();
        }
        break;
      default:
        _restartScanning();
        break;
    }
  }

  void _showStorageErrorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.storage, color: colorScheme.error),
              const SizedBox(width: 8),
              const Text('Storage Issue'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _errorMessage ?? 'Storage error occurred',
                style: TextStyle(fontSize: 16, color: colorScheme.onSurface),
              ),
              const SizedBox(height: 16),
              Text(
                'Suggestions:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Free up storage space on your device\n'
                '• Delete unnecessary files or apps\n'
                '• Move files to cloud storage',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _restartScanning();
              },
              child: const Text('Try Again'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive File'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        actions: _buildAppBarActions(),
      ),
      body: _buildBody(theme, colorScheme),
    );
  }

  List<Widget>? _buildAppBarActions() {
    switch (_currentState) {
      case ReceiveScreenState.scanning:
        return [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController?.toggleTorch(),
            tooltip: 'Toggle flashlight',
          ),
        ];
      case ReceiveScreenState.downloading:
        return [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: _cancelDownload,
            tooltip: 'Cancel download',
          ),
        ];
      default:
        return null;
    }
  }

  Widget _buildBody(ThemeData theme, ColorScheme colorScheme) {
    switch (_currentState) {
      case ReceiveScreenState.requestingPermissions:
        return _buildPermissionRequestView(colorScheme);
      case ReceiveScreenState.scanning:
        return _buildScanningView(colorScheme);
      case ReceiveScreenState.connecting:
        return _buildConnectingView(colorScheme);
      case ReceiveScreenState.downloading:
        return _buildDownloadingView(colorScheme);
      case ReceiveScreenState.completed:
        return _buildCompletedView(colorScheme);
      case ReceiveScreenState.error:
        return _buildErrorView(colorScheme);
    }
  }

  Widget _buildPermissionRequestView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.security, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Requesting Permissions',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Camera and storage permissions are required to scan QR codes and save files.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningView(ColorScheme colorScheme) {
    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onQRCodeDetected,
              ),
              _buildScanningOverlay(colorScheme),
            ],
          ),
        ),
        Expanded(flex: 1, child: _buildScanningGuidance(colorScheme)),
      ],
    );
  }

  Widget _buildScanningOverlay(ColorScheme colorScheme) {
    return Container(
      decoration: ShapeDecoration(
        shape: QrScannerOverlayShape(
          borderColor: colorScheme.primary,
          borderRadius: 16,
          borderLength: 30,
          borderWidth: 4,
          cutOutSize: 250,
        ),
      ),
    );
  }

  Widget _buildScanningGuidance(ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.qr_code_scanner, size: 48, color: colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Point your camera at the QR code displayed on the sender\'s device',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectingView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_find, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Connecting...',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (_session != null) ...[
              Text(
                'Connecting to ${_session!.ipAddress}:${_session!.port}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'File: ${_session!.fileName}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadingView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.download, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Downloading File',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (_session != null) ...[
              Text(
                _session!.fileName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 24),
            ],
            if (_progress != null) ...[
              LinearProgressIndicator(
                value: _progress!.percentage / 100,
                backgroundColor: colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
              const SizedBox(height: 16),
              Text(
                '${_progress!.percentage.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _progress!.formattedProgress,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_progress!.formattedSpeed} • ETA: ${_progress!.formattedETA}',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: _cancelDownload,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedView(ColorScheme colorScheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: colorScheme.primary),
            const SizedBox(height: 24),
            Text(
              'Download Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            if (_session != null) ...[
              Text(
                _session!.fileName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Size: ${_progress?.formattedTotalSize ?? 'Unknown'}',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (_downloadedFilePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Saved to: ${FileOperationsService.getFolderDisplayName(_downloadedFilePath!)}',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_downloadedFilePath != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _openFile(_downloadedFilePath!),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open File'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _openFolder(_downloadedFilePath!),
                    icon: const Icon(Icons.folder_open, size: 18),
                    label: const Text('Open Folder'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: _restartScanning,
                  child: const Text('Scan Another'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(ColorScheme colorScheme) {
    final errorType = _getErrorType(_errorMessage);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getErrorIcon(errorType), size: 80, color: colorScheme.error),
            const SizedBox(height: 24),
            Text(
              _getErrorTitle(errorType),
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_getErrorGuidance(errorType).isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colorScheme.error.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 16,
                          color: colorScheme.onErrorContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Suggestions:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getErrorGuidance(errorType),
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
                FilledButton(
                  onPressed: _retryOperation,
                  child: Text(_getRetryButtonText(errorType)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getErrorType(String? errorMessage) {
    if (errorMessage == null) return 'unknown';

    final message = errorMessage.toLowerCase();
    if (message.contains('permission')) return 'permission';
    if (message.contains('storage') || message.contains('space'))
      return 'storage';
    if (message.contains('network') || message.contains('connection'))
      return 'network';
    if (message.contains('qr') || message.contains('format')) return 'qr';
    if (message.contains('timeout')) return 'timeout';
    if (message.contains('token') || message.contains('access denied'))
      return 'security';
    if (message.contains('not found') || message.contains('cancelled'))
      return 'file_not_found';
    return 'unknown';
  }

  IconData _getErrorIcon(String errorType) {
    switch (errorType) {
      case 'permission':
        return Icons.security;
      case 'storage':
        return Icons.storage;
      case 'network':
        return Icons.wifi_off;
      case 'qr':
        return Icons.qr_code_scanner;
      case 'timeout':
        return Icons.timer_off;
      case 'security':
        return Icons.lock;
      case 'file_not_found':
        return Icons.file_present;
      default:
        return Icons.error_outline;
    }
  }

  String _getErrorTitle(String errorType) {
    switch (errorType) {
      case 'permission':
        return 'Permission Required';
      case 'storage':
        return 'Storage Issue';
      case 'network':
        return 'Connection Problem';
      case 'qr':
        return 'QR Code Error';
      case 'timeout':
        return 'Connection Timeout';
      case 'security':
        return 'Access Denied';
      case 'file_not_found':
        return 'File Not Available';
      default:
        return 'Error';
    }
  }

  String _getErrorGuidance(String errorType) {
    switch (errorType) {
      case 'permission':
        return '• Grant camera and storage permissions in Settings\n'
            '• Restart the app after granting permissions';
      case 'storage':
        return '• Free up storage space on your device\n'
            '• Delete unnecessary files or apps\n'
            '• Move files to cloud storage';
      case 'network':
        return '• Check your Wi-Fi connection\n'
            '• Make sure both devices are on the same network\n'
            '• Move closer to the sender device';
      case 'qr':
        return '• Make sure the QR code is clearly visible\n'
            '• Check that both apps are up to date\n'
            '• Ask the sender to generate a new QR code';
      case 'timeout':
        return '• Check your network connection\n'
            '• Move closer to the sender device\n'
            '• Ask the sender to restart sharing';
      case 'security':
        return '• Ask the sender to generate a new QR code\n'
            '• Make sure you scan the QR code quickly\n'
            '• Check that both devices have the same app version';
      case 'file_not_found':
        return '• Ask the sender to restart file sharing\n'
            '• Make sure the sender hasn\'t cancelled the transfer\n'
            '• Try scanning the QR code again';
      default:
        return '';
    }
  }

  String _getRetryButtonText(String errorType) {
    switch (errorType) {
      case 'permission':
        return 'Grant Permissions';
      case 'storage':
        return 'Check Storage';
      case 'network':
      case 'timeout':
        return 'Retry Connection';
      case 'qr':
        return 'Scan Again';
      case 'security':
      case 'file_not_found':
        return 'Scan New QR';
      default:
        return 'Retry';
    }
  }

  void _openFile(String filePath) async {
    try {
      final success = await FileOperationsService.openFile(filePath);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not open file. No suitable app found.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openFolder(String filePath) async {
    try {
      final success = await FileOperationsService.openFolder(filePath);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Could not open folder. No file manager found.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening folder: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showDownloadCompletionNotification() {
    if (!mounted) return;

    final fileName = _session?.fileName ?? 'File';
    final fileSize = _progress?.formattedTotalSize ?? '';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Download Complete',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  if (fileSize.isNotEmpty)
                    Text(
                      '$fileName ($fileSize)',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        action: _downloadedFilePath != null
            ? SnackBarAction(
                label: 'Open Folder',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  _openFolder(_downloadedFilePath!);
                },
              )
            : SnackBarAction(
                label: 'OK',
                textColor: Colors.white,
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
      ),
    );
  }
}

/// Custom shape for QR scanner overlay
class QrScannerOverlayShape extends ShapeBorder {
  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 3.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    Path getLeftTopPath(Rect rect) {
      return Path()
        ..moveTo(rect.left, rect.bottom)
        ..lineTo(rect.left, rect.top + borderRadius)
        ..quadraticBezierTo(
          rect.left,
          rect.top,
          rect.left + borderRadius,
          rect.top,
        )
        ..lineTo(rect.right, rect.top);
    }

    return getLeftTopPath(rect)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top);
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final borderWidthSize = width / 2;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final mBorderLength = borderLength > borderWidthSize / 2
        ? borderWidthSize / 2
        : borderLength;
    final mCutOutSize = cutOutSize < width ? cutOutSize : width - borderOffset;

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final boxPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.dstOut;

    final cutOutRect = Rect.fromLTWH(
      rect.left + width / 2 - mCutOutSize / 2 + borderOffset,
      rect.top + height / 2 - mCutOutSize / 2 + borderOffset,
      mCutOutSize - borderOffset * 2,
      mCutOutSize - borderOffset * 2,
    );

    canvas
      ..saveLayer(rect, backgroundPaint)
      ..drawRect(rect, backgroundPaint)
      ..drawRRect(
        RRect.fromRectAndRadius(cutOutRect, Radius.circular(borderRadius)),
        boxPaint,
      )
      ..restore();

    // Draw corner borders
    final path = Path()
      // Top left
      ..moveTo(
        cutOutRect.left - borderOffset,
        cutOutRect.top - borderOffset + mBorderLength,
      )
      ..lineTo(
        cutOutRect.left - borderOffset,
        cutOutRect.top - borderOffset + borderRadius,
      )
      ..quadraticBezierTo(
        cutOutRect.left - borderOffset,
        cutOutRect.top - borderOffset,
        cutOutRect.left - borderOffset + borderRadius,
        cutOutRect.top - borderOffset,
      )
      ..lineTo(
        cutOutRect.left - borderOffset + mBorderLength,
        cutOutRect.top - borderOffset,
      )
      // Top right
      ..moveTo(
        cutOutRect.right + borderOffset - mBorderLength,
        cutOutRect.top - borderOffset,
      )
      ..lineTo(
        cutOutRect.right + borderOffset - borderRadius,
        cutOutRect.top - borderOffset,
      )
      ..quadraticBezierTo(
        cutOutRect.right + borderOffset,
        cutOutRect.top - borderOffset,
        cutOutRect.right + borderOffset,
        cutOutRect.top - borderOffset + borderRadius,
      )
      ..lineTo(
        cutOutRect.right + borderOffset,
        cutOutRect.top - borderOffset + mBorderLength,
      )
      // Bottom right
      ..moveTo(
        cutOutRect.right + borderOffset,
        cutOutRect.bottom + borderOffset - mBorderLength,
      )
      ..lineTo(
        cutOutRect.right + borderOffset,
        cutOutRect.bottom + borderOffset - borderRadius,
      )
      ..quadraticBezierTo(
        cutOutRect.right + borderOffset,
        cutOutRect.bottom + borderOffset,
        cutOutRect.right + borderOffset - borderRadius,
        cutOutRect.bottom + borderOffset,
      )
      ..lineTo(
        cutOutRect.right + borderOffset - mBorderLength,
        cutOutRect.bottom + borderOffset,
      )
      // Bottom left
      ..moveTo(
        cutOutRect.left - borderOffset + mBorderLength,
        cutOutRect.bottom + borderOffset,
      )
      ..lineTo(
        cutOutRect.left - borderOffset + borderRadius,
        cutOutRect.bottom + borderOffset,
      )
      ..quadraticBezierTo(
        cutOutRect.left - borderOffset,
        cutOutRect.bottom + borderOffset,
        cutOutRect.left - borderOffset,
        cutOutRect.bottom + borderOffset - borderRadius,
      )
      ..lineTo(
        cutOutRect.left - borderOffset,
        cutOutRect.bottom + borderOffset - mBorderLength,
      );

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
